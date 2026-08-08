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

  // Quantos dias já se passaram desde o plantio.
  int get diasCultivo {
    final hoje = DateTime.now();

    final inicio = DateTime(
      dataPlantio.year,
      dataPlantio.month,
      dataPlantio.day,
    );

    final dataAtual = DateTime(
      hoje.year,
      hoje.month,
      hoje.day,
    );

    final dias = dataAtual.difference(inicio).inDays;

    // Evita valores negativos caso a data esteja errada.
    return dias < 0 ? 0 : dias;
  }

  // Nome da cultura para mostrar na tela.
  String get nomeCultura {
    switch (cultura) {
      case Cultura.milho:
        return 'Milho';

      case Cultura.soja:
        return 'Soja';
    }
  }

  // Nome do tipo de solo para mostrar na tela.
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

  // Duração aproximada do ciclo utilizada para determinar a fase.
  int get duracaoCiclo {
    switch (cultura) {
      case Cultura.milho:
        return 150;

      case Cultura.soja:
        return 130;
    }
  }

  // Porcentagem do ciclo que já passou.
  double get percentualCiclo {
    if (duracaoCiclo <= 0) {
      return 0;
    }

    return (diasCultivo / duracaoCiclo) * 100;
  }

  // Fase atual do cultivo.
  //
  // Esses períodos são uma aproximação para o sistema.
  // Depois podemos deixar os valores mais específicos conforme
  // a cultura e os dados agronômicos utilizados no TCC.
  String get faseAtual {
    switch (cultura) {
      case Cultura.milho:
        if (percentualCiclo < 17) {
          return 'F1 - Inicial';
        }

        if (percentualCiclo < 45) {
          return 'F2 - Desenvolvimento';
        }

        if (percentualCiclo < 78) {
          return 'F3 - Florescimento';
        }

        return 'F4 - Maturação';

      case Cultura.soja:
        if (diasCultivo <= 7) {
          return 'F1 - Germinação';

        }

        if (diasCultivo <= 45) {
          return 'F2 - Vegetativo';
        }

        if (diasCultivo <= 110) {
          return 'F3 - Reprodutivo';
        }

        return 'F4 - Maturação';
    }
  }

  // Data formatada para exibição.
  String get dataPlantioFormatada {
    return '${dataPlantio.day.toString().padLeft(2, '0')}/'
        '${dataPlantio.month.toString().padLeft(2, '0')}/'
        '${dataPlantio.year}';
  }

  @override
  String toString() {
    return '''
      Cultura: $nomeCultura
      Solo: $nomeSolo
      Data de plantio: $dataPlantioFormatada
      Dias de cultivo: $diasCultivo
      Fase: $faseAtual
      Percentual do ciclo: ${percentualCiclo.toStringAsFixed(1)}%
      ''';
  }
}
