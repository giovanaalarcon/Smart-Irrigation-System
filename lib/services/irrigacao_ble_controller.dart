import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/configuracao_cultivo.dart';
import '../models/weather_hour.dart';
import 'irrigacao_engine.dart';
import 'weather_service.dart';

/// UUIDs usados na comunicação BLE com o ESP32.
class BleUuids {
  static final Guid service =
      Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');

  /// ESP32 -> Flutter
  ///
  /// Exemplo de dado recebido:
  /// {
  ///   "humidity": 57.4,
  ///   "boia": "HIGH"
  /// }
  static final Guid sensorChar =
      Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  /// Flutter -> ESP32
  ///
  /// Envia:
  /// B:80
  /// B:150
  /// B:0
  static final Guid commandChar =
      Guid('0a3f7f28-6b8e-4f60-9e3a-6f9a2d8c1a11');
}

/// Estado atual da irrigação.
class IrrigacaoState {
  final double humidity;
  final bool boiaOk;
  final int bomba;
  final DateTime timestamp;
  // Informações da decisão da Engine
  final double limite;
  final double mad;
  final String fase;
  final int dias;
  final String cultura;
  final String solo;

  final bool irrigar;
  final String motivo;

  // Informações do clima
  final bool chuvaProxima;
  final double? temperaturaMedia;
  final int probabilidadeChuva;
  final double precipitacaoTotal;

  IrrigacaoState({
    required this.humidity,
    required this.boiaOk,
    required this.bomba,

    required this.limite,
    required this.mad,
    required this.fase,
    required this.dias,
    required this.cultura,
    required this.solo,

    required this.irrigar,
    required this.motivo,

    required this.chuvaProxima,
    required this.temperaturaMedia,
    required this.probabilidadeChuva,
    required this.precipitacaoTotal,

    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get irrigando => bomba > 0;

  @override
  String toString() {
    return '''
      IrrigacaoState(
        umidade: ${humidity.toStringAsFixed(1)}%,
        boiaOk: $boiaOk,
        bomba: $bomba,
        limite: ${limite.toStringAsFixed(1)}%,
        MAD: ${(mad * 100).toStringAsFixed(0)}%,
        cultura: $cultura,
        solo: $solo,
        fase: $fase,
        dia: $dias,
        irrigando: $irrigando,
        motivo: $motivo,
        chuvaProxima: $chuvaProxima,
        temperaturaMedia: $temperaturaMedia,
        probabilidadeChuva: $probabilidadeChuva%,
        precipitacaoTotal: $precipitacaoTotal mm
      )
    ''';
  }
}

class IrrigacaoBleController {
  final BluetoothDevice device;

  /// Configuração escolhida pelo usuário.
  final ConfiguracaoCultivo configuracao;

  /// Cidade usada para consultar a previsão.
  final String cidade;

  late final IrrigacaoEngine _engine;

  final WeatherService _weatherService = WeatherService();

  BluetoothCharacteristic? _sensorChar;
  BluetoothCharacteristic? _commandChar;

  StreamSubscription<List<int>>? _sensorSubscription;
  StreamSubscription<BluetoothConnectionState>?
      _connectionSubscription;

  final StreamController<IrrigacaoState> _stateController =
      StreamController<IrrigacaoState>.broadcast();

  Stream<IrrigacaoState> get stateStream =>
      _stateController.stream;

  IrrigacaoState? lastState;

  bool _disposed = false;
  bool _connecting = false;
  bool _reconnecting = false;

  Timer? _reconnectTimer;

  /// Último PWM enviado para evitar mandar o mesmo valor
  /// repetidamente.
  int _ultimoPwmEnviado = -1;

  /// Previsão armazenada em memória.
  List<WeatherHour> _previsao = [];

  /// Momento da última consulta à API.
  DateTime? _ultimaAtualizacaoClima;

  /// A API não precisa ser consultada a cada leitura do sensor.
  static const Duration _intervaloAtualizacaoClima =
      Duration(minutes: 15);

  IrrigacaoBleController({
    required this.device,
    required this.configuracao,
    required this.cidade,
  }) {
    _engine = IrrigacaoEngine(configuracao);
  }

  // ============================================================
  // CONEXÃO BLE
  // ============================================================

  Future<void> connectAndListen() async {
    if (_disposed) return;

    if (_connecting) return;

    _connecting = true;

    try {
      await _cancelSubscriptions();

      try {
        await device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 10),
        );
      } catch (e) {
        // Caso o dispositivo já esteja conectado, o
        // flutter_blue_plus pode gerar uma exceção.
        final estado = await device.connectionState.first;

        if (estado != BluetoothConnectionState.connected) {
          rethrow;
        }
      }

      if (_disposed) return;

      final services = await device.discoverServices();

      final service = services.firstWhere(
        (s) => s.uuid == BleUuids.service,
        orElse: () {
          throw Exception(
            'Serviço BLE de irrigação não encontrado.',
          );
        },
      );

      _sensorChar = service.characteristics.firstWhere(
        (c) => c.uuid == BleUuids.sensorChar,
        orElse: () {
          throw Exception(
            'Característica do sensor não encontrada.',
          );
        },
      );

      _commandChar = service.characteristics.firstWhere(
        (c) => c.uuid == BleUuids.commandChar,
        orElse: () {
          throw Exception(
            'Característica de comando não encontrada.',
          );
        },
      );

      await _sensorChar!.setNotifyValue(true);

      _sensorSubscription =
          _sensorChar!.lastValueStream.listen(
        _onSensorData,
        onError: (error) {
          print('Erro no recebimento dos dados BLE: $error');
          _handleBleFailure();
        },
      );

      _connectionSubscription =
          device.connectionState.listen(
        _onConnectionState,
      );

      _reconnecting = false;

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Sempre começa com a bomba desligada.
      await _sendPumpCommand(0);

      print('BLE conectado com sucesso.');

      // Busca o clima assim que conectar.
      await _atualizarClima(force: true);
    } finally {
      _connecting = false;
    }
  }

