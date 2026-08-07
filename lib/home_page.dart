import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'services/irrigacao_ble_controller.dart';

class HomePage extends StatefulWidget {
  final IrrigacaoBleController controller;
  const HomePage({super.key, required this.controller,});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Sem limite de tamanho: guarda todas as leituras da sessão.
  final List<IrrigacaoState> _historico = [];

  @override
  void initState() {
    super.initState();
    widget.controller.stateStream.listen(_onNovoEstado);
  }

  void _onNovoEstado(IrrigacaoState state) {
    setState(() {
      _historico.add(state);
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atual = _historico.isNotEmpty ? _historico.last : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Irrigação')),
      body: atual == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aguardando primeira leitura do ESP32...',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(state: atual),
                const SizedBox(height: 16),
                Text(
                  'Histórico de umidade (${_historico.length} leituras)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _HistoricoChart(historico: _historico),
                const SizedBox(height: 8),
                const _ChartLegend(),
              ],
            ),
    );
  }
}

/// Gráfico de linha com o histórico completo de umidade (e bomba, em escala
/// secundária). Rola horizontalmente quando há muitos pontos, em vez de
/// espremer tudo na largura da tela.
class _HistoricoChart extends StatelessWidget {
  final List<IrrigacaoState> historico;

  const _HistoricoChart({required this.historico});

  static const double _pxPorPonto = 6.0;
  static const double _alturaGrafico = 260.0;

  @override
  Widget build(BuildContext context) {
    final primeiro = historico.first.timestamp;

    final humidadeSpots = <FlSpot>[];
    final bombaSpots = <FlSpot>[]; // bomba (0-255) escalada para 0-100
    final boiaBaixaMarks = <double>[];

    for (var i = 0; i < historico.length; i++) {
      final s = historico[i];
      final x = s.timestamp.difference(primeiro).inSeconds.toDouble();

      humidadeSpots.add(FlSpot(x, s.humidity));
      bombaSpots.add(FlSpot(x, (s.bomba / 255.0) * 100.0));
      if (!s.boiaOk) boiaBaixaMarks.add(x);
    }

    final larguraCalculada = historico.length * _pxPorPonto;

    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = larguraCalculada < constraints.maxWidth
            ? constraints.maxWidth
            : larguraCalculada;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // já abre mostrando a leitura mais recente
          child: SizedBox(
            width: largura,
            height: _alturaGrafico,
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
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (value, meta) =>
                          Text('${value.toInt()}%'),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 75,
                      color: Colors.orange.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                    HorizontalLine(
                      y: 85,
                      color: Colors.green.withOpacity(0.6),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      if (s.barIndex != 0) return null; // só tooltip da umidade
                      return LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}%',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  // Umidade
                  LineChartBarData(
                    spots: humidadeSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.12),
                    ),
                  ),
                  // Intensidade da bomba (0-255 escalado p/ 0-100)
                  LineChartBarData(
                    spots: bombaSpots,
                    isCurved: false,
                    color: Colors.teal.withOpacity(0.7),
                    barWidth: 1.5,
                    dashArray: [4, 3],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: const [
        _LegendItem(color: Colors.blue, label: 'Umidade'),
        _LegendItem(color: Colors.teal, label: 'Bomba (intensidade)'),
        _LegendItem(color: Colors.orange, label: 'Limite 75%'),
        _LegendItem(color: Colors.green, label: 'Limite 85%'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IrrigacaoState state;

  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.humidity.toStringAsFixed(1)}%',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(
                  state.irrigando ? Icons.water_drop : Icons.water_drop_outlined,
                  size: 40,
                  color: state.irrigando ? Colors.blue : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Boia',
              value: state.boiaOk ? 'Água OK' : 'Água baixa',
              color: state.boiaOk ? Colors.green : Colors.red,
            ),
            _InfoRow(
              label: 'Bomba (PWM)',
              value: '${state.bomba}',
              color: state.irrigando ? Colors.blue : Colors.grey,
            ),
            _InfoRow(
              label: 'Irrigando',
              value: state.irrigando ? 'Sim' : 'Não',
              color: state.irrigando ? Colors.blue : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}