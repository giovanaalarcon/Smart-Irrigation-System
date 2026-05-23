class WeatherHour {

  final String time;
  final int chanceRain;
  final double precipMm;
  final int willRain;
  final double tempC;
  final String condition;

  WeatherHour({
    required this.time,
    required this.chanceRain,
    required this.precipMm,
    required this.willRain,
    required this.tempC,
    required this.condition,
  });

  factory WeatherHour.fromJson(Map<String, dynamic> json) {

    return WeatherHour(
      time: json['time'],
      chanceRain: json['chance_of_rain'],
      precipMm: (json['precip_mm'] as num).toDouble(),
      willRain: json['will_it_rain'],
      tempC: (json['temp_c'] as num).toDouble(),
      condition: json['condition']['text'],
    );
  }
}