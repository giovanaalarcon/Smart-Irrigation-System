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
      time: json['time']?.toString() ?? '',
      chanceRain: (json['chance_of_rain'] as num?)?.toInt() ?? 0,
      precipMm: (json['precip_mm'] as num?)?.toDouble() ?? 0.0,
      willRain: (json['will_it_rain'] as num?)?.toInt() ?? 0,
      tempC: (json['temp_c'] as num?)?.toDouble() ?? 0.0,
      condition: json['condition']?['text']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'WeatherHour('
        'time: $time, '
        'chanceRain: $chanceRain%, '
        'precipMm: $precipMm mm, '
        'willRain: $willRain, '
        'tempC: $tempC°C, '
        'condition: $condition'
        ')';
  }
}
