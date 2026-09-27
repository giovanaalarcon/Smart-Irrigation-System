import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/configuracao_cultivo.dart';
import '../models/weather_hour.dart';
import 'irrigacao_engine.dart';
import 'weather_service.dart';

// ============================================================
// UUIDs BLE
// ============================================================

class BleUuids {
  static final Guid service =
      Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');

  /// ESP32 -> Flutter
  ///
  /// Exemplo:
  ///
  /// {
  ///   "humidity": 57.4,
  ///   "temperature": 25.1,
  ///   "water": "LOW",
  ///   "timestamp": "2026-09-14T21:20:00"
  /// }
  static final Guid sensorChar =
      Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  /// Flutter -> ESP32
  ///
  /// Formato:
  ///
  /// L:<0|1>;B:<0-255>
  ///
  /// L:0 -> temperatura da WeatherAPI
  /// L:1 -> temperatura do DS3231
  ///
  /// Exemplo:
  ///
  /// L:1;B:80
  static final Guid commandChar =
      Guid('0a3f7f28-6b8e-4f60-9e3a-6f9a2d8c1a11');
}

// ============================================================
// ESTADO DA IRRIGAÇÃO
// ============================================================

class IrrigacaoState {
  final double humidity;
  final bool boiaOk;
  final int bomba;

  /// Horário oficial recebido do DS3231.
  ///
  /// null caso o RTC esteja indisponível.
  final DateTime? timestamp;

  // Informações agronômicas
  final double limite;
  final double mad;
  final String fase;
  final int dias;
  final String cultura;
  final String solo;

  // Decisão
  final bool irrigar;
  final String motivo;

  // Clima
  final bool chuvaProxima;

  /// Apesar do nome histórico, representa a temperatura
  /// efetivamente utilizada pelo Engine.
  final double? temperaturaMedia;

  final int probabilidadeChuva;
  final double precipitacaoTotal;

  /// Informa se a WeatherAPI está disponível atualmente.
  final bool apiDisponivel;

  /// true quando a temperatura efetivamente utilizada
  /// é proveniente do DS3231.
  final bool usandoTemperaturaLocal;

  IrrigacaoState({
    required this.humidity,
    required this.boiaOk,
    required this.bomba,
    required this.timestamp,
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
    required this.apiDisponivel,
    required this.usandoTemperaturaLocal,
  });

