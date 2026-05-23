// pages/setup_page.dart

import 'package:flutter/material.dart';
import '../models/crop_data.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {

  SoilType? selectedSoil;
  CropType? selectedCrop;
  DateTime? plantingDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      helpText: 'Data do Plantio',
    );
    if (picked != null) {
      setState(() => plantingDate = picked);
    }
  }

  bool get _isValid =>
      selectedSoil != null &&
      selectedCrop != null &&
      plantingDate != null;

  @override
  Widget build(BuildContext context) {

    final dap = plantingDate != null
        ? DateTime.now().difference(plantingDate!).inDays
        : null;

    final currentPhase = (selectedCrop != null && dap != null)
        ? selectedCrop!.phaseAt(dap)
        : null;

    return Scaffold(

      appBar: AppBar(
        title: const Text('Configuração da Lavoura'),
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ── Tipo de Solo ────────────────────────────────────────────────

            const Text(
              'Tipo de Solo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...soilTypes.map((soil) => _SoilCard(
              soil: soil,
              selected: selectedSoil == soil,
              onTap: () => setState(() => selectedSoil = soil),
            )),

            const SizedBox(height: 28),

            // ── Cultura ─────────────────────────────────────────────────────

            const Text(
              'Cultura',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cropTypes.map((crop) {
                final selected = selectedCrop == crop;
                return ChoiceChip(
                  label: Text(crop.name),
                  selected: selected,
                  selectedColor: Colors.green,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (_) =>
                      setState(() => selectedCrop = crop),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Data de Plantio ──────────────────────────────────────────────

            const Text(
              'Data de Plantio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      plantingDate != null
                          ? '${plantingDate!.day.toString().padLeft(2, '0')}/'
                            '${plantingDate!.month.toString().padLeft(2, '0')}/'
                            '${plantingDate!.year}'
                          : 'Selecionar data',
                      style: TextStyle(
                        fontSize: 16,
                        color: plantingDate != null
                            ? Colors.black87
                            : Colors.grey,
                      ),
                    ),
                    if (dap != null) ...[
                      const Spacer(),
                      Text(
                        '$dap DAP',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),

            // ── Preview da fase atual ────────────────────────────────────────

            if (currentPhase != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: currentPhase.isCritical
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: currentPhase.isCritical
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          currentPhase.isCritical
                              ? Icons.warning_amber
                              : Icons.eco,
                          color: currentPhase.isCritical
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentPhase.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentPhase.isCritical
                                  ? Colors.red.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PhaseDetail('Kc', currentPhase.kc.toStringAsFixed(2)),
                    _PhaseDetail(
                      'Profundidade radicular',
                      '${currentPhase.rootDepth.toInt()} cm',
                    ),
                    _PhaseDetail(
                      'MAD',
                      '${(currentPhase.madFactor * 100).toInt()}%',
                    ),
                    if (currentPhase.isCritical)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ Fase crítica — déficit hídrico impacta produtividade.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 36),

            // ── Botão Continuar ──────────────────────────────────────────────

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, {
                          'soil': selectedSoil,
                          'crop': selectedCrop,
                          'plantingDate': plantingDate,
                        })
                    : null,
                child: const Text(
                  'Confirmar',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SoilCard extends StatelessWidget {

  final SoilType soil;
  final bool selected;
  final VoidCallback onTap;

  const _SoilCard({
    required this.soil,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.white,
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.layers,
              color: selected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soil.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.green.shade800
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CC: ${soil.fieldCapacity}%  |  PMP: ${soil.wiltingPoint}%  |  d: ${soil.density} g/cm³',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

class _PhaseDetail extends StatelessWidget {

  final String label;
  final String value;

  const _PhaseDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}