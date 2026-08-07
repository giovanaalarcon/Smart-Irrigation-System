import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/configuracao_cultivo.dart';
import 'irrigacao_engine.dart';

class BleUuids {
  static final Guid service =Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final Guid sensorChar =Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');
  static final Guid commandChar =Guid('0a3f7f28-6b8e-4f60-9e3a-6f9a2d8c1a11');
}

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
  final ConfiguracaoCultivo configuracao;
  late final IrrigacaoEngine engine;

  BluetoothCharacteristic? _sensorChar;
  BluetoothCharacteristic? _commandChar;
  StreamSubscription? _disconnectSubscription;
  final StreamController<IrrigacaoState>
      _stateController =
      StreamController.broadcast();
  Stream<IrrigacaoState> get stateStream =>_stateController.stream;
  IrrigacaoState? lastState;
  bool _reconnecting = false;

  IrrigacaoBleController({
    required this.device,
    required this.configuracao,
  }) {
    engine =IrrigacaoEngine(configuracao);
  }

  Future<void> connectAndListen() async {
    await device.connect(
      autoConnect: false,
    );
    await _discoverServices();
    _disconnectSubscription = device.connectionState.listen((state) {
      if(state ==BluetoothConnectionState.disconnected){
        _handleDisconnect();
      }
    });
  }

  Future<void> _discoverServices() async {
    final services =
        await device.discoverServices();
    final service =
        services.firstWhere(
          (s) =>
              s.uuid == BleUuids.service,
        );
    _sensorChar = service.characteristics.firstWhere( (c) =>c.uuid == BleUuids.sensorChar, );
    _commandChar =
        service.characteristics.firstWhere(
          (c) =>
              c.uuid ==
              BleUuids.commandChar,
        );
    await _sensorChar!
        .setNotifyValue(true);
    _sensorChar!
        .lastValueStream
        .listen(_onSensorData);
  }

  void _onSensorData(
      List<int> bytes) {
    if(bytes.isEmpty)
      return;
    try {
      final json =
          utf8.decode(bytes);
      final data =
          jsonDecode(json);
      final humidity =
          (data['humidity'] as num)
          .toDouble();
      final water =
          data['water']
          .toString()
          .toUpperCase();
      final boiaOk =
          water == "LOW";
      final resultado = engine.calcularBomba(
          humidity: humidity,
          boiaOk: boiaOk,
        );

        final pwm = resultado.pwm;
        print(
            '''
            PWM enviado: $pwm
            (
            cultura=${resultado.cultura},
            solo=${resultado.solo},
            fase=${resultado.fase},
            dia=${resultado.dias},
            limiar=${resultado.limite.toStringAsFixed(1)}%,
            umidade=${humidity.toStringAsFixed(1)}%
            )
            '''
          );
      final bomba = resultado.pwm;
      final state =
          IrrigacaoState(
            humidity: humidity,
            boiaOk: boiaOk,
            bomba: bomba,
          );
      lastState = state;
      _stateController.add(state);
      _sendPumpCommand(bomba);
    }
    catch(e){
      print("Erro BLE dados: $e");
    }
  }

  Future<void> _sendPumpCommand(
      int pwm) async {
    if(_commandChar == null)
      return;
    final comando = "B:$pwm";
    await _commandChar!.write(
      Uint8List.fromList(
        utf8.encode(comando),
      ),
      withoutResponse:false,
    );
  }

  Future<void> stopPump()
  async {
    try{
      await _sendPumpCommand(0);
    }
    catch(_){}
  }

  void _handleDisconnect(){
    print("BLE caiu");
    stopPump();
    _tryReconnect();
  }
  Future<void> _tryReconnect()
  async {
    if(_reconnecting)
      return;
    _reconnecting=true;
    while(_reconnecting){
      try{
        print("Tentando reconectar...");
        await Future.delayed(
          const Duration(
            seconds:5
          )
        );
        await device.connect(
          autoConnect:false,
        );
        await _discoverServices();
        print("Reconectado");
        _reconnecting=false;
      }
      catch(e){
        print("Falha reconexão: $e");
      }
    }
  }
  Future<void> dispose() async {
    _reconnecting=false;
    await stopPump();
    await _disconnectSubscription?.cancel();
    await _stateController.close();
    await device.disconnect();
  }
}

