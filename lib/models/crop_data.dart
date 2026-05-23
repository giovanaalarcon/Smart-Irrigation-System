// models/crop_data.dart

class SoilType {
  final String name;
  final double fieldCapacity; // CC (%)
  final double wiltingPoint;  // PMP (%)
  final double density;       // g/cm³

  const SoilType({
    required this.name,
    required this.fieldCapacity,
    required this.wiltingPoint,
    required this.density,
  });
}

class CropPhase {
  final String name;
  final double startPct;  // % início do ciclo
  final double endPct;    // % fim do ciclo
  final double kc;
  final double rootDepth; // cm
  final double madFactor;
  final bool isCritical;

  const CropPhase({
    required this.name,
    required this.startPct,
    required this.endPct,
    required this.kc,
    required this.rootDepth,
    required this.madFactor,
    this.isCritical = false,
  });
}

class CropType {
  final String name;
  final int cycleDays;
  final List<CropPhase> phases;

  const CropType({
    required this.name,
    required this.cycleDays,
    required this.phases,
  });

  CropPhase phaseAt(int dap) {
    final pct = dap / cycleDays;
    for (final phase in phases) {
      if (pct >= phase.startPct && pct < phase.endPct) {
        return phase;
      }
    }
    return phases.last;
  }
}

// ── Tabela de Solos ──────────────────────────────────────────────────────────

const List<SoilType> soilTypes = [
  SoilType(
    name: 'Arenoso',
    fieldCapacity: 9.0,
    wiltingPoint: 4.0,
    density: 1.65,
  ),
  SoilType(
    name: 'Médio (Franco)',
    fieldCapacity: 22.0,
    wiltingPoint: 10.0,
    density: 1.40,
  ),
  SoilType(
    name: 'Argiloso',
    fieldCapacity: 35.0,
    wiltingPoint: 17.0,
    density: 1.25,
  ),
];

// ── Tabela de Culturas ───────────────────────────────────────────────────────

const List<CropType> cropTypes = [

  CropType(
    name: 'Milho',
    cycleDays: 135,
    phases: [
      CropPhase(
        name: 'Germinação / Estabelecimento',
        startPct: 0.00, endPct: 0.11,
        kc: 0.30, rootDepth: 15, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Vegetativo Inicial',
        startPct: 0.11, endPct: 0.26,
        kc: 0.60, rootDepth: 25, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Vegetativo Avançado',
        startPct: 0.26, endPct: 0.44,
        kc: 1.00, rootDepth: 40, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Florescimento (Fase Crítica)',
        startPct: 0.44, endPct: 0.52,
        kc: 1.20, rootDepth: 50, madFactor: 0.50,
        isCritical: true,
      ),
      CropPhase(
        name: 'Enchimento de Grãos',
        startPct: 0.52, endPct: 0.81,
        kc: 1.10, rootDepth: 50, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Maturação',
        startPct: 0.81, endPct: 1.00,
        kc: 0.35, rootDepth: 50, madFactor: 0.50,
      ),
    ],
  ),

  CropType(
    name: 'Soja',
    cycleDays: 120,
    phases: [
      CropPhase(
        name: 'Inicial',
        startPct: 0.00, endPct: 0.15,
        kc: 0.40, rootDepth: 15, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Crescimento',
        startPct: 0.15, endPct: 0.40,
        kc: 0.80, rootDepth: 30, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Formação de Vagens (Fase Crítica)',
        startPct: 0.40, endPct: 0.75,
        kc: 1.15, rootDepth: 50, madFactor: 0.50,
        isCritical: true,
      ),
      CropPhase(
        name: 'Maturação',
        startPct: 0.75, endPct: 1.00,
        kc: 0.50, rootDepth: 50, madFactor: 0.50,
      ),
    ],
  ),

  CropType(
    name: 'Feijão',
    cycleDays: 100,
    phases: [
      CropPhase(
        name: 'Inicial',
        startPct: 0.00, endPct: 0.16,
        kc: 0.40, rootDepth: 15, madFactor: 0.45,
      ),
      CropPhase(
        name: 'Crescimento',
        startPct: 0.16, endPct: 0.41,
        kc: 0.80, rootDepth: 25, madFactor: 0.45,
      ),
      CropPhase(
        name: 'Floração / Enchimento (Fase Crítica)',
        startPct: 0.41, endPct: 0.81,
        kc: 1.15, rootDepth: 30, madFactor: 0.45,
        isCritical: true,
      ),
      CropPhase(
        name: 'Maturação',
        startPct: 0.81, endPct: 1.00,
        kc: 0.35, rootDepth: 30, madFactor: 0.45,
      ),
    ],
  ),

  CropType(
    name: 'Trigo',
    cycleDays: 135,
    phases: [
      CropPhase(
        name: 'Inicial',
        startPct: 0.00, endPct: 0.13,
        kc: 0.30, rootDepth: 15, madFactor: 0.55,
      ),
      CropPhase(
        name: 'Crescimento',
        startPct: 0.13, endPct: 0.33,
        kc: 0.70, rootDepth: 30, madFactor: 0.55,
      ),
      CropPhase(
        name: 'Espigamento (Fase Crítica)',
        startPct: 0.33, endPct: 0.76,
        kc: 1.15, rootDepth: 40, madFactor: 0.55,
        isCritical: true,
      ),
      CropPhase(
        name: 'Maturação',
        startPct: 0.76, endPct: 1.00,
        kc: 0.30, rootDepth: 40, madFactor: 0.55,
      ),
    ],
  ),

  CropType(
    name: 'Cana-de-açúcar',
    cycleDays: 365,
    phases: [
      CropPhase(
        name: 'Brotação (Fase Crítica)',
        startPct: 0.00, endPct: 0.25,
        kc: 0.40, rootDepth: 30, madFactor: 0.65,
        isCritical: true,
      ),
      CropPhase(
        name: 'Crescimento Vegetativo',
        startPct: 0.25, endPct: 0.74,
        kc: 1.25, rootDepth: 60, madFactor: 0.65,
      ),
      CropPhase(
        name: 'Maturação',
        startPct: 0.74, endPct: 1.00,
        kc: 0.75, rootDepth: 70, madFactor: 0.65,
      ),
    ],
  ),

  CropType(
    name: 'Café',
    cycleDays: 365,
    phases: [
      CropPhase(
        name: 'Indução Floral',
        startPct: 0.00, endPct: 0.33,
        kc: 0.90, rootDepth: 40, madFactor: 0.50,
      ),
      CropPhase(
        name: 'Florada',
        startPct: 0.33, endPct: 0.44,
        kc: 1.00, rootDepth: 50, madFactor: 0.50,
        isCritical: true,
      ),
      CropPhase(
        name: 'Frutificação / Enchimento (Fase Crítica)',
        startPct: 0.44, endPct: 0.78,
        kc: 1.10, rootDepth: 50, madFactor: 0.50,
        isCritical: true,
      ),
      CropPhase(
        name: 'Maturação dos Frutos',
        startPct: 0.78, endPct: 1.00,
        kc: 0.95, rootDepth: 50, madFactor: 0.50,
      ),
    ],
  ),
];