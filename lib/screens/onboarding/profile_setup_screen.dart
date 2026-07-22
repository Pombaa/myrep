import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/body_metrics_calculator.dart';
import '../../models/body_measurement.dart';
import '../../models/user_profile.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/user_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _restrictionsController = TextEditingController();
  final _armController = TextEditingController();
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _abdomenController = TextEditingController();
  final _hipController = TextEditingController();
  final _thighController = TextEditingController();
  final _calfController = TextEditingController();

  String _sex = 'Masculino';
  String _level = 'Intermediário';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _objectiveController.dispose();
    _restrictionsController.dispose();
    _armController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _abdomenController.dispose();
    _hipController.dispose();
    _thighController.dispose();
    _calfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FitAI Trainer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crie seu perfil',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Informe seus dados iniciais para personalizar treinos e avaliações. Esses dados ficarão salvos apenas no seu dispositivo.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Idade'),
                        validator: (value) {
                          final age = int.tryParse(value ?? '');
                          if (age == null || age <= 0) {
                            return 'Idade inválida';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sex,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: const [
                          DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                          DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                        ],
                        onChanged: (value) => setState(() => _sex = value ?? 'Masculino'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Altura (m)'),
                        validator: (value) {
                          final height = double.tryParse(value ?? '');
                          if (height == null || height <= 1.2) {
                            return 'Altura inválida';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
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
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _level,
                  decoration: const InputDecoration(labelText: 'Nível de condicionamento'),
                  items: const [
                    DropdownMenuItem(value: 'Iniciante', child: Text('Iniciante')),
                    DropdownMenuItem(value: 'Intermediário', child: Text('Intermediário')),
                    DropdownMenuItem(value: 'Avançado', child: Text('Avançado')),
                  ],
                  onChanged: (value) => setState(() => _level = value ?? 'Intermediário'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _objectiveController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Objetivo principal'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Informe o objetivo' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _restrictionsController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Restrições, lesões ou observações',
                    hintText: 'Opcional',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Medidas Corporais (cm)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Salvando...' : 'Concluir cadastro'),
                    onPressed: _isSaving ? null : () => _submit(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final height = double.parse(_heightController.text.trim().replaceAll(',', '.'));
      final weight = double.parse(_weightController.text.trim().replaceAll(',', '.'));
      final objective = _objectiveController.text.trim();
      final restrictions = _restrictionsController.text.trim().isEmpty ? null : _restrictionsController.text.trim();

      final metrics = BodyMetricsCalculator.calculate(
        weightKg: weight,
        heightMeters: height,
        age: age,
        sex: _sex,
      );

      final profile = UserProfile(
        name: name,
        age: age,
        sex: _sex,
        height: height,
        weight: weight,
        activityLevel: _level,
        objective: objective,
        restrictions: restrictions,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final savedProfile = await ref.read(userProfileProvider.notifier).saveProfile(profile);
      final measurement = BodyMeasurement(
        userId: savedProfile.id ?? 1,
        recordedAt: DateTime.now(),
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
        notes: 'Cadastro inicial em ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      );

      await ref.read(bodyMeasurementsProvider.notifier).addMeasurement(measurement);

      messenger.showSnackBar(const SnackBar(content: Text('Perfil criado com sucesso!')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

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
