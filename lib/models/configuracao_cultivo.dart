enum Cultura {
  milho,
  soja,
  trigo,
  canadeacucar,
  algodao,
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

  // ============================================================
  // DIAS DE CULTIVO
  // ============================================================

  /// Quantidade de dias decorridos desde a data de plantio.
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

    final dias =
        dataAtual.difference(inicio).inDays;

    // Evita valores negativos caso a data de plantio
    // seja posterior à data atual.
    return dias < 0 ? 0 : dias;
  }

  // ============================================================
  // NOME DA CULTURA
  // ============================================================

  String get nomeCultura {
    switch (cultura) {
      case Cultura.milho:
        return 'Milho';

      case Cultura.soja:
        return 'Soja';

      case Cultura.trigo:
        return 'Trigo';

      case Cultura.canadeacucar:
        return 'Cana-de-açúcar';

      case Cultura.algodao:
        return 'Algodão';
    }
  }

  // ============================================================
  // NOME DO SOLO
  // ============================================================

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

  // ============================================================
  // DURAÇÃO DO CICLO
  // ============================================================

  /// Duração aproximada do ciclo utilizada pelo HydroFlow
  /// para determinar o avanço da cultura.
  int get duracaoCiclo {
    switch (cultura) {
      case Cultura.milho:
        return 150;

      case Cultura.soja:
        return 130;

      case Cultura.trigo:
        return 130;

      case Cultura.canadeacucar:
        return 360;

      case Cultura.algodao:
        return 180;
    }
  }

  // ============================================================
  // PERCENTUAL DO CICLO
  // ============================================================

  double get percentualCiclo {
    if (duracaoCiclo <= 0) {
      return 0.0;
    }

    final percentual =
        (diasCultivo / duracaoCiclo) * 100.0;

    return percentual
        .clamp(
          0.0,
          100.0,
        )
        .toDouble();
  }

  // ============================================================
  // FASE ATUAL
  // ============================================================

  String get faseAtual {
    switch (cultura) {
      // ========================================================
      // MILHO
      // ========================================================

      case Cultura.milho:
        if (percentualCiclo < 17.0) {
          return 'F1 - Inicial';
        }

        if (percentualCiclo < 45.0) {
          return 'F2 - Desenvolvimento';
        }

        if (percentualCiclo < 78.0) {
          return 'F3 - Florescimento';
        }

        return 'F4 - Maturação';

      // ========================================================
      // SOJA
      // ========================================================

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

      // ========================================================
      // TRIGO
      // ========================================================

      case Cultura.trigo:
        if (percentualCiclo < 13.0) {
          return 'F1 - Germinação/Emergência';
        }

        if (percentualCiclo < 33.0) {
          return 'F2 - Perfilhamento/Alongamento';
        }

        if (percentualCiclo < 76.0) {
          return 'F3 - Espigamento/Florescimento';
        }

        return 'F4 - Maturação/Colheita';

      // ========================================================
      // CANA-DE-AÇÚCAR
      // ========================================================

      case Cultura.canadeacucar:
        if (diasCultivo <= 90) {
          return 'F1 - Brotação';
        }

        if (diasCultivo <= 270) {
          return 'F2 - Crescimento Vegetativo Intenso';
        }

        return 'F3 - Maturação (Acúmulo de Açúcar)';

      // ========================================================
      // ALGODÃO
      // ========================================================

      case Cultura.algodao:
        if (percentualCiclo < 16.0) {
          return 'F1 - Inicial';
        }

        if (percentualCiclo < 43.0) {
          return 'F2 - Crescimento';
        }

        if (percentualCiclo < 74.0) {
          return 'F3 - Florada/Maçãs';
        }

        return 'F4 - Maturação/Capulhos';
    }
  }

  // ============================================================
  // DATA FORMATADA
  // ============================================================

  String get dataPlantioFormatada {
    return '${dataPlantio.day.toString().padLeft(2, '0')}/'
        '${dataPlantio.month.toString().padLeft(2, '0')}/'
        '${dataPlantio.year}';
  }

  // ============================================================
  // REPRESENTAÇÃO
  // ============================================================

  @override
  String toString() {
    return '''
      ConfiguracaoCultivo(
        cultura: $nomeCultura,
        solo: $nomeSolo,
        data de plantio: $dataPlantioFormatada,
        dias de cultivo: $diasCultivo,
        fase: $faseAtual,
        percentual do ciclo: ${percentualCiclo.toStringAsFixed(1)}%
      )
      ''';
  }
}