  // ============================================================
  // ESTADO DA CONEXÃO
  // ============================================================

  void _onConnectionState(
    BluetoothConnectionState state,
  ) {
    print('Estado BLE: $state');

    if (state == BluetoothConnectionState.disconnected) {
      _handleBleFailure();
    }
  }

  void _handleBleFailure() {
    if (_disposed) return;

    print('BLE desconectado.');

    // Perdeu comunicação -> bomba desligada.
    _sendPumpCommand(0);

    _startReconnect();
  }

  // ============================================================
  // RECONEXÃO
  // ============================================================

  void _startReconnect() {
    if (_disposed) return;

    if (_reconnecting) return;

    _reconnecting = true;

    print('Iniciando tentativa de reconexão...');

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (_disposed) {
          _reconnectTimer?.cancel();
          return;
        }

        if (_connecting) return;

        try {
          final estado =
              await device.connectionState.first;

          if (estado ==
              BluetoothConnectionState.connected) {
            _reconnecting = false;
            _reconnectTimer?.cancel();
            return;
          }

          print('Tentando reconectar ao ESP32...');

          await connectAndListen();

          if (!_reconnecting) {
            _reconnectTimer?.cancel();
          }
        } catch (e) {
          print('Falha na reconexão: $e');
        }
      },
    );
  }

  // ============================================================
  // RECEBIMENTO DOS DADOS DO ESP32
  // ============================================================

  Future<void> _onSensorData(List<int> data) async {
    if (_disposed) return;

    if (data.isEmpty) return;

    try {
      final texto = utf8.decode(data).trim();

      print('Dados recebidos do ESP32: $texto');

      final json = jsonDecode(texto);

      final humidity = _lerUmidade(json);
      final boiaOk = _lerBoia(json);
      print('umidade: $humidity');
      print('boia: $boiaOk');
      if (humidity == null || boiaOk == null) {
        print('Dados BLE inválidos: $texto');
        return;
      }

      // Atualiza a previsão somente quando necessário.
      await _atualizarClima();

      // --------------------------------------------------------
      // DECISÃO
      // --------------------------------------------------------
      //
      // Aqui passamos a LISTA inteira de previsão para o engine.
      //
      // O engine então consegue analisar:
      //
      // - precipitação
      // - chance de chuva
      // - temperatura
      // - umidade
      // - boia
      // - cultura
      // - solo
      // - fase
      // - MAD
      //
      final resultado = _engine.calcularBomba(
        humidity: humidity,
        boiaOk: boiaOk,
        clima: _previsao,
      );

      // Pega apenas o horário mais próximo para exibir na Home.
      final climaAtual = _obterClimaMaisProximo();

     final state = IrrigacaoState(
      humidity: humidity,
      boiaOk: boiaOk,
      bomba: resultado.pwm,

      limite: resultado.limite,
      mad: _engine.fatorMAD(),
      fase: resultado.fase,
      dias: resultado.dias,
      cultura: resultado.cultura,
      solo: resultado.solo,

      irrigar: resultado.irrigar,
      motivo: resultado.motivo,

      chuvaProxima: resultado.chuvaProxima,
      temperaturaMedia: resultado.temperaturaMedia,
      probabilidadeChuva: resultado.probabilidadeChuva,
      precipitacaoTotal: resultado.precipitacaoTotal,
    );

      lastState = state;

      if (!_stateController.isClosed) {
        _stateController.add(state);
      }

      // Envia somente B:<PWM>.
      await _sendPumpCommand(resultado.pwm);

      _mostrarDiagnostico(
        humidity: humidity,
        boiaOk: boiaOk,
        resultado: resultado,
        clima: climaAtual,
      );
    } catch (e) {
      print('Erro ao processar dados BLE: $e');
    }
  }

  // ============================================================
  // WEATHER API
  // ============================================================

  Future<void> _atualizarClima({
    bool force = false,
  }) async {
    if (_disposed) return;

    final agora = DateTime.now();

    if (!force &&
        _ultimaAtualizacaoClima != null &&
        agora.difference(_ultimaAtualizacaoClima!) <
            _intervaloAtualizacaoClima) {
      return;
    }

    try {
      print(
        'Buscando previsão do tempo para $cidade...',
      );

      final previsao =
          await _weatherService.getForecast(cidade);

      if (_disposed) return;

      _previsao = previsao;
      _ultimaAtualizacaoClima = agora;

      print(
        'Previsão atualizada: '
        '${_previsao.length} horários.',
      );
    } catch (e) {
      print('Erro ao consultar WeatherAPI: $e');

      // Se a API falhar, mantemos a última previsão.
      // Assim o sistema não perde os dados que já tinha.
    }
  }

  /// Retorna a previsão cujo horário está mais próximo
  /// do momento atual.
  WeatherHour? _obterClimaMaisProximo() {
    if (_previsao.isEmpty) {
      return null;
    }

    final agora = DateTime.now();

    WeatherHour? melhor;
    Duration? menorDiferenca;

    for (final hora in _previsao) {
      DateTime? horario;

      try {
        horario = DateTime.parse(hora.time);
      } catch (_) {
        continue;
      }

      final diferenca =
          horario.difference(agora).abs();

      if (menorDiferenca == null ||
          diferenca < menorDiferenca) {
        menorDiferenca = diferenca;
        melhor = hora;
      }
    }

    return melhor;
  }

  // ============================================================
  // LEITURA DA UMIDADE
  // ============================================================

  double? _lerUmidade(
    Map<String, dynamic> json,
  ) {
    dynamic valor;

    if (json.containsKey('humidity')) {
      valor = json['humidity'];
    } else if (json.containsKey('umidade')) {
      valor = json['umidade'];
    } else if (json.containsKey('moisture')) {
      valor = json['moisture'];
    }

    if (valor == null) return null;

    if (valor is num) {
      return valor.toDouble().clamp(0.0, 100.0);
    }

    return double.tryParse(
      valor.toString(),
    )?.clamp(0.0, 100.0);
  }

  // ============================================================
  // LEITURA DA BOIA
  // ============================================================

  bool? _lerBoia(Map<String, dynamic> json) {
    dynamic valor;

    if (json.containsKey('water')) {
      valor = json['water'];
    } else if (json.containsKey('boia')) {
      valor = json['boia'];
    } else if (json.containsKey('boiaOk')) {
      valor = json['boiaOk'];
    } else if (json.containsKey('float')) {
      valor = json['float'];
    } else if (json.containsKey('floatState')) {
      valor = json['floatState'];
    }

    if (valor == null) return null;

    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor != 0;
    }

    final texto = valor.toString().trim().toUpperCase();

    if (texto == 'LOW') return true;
    if (texto == 'HIGH') return false;

    if (texto == '0') return true;
    if (texto == '1') return false;

    if (texto == 'FALSE') return true;
    if (texto == 'TRUE') return false;

    return null;
  }

  // ============================================================
  // ENVIO DO PWM
  // ============================================================

  Future<void> _sendPumpCommand(int pwm) async {
    if (_disposed) return;

    pwm = pwm.clamp(0, 255);

    if (_commandChar == null) {
      print(
        'PWM não enviado: BLE não conectado.',
      );
      return;
    }

    // Se já mandamos esse mesmo PWM, não precisa
    // mandar novamente.
    if (pwm == _ultimoPwmEnviado) {
      return;
    }

    final comando = 'B:$pwm';

    try {
      await _commandChar!.write(
        utf8.encode(comando),
        withoutResponse: false,
      );

      _ultimoPwmEnviado = pwm;

      print('PWM enviado: $pwm');
    } catch (e) {
      print('Erro ao enviar PWM: $e');

      _handleBleFailure();
    }
  }

  // ============================================================
  // DIAGNÓSTICO
  // ============================================================

  void _mostrarDiagnostico({
    required double humidity,
    required bool boiaOk,
    required ResultadoIrrigacao resultado,
    required WeatherHour? clima,
  }) {
    print('''
========================================
IRRIGAÇÃO
========================================

Cultura: ${resultado.cultura}
Solo: ${resultado.solo}
Fase: ${resultado.fase}
Dia: ${resultado.dias}

Umidade: ${humidity.toStringAsFixed(1)}%
Limiar: ${resultado.limite.toStringAsFixed(1)}%

Boia: ${boiaOk ? 'ÁGUA OK' : 'ÁGUA BAIXA'}

CLIMA:
${clima == null ? 'Sem previsão disponível' : '''
Horário: ${clima.time}
Temperatura: ${clima.tempC.toStringAsFixed(1)} °C
Chance de chuva: ${clima.chanceRain}%
Precipitação: ${clima.precipMm.toStringAsFixed(1)} mm
Vai chover: ${clima.willRain == 1 ? 'SIM' : 'NÃO'}
Condição: ${clima.condition}
'''}

CLIMA CONSIDERADO PELO ENGINE:
Temperatura média:
${resultado.temperaturaMedia?.toStringAsFixed(1) ?? '--'} °C

Maior chance de chuva:
${resultado.probabilidadeChuva}%

Precipitação total:
${resultado.precipitacaoTotal.toStringAsFixed(1)} mm

Chuva próxima:
${resultado.chuvaProxima ? 'SIM' : 'NÃO'}

DECISÃO:
PWM: ${resultado.pwm}
Irrigar: ${resultado.irrigar ? 'SIM' : 'NÃO'}

Motivo:
${resultado.motivo}

========================================
''');
  }

  // ============================================================
  // CANCELAMENTO DAS SUBSCRIPTIONS
  // ============================================================

  Future<void> _cancelSubscriptions() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    if (_disposed) return;

    // Antes de encerrar o controller, tenta desligar
    // a bomba.
    await _sendPumpCommand(0);

    _disposed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _cancelSubscriptions();

    if (!_stateController.isClosed) {
      await _stateController.close();
    }

    try {
      await device.disconnect();
    } catch (_) {
      // Pode já estar desconectado.
    }
  }
}
