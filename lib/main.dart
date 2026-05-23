// main.dart

import 'package:flutter/material.dart';
import 'models/weather_hour.dart';
import 'models/crop_data.dart';
import 'services/weather_service.dart';
import 'logic/irrigation_logic.dart';
import 'pages/setup_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const CityPage(),
    );
  }
}

// ── Tela 1: Cidade ───────────────────────────────────────────────────────────

class CityPage extends StatefulWidget {
  const CityPage({super.key});

  @override
  State<CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<CityPage> {

  final TextEditingController cityController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: Padding(
          padding: const EdgeInsets.all(30),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.water_drop,
                size: 100,
                color: Colors.green,
              ),

              const SizedBox(height: 30),

              const Text(
                'Sistema Inteligente de Irrigação',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'Digite a cidade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {

                    // Abre tela de configuração da lavoura
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SetupPage(),
                      ),
                    );

                    if (result != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardPage(
                            city: cityController.text,
                            soil: result['soil'] as SoilType,
                            crop: result['crop'] as CropType,
                            plantingDate:
                                result['plantingDate'] as DateTime,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tela 2: Dashboard ────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {

  final String city;
  final SoilType soil;
  final CropType crop;
  final DateTime plantingDate;

  const DashboardPage({
    super.key,
    required this.city,
    required this.soil,
    required this.crop,
    required this.plantingDate,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  final WeatherService weatherService = WeatherService();

  List<WeatherHour> forecast = [];

  String currentTemp = '-';
  String condition = '-';
  String maxTemp = '-';
  String minTemp = '-';

  IrrigationResult? irrigationResult;

  bool loading = true;

  // MOCK TEMPORÁRIO ESP32
  double soilHumidity = 9.0;
  bool waterLevel = true;

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {

    try {

      forecast = await weatherService.getForecast(widget.city);

      irrigationResult = IrrigationLogic.evaluate(
        soilHumidity: soilHumidity,
        soil: widget.soil,
        crop: widget.crop,
        plantingDate: widget.plantingDate,
        forecast: forecast,
      );

      setState(() {
        currentTemp =
            '${forecast[0].tempC.toStringAsFixed(1)} °C';
        condition = forecast[0].condition;

        double max = forecast
            .map((e) => e.tempC)
            .reduce((a, b) => a > b ? a : b);
        double min = forecast
            .map((e) => e.tempC)
            .reduce((a, b) => a < b ? a : b);

        maxTemp = '${max.toStringAsFixed(1)} °C';
        minTemp = '${min.toStringAsFixed(1)} °C';
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar clima'),
          ),
        );
      }
    }

    setState(() => loading = false);
  }

  IconData getWeatherIcon(String condition) {

    final c = condition.toLowerCase();

    if (c.contains('rain') ||
        c.contains('drizzle') ||
        c.contains('shower')) {
      return Icons.cloudy_snowing;
    }
    if (c.contains('cloud') ||
        c.contains('overcast') ||
        c.contains('mist') ||
        c.contains('fog')) {
      return Icons.cloud;
    }
    if (c.contains('sunny') || c.contains('clear')) {
      return Icons.wb_sunny;
    }
    return Icons.wb_cloudy;
  }

  Color _statusColor(String status) {
    if (status.contains('URGENTE')) return Colors.red.shade700;
    if (status.contains('IRRIGAR')) return Colors.green;
    if (status.contains('AGUARDAR')) return Colors.blue;
    if (status.contains('ÚMIDO') || status.contains('ADEQUADO')) {
      return Colors.teal;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final result = irrigationResult;

    return Scaffold(

      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Reconfigurar lavoura',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),

      body: SingleChildScrollView(

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(

            children: [

              // ── Cidade e clima atual ───────────────────────────────────────

              Text(
                widget.city,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Text(
                currentTemp,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                condition,
                style: const TextStyle(fontSize: 22),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    const Text('Máxima'),
                    Text(maxTemp),
                  ]),
                  Column(children: [
                    const Text('Mínima'),
                    Text(minTemp),
                  ]),
                ],
              ),

              const SizedBox(height: 30),

              // ── Próximas horas ─────────────────────────────────────────────

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Próximas Horas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                height: 160,
                child: Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final nextHours = forecast
                        .where((h) =>
                            DateTime.parse(h.time).isAfter(now))
                        .take(5)
                        .toList();

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: nextHours.length,
                      itemBuilder: (context, index) {
                        final hour = nextHours[index];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                hour.time.substring(11),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Icon(
                                getWeatherIcon(hour.condition),
                                size: 42,
                                color: Colors.orange,
                              ),
                              Text(
                                '${hour.tempC.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${hour.chanceRain}% chuva',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // ── Umidade do solo ────────────────────────────────────────────

              const Text(
                'Umidade do Solo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: soilHumidity / 100,
                      strokeWidth: 18,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '${soilHumidity.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ── Reservatório ───────────────────────────────────────────────

              Card(
                child: ListTile(
                  leading: Icon(
                    waterLevel ? Icons.water : Icons.warning,
                    color: waterLevel ? Colors.blue : Colors.red,
                  ),
                  title: const Text('Reservatório'),
                  subtitle: Text(
                    waterLevel ? 'Nível Alto' : 'Nível Baixo',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Fase da cultura ────────────────────────────────────────────

              if (result != null) ...[

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.eco, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.crop.name} — DAP ${result.dap}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.phase,
                          style: TextStyle(
                            color: result.isCriticalPhase
                                ? Colors.red
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (result.isCriticalPhase)
                          const Text(
                            '⚠️ Fase crítica',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        const Divider(height: 20),
                        _InfoRow('Solo', widget.soil.name),
                        _InfoRow(
                          'ETc estimada',
                          '${result.etc.toStringAsFixed(1)} mm/dia',
                        ),
                        _InfoRow(
                          'Chuva efetiva prevista',
                          '${result.effectiveRain.toStringAsFixed(1)} mm',
                        ),
                        if (result.irnMm > 0)
                          _InfoRow(
                            'Lâmina necessária',
                            '${result.irnMm.toStringAsFixed(1)} mm',
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Status da irrigação ──────────────────────────────────────

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _statusColor(result.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Status da Irrigação',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {

  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}