  bool get irrigando =>
      bomba > 0;

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
  temperaturaUtilizada: ${temperaturaMedia?.toStringAsFixed(1) ?? '--'} °C,
  probabilidadeChuva: $probabilidadeChuva%,
  precipitacaoTotal: ${precipitacaoTotal.toStringAsFixed(1)} mm,
  apiDisponivel: $apiDisponivel,
  usandoTemperaturaLocal: $usandoTemperaturaLocal,
  timestamp: $timestamp
)
''';
  }
}

// ============================================================
// CONTROLLER
// ============================================================

class IrrigacaoBleController {
  // ==========================================================
  // DISPOSITIVO E CONFIGURAÇÃO
  // ==========================================================

  final BluetoothDevice device;

  final ConfiguracaoCultivo configuracao;

  final String cidade;

  final WeatherService _weatherService;

  late final IrrigacaoEngine _engine;

  // ==========================================================
  // BLE
  // ==========================================================

  BluetoothCharacteristic? _sensorChar;
  BluetoothCharacteristic? _commandChar;

  StreamSubscription<List<int>>? _sensorSubscription;

  StreamSubscription<BluetoothConnectionState>?
      _connectionSubscription;

  // ==========================================================
  // STREAM DA INTERFACE
  // ==========================================================

  final StreamController<IrrigacaoState> _stateController =
      StreamController<IrrigacaoState>.broadcast();

  Stream<IrrigacaoState> get stateStream =>
      _stateController.stream;

  IrrigacaoState? lastState;

  // ==========================================================
  // ESTADO INTERNO
  // ==========================================================

  bool _disposed = false;
  bool _connecting = false;
  bool _reconnecting = false;

  Timer? _reconnectTimer;

  // ==========================================================
  // DADOS DO ESP32
  // ==========================================================

  double? _humidity;
  bool? _boiaOk;

  double? _temperaturaEsp32;
  DateTime? _timestampEsp32;

  // ==========================================================
  // WEATHERAPI
  // ==========================================================

  List<WeatherHour> _previsao = [];

  double? _temperaturaApi;

  bool _apiDisponivel = false;

  /// Última tentativa de acesso à API.
  ///
  /// É atualizada tanto em sucesso quanto em falha.
  DateTime? _ultimaTentativaClima;

  static const Duration _intervaloAtualizacaoClima =
      Duration(minutes: 15);

  // ==========================================================
  // ÚLTIMO COMANDO
  // ==========================================================
  //
  // Não armazenamos apenas o PWM.
  //
  // Exemplo:
  //
  // L:0;B:60
  //
  // pode precisar mudar para:
  //
  // L:1;B:60
  //
  // mesmo que o PWM continue igual.
  // ==========================================================

  String? _ultimoComandoEnviado;

  // ==========================================================
  // CONSTRUTOR
  // ==========================================================

  IrrigacaoBleController({
    required this.device,
    required this.configuracao,
    required this.cidade,
    required String weatherApiKey,
  }) : _weatherService = WeatherService(
          apiKey: weatherApiKey,
          cidade: cidade,
        ) {
    _engine =
        IrrigacaoEngine(
      configuracao,
    );
  }

  // ==========================================================
  // GETTERS
  // ==========================================================

  bool get apiDisponivel =>
      _apiDisponivel;

  double? get temperaturaEsp32 =>
      _temperaturaEsp32;

  double? get temperaturaApi =>
      _temperaturaApi;

  DateTime? get timestamp =>
      _timestampEsp32;

  List<WeatherHour> get previsao =>
      List.unmodifiable(
        _previsao,
      );

  // ==========================================================
  // TEMPERATURA UTILIZADA
  // ==========================================================
  //
  // Prioridade:
  //
  // 1. WeatherAPI;
  // 2. DS3231;
  // 3. null.
  // ==========================================================

  double? get temperaturaAtual {
    if (_apiDisponivel &&
        _temperaturaApi != null) {
      return _temperaturaApi;
    }

    return _temperaturaEsp32;
  }

  // ==========================================================
  // FONTE DA TEMPERATURA
  // ==========================================================

  bool get usandoTemperaturaLocal {
    if (_apiDisponivel &&
        _temperaturaApi != null) {
      return false;
    }

    return _temperaturaEsp32 != null;
  }

  // ==========================================================
  // CONEXÃO BLE
  // ==========================================================

  Future<void> connectAndListen() async {
    if (_disposed ||
        _connecting) {
      return;
    }

    _connecting = true;

    try {
      await _cancelSubscriptions();

      _sensorChar = null;
      _commandChar = null;

      // Força o primeiro comando da nova conexão.
      _ultimoComandoEnviado = null;

      try {
        await device.connect(
          autoConnect: false,
          timeout: const Duration(
            seconds: 10,
          ),
        );
      } catch (_) {
        // Pode ocorrer se o dispositivo já estiver conectado.
        final estado =
            await device.connectionState.first;

        if (estado !=
            BluetoothConnectionState.connected) {
          rethrow;
        }
      }

      if (_disposed) {
        return;
      }

      // É necessário descobrir novamente os serviços
      // após cada nova conexão/reconexão.
      final services =
          await device.discoverServices();

      final service =
          services.firstWhere(
        (s) =>
            s.uuid ==
            BleUuids.service,
        orElse: () {
          throw Exception(
            'Serviço BLE de irrigação não encontrado.',
          );
        },
      );

      _sensorChar =
          service.characteristics.firstWhere(
        (c) =>
            c.uuid ==
            BleUuids.sensorChar,
        orElse: () {
          throw Exception(
            'Característica do sensor não encontrada.',
          );
        },
      );

      _commandChar =
          service.characteristics.firstWhere(
        (c) =>
            c.uuid ==
            BleUuids.commandChar,
        orElse: () {
          throw Exception(
            'Característica de comando não encontrada.',
          );
        },
      );

      // ======================================================
      // SENSOR NOTIFY
      // ======================================================

      _sensorSubscription =
          _sensorChar!
              .onValueReceived
              .listen(
        _onSensorData,
        onError: (error) {
          print(
            'Erro no recebimento BLE: $error',
          );

          _handleBleFailure();
        },
      );

      await _sensorChar!
          .setNotifyValue(
        true,
      );

      // ======================================================
      // ESTADO DA CONEXÃO
      // ======================================================

      _connectionSubscription =
          device.connectionState.listen(
        _onConnectionState,
      );

      _reconnecting = false;

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // ======================================================
      // ESTADO SEGURO INICIAL
      // ======================================================

      await _sendCommand(
        pwm: 0,
        usarTemperaturaLocal: false,
        force: true,
      );

      print(
        'BLE conectado com sucesso.',
      );

      // Primeira consulta climática.
      await _atualizarClima(
        force: true,
      );
    } finally {
      _connecting = false;
    }
  }

  // ==========================================================
  // ESTADO DA CONEXÃO
  // ==========================================================

  void _onConnectionState(
    BluetoothConnectionState state,
  ) {
    print(
      'Estado BLE: $state',
    );

    if (state ==
        BluetoothConnectionState.disconnected) {
      _handleBleFailure();
    }
  }

  // ==========================================================
  // FALHA BLE
  // ==========================================================

  void _handleBleFailure() {
    if (_disposed) {
      return;
    }

    print(
      'BLE desconectado.',
    );

    // O próprio firmware do ESP32 desliga a bomba
    // imediatamente no onDisconnect.
    //
    // Portanto NÃO tentamos escrever B:0 em uma conexão
    // que acabou de falhar.

    _sensorChar = null;
    _commandChar = null;

    _ultimoComandoEnviado = null;

    _startReconnect();
  }

  // ==========================================================
  // RECONEXÃO
  // ==========================================================

  void _startReconnect() {
    if (_disposed ||
        _reconnecting) {
      return;
    }

    _reconnecting = true;

    print(
      'Iniciando tentativa de reconexão...',
    );

    _reconnectTimer?.cancel();

    _reconnectTimer =
        Timer.periodic(
      const Duration(
        seconds: 5,
      ),
      (_) async {
        if (_disposed) {
          _reconnectTimer?.cancel();
          return;
        }

        if (_connecting) {
          return;
        }

        try {
          final estado =
              await device
                  .connectionState
                  .first;

          if (estado ==
              BluetoothConnectionState.connected) {
            _reconnecting = false;

            _reconnectTimer?.cancel();
            _reconnectTimer = null;

            return;
          }

          print(
            'Tentando reconectar ao ESP32...',
          );

          await connectAndListen();

          if (!_reconnecting) {
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
          }
        } catch (e) {
          print(
            'Falha na reconexão: $e',
          );
        }
      },
    );
  }

  // ==========================================================
  // RECEBIMENTO DOS DADOS
  // ==========================================================

  Future<void> _onSensorData(
    List<int> data,
  ) async {
    if (_disposed ||
        data.isEmpty) {
      return;
    }

    try {
      final texto =
          utf8.decode(data).trim();

      if (texto.isEmpty) {
        return;
      }

      print(
        'Dados recebidos do ESP32: $texto',
      );

      final dynamic decoded =
          jsonDecode(
        texto,
      );

      if (decoded is! Map<String, dynamic>) {
        print(
          'JSON BLE inválido: $texto',
        );

        return;
      }

      // ======================================================
      // ESP32
      // ======================================================

      final humidity =
          _lerUmidade(
        decoded,
      );

      final boiaOk =
          _lerBoia(
        decoded,
      );

      final temperaturaEsp32 =
          _lerTemperatura(
        decoded,
      );

      final timestampEsp32 =
          _lerTimestamp(
        decoded,
      );

      // Umidade e boia são obrigatórias.
      if (humidity == null ||
          boiaOk == null) {
        print(
          'Dados essenciais BLE inválidos.',
        );

        return;
      }

      _humidity =
          humidity;

      _boiaOk =
          boiaOk;

      _temperaturaEsp32 =
          temperaturaEsp32;

      _timestampEsp32 =
          timestampEsp32;

      // ======================================================
      // WEATHERAPI
      // ======================================================

      await _atualizarClima();

      if (_disposed) {
        return;
      }

      // ======================================================
      // PREVISÃO QUE PODE PARTICIPAR DA DECISÃO
      // ======================================================

      final List<WeatherHour>
          climaParaDecisao =
          _apiDisponivel
              ? _previsao
              : <WeatherHour>[];

      // ======================================================
      // ENGINE
      // ======================================================

      final resultado =
          _engine.calcularBomba(
        humidity: humidity,
        boiaOk: boiaOk,
        clima: climaParaDecisao,
        apiDisponivel:
            _apiDisponivel,
        temperatura:
            temperaturaAtual,

        // ÚNICA fonte horária da regra de irrigação.
        timestamp:
            _timestampEsp32,
      );

      // ======================================================
      // ESTADO
      // ======================================================

      final state =
          IrrigacaoState(
        humidity:
            humidity,
        boiaOk:
            boiaOk,
        bomba:
            resultado.pwm,
        timestamp:
            _timestampEsp32,
        limite:
            resultado.limite,
        mad:
            _engine.fatorMAD(),
        fase:
            resultado.fase,
        dias:
            resultado.dias,
        cultura:
            resultado.cultura,
        solo:
            resultado.solo,
        irrigar:
            resultado.irrigar,
        motivo:
            resultado.motivo,
        chuvaProxima:
            resultado.chuvaProxima,
        temperaturaMedia:
            resultado.temperaturaMedia,
        probabilidadeChuva:
            resultado.probabilidadeChuva,
        precipitacaoTotal:
            resultado.precipitacaoTotal,
        apiDisponivel:
            _apiDisponivel,
        usandoTemperaturaLocal:
            usandoTemperaturaLocal,
      );

      lastState =
          state;

      if (!_stateController.isClosed) {
        _stateController.add(
          state,
        );
      }

      // ======================================================
      // ESP32
      // ======================================================

      await _sendCommand(
        pwm: resultado.pwm,
        usarTemperaturaLocal:
            usandoTemperaturaLocal,
      );

      // ======================================================
      // DIAGNÓSTICO
      // ======================================================

      _mostrarDiagnostico(
        humidity:
            humidity,
        boiaOk:
            boiaOk,
        resultado:
            resultado,
      );
    } catch (e) {
      print(
        'Erro ao processar dados BLE: $e',
      );
    }
  }

  // ==========================================================
  // WEATHERAPI
  // ==========================================================

  Future<void> _atualizarClima({
    bool force = false,
  }) async {
    if (_disposed) {
      return;
    }

    final agora =
        DateTime.now();

    if (!force &&
        _ultimaTentativaClima != null &&
        agora.difference(
              _ultimaTentativaClima!,
            ) <
            _intervaloAtualizacaoClima) {
      return;
    }

    // Registra ANTES da chamada.
    //
    // Assim uma falha da API também respeita
    // o intervalo de 15 minutos.
    _ultimaTentativaClima =
        agora;

    try {
      print(
        'Buscando previsão para $cidade...',
      );

      final weatherData =
          await _weatherService
              .getWeatherData(
        quantidade: 5,

        // Serve apenas para selecionar as próximas
        // previsões dentro do WeatherService.
        agora:
            _timestampEsp32,
      );

      if (_disposed) {
        return;
      }

      _previsao =
          weatherData.proximasHoras;

      _temperaturaApi =
          weatherData.temperaturaAtual;

      _apiDisponivel =
          true;

      print(
        'WeatherAPI disponível.',
      );

      print(
        'Temperatura atual: '
        '${_temperaturaApi?.toStringAsFixed(1) ?? '--'} °C',
      );

      print(
        'Previsões recebidas: ${_previsao.length}',
      );
    } catch (e) {
      print(
        'Erro ao consultar WeatherAPI: $e',
      );

      _apiDisponivel =
          false;

      _temperaturaApi =
          null;

      // IMPORTANTE:
      //
      // A previsão antiga pode continuar em memória
      // para apresentação visual.
      //
      // Porém NÃO é enviada ao Engine enquanto
      // apiDisponivel == false.

      print(
        'WeatherAPI indisponível. '
        'Sistema operando com dados locais.',
      );
    }
  }

  // ==========================================================
  // UMIDADE
  // ==========================================================

  double? _lerUmidade(
    Map<String, dynamic> json,
  ) {
    final valor =
        json['humidity'];

    if (valor == null) {
      return null;
    }

    if (valor is num) {
      return valor
          .toDouble()
          .clamp(
            0.0,
            100.0,
          )
          .toDouble();
    }

    final resultado =
        double.tryParse(
      valor.toString(),
    );

    if (resultado == null) {
      return null;
    }

    return resultado
        .clamp(
          0.0,
          100.0,
        )
        .toDouble();
  }

  // ==========================================================
  // BOIA
  // ==========================================================
  //
  // CONTRATO DEFINIDO COM O ARDUINO:
  //
  // LOW  / 0 -> água suficiente -> true
  // HIGH / 1 -> falta de água   -> false
  // ==========================================================

  bool? _lerBoia(
    Map<String, dynamic> json,
  ) {
    final valor =
        json['water'];

    if (valor == null) {
      return null;
    }

    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      if (valor == 0) {
        return true;
      }

      if (valor == 1) {
        return false;
      }

      return null;
    }

    final texto =
        valor
            .toString()
            .trim()
            .toUpperCase();

    if (texto == 'LOW') {
      return true;
    }

    if (texto == 'HIGH') {
      return false;
    }

    if (texto == '0') {
      return true;
    }

    if (texto == '1') {
      return false;
    }

    return null;
  }

  // ==========================================================
  // TEMPERATURA DS3231
  // ==========================================================

  double? _lerTemperatura(
    Map<String, dynamic> json,
  ) {
    final valor =
        json['temperature'];

    // Arduino envia null se o DS3231
    // estiver indisponível.
    if (valor == null) {
      return null;
    }

    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(
      valor.toString(),
    );
  }

  // ==========================================================
  // HORÁRIO DS3231
  // ==========================================================

  DateTime? _lerTimestamp(
    Map<String, dynamic> json,
  ) {
    final valor =
        json['timestamp'];

    if (valor == null) {
      return null;
    }

    final texto =
        valor
            .toString()
            .trim();

    if (texto.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      texto,
    );
  }

  // ==========================================================
  // COMANDO FLUTTER -> ESP32
  // ==========================================================

  Future<void> _sendCommand({
    required int pwm,
    required bool usarTemperaturaLocal,
    bool force = false,
  }) async {
    if (_disposed) {
      return;
    }

    final characteristic =
        _commandChar;

    if (characteristic == null) {
      print(
        'Comando não enviado: BLE não conectado.',
      );

      return;
    }

    final int pwmSeguro =
        pwm
            .clamp(
              0,
              255,
            )
            .toInt();

    final int led =
        usarTemperaturaLocal
            ? 1
            : 0;

    final comando =
        'L:$led;B:$pwmSeguro';

    // Evita comandos idênticos repetidos.
    if (!force &&
        comando ==
            _ultimoComandoEnviado) {
      return;
    }

    try {
      await characteristic.write(
        utf8.encode(
          comando,
        ),
        withoutResponse: false,
      );

      _ultimoComandoEnviado =
          comando;

      print(
        'Comando enviado: $comando',
      );
    } catch (e) {
      print(
        'Erro ao enviar comando BLE: $e',
      );

      _handleBleFailure();
    }
  }

  // ==========================================================
  // DIAGNÓSTICO
  // ==========================================================

  void _mostrarDiagnostico({
    required double humidity,
    required bool boiaOk,
    required ResultadoIrrigacao resultado,
  }) {
    final WeatherHour? proximaHora =
        _previsao.isNotEmpty
            ? _previsao.first
            : null;

    final fonteTemperatura =
        usandoTemperaturaLocal
            ? 'DS3231'
            : (_apiDisponivel &&
                    _temperaturaApi != null)
                ? 'WeatherAPI'
                : 'Indisponível';

    print('''
