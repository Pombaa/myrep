import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/body_metrics_calculator.dart';
import '../../models/body_measurement.dart';
import '../../models/user_profile.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/user_providers.dart';

class BodyAssessmentScreen extends ConsumerStatefulWidget {
  const BodyAssessmentScreen({super.key});

  @override
  ConsumerState<BodyAssessmentScreen> createState() => _BodyAssessmentScreenState();
}

class _BodyAssessmentScreenState extends ConsumerState<BodyAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _armController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _abdomenController = TextEditingController();
  final _hipController = TextEditingController();
  final _thighController = TextEditingController();
  final _calfController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _assessmentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _armController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _abdomenController.dispose();
    _hipController.dispose();
    _thighController.dispose();
    _calfController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final measurement = ref.read(latestMeasurementProvider);
    if (measurement != null) {
      _weightController.text = measurement.weight.toStringAsFixed(1);
      _armController.text = _format(measurement.arm);
      _chestController.text = _format(measurement.chest);
      _waistController.text = _format(measurement.waist);
      _abdomenController.text = _format(measurement.abdomen);
      _hipController.text = _format(measurement.hip);
      _thighController.text = _format(measurement.thigh);
      _calfController.text = _format(measurement.calf);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova avaliação corporal')),
      body: profile == null
          ? const Center(child: Text('Cadastre seu perfil primeiro.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registre suas novas medidas para atualizar o plano de treino.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Data da avaliação'),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_assessmentDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _assessmentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _assessmentDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Peso (kg)'),
                        validator: (value) {
                          final weight = double.tryParse(value ?? '');
                          if (weight == null || weight <= 20) {
                            return 'Peso inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricField(controller: _armController, label: 'Braço'),
                          _MetricField(controller: _chestController, label: 'Peito'),
                          _MetricField(controller: _waistController, label: 'Cintura'),
                          _MetricField(controller: _abdomenController, label: 'Abdômen'),
                          _MetricField(controller: _hipController, label: 'Quadril'),
                          _MetricField(controller: _thighController, label: 'Coxa'),
                          _MetricField(controller: _calfController, label: 'Panturrilha'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          hintText: 'Como se sentiu, mudanças de rotina, etc.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(_isSaving ? 'Salvando...' : 'Registrar avaliação'),
                          onPressed: _isSaving ? null : () => _saveAssessment(profile),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _saveAssessment(UserProfile profile) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final weight = double.parse(_weightController.text.trim().replaceAll(',', '.'));
      final metrics = BodyMetricsCalculator.calculate(
        weightKg: weight,
        heightMeters: profile.height,
        age: profile.age,
        sex: profile.sex,
      );

      final measurement = BodyMeasurement(
        userId: profile.id ?? 1,
        recordedAt: _assessmentDate,
        weight: weight,
        bodyFatPercent: metrics.bodyFatPercent,
        leanMass: metrics.leanMass,
        fatMass: metrics.fatMass,
        bmi: metrics.bmi,
        arm: _parseOptional(_armController.text),
        chest: _parseOptional(_chestController.text),
        waist: _parseOptional(_waistController.text),
        abdomen: _parseOptional(_abdomenController.text),
        hip: _parseOptional(_hipController.text),
        thigh: _parseOptional(_thighController.text),
        calf: _parseOptional(_calfController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await ref.read(bodyMeasurementsProvider.notifier).addMeasurement(measurement);
      await ref.read(userProfileProvider.notifier).saveProfile(profile.copyWith(weight: weight));

      messenger.showSnackBar(const SnackBar(content: Text('Avaliação registrada com sucesso.')));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao registrar: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _format(double? value) => value == null ? '' : value.toStringAsFixed(1);

  double? _parseOptional(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
