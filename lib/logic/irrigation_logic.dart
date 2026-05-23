// logic/irrigation_logic.dart

import 'package:flutter/foundation.dart';
import '../models/weather_hour.dart';
import '../models/crop_data.dart';

class IrrigationResult {
  final String status;
  final String phase;
  final bool isCriticalPhase;
  final double irnMm;          // Irrigação Real Necessária (mm)
  final double effectiveRain;  // Precipitação efetiva (mm)
  final double etc;            // ETc calculada (mm/dia)
  final int dap;               // Dias após plantio

  const IrrigationResult({
    required this.status,
    required this.phase,
    required this.isCriticalPhase,
    required this.irnMm,
    required this.effectiveRain,
    required this.etc,
    required this.dap,
  });
}

class IrrigationLogic {

  // ETo estimada pela temperatura (fórmula simplificada de Hargreaves)
  // ETo ≈ 0.0023 × (Tmed + 17.8) × (Tmax - Tmin)^0.5 × Ra
  // Ra (radiação extraterrestre) estimada pela latitude como constante ~11 mm/dia
  // Para uso embarcado simplificamos: ETo = 0.408 × (Tmed - 2)
  static double _estimateETo(List<WeatherHour> forecast) {
    if (forecast.isEmpty) return 5.0; // fallback
    final now = DateTime.now();
    final todayHours = forecast
        .where((h) => DateTime.parse(h.time).isAfter(now))
        .toList();
    if (todayHours.isEmpty) return 5.0;
    final tmed = todayHours.map((h) => h.tempC).reduce((a, b) => a + b) /
        todayHours.length;
    return (0.408 * (tmed - 2)).clamp(1.0, 12.0);
  }

  static IrrigationResult evaluate({
    required double soilHumidity,      // Ui: umidade atual (%)
    required SoilType soil,
    required CropType crop,
    required DateTime plantingDate,
    required List<WeatherHour> forecast,
    double systemEfficiency = 0.75,    // Ea: eficiência do sistema (aspersão convencional)
  }) {

    // ── 1. Dias após plantio e fase fenológica ───────────────────────────────
    final dap = DateTime.now().difference(plantingDate).inDays;
    final phase = crop.phaseAt(dap);

    debugPrint('DAP: $dap | Fase: ${phase.name} | Kc: ${phase.kc} | Z: ${phase.rootDepth}cm');

    // ── 2. ETo estimada e ETc ────────────────────────────────────────────────
    final eto = _estimateETo(forecast);
    final etc = eto * phase.kc;

    debugPrint('ETo: ${eto.toStringAsFixed(2)} mm/dia | ETc: ${etc.toStringAsFixed(2)} mm/dia');

    // ── 3. Precipitação efetiva (Pe) ─────────────────────────────────────────
    // Soma das próximas 24h; aproveita 75% apenas se total > 5mm
    final now = DateTime.now();
    final nextHours = forecast
        .where((h) => DateTime.parse(h.time).isAfter(now))
        .toList();

    final double totalRain =
        nextHours.fold(0.0, (sum, h) => sum + h.precipMm);
    final double effectiveRain = totalRain >= 5.0 ? totalRain * 0.75 : 0.0;

    debugPrint('Chuva total prevista: ${totalRain.toStringAsFixed(2)}mm | Pe: ${effectiveRain.toStringAsFixed(2)}mm');

    // ── 4. CAD e limiar de irrigação (Ui) ────────────────────────────────────
    // CAD = 10 × (CC - PMP) mm/cm
    final double cad = 10 * (soil.fieldCapacity - soil.wiltingPoint);

    // Ui = CC - (f × (CC - PMP))
    final double irrigationThreshold =
        soil.fieldCapacity - (phase.madFactor * (soil.fieldCapacity - soil.wiltingPoint));

    debugPrint('CAD: ${cad.toStringAsFixed(2)} mm/cm | Ui: ${irrigationThreshold.toStringAsFixed(2)}%');
    debugPrint('Umidade atual: ${soilHumidity.toStringAsFixed(2)}% | CC: ${soil.fieldCapacity}% | PMP: ${soil.wiltingPoint}%');

    // ── 5. IRN: lâmina necessária para repor até CC ──────────────────────────
    // IRN = (CC - Ui_atual) × Z × d / 10  (em mm)
    final double irnBruto =
        ((soil.fieldCapacity - soilHumidity) / 100) *
        phase.rootDepth *
        soil.density *
        10;

    // IRN ajustado pela eficiência do sistema
    final double irnLiquido = irnBruto / systemEfficiency;

    // IRN suplementar = ETc - Pe (quanto a chuva não supre)
    final double irnSupplemental = etc - effectiveRain;

    debugPrint('IRN bruto: ${irnBruto.toStringAsFixed(2)}mm | IRN líquido: ${irnLiquido.toStringAsFixed(2)}mm');
    debugPrint('IRN suplementar (ETc - Pe): ${irnSupplemental.toStringAsFixed(2)}mm');

    // ── 6. Decisão ───────────────────────────────────────────────────────────

    // Ciclo encerrado
    if (dap >= crop.cycleDays) {
      return IrrigationResult(
        status: 'CICLO ENCERRADO',
        phase: phase.name,
        isCriticalPhase: false,
        irnMm: 0,
        effectiveRain: effectiveRain,
        etc: etc,
        dap: dap,
      );
    }

    // Solo abaixo do PMP: emergência
    if (soilHumidity <= soil.wiltingPoint) {
      return IrrigationResult(
        status: 'IRRIGAR — URGENTE',
        phase: phase.name,
        isCriticalPhase: phase.isCritical,
        irnMm: irnLiquido,
        effectiveRain: effectiveRain,
        etc: etc,
        dap: dap,
      );
    }

    // Solo acima da CC
    if (soilHumidity >= soil.fieldCapacity) {
      return IrrigationResult(
        status: 'SOLO ÚMIDO',
        phase: phase.name,
        isCriticalPhase: phase.isCritical,
        irnMm: 0,
        effectiveRain: effectiveRain,
        etc: etc,
        dap: dap,
      );
    }

    // Solo abaixo do limiar de irrigação
    if (soilHumidity <= irrigationThreshold) {

      // Chuva efetiva supre a ETc completamente
      if (irnSupplemental <= 0) {
        return IrrigationResult(
          status: 'AGUARDAR CHUVA',
          phase: phase.name,
          isCriticalPhase: phase.isCritical,
          irnMm: 0,
          effectiveRain: effectiveRain,
          etc: etc,
          dap: dap,
        );
      }

      // Chuva parcial: irrigação complementar
      if (effectiveRain > 0) {
        return IrrigationResult(
          status: 'IRRIGAR — COMPLEMENTAR',
          phase: phase.name,
          isCriticalPhase: phase.isCritical,
          irnMm: irnSupplemental / systemEfficiency,
          effectiveRain: effectiveRain,
          etc: etc,
          dap: dap,
        );
      }

      // Sem chuva prevista: irrigar normalmente
      return IrrigationResult(
        status: 'IRRIGAR',
        phase: phase.name,
        isCriticalPhase: phase.isCritical,
        irnMm: irnLiquido,
        effectiveRain: effectiveRain,
        etc: etc,
        dap: dap,
      );
    }

    // Umidade entre Ui e CC: adequada
    return IrrigationResult(
      status: 'SOLO ADEQUADO',
      phase: phase.name,
      isCriticalPhase: phase.isCritical,
      irnMm: 0,
      effectiveRain: effectiveRain,
      etc: etc,
      dap: dap,
    );
  }
}