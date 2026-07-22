import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/ai_interaction.dart';
import '../../models/workout_plan.dart';
import '../../models/workout_session.dart';
import '../../providers/ai_providers.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/progress_providers.dart';
import '../../providers/services_providers.dart';
import '../../providers/settings_providers.dart' show themeModeProvider, ThemeModeController, openAiKeyProvider, OpenAiKeyController, nvidiaKeyProvider, NvidiaKeyController, selectedAiProviderProvider, SelectedAiProviderController, AiProvider;
import '../../providers/workout_providers.dart';
import 'reminders_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _openAiKeyController = TextEditingController();
  final _nvidiaKeyController = TextEditingController();
  bool _isSavingKey = false;
  bool _isExporting = false;

  @override
  void dispose() {
    _openAiKeyController.dispose();
    _nvidiaKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final openAiKeyState = ref.watch(openAiKeyProvider);
    final nvidiaKeyState = ref.watch(nvidiaKeyProvider);
    final selectedProvider = ref.watch(selectedAiProviderProvider);

    openAiKeyState.whenData((value) {
      if (_openAiKeyController.text.isEmpty && value != null) {
        _openAiKeyController.text = value;
      }
    });
    nvidiaKeyState.whenData((value) {
      if (_nvidiaKeyController.text.isEmpty && value != null) {
        _nvidiaKeyController.text = value;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tema', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.auto_mode)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref.read(themeModeProvider.notifier).updateThemeMode(selection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provedor de IA', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AiProvider>(
                    segments: const [
                      ButtonSegment(
                        value: AiProvider.openai,
                        label: Text('OpenAI'),
                        icon: Icon(Icons.psychology_alt),
                      ),
                      ButtonSegment(
                        value: AiProvider.nvidia,
                        label: Text('NVIDIA'),
                        icon: Icon(Icons.memory),
                      ),
                    ],
                    selected: {selectedProvider},
                    onSelectionChanged: (s) =>
                        ref.read(selectedAiProviderProvider.notifier).select(s.first),
                  ),
                  const SizedBox(height: 16),
                  if (selectedProvider == AiProvider.openai) ...[
                    const Text('Chave da API OpenAI (paga por uso)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _openAiKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isSavingKey
                            ? null
                            : () async {
                                setState(() => _isSavingKey = true);
                                try {
                                  await ref.read(openAiKeyProvider.notifier).save(_openAiKeyController.text.trim());
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave OpenAI salva.')));
                                } finally {
                                  if (mounted) setState(() => _isSavingKey = false);
                                }
                              },
                        child: Text(_isSavingKey ? 'Salvando...' : 'Salvar'),
                      ),
                    ),
                  ] else ...[
                    const Text('Chave da API NVIDIA (gratuita em nvidia.com/ngc)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nvidiaKeyController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'nvapi-...',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Modelo: meta/llama-3.3-70b-instruct',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isSavingKey
                            ? null
                            : () async {
                                setState(() => _isSavingKey = true);
                                try {
                                  await ref.read(nvidiaKeyProvider.notifier).save(_nvidiaKeyController.text.trim());
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave NVIDIA salva.')));
                                } finally {
                                  if (mounted) setState(() => _isSavingKey = false);
                                }
                              },
                        child: Text(_isSavingKey ? 'Salvando...' : 'Salvar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_outlined),
              title: const Text('Lembretes de treino'),
              subtitle: const Text('Gerencie preferências e restrições salvas.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar histórico em JSON'),
              subtitle: const Text('Gera um arquivo com avaliações, treinos e interações.'),
              onTap: _isExporting ? null : () => _exportData(context, format: _ExportFormat.json),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_present_outlined),
              title: const Text('Exportar histórico em CSV'),
              subtitle: const Text('Exporta tabelas básicas para planilhas.'),
              onTap: _isExporting ? null : () => _exportData(context, format: _ExportFormat.csv),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Reprogramar lembrete de avaliação'),
              subtitle: const Text('Agenda a próxima notificação em 90 dias.'),
              onTap: () async {
                final latest = ref.read(latestMeasurementProvider);
                final notificationService = ref.read(notificationServiceProvider);
                if (latest != null) {
                  await notificationService.scheduleEvaluationReminder(latest.recordedAt);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lembrete reagendado.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registre uma avaliação primeiro.')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, {required _ExportFormat format}) async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
  final measurements = ref.read(bodyMeasurementsProvider).valueOrNull ?? [];
  final List<WorkoutSession> sessions = await ref.read(workoutSessionsProvider.future);
  final List<WorkoutPlan> plans = await ref.read(workoutHistoryProvider.future);
  final List<AiInteraction> interactions = await ref.read(aiHistoryProvider.future);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      late File file;

      if (format == _ExportFormat.json) {
        final data = {
          'measurements': measurements.map((m) => m.toMap()).toList(),
          'sessions': sessions.map((s) => s.toMap()).toList(),
          'plans': plans.map((p) => p.toMap()).toList(),
          'interactions': interactions.map((i) => i.toMap()).toList(),
        };
        file = File('${directory.path}/fitai_export_$timestamp.json');
        await file.writeAsString(jsonEncode(data));
      } else {
        final buffer = StringBuffer();
        buffer.writeln('type,date,details');
        for (final m in measurements) {
          buffer.writeln('measurement,${m.recordedAt.toIso8601String()},peso:${m.weight};gordura:${m.bodyFatPercent};massa_magra:${m.leanMass}');
        }
        for (final s in sessions) {
          buffer.writeln('session,${s.executedAt.toIso8601String()},dia:${s.dayLabel};exercicios:${s.exercises.length}');
        }
  for (final i in interactions) {
          buffer.writeln('ai,${i.createdAt.toIso8601String()},prompt:${i.prompt.length} caracteres');
        }
        file = File('${directory.path}/fitai_export_$timestamp.csv');
        await file.writeAsString(buffer.toString());
      }

      messenger.showSnackBar(SnackBar(content: Text('Arquivo salvo em ${file.path}')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao exportar: $error')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

enum _ExportFormat { json, csv }
