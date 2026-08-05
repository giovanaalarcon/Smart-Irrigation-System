import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUIDs precisam bater exatamente com os definidos no firmware do ESP32.
class BleUuids {
  static final Guid service = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final Guid sensorChar = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8'); // notify
  static final Guid commandChar = Guid('0a3f7f28-6b8e-4f60-9e3a-6f9a2d8c1a11'); // write
}

/// Snapshot do estado lido do ESP32 + decisão calculada.
class IrrigacaoState {
  final double humidity;
  final bool boiaOk;
  final int bomba;
  final DateTime timestamp;

  IrrigacaoState({
    required this.humidity,
    required this.boiaOk,
    required this.bomba,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get irrigando => bomba > 0;
}

class IrrigacaoBleController {
  final BluetoothDevice device;

  BluetoothCharacteristic? _sensorChar;
  BluetoothCharacteristic? _commandChar;

  final _stateController = StreamController<IrrigacaoState>.broadcast();
  Stream<IrrigacaoState> get stateStream => _stateController.stream;

  int _ultimoPwmEnviado = -1;

  IrrigacaoState? lastState;

  IrrigacaoBleController(this.device);

  Future<void> connectAndListen() async {
    await device.connect(autoConnect: false);

    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == BleUuids.service);

    _sensorChar = service.characteristics
        .firstWhere((c) => c.uuid == BleUuids.sensorChar);
    _commandChar = service.characteristics
        .firstWhere((c) => c.uuid == BleUuids.commandChar);

    await _sensorChar!.setNotifyValue(true);
    _sensorChar!.lastValueStream.listen(_onSensorData);
  }

  void _onSensorData(List<int> bytes) {
    if (bytes.isEmpty) return;

    final jsonStr = utf8.decode(bytes);
    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return; // payload incompleto/corrompido, ignora esse pacote
    }

    final humidity = (data['humidity'] as num).toDouble();
    final String water = (data['water']?.toString().trim().toUpperCase() ?? 'LOW');
    final bool boiaOk = water == 'LOW';

    final state = _decide(humidity: humidity, boiaOk: boiaOk);
    lastState = state;
    _stateController.add(state);

    _sendCommand(state);
  }

  /// Regra de decisão:
  /// - boia baixa  -> LEDALTO on, bomba 0
  /// - umidade<75  -> LEDALTO off, bomba 60
  /// - umidade<85  -> LEDALTO off, bomba 25
  /// - caso contrário -> LEDALTO off, bomba 0

  IrrigacaoState _decide({required double humidity, required bool boiaOk,}) {
    int bomba;

    if (!boiaOk) {
      bomba = 0;
    } else if (humidity < 75) {
      bomba = 60;
    } else if (humidity < 85) {
      bomba = 25;
    } else {
      bomba = 0;
    }

    return IrrigacaoState(
      humidity: humidity,
      boiaOk: boiaOk,
      bomba: bomba,
    );
  }

  Future<void> _sendCommand(IrrigacaoState state) async {
    if (_commandChar == null) return;

    if (state.bomba == _ultimoPwmEnviado) {
      return;
    }

    _ultimoPwmEnviado = state.bomba;

    final cmd = 'B:${state.bomba}';

    await _commandChar!.write(
      Uint8List.fromList(utf8.encode(cmd)),
      withoutResponse: false,
    );

    print('PWM enviado: ${state.bomba}');
  }

  Future<void> dispose() async {
    await _stateController.close();
    await device.disconnect();
  }
}