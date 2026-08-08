import '../models/configuracao_cultivo.dart';
import '../models/weather_hour.dart';

class IrrigacaoEngine {
  final ConfiguracaoCultivo configuracao;

  IrrigacaoEngine(this.configuracao);

  // ============================================================
  // DECISÃO PRINCIPAL
  // ============================================================

  ResultadoIrrigacao calcularBomba({
    required double humidity,
    required bool boiaOk,
    required List<WeatherHour> clima,
  }) {
    // Mantém a leitura dentro da escala do sensor.
    humidity = humidity.clamp(0.0, 100.0);

    final limite = calcularUmidadeMinima();

    // ------------------------------------------------------------
    // 1. Segurança da boia
    // ------------------------------------------------------------
    //
    // Se não existe água no reservatório, a bomba nunca deve
    // ser ligada, independentemente das outras condições.
    //
    if (!boiaOk) {
      return ResultadoIrrigacao(
        pwm: 0,
        limite: limite,
        fase: configuracao.faseAtual,
        dias: configuracao.diasCultivo,
        cultura: configuracao.nomeCultura,
        solo: configuracao.nomeSolo,
        irrigar: false,
        motivo: 'Reservatório sem água',
        chuvaProxima: false,
        temperaturaMedia: _temperaturaMedia(clima),
        probabilidadeChuva: _maiorChanceChuva(clima),
        precipitacaoTotal: _precipitacaoTotal(clima),
      );
    }

    // ------------------------------------------------------------
    // 2. Verifica a necessidade de irrigação pelo sensor
    // ------------------------------------------------------------

    final soloSeco = humidity < limite;

    if (!soloSeco) {
      return ResultadoIrrigacao(
        pwm: 0,
        limite: limite,
        fase: configuracao.faseAtual,
        dias: configuracao.diasCultivo,
        cultura: configuracao.nomeCultura,
        solo: configuracao.nomeSolo,
        irrigar: false,
        motivo: 'Umidade do solo acima do limiar',
        chuvaProxima: _chuvaSignificativa(clima),
        temperaturaMedia: _temperaturaMedia(clima),
        probabilidadeChuva: _maiorChanceChuva(clima),
        precipitacaoTotal: _precipitacaoTotal(clima),
      );
    }

    // ------------------------------------------------------------
    // 3. Verifica a previsão do tempo
    // ------------------------------------------------------------
    //
    // O sensor indicou que o solo precisa de água.
    //
    // Porém, se existe chuva suficiente prevista para as próximas
    // horas, evitamos ligar a bomba.
    //
    if (_chuvaSignificativa(clima)) {
      return ResultadoIrrigacao(
        pwm: 0,
        limite: limite,
        fase: configuracao.faseAtual,
        dias: configuracao.diasCultivo,
        cultura: configuracao.nomeCultura,
        solo: configuracao.nomeSolo,
        irrigar: false,
        motivo: 'Chuva prevista nas próximas horas',
        chuvaProxima: true,
        temperaturaMedia: _temperaturaMedia(clima),
        probabilidadeChuva: _maiorChanceChuva(clima),
        precipitacaoTotal: _precipitacaoTotal(clima),
      );
    }

    // ------------------------------------------------------------
    // 4. Verifica condições de temperatura
    // ------------------------------------------------------------
    //
    // Temperaturas muito altas aumentam a perda de água.
    // Nesse caso não bloqueamos a irrigação.
    //
    // A temperatura será usada para aumentar a intensidade
    // quando o solo estiver seco.
    //
    final temperatura = _temperaturaMedia(clima);

    // ------------------------------------------------------------
    // 5. Calcula o PWM
    // ------------------------------------------------------------

    int pwm = calcularIntensidade(
      humidity: humidity,
      limite: limite,
      temperatura: temperatura,
    );

    String motivo = 'Solo abaixo do limiar';

    if (temperatura != null && temperatura >= 35) {
      motivo = 'Solo seco e temperatura elevada';
    }

    return ResultadoIrrigacao(
      pwm: pwm,
      limite: limite,
      fase: configuracao.faseAtual,
      dias: configuracao.diasCultivo,
      cultura: configuracao.nomeCultura,
      solo: configuracao.nomeSolo,
      irrigar: pwm > 0,
      motivo: motivo,
      chuvaProxima: false,
      temperaturaMedia: temperatura,
      probabilidadeChuva: _maiorChanceChuva(clima),
      precipitacaoTotal: _precipitacaoTotal(clima),
    );
  }

