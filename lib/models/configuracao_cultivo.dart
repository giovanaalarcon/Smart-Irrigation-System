enum Cultura {
  milho,
  soja,
}

enum TipoSolo {
  arenoso,
  franco,
  argiloso,
}

class ConfiguracaoCultivo {
  final Cultura cultura;
  final TipoSolo solo;
  final DateTime dataPlantio;

  const ConfiguracaoCultivo({
    required this.cultura,
    required this.solo,
    required this.dataPlantio,
  });

  /// Dias desde o plantio
  int get diasCultivo {
    return DateTime.now().difference(dataPlantio).inDays;
  }

  /// Nome da cultura
  String get nomeCultura {
    switch (cultura) {
      case Cultura.milho:
        return 'Milho';

      case Cultura.soja:
        return 'Soja';
    }
  }

  /// Nome do solo
  String get nomeSolo {
    switch (solo) {
      case TipoSolo.arenoso:
        return 'Arenoso';

      case TipoSolo.franco:
        return 'Franco';

      case TipoSolo.argiloso:
        return 'Argiloso';
    }
  }

  /// Duração média utilizada para calcular a fase.
  /// (Posteriormente poderá ser configurável.)
  int get duracaoCiclo {
    switch (cultura) {
      case Cultura.milho:
        return 150;

      case Cultura.soja:
        return 130;
    }
  }

  /// Percentual do ciclo já percorrido
  double get percentualCiclo {
    return (diasCultivo / duracaoCiclo) * 100;
  }

  /// Fase atual do cultivo
  String get faseAtual {
    switch (cultura) {
      case Cultura.milho:
        if (percentualCiclo < 17) {
          return "F1 - Inicial";
        }

        if (percentualCiclo < 45) {
          return "F2 - Desenvolvimento";
        }

        if (percentualCiclo < 78) {
          return "F3 - Florescimento";
        }

        return "F4 - Maturação";

      case Cultura.soja:
        if (diasCultivo <= 7) {
          return "Germinação";
        }

        if (diasCultivo <= 45) {
          return "Vegetativo";
        }

        if (diasCultivo <= 110) {
          return "Reprodutivo";
        }

        return "Maturação";
    }
  }

  @override
  String toString() {
    return '''
      Cultura: $nomeCultura
      Solo: $nomeSolo
      Plantio: ${dataPlantio.day}/${dataPlantio.month}/${dataPlantio.year}
      Dias: $diasCultivo
      Fase: $faseAtual
      ''';
  }
}