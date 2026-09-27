import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_hour.dart';

// ============================================================
// RESULTADO DA WEATHERAPI
// ============================================================

/// Resultado retornado pelo WeatherService.
///
/// Contém:
///
/// - temperatura atual da WeatherAPI;
/// - previsão das próximas horas.
///
/// O WeatherService apenas coleta e organiza os dados.
/// A decisão sobre qual temperatura utilizar e se a previsão
/// participa da irrigação pertence ao IrrigacaoBleController.
class WeatherData {
  /// Temperatura atual informada pela WeatherAPI.
  ///
  /// Pode ser null caso a API responda sem esse campo.
  final double? temperaturaAtual;

  /// Próximas horas de previsão meteorológica.
  final List<WeatherHour> proximasHoras;

  const WeatherData({
    required this.temperaturaAtual,
    required this.proximasHoras,
  });
}

// ============================================================
// WEATHER SERVICE
// ============================================================

class WeatherService {
  /// Chave utilizada para acessar a WeatherAPI.
  final String apiKey;

  /// Cidade escolhida pelo usuário na configuração do cultivo.
  final String cidade;

  static const String _baseUrl =
      'https://api.weatherapi.com/v1';

  WeatherService({
    required this.apiKey,
    required this.cidade,
  });

  // ==========================================================
  // CONSULTA PRINCIPAL
  // ==========================================================

  /// Consulta a WeatherAPI e retorna:
  ///
  /// - temperatura atual;
  /// - próximas [quantidade] horas.
  ///
  /// O parâmetro [agora] é utilizado apenas para determinar
  /// quais previsões ainda são futuras.
  ///
  /// Normalmente ele será o horário enviado pelo DS3231.
  ///
  /// IMPORTANTE:
  ///
  /// Esse horário NÃO é utilizado para decidir se a irrigação
  /// pode ocorrer.
  ///
  /// As regras de horário continuam sendo responsabilidade
  /// exclusiva do IrrigacaoEngine utilizando o timestamp
  /// proveniente do DS3231.
  Future<WeatherData> getWeatherData({
    int quantidade = 5,
    DateTime? agora,
  }) async {
    if (quantidade <= 0) {
      throw ArgumentError(
        'A quantidade de horas deve ser maior que zero.',
      );
    }

    // ========================================================
    // URL
    // ========================================================
    //
    // Utilizamos 2 dias para permitir obter as próximas horas
    // mesmo quando a consulta ocorre próxima da meia-noite.
    // ========================================================

    final uri = Uri.parse(
      '$_baseUrl/forecast.json',
    ).replace(
      queryParameters: {
        'key': apiKey,
        'q': cidade,
        'days': '2',
        'aqi': 'no',
        'alerts': 'no',
        'lang': 'pt',
      },
    );

    // ========================================================
    // REQUISIÇÃO HTTP
    // ========================================================

    late final http.Response response;

    try {
      response = await http
          .get(uri)
          .timeout(
            const Duration(
              seconds: 10,
            ),
          );
    } on TimeoutException {
      throw Exception(
        'Tempo limite excedido ao consultar a WeatherAPI.',
      );
    } catch (e) {
      throw Exception(
        'Erro de comunicação com a WeatherAPI: $e',
      );
    }

    // ========================================================
    // STATUS HTTP
    // ========================================================

    if (response.statusCode != 200) {
      throw Exception(
        'WeatherAPI retornou HTTP '
        '${response.statusCode}.',
      );
    }

    // ========================================================
    // JSON
    // ========================================================

    final dynamic decoded;

    try {
      decoded = jsonDecode(
        response.body,
      );
    } catch (_) {
      throw Exception(
        'Resposta inválida da WeatherAPI.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Formato de resposta inválido da WeatherAPI.',
      );
    }

    final Map<String, dynamic> data =
        decoded;

    // ========================================================
    // TEMPERATURA ATUAL
    // ========================================================

    final double? temperaturaAtual =
        _lerTemperaturaAtual(
      data,
    );

    // ========================================================
    // FORECAST
    // ========================================================

    final forecast =
        data['forecast'];

    if (forecast is! Map<String, dynamic>) {
      throw Exception(
        'Resposta da WeatherAPI sem previsão.',
      );
    }

    final forecastDays =
        forecast['forecastday'];

    if (forecastDays is! List) {
      throw Exception(
        'Resposta da WeatherAPI sem dados horários.',
      );
    }

    final List<WeatherHour> todasAsHoras =
        [];

    // ========================================================
    // CONVERSÃO DA PREVISÃO
    // ========================================================

    for (final dia in forecastDays) {
      if (dia is! Map) {
        continue;
      }

      final horas =
          dia['hour'];

      if (horas is! List) {
        continue;
      }

      for (final hora in horas) {
        if (hora is! Map) {
          continue;
        }

        try {
          todasAsHoras.add(
            WeatherHour.fromJson(
              Map<String, dynamic>.from(
                hora,
              ),
            ),
          );
        } catch (_) {
          // Uma entrada horária inválida não interrompe
          // toda a consulta meteorológica.
        }
      }
    }

    if (todasAsHoras.isEmpty) {
      throw Exception(
        'A WeatherAPI não retornou '
        'dados horários válidos.',
      );
    }

    // ========================================================
    // REMOVE HORÁRIOS INVÁLIDOS
    // ========================================================

    final List<WeatherHour> horasValidas =
        todasAsHoras.where(
      (hora) {
        return _parseDataHora(
              hora.time,
            ) !=
            null;
      },
    ).toList();

    if (horasValidas.isEmpty) {
      throw Exception(
        'A WeatherAPI não retornou horários válidos.',
      );
    }

    // ========================================================
    // ORDENA CRONOLOGICAMENTE
    // ========================================================

    horasValidas.sort(
      (a, b) {
        final dataA =
            _parseDataHora(
          a.time,
        )!;

        final dataB =
            _parseDataHora(
          b.time,
        )!;

        return dataA.compareTo(
          dataB,
        );
      },
    );

    // ========================================================
    // HORÁRIO DE REFERÊNCIA
    // ========================================================
    //
    // Prioridade:
    //
    // 1. DS3231 recebido pelo Controller;
    // 2. horário local retornado pela própria WeatherAPI;
    // 3. DateTime.now() apenas como fallback.
    //
    // Esse horário serve SOMENTE para filtrar a previsão.
    // ========================================================

    final DateTime referencia =
        agora ??
        _lerHorarioLocalApi(
          data,
        ) ??
        DateTime.now();

    // ========================================================
    // PRÓXIMAS HORAS
    // ========================================================

    final List<WeatherHour> futuras =
        horasValidas.where(
      (hora) {
        final horario =
            _parseDataHora(
          hora.time,
        );

        if (horario == null) {
          return false;
        }

        return !horario.isBefore(
          referencia,
        );
      },
    ).toList();

    if (futuras.isEmpty) {
      throw Exception(
        'Nenhuma previsão futura disponível.',
      );
    }

    // ========================================================
    // RESULTADO
    // ========================================================

    return WeatherData(
      temperaturaAtual:
          temperaturaAtual,
      proximasHoras:
          futuras
              .take(
                quantidade,
              )
              .toList(),
    );
  }