  // ============================================================
  // LIMIAR DE UMIDADE
  // ============================================================

  double calcularUmidadeMinima() {
    /*
     * O sensor está calibrado em uma escala própria:
     *
     * 100% -> condição muito molhada
     *   0% -> extremamente seco
     *
     * Portanto não usamos diretamente valores de capacidade
     * de campo e ponto de murcha em porcentagem física.
     *
     * O MAD representa quanto da água disponível podemos perder
     * antes de iniciar uma nova irrigação.
     *
     * MAD = 0.50
     *
     * Significa que usamos aproximadamente 50% da faixa útil
     * antes de irrigar.
     */

    final mad = fatorMAD();

    // Escala do sensor: 100% = completamente úmido.
    //
    // Exemplo:
    // MAD 0.50 -> limiar de aproximadamente 50%.
    double limite = 100.0 * (1.0 - mad);

    // Algumas fases são mais sensíveis à falta de água.
    //
    // Nessas fases elevamos um pouco o limiar para que a
    // irrigação aconteça antes.
    limite += ajustePorFase();

    return limite.clamp(0.0, 100.0);
  }

  // ============================================================
  // MAD
  // ============================================================

  double fatorMAD() {
    switch (configuracao.cultura) {
      case Cultura.milho:
        return 0.50;

      case Cultura.soja:
        return 0.50;
    }
  }

  // ============================================================
  // AJUSTE DE ACORDO COM A FASE
  // ============================================================

  double ajustePorFase() {
    final fase = configuracao.faseAtual.toLowerCase();

    // No florescimento/reprodução, a falta de água é mais crítica.
    if (fase.contains('florescimento') ||
        fase.contains('reprodutivo')) {
      return 5.0;
    }

    // Durante o desenvolvimento vegetativo fazemos um pequeno
    // ajuste, mas sem deixar o sistema irrigar excessivamente.
    if (fase.contains('desenvolvimento') ||
        fase.contains('vegetativo')) {
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
    final deficit = limite - humidity;

    // Solo apenas um pouco abaixo do limite.
    if (deficit < 5) {
      return 60;
    }

    // Solo moderadamente seco.
    if (deficit < 10) {
      return 100;
    }

    // Solo bastante seco.
    if (deficit < 20) {
      return 160;
    }

    // Solo muito seco.
    int pwm = 220;

    // Temperatura elevada aumenta a necessidade de água.
    if (temperatura != null && temperatura >= 35) {
      pwm += 20;
    }

    return pwm.clamp(0, 255);
  }

  // ============================================================
  // CHUVA
  // ============================================================

  bool _chuvaSignificativa(List<WeatherHour> previsao) {
    if (previsao.isEmpty) {
      return false;
    }

    for (final hora in previsao) {
      // Chuva prevista com precipitação relevante.
      if (hora.precipMm >= 2.0) {
        return true;
      }

      // Mesmo que a precipitação estimada seja pequena, uma
      // probabilidade muito alta também merece ser considerada.
      if (hora.chanceRain >= 70 && hora.willRain == 1) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // PROBABILIDADE DE CHUVA
  // ============================================================

  int _maiorChanceChuva(List<WeatherHour> previsao) {
    if (previsao.isEmpty) {
      return 0;
    }

    int maior = 0;

    for (final hora in previsao) {
      if (hora.chanceRain > maior) {
        maior = hora.chanceRain;
      }
    }

    return maior;
  }

  // ============================================================
  // PRECIPITAÇÃO
  // ============================================================

  double _precipitacaoTotal(List<WeatherHour> previsao) {
    double total = 0;

    for (final hora in previsao) {
      total += hora.precipMm;
    }

    return total;
  }

  // ============================================================
  // TEMPERATURA
  // ============================================================

  double? _temperaturaMedia(List<WeatherHour> previsao) {
    if (previsao.isEmpty) {
      return null;
    }

    double soma = 0;

    for (final hora in previsao) {
      soma += hora.tempC;
    }

    return soma / previsao.length;
  }

  // ============================================================
  // DIAGNÓSTICO
  // ============================================================

  Map<String, dynamic> diagnostico() {
    return {
      'cultura': configuracao.nomeCultura,
      'solo': configuracao.nomeSolo,
      'fase': configuracao.faseAtual,
      'dias': configuracao.diasCultivo,
      'limite': calcularUmidadeMinima(),
      'MAD': fatorMAD(),
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
        temperatura média: ${temperaturaMedia?.toStringAsFixed(1) ?? '--'} °C
      )
      ''';
  }
}
