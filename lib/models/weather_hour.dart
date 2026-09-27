class WeatherHour {
  final String time;

  final int chanceRain;

  final double precipMm;

  final int willRain;

  final double tempC;

  final String condition;

  const WeatherHour({
    required this.time,
    required this.chanceRain,
    required this.precipMm,
    required this.willRain,
    required this.tempC,
    required this.condition,
  });

  // ============================================================
  // JSON -> WEATHER HOUR
  // ============================================================

  factory WeatherHour.fromJson(
    Map<String, dynamic> json,
  ) {
    return WeatherHour(
      time: json['time']
              ?.toString()
              .trim() ??
          '',

      chanceRain: _toInt(
        json['chance_of_rain'],
      ),

      precipMm: _toDouble(
        json['precip_mm'],
      ),

      willRain: _toInt(
        json['will_it_rain'],
      ),

      tempC: _toDouble(
        json['temp_c'],
      ),

      condition: json['condition']?['text']
              ?.toString()
              .trim() ??
          '',
    );
  }

  // ============================================================
  // CONVERSÃO PARA INT
  // ============================================================

  static int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  // ============================================================
  // CONVERSÃO PARA DOUBLE
  // ============================================================

  static double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  // ============================================================
  // REPRESENTAÇÃO
  // ============================================================

  @override
  String toString() {
    return '''
      WeatherHour(
        time: $time,
        chanceRain: $chanceRain%,
        precipMm: ${precipMm.toStringAsFixed(1)} mm,
        willRain: $willRain,
        tempC: ${tempC.toStringAsFixed(1)} °C,
        condition: $condition
      )
      ''';
  }
}