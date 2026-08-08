import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_hour.dart';

class WeatherService {
  // Chave da WeatherAPI
  final String apiKey = '7169c46fbf214d5e9b803630262205';

  /// Busca a previsão das próximas horas para a cidade informada.
  ///
  /// A API retorna a previsão hora a hora do dia atual.
  Future<List<WeatherHour>> getForecast(String city) async {
    final uri = Uri.parse(
      'https://api.weatherapi.com/v1/forecast.json'
      '?key=$apiKey'
      '&q=${Uri.encodeComponent(city)}'
      '&days=1'
      '&aqi=no'
      '&alerts=no',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao buscar previsão do tempo. '
        'Código: ${response.statusCode}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (!data.containsKey('forecast')) {
      throw Exception('Resposta da API não contém previsão.');
    }

    final forecast = data['forecast'];

    if (forecast['forecastday'] == null ||
        forecast['forecastday'].isEmpty) {
      throw Exception('Nenhuma previsão encontrada.');
    }

    final List<dynamic> hours =
        forecast['forecastday'][0]['hour'] ?? [];

    return hours
        .map(
          (json) => WeatherHour.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Retorna somente as próximas [quantidade] horas.
  ///
  /// Isso será útil para a decisão de irrigação.
  Future<List<WeatherHour>> getNextHours(
    String city, {
    int quantidade = 5,
  }) async {
    final forecast = await getForecast(city);

    final agora = DateTime.now();

    final proximasHoras = forecast.where((weather) {
      final horario = DateTime.tryParse(weather.time);

      if (horario == null) {
        return false;
      }

      return horario.isAfter(
        agora.subtract(const Duration(minutes: 30)),
      );
    }).toList();

    if (proximasHoras.length <= quantidade) {
      return proximasHoras;
    }

    return proximasHoras.take(quantidade).toList();
  }
}
