import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import '../../providers/user_providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _objectiveController;
  late final TextEditingController _restrictionsController;
  late String _sex;
  late String _level;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: '${profile.age}');
    _heightController = TextEditingController(text: profile.height.toString());
    _weightController = TextEditingController(text: profile.weight.toString());
    _objectiveController = TextEditingController(text: profile.objective);
    _restrictionsController = TextEditingController(text: profile.restrictions ?? '');
    _sex = profile.sex == 'Feminino' ? 'Feminino' : 'Masculino';
    const levels = {'Iniciante', 'Intermediário', 'Avançado'};
    _level = levels.contains(profile.activityLevel)
        ? profile.activityLevel
        : 'Intermediário';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _objectiveController.dispose();
    _restrictionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Esses dados entram no contexto da IA no próximo plano.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Idade'),
                validator: (value) {
                  final age = int.tryParse(value ?? '');
                  if (age == null || age <= 0) return 'Idade inválida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sex,
                decoration: const InputDecoration(labelText: 'Sexo'),
                items: const [
                  DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                  DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                ],
                onChanged: (value) => setState(() => _sex = value ?? _sex),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Altura (m)'),
                validator: (value) {
                  final height = double.tryParse((value ?? '').replaceAll(',', '.'));
                  if (height == null || height <= 1.2) return 'Altura inválida';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
                validator: (value) {
                  final weight = double.tryParse((value ?? '').replaceAll(',', '.'));
                  if (weight == null || weight <= 20) return 'Peso inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(labelText: 'Nível'),
                items: const [
                  DropdownMenuItem(value: 'Iniciante', child: Text('Iniciante')),
                  DropdownMenuItem(value: 'Intermediário', child: Text('Intermediário')),
                  DropdownMenuItem(value: 'Avançado', child: Text('Avançado')),
                ],
                onChanged: (value) => setState(() => _level = value ?? _level),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _objectiveController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Objetivo'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Informe o objetivo' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _restrictionsController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Restrições ou lesões',
                  hintText: 'Opcional. Vazio remove a restrição anterior.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Salvando...' : 'Salvar perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final restrictions = _restrictionsController.text.trim();
    final updated = UserProfile(
      id: widget.profile.id,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      sex: _sex,
      height: double.parse(_heightController.text.trim().replaceAll(',', '.')),
      weight: double.parse(_weightController.text.trim().replaceAll(',', '.')),
      activityLevel: _level,
      objective: _objectiveController.text.trim(),
      restrictions: restrictions.isEmpty ? null : restrictions,
      createdAt: widget.profile.createdAt,
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(userProfileProvider.notifier).saveProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
