import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'models/configuracao_cultivo.dart';
import 'services/irrigacao_ble_controller.dart';

class HomePage extends StatefulWidget {
  final IrrigacaoBleController controller;
  final ConfiguracaoCultivo configuracao;
  final String cidade;

  const HomePage({
    super.key,
    required this.controller,
    required this.configuracao,
    required this.cidade,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ============================================================
  // HISTÓRICO
  // ============================================================

  final List<IrrigacaoState> _historico = [];

  /// Limita a quantidade de leituras mantidas em memória.
  ///
  /// O HydroFlow não utiliza banco de dados.
  static const int _maxHistorico = 200;

  StreamSubscription<IrrigacaoState>?
      _stateSubscription;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Primeiro começamos a escutar os próximos estados.
    _stateSubscription =
        widget.controller.stateStream.listen(
      _onNovoEstado,
    );

    // Como stateStream é broadcast, um estado emitido antes
    // da HomePage começar a escutar poderia ser perdido.
    //
    // Por isso recuperamos o último estado armazenado
    // pelo Controller.
    final estadoInicial =
        widget.controller.lastState;

    if (estadoInicial != null) {
      _historico.add(
        estadoInicial,
      );
    }
  }

  // ============================================================
  // NOVO ESTADO
  // ============================================================

  void _onNovoEstado(
    IrrigacaoState state,
  ) {
    if (!mounted) {
      return;
    }

    // Evita adicionar duas vezes exatamente o mesmo objeto
    // caso ele também tenha sido recuperado por lastState.
    if (_historico.isNotEmpty &&
        identical(
          _historico.last,
          state,
        )) {
      return;
    }

    setState(() {
      _historico.add(
        state,
      );

      // Mantém apenas as leituras mais recentes.
      if (_historico.length >
          _maxHistorico) {
        _historico.removeRange(
          0,
          _historico.length -
              _maxHistorico,
        );
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    unawaited(
      _stateSubscription?.cancel(),
    );

    unawaited(
      widget.controller.dispose(),
    );

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final IrrigacaoState? atual =
        _historico.isNotEmpty
            ? _historico.last
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Irrigação',
        ),
      ),

      body: atual == null
          ? _TelaAguardando(
              configuracao:
                  widget.configuracao,
              cidade:
                  widget.cidade,
            )
          : ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: [
                // =================================================
                // CULTIVO
                // =================================================

                _CultivoCard(
                  configuracao:
                      widget.configuracao,
                  cidade:
                      widget.cidade,
                ),

                const SizedBox(
                  height: 16,
                ),

                // =================================================
                // SISTEMA
                // =================================================

                _StatusCard(
                  state:
                      atual,
                ),

                const SizedBox(
                  height: 16,
                ),

                // =================================================
                // CLIMA
                // =================================================

                _ClimaCard(
                  state:
                      atual,
                ),

                const SizedBox(
                  height: 16,
                ),

                // =================================================
                // DECISÃO
                // =================================================

                _DecisaoCard(
                  state:
                      atual,
                ),

                const SizedBox(
                  height: 24,
                ),

                // =================================================
                // HISTÓRICO
                // =================================================

                Text(
                  'Histórico de umidade',
                  style:
                      Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  '${_historico.length} leituras recebidas',
                  style:
                      Theme.of(
                    context,
                  ).textTheme.bodySmall,
                ),

                const SizedBox(
                  height: 8,
                ),

                if (_historico.length >= 2)
                  _HistoricoChart(
                    historico:
                        _historico,
                  )
                else
                  const SizedBox(
                    height:
                        180,
                    child:
                        Center(
                      child:
                          Text(
                        'Aguardando mais leituras para montar o gráfico.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 8,
                ),

                const _ChartLegend(),

                const SizedBox(
                  height: 24,
                ),

                // =================================================
                // HORÁRIO
                // =================================================

                _UltimaAtualizacao(
                  timestamp:
                      atual.timestamp,
                ),
              ],
            ),
    );
  }
}

// ============================================================
// TELA INICIAL
// ============================================================

class _TelaAguardando extends StatelessWidget {
  final ConfiguracaoCultivo configuracao;
  final String cidade;

  const _TelaAguardando({
    required this.configuracao,
    required this.cidade,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding:
          const EdgeInsets.all(
        16,
      ),
      children: [
        _CultivoCard(
          configuracao:
              configuracao,
          cidade:
              cidade,
        ),

        const SizedBox(
          height: 32,
        ),

        const Center(
          child:
              CircularProgressIndicator(),
        ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Aguardando primeira leitura do ESP32...',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            fontSize: 16,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        const Text(
          'O aplicativo está aguardando os dados de umidade, '
          'reservatório, temperatura e horário do ESP32.',
          textAlign:
              TextAlign.center,
        ),
      ],
    );
  }
}

// ============================================================
// CULTIVO
// ============================================================

class _CultivoCard extends StatelessWidget {
  final ConfiguracaoCultivo configuracao;
  final String cidade;

  const _CultivoCard({
    required this.configuracao,
    required this.cidade,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.eco,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Cultivo',
                  style:
                      Theme.of(
                    context,
                  )
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            _InfoRow(
              label:
                  'Cultura',
              value:
                  configuracao.nomeCultura,
            ),

            _InfoRow(
              label:
                  'Tipo de solo',
              value:
                  configuracao.nomeSolo,
            ),

            _InfoRow(
              label:
                  'Data do plantio',
              value:
                  configuracao
                      .dataPlantioFormatada,
            ),

            _InfoRow(
              label:
                  'Idade do plantio',
              value:
                  '${configuracao.diasCultivo} dias',
            ),

            _InfoRow(
              label:
                  'Fase atual',
              value:
                  configuracao.faseAtual,
            ),

            _InfoRow(
              label:
                  'Cidade',
              value:
                  cidade,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATUS
// ============================================================

class _StatusCard extends StatelessWidget {
  final IrrigacaoState state;

  const _StatusCard({
    required this.state,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color corUmidade =
        state.humidity <
                state.limite
            ? Colors.orange
            : Colors.green;

    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Estado do sistema',
              style:
                  Theme.of(
                context,
              )
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),

            const SizedBox(
              height: 16,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Umidade do solo',
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      '${state.humidity.toStringAsFixed(1)}%',
                      style:
                          Theme.of(
                        context,
                      )
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    corUmidade,
                              ),
                    ),
                  ],
                ),

                Icon(
                  state.irrigando
                      ? Icons.water_drop
                      : Icons.water_drop_outlined,
                  size:
                      50,
                  color:
                      state.irrigando
                          ? Colors.blue
                          : Colors.grey,
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            _InfoRow(
              label:
                  'Limiar de irrigação',
              value:
                  '${state.limite.toStringAsFixed(1)}%',
            ),

            _InfoRow(
              label:
                  'MAD',
              value:
                  '${(state.mad * 100).toStringAsFixed(0)}%',
            ),

            _InfoRow(
              label:
                  'Reservatório',
              value:
                  state.boiaOk
                      ? 'Água suficiente'
                      : 'Sem água',
              color:
                  state.boiaOk
                      ? Colors.green
                      : Colors.red,
            ),

            _InfoRow(
              label:
                  'PWM da bomba',
              value:
                  '${state.bomba}',
              color:
                  state.irrigando
                      ? Colors.blue
                      : Colors.grey,
            ),

            _InfoRow(
              label:
                  'Potência da bomba',
              value:
                  '${((state.bomba / 255.0) * 100.0).toStringAsFixed(0)}%',
              color:
                  state.irrigando
                      ? Colors.blue
                      : Colors.grey,
            ),

            _InfoRow(
              label:
                  'Irrigando',
              value:
                  state.irrigando
                      ? 'Sim'
                      : 'Não',
              color:
                  state.irrigando
                      ? Colors.blue
                      : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CLIMA
// ============================================================

class _ClimaCard extends StatelessWidget {
  final IrrigacaoState state;

  const _ClimaCard({
    required this.state,
  });

  String get _fonteTemperatura {
    if (state.usandoTemperaturaLocal) {
      return 'DS3231';
    }

    if (state.apiDisponivel &&
        state.temperaturaMedia != null) {
      return 'WeatherAPI';
    }

    return 'Indisponível';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  'Condições climáticas',
                  style:
                      Theme.of(
                    context,
                  )
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // TEMPERATURA
            // ==================================================

            _InfoRow(
              label:
                  'Temperatura utilizada',
              value:
                  state.temperaturaMedia != null
                      ? '${state.temperaturaMedia!.toStringAsFixed(1)} °C'
                      : '--',
            ),

            _InfoRow(
              label:
                  'Fonte da temperatura',
              value:
                  _fonteTemperatura,
              color:
                  state.usandoTemperaturaLocal
                      ? Colors.orange
                      : state.apiDisponivel
                          ? Colors.green
                          : Colors.grey,
            ),

            _InfoRow(
              label:
                  'WeatherAPI',
              value:
                  state.apiDisponivel
                      ? 'Disponível'
                      : 'Indisponível',
              color:
                  state.apiDisponivel
                      ? Colors.green
                      : Colors.orange,
            ),

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // PREVISÃO
            // ==================================================

            if (state.apiDisponivel) ...[
              _InfoRow(
                label:
                    'Probabilidade de chuva (2h)',
                value:
                    '${state.probabilidadeChuva}%',
              ),

              _InfoRow(
                label:
                    'Precipitação considerada (2h)',
                value:
                    '${state.precipitacaoTotal.toStringAsFixed(1)} mm',
              ),

              _InfoRow(
                label:
                    'Chuva significativa (2h)',
                value:
                    state.chuvaProxima
                        ? 'Sim'
                        : 'Não',
                color:
                    state.chuvaProxima
                        ? Colors.blue
                        : Colors.grey,
              ),
            ] else ...[
              Container(
                width:
                    double.infinity,
                margin:
                    const EdgeInsets.only(
                  top: 8,
                ),
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                  color:
                      Colors.orange.withOpacity(
                    0.08,
                  ),
                ),
                child:
                    const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      color:
                          Colors.orange,
                    ),

                    SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child:
                          Text(
                        'Previsão meteorológica indisponível. '
                        'A decisão de irrigação está utilizando '
                        'somente os dados locais disponíveis.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DECISÃO
// ============================================================

class _DecisaoCard extends StatelessWidget {
  final IrrigacaoState state;

  const _DecisaoCard({
    required this.state,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color cor =
        state.irrigando
            ? Colors.blue
            : Colors.grey;

    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Decisão da irrigação',
              style:
                  Theme.of(
                context,
              )
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),

            const SizedBox(
              height: 16,
            ),

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                border:
                    Border.all(
                  color:
                      cor,
                ),
              ),
              child:
                  Row(
                children: [
                  Icon(
                    state.irrigando
                        ? Icons.play_arrow
                        : Icons.stop,
                    color:
                        cor,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        Text(
                      state.irrigando
                          ? 'Irrigação ativada'
                          : 'Irrigação desativada',
                      style:
                          TextStyle(
                        color:
                            cor,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Motivo:',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              state.motivo,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// GRÁFICO
// ============================================================

class _HistoricoChart extends StatelessWidget {
  final List<IrrigacaoState> historico;

  const _HistoricoChart({
    required this.historico,
  });

  static const double _altura =
      260;

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<FlSpot> umidadeSpots =
        [];

    final List<FlSpot> bombaSpots =
        [];

    // Utilizamos o índice da leitura no eixo X.
    //
    // Isso permite manter o gráfico funcionando mesmo
    // quando o DS3231 estiver indisponível e timestamp == null.
    for (var i = 0;
        i < historico.length;
        i++) {
      final state =
          historico[i];

      final x =
          i.toDouble();

      umidadeSpots.add(
        FlSpot(
          x,
          state.humidity,
        ),
      );

      bombaSpots.add(
        FlSpot(
          x,
          (state.bomba / 255.0) *
              100.0,
        ),
      );
    }

    return SizedBox(
      height:
          _altura,
      child:
          LineChart(
        LineChartData(
          minY:
              0,
          maxY:
              100,

          gridData:
              FlGridData(
            show:
                true,
            horizontalInterval:
                25,
            drawVerticalLine:
                false,
          ),

          titlesData:
              FlTitlesData(
            topTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),

            rightTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),

            bottomTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    false,
              ),
            ),

            leftTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles:
                    true,
                reservedSize:
                    40,
                interval:
                    25,
                getTitlesWidget:
                    (
                  value,
                  meta,
                ) {
                  return Text(
                    '${value.toInt()}%',
                  );
                },
              ),
            ),
          ),

          borderData:
              FlBorderData(
            show:
                true,
          ),

          // ====================================================
          // LIMIAR
          // ====================================================

          extraLinesData:
              ExtraLinesData(
            horizontalLines:
                [
              HorizontalLine(
                y:
                    historico.last.limite,
                color:
                    Colors.orange,
                strokeWidth:
                    1.5,
                dashArray:
                    [6, 4],
              ),
            ],
          ),

          // ====================================================
          // TOOLTIP
          // ====================================================

          lineTouchData:
              LineTouchData(
            touchTooltipData:
                LineTouchTooltipData(
              getTooltipItems:
                  (spots) {
                return spots.map(
                  (
                    spot,
                  ) {
                    if (spot.barIndex ==
                        0) {
                      return LineTooltipItem(
                        'Umidade: '
                        '${spot.y.toStringAsFixed(1)}%',
                        const TextStyle(
                          color:
                              Colors.white,
                        ),
                      );
                    }

                    return LineTooltipItem(
                      'Bomba: '
                      '${spot.y.toStringAsFixed(0)}%',
                      const TextStyle(
                        color:
                            Colors.white,
                      ),
                    );
                  },
                ).toList();
              },
            ),
          ),

          // ====================================================
          // LINHAS
          // ====================================================

          lineBarsData:
              [
            // Umidade
            LineChartBarData(
              spots:
                  umidadeSpots,
              isCurved:
                  true,
              color:
                  Colors.blue,
              barWidth:
                  2,
              dotData:
                  const FlDotData(
                show:
                    false,
              ),
              belowBarData:
                  BarAreaData(
                show:
                    true,
                color:
                    Colors.blue.withOpacity(
                  0.12,
                ),
              ),
            ),

            // Bomba (% PWM)
            LineChartBarData(
              spots:
                  bombaSpots,
              isCurved:
                  false,
              color:
                  Colors.teal,
              barWidth:
                  1.5,
              dashArray:
                  [4, 3],
              dotData:
                  const FlDotData(
                show:
                    false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LEGENDA
// ============================================================

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Wrap(
      spacing:
          16,
      runSpacing:
          8,
      children: [
        _LegendItem(
          color:
              Colors.blue,
          label:
              'Umidade (%)',
        ),
        _LegendItem(
          color:
              Colors.teal,
          label:
              'Bomba (% PWM)',
        ),
        _LegendItem(
          color:
              Colors.orange,
          label:
              'Limiar',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width:
              12,
          height:
              12,
          color:
              color,
        ),

        const SizedBox(
          width: 5,
        ),

        Text(
          label,
        ),
      ],
    );
  }
}

// ============================================================
// ÚLTIMA ATUALIZAÇÃO
// ============================================================

class _UltimaAtualizacao extends StatelessWidget {
  final DateTime? timestamp;

  const _UltimaAtualizacao({
    required this.timestamp,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (timestamp == null) {
      return Center(
        child:
            Text(
          'Horário do DS3231 indisponível',
          style:
              Theme.of(
            context,
          ).textTheme.bodySmall,
        ),
      );
    }

    final hora =
        '${timestamp!.hour.toString().padLeft(2, '0')}:'
        '${timestamp!.minute.toString().padLeft(2, '0')}:'
        '${timestamp!.second.toString().padLeft(2, '0')}';

    return Center(
      child:
          Text(
        'Última leitura (DS3231): $hora',
        style:
            Theme.of(
          context,
        ).textTheme.bodySmall,
      ),
    );
  }
}

// ============================================================
// LINHA DE INFORMAÇÃO
// ============================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Text(
              label,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Flexible(
            child:
                Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  TextStyle(
                color:
                    color,
                fontWeight:
                    color != null
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}