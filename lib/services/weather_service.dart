import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_hour.dart';

class WeatherService {

  final String apiKey = '7169c46fbf214d5e9b803630262205';

  Future<List<WeatherHour>> getForecast(
      String city) async {

    final url =
        'http://api.weatherapi.com/v1/forecast.json?key=$apiKey&q=$city&days=1&aqi=no&alerts=no';

    final response =
        await http.get(Uri.parse(url));

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      final List hours =
          data['forecast']['forecastday'][0]['hour'];

      return hours
          .map((e) => WeatherHour.fromJson(e))
          .toList();

    } else {
      throw Exception('Erro ao buscar clima');
    }
  }
}