  // ==========================================================
  // TEMPERATURA ATUAL
  // ==========================================================

  /// Lê:
  ///
  /// current.temp_c
  ///
  /// da resposta da WeatherAPI.
  double? _lerTemperaturaAtual(
    Map<String, dynamic> data,
  ) {
    final current =
        data['current'];

    if (current is! Map<String, dynamic>) {
      return null;
    }

    final value =
        current['temp_c'];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ==========================================================
  // CONVERSÃO DE DATA/HORA
  // ==========================================================

  DateTime? _parseDataHora(
    String valor,
  ) {
    final texto =
        valor.trim();

    if (texto.isEmpty) {
      return null;
    }

    // WeatherAPI:
    //
    // 2026-09-14 21:00
    //
    // Dart:
    //
    // 2026-09-14T21:00

    return DateTime.tryParse(
      texto.replaceFirst(
        ' ',
        'T',
      ),
    );
  }

  // ==========================================================
  // HORÁRIO LOCAL DA WEATHERAPI
  // ==========================================================

  /// Recupera o horário local retornado pela API.
  ///
  /// Esse valor é somente um fallback para selecionar
  /// previsões futuras.
  ///
  /// Ele NÃO substitui o DS3231 nas regras de irrigação.
  DateTime? _lerHorarioLocalApi(
    Map<String, dynamic> data,
  ) {
    final location =
        data['location'];

    if (location is! Map<String, dynamic>) {
      return null;
    }

    final localtime =
        location['localtime'];

    if (localtime == null) {
      return null;
    }

    final texto =
        localtime
            .toString()
            .trim();

    if (texto.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      texto.replaceFirst(
        ' ',
        'T',
      ),
    );
  }
}