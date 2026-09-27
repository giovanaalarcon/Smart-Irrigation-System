import '../models/configuracao_cultivo.dart';
import '../models/weather_hour.dart';

class IrrigacaoEngine {
  final ConfiguracaoCultivo configuracao;

  IrrigacaoEngine(this.configuracao);

  // ============================================================
  // CONFIGURAÇÕES DAS REGRAS
  // ============================================================

  /// Quantidade de horas futuras consideradas na decisão
  /// meteorológica.
  ///
  /// O Controller pode manter uma previsão maior para exibição,
  /// mas somente as próximas 2 horas influenciam a irrigação.
  static const int horasPrevisaoIrrigacao = 2;

  /// Temperatura considerada elevada.
  static const double temperaturaElevada = 35.0;

  /// Precipitação considerada significativa em uma hora.
  static const double precipitacaoSignificativa = 2.0;

  /// Probabilidade de chuva considerada alta.
  static const int probabilidadeChuvaAlta = 70;

  // ============================================================
  // DECISÃO PRINCIPAL
  // ============================================================

  ResultadoIrrigacao calcularBomba({
    required double humidity,
    required bool boiaOk,
    required List<WeatherHour> clima,

    /// true:
    /// WeatherAPI disponível e previsão pode participar
    /// da decisão.
    ///
    /// false:
    /// previsão meteorológica é ignorada.
    required bool apiDisponivel,

    /// Temperatura efetivamente escolhida pelo Controller.
    ///
    /// Prioridade definida no Controller:
    ///
    /// 1. WeatherAPI;
    /// 2. DS3231;
    /// 3. null.
    required double? temperatura,

    /// Horário oficial recebido do RTC DS3231.
    ///
    /// É utilizado exclusivamente nas regras de horário
    /// de irrigação.
    required DateTime? timestamp,
  }) {
    // Mantém a leitura dentro da escala válida.
    humidity = humidity
        .clamp(
          0.0,
          100.0,
        )
        .toDouble();

    // ==========================================================
    // PREVISÃO VÁLIDA PARA A DECISÃO
    // ==========================================================
    //
    // Mesmo que exista uma previsão antiga armazenada no
    // Controller, ela nunca será usada quando a API estiver
    // indisponível.
    // ==========================================================

    final List<WeatherHour> climaParaDecisao;

    if (apiDisponivel) {
      climaParaDecisao = clima
          .take(
            horasPrevisaoIrrigacao,
          )
          .toList();
    } else {
      climaParaDecisao =
          <WeatherHour>[];
    }

    final double limite =
        calcularUmidadeMinima();

    // ==========================================================
    // 1. SEGURANÇA DO RESERVATÓRIO
    // ==========================================================

    if (!boiaOk) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Reservatório sem água',
        clima: climaParaDecisao,
        temperatura: temperatura,
      );
    }

    // ==========================================================
    // 2. NECESSIDADE DE IRRIGAÇÃO
    // ==========================================================

    final bool soloSeco =
        humidity < limite;

    if (!soloSeco) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Umidade do solo acima do limiar',
        clima: climaParaDecisao,
        temperatura: temperatura,
      );
    }

    // ==========================================================
    // 3. HORÁRIO DO DS3231
    // ==========================================================
    //
    // Sem horário confiável, o sistema assume comportamento
    // seguro e não liga a bomba.
    // ==========================================================

    if (timestamp == null) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Horário do ESP32 indisponível',
        clima: climaParaDecisao,
        temperatura: temperatura,
      );
    }

    final int minutos =
        timestamp.hour * 60 +
        timestamp.minute;

    // ==========================================================
    // 00:00 – 03:59
    // ==========================================================

    if (minutos < 240) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Irrigação bloqueada no período noturno',
        clima: climaParaDecisao,
        temperatura: temperatura,
      );
    }

    // ==========================================================
    // 04:00 – 09:59
    // ==========================================================

    if (minutos < 600) {
      return _calcularResultadoComBomba(
        humidity: humidity,
        limite: limite,
        temperatura: temperatura,
        clima: climaParaDecisao,
        limiteHorario: null,
      );
    }

    // ==========================================================
    // 10:00 – 15:59
    // ==========================================================
    //
    // Irrigação bloqueada durante o período de maior
    // incidência solar.
    // ==========================================================

    if (minutos < 960) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Irrigação bloqueada no período de sol intenso',
        clima: climaParaDecisao,
        temperatura: temperatura,
      );
    }

    // ==========================================================
    // 16:00 – 17:59
    // ==========================================================

    if (minutos < 1080) {
      return _calcularResultadoComBomba(
        humidity: humidity,
        limite: limite,
        temperatura: temperatura,
        clima: climaParaDecisao,
        limiteHorario: null,
      );
    }

    // ==========================================================
    // 18:00 – 21:00
    // ==========================================================
    //
    // Irrigação permitida, mas PWM limitado a 70.
    //
    // 21:00 = 1260 minutos.
    // ==========================================================

    if (minutos <= 1260) {
      return _calcularResultadoComBomba(
        humidity: humidity,
        limite: limite,
        temperatura: temperatura,
        clima: climaParaDecisao,
        limiteHorario: 70,
      );
    }

    // ==========================================================
    // 21:01 – 23:59
    // ==========================================================

    return _resultado(
      pwm: 0,
      limite: limite,
      irrigar: false,
      motivo:
          'Irrigação bloqueada no período noturno',
      clima: climaParaDecisao,
      temperatura: temperatura,
    );
  }

  // ============================================================
  // CÁLCULO DA IRRIGAÇÃO
  // ============================================================

  ResultadoIrrigacao _calcularResultadoComBomba({
    required double humidity,
    required double limite,
    required double? temperatura,
    required List<WeatherHour> clima,
    required int? limiteHorario,
  }) {
    // ==========================================================
    // PREVISÃO DE CHUVA
    // ==========================================================

    if (_chuvaSignificativa(clima)) {
      return _resultado(
        pwm: 0,
        limite: limite,
        irrigar: false,
        motivo:
            'Chuva prevista nas próximas horas',
        clima: clima,
        temperatura: temperatura,
      );
    }

    // ==========================================================
    // INTENSIDADE
    // ==========================================================

    int pwm =
        calcularIntensidade(
      humidity: humidity,
      limite: limite,
      temperatura: temperatura,
    );

    // ==========================================================
    // LIMITE DO HORÁRIO
    // ==========================================================

    if (limiteHorario != null &&
        pwm > limiteHorario) {
      pwm =
          limiteHorario;
    }

    // ==========================================================
    // MOTIVO
    // ==========================================================

    String motivo =
        'Solo abaixo do limiar';

    if (temperatura != null &&
        temperatura >=
            temperaturaElevada) {
      motivo =
          'Solo seco e temperatura elevada';
    }

    if (limiteHorario != null) {
      motivo =
          '$motivo — potência limitada pelo horário';
    }

    return _resultado(
      pwm: pwm,
      limite: limite,
      irrigar: pwm > 0,
      motivo: motivo,
      clima: clima,
      temperatura: temperatura,
    );
  }

  // ============================================================
  // CONSTRUÇÃO DO RESULTADO
  // ============================================================

  ResultadoIrrigacao _resultado({
    required int pwm,
    required double limite,
    required bool irrigar,
    required String motivo,
    required List<WeatherHour> clima,
    required double? temperatura,
  }) {
    return ResultadoIrrigacao(
      pwm: pwm,
      limite: limite,
      fase:
          configuracao.faseAtual,
      dias:
          configuracao.diasCultivo,
      cultura:
          configuracao.nomeCultura,
      solo:
          configuracao.nomeSolo,
      irrigar:
          irrigar,
      motivo:
          motivo,
      chuvaProxima:
          _chuvaSignificativa(
        clima,
      ),

      // Mantemos o nome por compatibilidade com os demais
      // arquivos, apesar de representar a temperatura utilizada
      // e não uma média.
      temperaturaMedia:
          temperatura,

      probabilidadeChuva:
          _maiorChanceChuva(
        clima,
      ),
      precipitacaoTotal:
          _precipitacaoTotal(
        clima,
      ),
    );
  }

  // ============================================================
  // LIMIAR DE UMIDADE
  // ============================================================

  double calcularUmidadeMinima() {
    /*
     * O sensor utiliza uma escala calibrada:
     *
     * 100% -> condição muito úmida
     *   0% -> condição extremamente seca
     *
     * O MAD representa a fração da água disponível que pode
     * ser utilizada antes de iniciar uma nova irrigação.
     */

    final double mad =
        fatorMAD();

    double limite =
        100.0 * (1.0 - mad);

    // Ajuste de sensibilidade conforme a fase fenológica.
    limite +=
        ajustePorFase();

    return limite
        .clamp(
          0.0,
          100.0,
        )
        .toDouble();
  }

  // ============================================================
  // MAD POR CULTURA
  // ============================================================

  double fatorMAD() {
    switch (configuracao.cultura) {
      case Cultura.milho:
        return 0.50;

      case Cultura.soja:
        return 0.50;

      case Cultura.trigo:
        return 0.50;

      case Cultura.canadeacucar:
        return 0.65;

      case Cultura.algodao:
        return 0.65;
    }
  }

  // ============================================================
  // AJUSTE PELA FASE FENOLÓGICA
  // ============================================================

  double ajustePorFase() {
    final String fase =
        configuracao.faseAtual
            .toLowerCase();

    // ==========================================================
    // FASES MAIS SENSÍVEIS
    // ==========================================================
    //
    // Milho:
    // Florescimento
    //
    // Soja:
    // Reprodutivo
    //
    // Trigo:
    // Espigamento/Florescimento
    //
    // Algodão:
    // Florada/Maçãs
    // ==========================================================

    if (fase.contains(
          'florescimento',
        ) ||
        fase.contains(
          'reprodutivo',
        ) ||
        fase.contains(
          'florada',
        )) {
      return 5.0;
    }

    // ==========================================================
    // DESENVOLVIMENTO VEGETATIVO
    // ==========================================================

    if (fase.contains(
          'desenvolvimento',
        ) ||
        fase.contains(
          'vegetativo',
        )) {
      return 2.0;
    }

    return 0.0;
  }

  // ============================================================
  // INTENSIDADE DA BOMBA
  // ============================================================

  int calcularIntensidade({
    required double humidity,
    required double limite,
    double? temperatura,
  }) {
    final double deficit =
        limite - humidity;

    // Solo pouco abaixo do limite.
    if (deficit < 5.0) {
      return 60;
    }

    // Solo moderadamente seco.
    if (deficit < 10.0) {
      return 100;
    }

    // Solo bastante seco.
    if (deficit < 20.0) {
      return 160;
    }

    // Solo muito seco.
    int pwm = 220;

    // Temperatura elevada aumenta a intensidade somente
    // quando o déficit já é elevado.
    if (temperatura != null &&
        temperatura >=
            temperaturaElevada) {
      pwm += 20;
    }

    return pwm
        .clamp(
          0,
          255,
        )
        .toInt();
  }

  // ============================================================
  // CHUVA SIGNIFICATIVA
  // ============================================================

  bool _chuvaSignificativa(
    List<WeatherHour> previsao,
  ) {
    if (previsao.isEmpty) {
      return false;
    }

    for (final hora in previsao) {
      // Precipitação relevante.
      if (hora.precipMm >=
          precipitacaoSignificativa) {
        return true;
      }

      // Alta probabilidade acompanhada da indicação
      // explícita de chuva da WeatherAPI.
      if (hora.chanceRain >=
              probabilidadeChuvaAlta &&
          hora.willRain == 1) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // MAIOR PROBABILIDADE DE CHUVA
  // ============================================================

  int _maiorChanceChuva(
    List<WeatherHour> previsao,
  ) {
    if (previsao.isEmpty) {
      return 0;
    }

    int maior = 0;

    for (final hora in previsao) {
      if (hora.chanceRain >
          maior) {
        maior =
            hora.chanceRain;
      }
    }

    return maior;
  }

  // ============================================================
  // PRECIPITAÇÃO TOTAL
  // ============================================================

  double _precipitacaoTotal(
    List<WeatherHour> previsao,
  ) {
    double total =
        0.0;

    for (final hora in previsao) {
      total +=
          hora.precipMm;
    }

    return total;
  }

  // ============================================================
  // DIAGNÓSTICO
  // ============================================================

  Map<String, dynamic> diagnostico() {
    return {
      'cultura':
          configuracao.nomeCultura,
      'solo':
          configuracao.nomeSolo,
      'fase':
          configuracao.faseAtual,
      'dias':
          configuracao.diasCultivo,
      'limite':
          calcularUmidadeMinima(),
      'MAD':
          fatorMAD(),
    };
  }
}

// ================================================================
// RESULTADO DA DECISÃO
// ================================================================

class ResultadoIrrigacao {
  final int pwm;

  final double limite;

  final String fase;

  final int dias;

  final String cultura;

  final String solo;

  final bool irrigar;

  final String motivo;

  final bool chuvaProxima;

  /// Nome mantido por compatibilidade.
  ///
  /// Representa a temperatura efetivamente utilizada pelo
  /// sistema, e não uma média das previsões.
  final double? temperaturaMedia;

  final int probabilidadeChuva;

  final double precipitacaoTotal;

  ResultadoIrrigacao({
    required this.pwm,
    required this.limite,
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
  });

  @override
  String toString() {
    return '''
      ResultadoIrrigacao(
        pwm: $pwm,
        irrigar: $irrigar,
        motivo: $motivo,
        cultura: $cultura,
        solo: $solo,
        fase: $fase,
        dias: $dias,
        umidade limite: ${limite.toStringAsFixed(1)}%,
        chuva próxima: $chuvaProxima,
        probabilidade de chuva: $probabilidadeChuva%,
        precipitação: ${precipitacaoTotal.toStringAsFixed(1)} mm,
        temperatura utilizada: ${temperaturaMedia?.toStringAsFixed(1) ?? '--'} °C
      )
      ''';
  }
}