========================================
HYDROFLOW - IRRIGAÇÃO
========================================

CULTIVO
Cultura: ${resultado.cultura}
Solo: ${resultado.solo}
Fase: ${resultado.fase}
Dia: ${resultado.dias}

SOLO
Umidade: ${humidity.toStringAsFixed(1)}%
Limiar: ${resultado.limite.toStringAsFixed(1)}%
MAD: ${(_engine.fatorMAD() * 100).toStringAsFixed(0)}%

RESERVATÓRIO
Boia: ${boiaOk ? 'ÁGUA OK' : 'SEM ÁGUA'}

RTC
Horário: ${_timestampEsp32 ?? 'indisponível'}
Temperatura DS3231:
${_temperaturaEsp32?.toStringAsFixed(1) ?? '--'} °C

WEATHERAPI
Disponível: ${_apiDisponivel ? 'SIM' : 'NÃO'}

Temperatura API:
${_temperaturaApi?.toStringAsFixed(1) ?? '--'} °C

Fonte da temperatura utilizada:
$fonteTemperatura

PRÓXIMA PREVISÃO
${proximaHora == null ? 'Sem previsão válida.' : '''
Horário: ${proximaHora.time}
Temperatura: ${proximaHora.tempC.toStringAsFixed(1)} °C
Chance de chuva: ${proximaHora.chanceRain}%
Precipitação: ${proximaHora.precipMm.toStringAsFixed(1)} mm
Vai chover: ${proximaHora.willRain == 1 ? 'SIM' : 'NÃO'}
Condição: ${proximaHora.condition}
'''}

DECISÃO
Temperatura utilizada:
${resultado.temperaturaMedia?.toStringAsFixed(1) ?? '--'} °C

Maior chance de chuva:
${resultado.probabilidadeChuva}%

Precipitação considerada:
${resultado.precipitacaoTotal.toStringAsFixed(1)} mm

Chuva próxima:
${resultado.chuvaProxima ? 'SIM' : 'NÃO'}

PWM:
${resultado.pwm}

Irrigar:
${resultado.irrigar ? 'SIM' : 'NÃO'}

Motivo:
${resultado.motivo}

========================================
''');
  }

  // ==========================================================
  // CANCELAMENTO DAS SUBSCRIPTIONS
  // ==========================================================

  Future<void> _cancelSubscriptions() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    // Enquanto a conexão ainda existe,
    // coloca o sistema em estado seguro.
    await _sendCommand(
      pwm: 0,
      usarTemperaturaLocal: false,
      force: true,
    );

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

    _sensorChar = null;
    _commandChar = null;
  }
}