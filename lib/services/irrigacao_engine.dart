import '../models/configuracao_cultivo.dart';

class IrrigacaoEngine {

  final ConfiguracaoCultivo configuracao;
  IrrigacaoEngine(this.configuracao);

  /// Calcula a velocidade da bomba.
  /// Retorno:
  /// 0   -> bomba desligada
  /// 1-255 -> PWM da bomba
  ResultadoIrrigacao calcularBomba({
      required double humidity,
      required bool boiaOk,
    }) {

      final limite = calcularUmidadeMinima();

      int pwm = 0;


      // Segurança
      if(!boiaOk){
        pwm = 0;
      }

      else if(humidity < limite){
        pwm = calcularIntensidade(
          humidity,
          limite,
        );
      }

      else{
        pwm = 0;
      }


      return ResultadoIrrigacao(
        pwm: pwm,
        limite: limite,
        fase: configuracao.faseAtual,
        dias: configuracao.diasCultivo,
        cultura: configuracao.nomeCultura,
        solo: configuracao.nomeSolo,
      );
    }

  /// Calcula o limite de irrigação (%)
  /// Baseado em:
  /// MAD = perda aceitável de água disponível
  double calcularUmidadeMinima(){
    final cc = capacidadeCampo();
    final pmp = pontoMurcha();
    final mad = fatorMAD();
    // Água disponível no solo:
    // AD = CC - PMP
    final aguaDisponivel =cc - pmp;
    // Momento de irrigar:
    // Limite = CC - (AD * MAD)
    final limite = cc - (aguaDisponivel * mad);
    return limite;
  }
  /// Capacidade de campo (%)
  /// Valores aproximados:
  /// Arenoso: 10%
  /// Franco: 25%
  /// Argiloso: 45%
  double capacidadeCampo(){
    switch(configuracao.solo){
      case TipoSolo.arenoso:
        return 10;
      case TipoSolo.franco:
        return 25;
      case TipoSolo.argiloso:
        return 45;
    }
  }

  /// Ponto de murcha permanente (%)
  ///
  /// Arenoso: 5%
  /// Franco: 12%
  /// Argiloso: 25%
  ///
  double pontoMurcha(){
    switch(configuracao.solo){
      case TipoSolo.arenoso:
        return 5;
      case TipoSolo.franco:
        return 12;
      case TipoSolo.argiloso:
        return 25;
    }
  }
  /// MAD:
  ///
  /// Milho:
  /// 0.50 - 0.55
  ///
  /// Soja:
  /// 0.50
  ///
  double fatorMAD(){
    switch(configuracao.cultura){
      case Cultura.milho:
        return 0.50;
      case Cultura.soja:
        return 0.50;
    }
  }

  /// Define a força da bomba.
  /// Quanto mais seco:
  /// maior PWM.
  int calcularIntensidade(double humidity,double limite) {
    final deficit = limite - humidity;
    if(deficit >= 20){
      return 255;
    }
    if(deficit >= 10){
      return 150;
    }
    return 80;
  }

  /// Informações para mostrar na tela
  /// de diagnóstico.
  Map<String,dynamic> diagnostico(){
    return {
      "cultura":configuracao.nomeCultura,
      "solo":configuracao.nomeSolo,
      "fase":configuracao.faseAtual,
      "dias":configuracao.diasCultivo,
      "limite":calcularUmidadeMinima(),
      "MAD":fatorMAD(),
    };
  }
}

class ResultadoIrrigacao {
  final int pwm;
  final double limite;
  final String fase;
  final int dias;
  final String cultura;
  final String solo;

  ResultadoIrrigacao({
    required this.pwm,
    required this.limite,
    required this.fase,
    required this.dias,
    required this.cultura,
    required this.solo,
  });
}