import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'models/configuracao_cultivo.dart';
import 'models/weather_hour.dart';
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<IrrigacaoState> _historico = [];

  StreamSubscription<IrrigacaoState>? _stateSubscription;

  @override
  void initState() {
    super.initState();

    _stateSubscription =
        widget.controller.stateStream.listen(_onNovoEstado);
  }

  void _onNovoEstado(IrrigacaoState state) {
    if (!mounted) return;

    setState(() {
      _historico.add(state);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    widget.controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atual = _historico.isNotEmpty ? _historico.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Irrigação'),
      ),
      body: atual == null
          ? _TelaAguardando(
              configuracao: widget.configuracao,
              cidade: widget.cidade,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CultivoCard(
                  configuracao: widget.configuracao,
                  cidade: widget.cidade,
                ),

                const SizedBox(height: 16),

                _StatusCard(
                  state: atual,
                ),

                const SizedBox(height: 16),

                _ClimaCard(
                  state: atual,
                ),

                const SizedBox(height: 16),

                _DecisaoCard(
                  state: atual,
                ),

                const SizedBox(height: 16),

                Text(
                  'Histórico de umidade',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 8),

                Text(
                  '${_historico.length} leituras recebidas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                const SizedBox(height: 8),

                if (_historico.length >= 2)
                  _HistoricoChart(
                    historico: _historico,
                  )
                else
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        'Aguardando mais leituras para montar o gráfico.',
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                const _ChartLegend(),

                const SizedBox(height: 24),

                _UltimaAtualizacao(
                  timestamp: atual.timestamp,
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CultivoCard(
          configuracao: configuracao,
          cidade: cidade,
        ),

        const SizedBox(height: 32),

        const Center(
          child: CircularProgressIndicator(),
        ),

        const SizedBox(height: 24),

        const Text(
          'Aguardando primeira leitura do ESP32...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'O aplicativo está aguardando os dados do sensor de umidade e da boia.',
          textAlign: TextAlign.center,
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

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco),
                const SizedBox(width: 8),
                Text(
                  'Cultivo',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _InfoRow(
              label: 'Cultura',
              value: configuracao.nomeCultura,
            ),

            _InfoRow(
              label: 'Tipo de solo',
              value: configuracao.nomeSolo,
            ),

            _InfoRow(
              label: 'Data do plantio',
              value: _formatarData(
                configuracao.dataPlantio,
              ),
            ),

            _InfoRow(
              label: 'Idade do plantio',
              value: '${configuracao.diasCultivo} dias',
            ),

            _InfoRow(
              label: 'Fase atual',
              value: configuracao.faseAtual,
            ),

            _InfoRow(
              label: 'Cidade',
              value: cidade,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATUS DO SENSOR
// ============================================================

class _StatusCard extends StatelessWidget {
  final IrrigacaoState state;

  const _StatusCard({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final corUmidade = state.humidity < state.limite
        ? Colors.orange
        : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado do sistema',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

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

                    const SizedBox(height: 4),

                    Text(
                      '${state.humidity.toStringAsFixed(1)}%',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: corUmidade,
                          ),
                    ),
                  ],
                ),

                Icon(
                  state.irrigando
                      ? Icons.water_drop
                      : Icons.water_drop_outlined,
                  size: 50,
                  color: state.irrigando
                      ? Colors.blue
                      : Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _InfoRow(
              label: 'Limiar de irrigação',
              value:
                  '${state.limite.toStringAsFixed(1)}%',
            ),

            _InfoRow(
              label: 'MAD',
              value:
                  '${(state.mad * 100).toStringAsFixed(0)}%',
            ),

            _InfoRow(
              label: 'Boia',
              value: state.boiaOk
                  ? 'Água OK'
                  : 'Água baixa',
              color: state.boiaOk
                  ? Colors.green
                  : Colors.red,
            ),

            _InfoRow(
              label: 'PWM da bomba',
              value: '${state.bomba}',
              color: state.irrigando
                  ? Colors.blue
                  : Colors.grey,
            ),

            _InfoRow(
              label: 'Irrigando',
              value: state.irrigando
                  ? 'Sim'
                  : 'Não',
              color: state.irrigando
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud),
                const SizedBox(width: 8),
                Text(
                  'Condições climáticas',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _InfoRow(
              label: 'Temperatura média',
              value: state.temperaturaMedia != null
                  ? '${state.temperaturaMedia!.toStringAsFixed(1)} °C'
                  : '--',
            ),

            _InfoRow(
              label: 'Probabilidade de chuva',
              value:
                  '${state.probabilidadeChuva}%',
            ),

            _InfoRow(
              label: 'Precipitação prevista',
              value:
                  '${state.precipitacaoTotal.toStringAsFixed(1)} mm',
            ),

            _InfoRow(
              label: 'Chuva significativa',
              value: state.chuvaProxima
                  ? 'Sim'
                  : 'Não',
              color: state.chuvaProxima
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
// DECISÃO DA IRRIGAÇÃO
// ============================================================

class _DecisaoCard extends StatelessWidget {
  final IrrigacaoState state;

  const _DecisaoCard({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final cor = state.irrigando
        ? Colors.blue
        : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Decisão da irrigação',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: cor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.irrigando
                        ? Icons.play_arrow
                        : Icons.stop,
                    color: cor,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      state.irrigando
                          ? 'Irrigação ativada'
                          : 'Irrigação não necessária',
                      style: TextStyle(
                        color: cor,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Motivo:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

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

  static const double _altura = 260;

  @override
  Widget build(BuildContext context) {
    final primeiro =
        historico.first.timestamp;

    final umidadeSpots = <FlSpot>[];
    final bombaSpots = <FlSpot>[];

    for (var i = 0; i < historico.length; i++) {
      final state = historico[i];

      final x = state.timestamp
          .difference(primeiro)
          .inSeconds
          .toDouble();

      umidadeSpots.add(
        FlSpot(
          x,
          state.humidity,
        ),
      );

      bombaSpots.add(
        FlSpot(
          x,
          (state.bomba / 255.0) * 100.0,
        ),
      );
    }

    return SizedBox(
      height: _altura,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,

          gridData: FlGridData(
            show: true,
            horizontalInterval: 25,
            drawVerticalLine: false,
          ),

          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),

            rightTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),

            bottomTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget:
                    (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                  );
                },
              ),
            ),
          ),

          borderData:
              FlBorderData(
            show: true,
          ),

          extraLinesData:
              ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: historico.last.limite,
                color: Colors.orange,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),

          lineTouchData:
              LineTouchData(
            touchTooltipData:
                LineTouchTooltipData(
              getTooltipItems:
                  (spots) {
                return spots.map(
                  (spot) {
                    if (spot.barIndex != 0) {
                      return null;
                    }

                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)}%',
                      const TextStyle(
                        color: Colors.white,
                      ),
                    );
                  },
                ).toList();
              },
            ),
          ),

          lineBarsData: [
            // Umidade
            LineChartBarData(
              spots: umidadeSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              dotData:
                  const FlDotData(
                show: false,
              ),
              belowBarData:
                  BarAreaData(
                show: true,
                color:
                    Colors.blue.withOpacity(
                  0.12,
                ),
              ),
            ),

            // Bomba
            LineChartBarData(
              spots: bombaSpots,
              isCurved: false,
              color: Colors.teal,
              barWidth: 1.5,
              dashArray: [4, 3],
              dotData:
                  const FlDotData(
                show: false,
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
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(
          color: Colors.blue,
          label: 'Umidade',
        ),
        _LegendItem(
          color: Colors.teal,
          label: 'Bomba',
        ),
        _LegendItem(
          color: Colors.orange,
          label: 'Limiar',
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),

        const SizedBox(width: 5),

        Text(label),
      ],
    );
  }
}

// ============================================================
// ÚLTIMA ATUALIZAÇÃO
// ============================================================

class _UltimaAtualizacao extends StatelessWidget {
  final DateTime timestamp;

  const _UltimaAtualizacao({
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final hora =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';

    return Center(
      child: Text(
        'Última leitura: $hora',
        style: Theme.of(context)
            .textTheme
            .bodySmall,
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
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
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