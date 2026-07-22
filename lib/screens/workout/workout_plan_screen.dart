import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/workout_plan.dart';
import '../../providers/workout_providers.dart';
import '../workout/conversational_workout_screen.dart';
import '../workout/manual_workout_entry_screen.dart';
import '../workout/workout_session_screen.dart';

class WorkoutPlanScreen extends ConsumerStatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  ConsumerState<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends ConsumerState<WorkoutPlanScreen> {
  final _customRequestController = TextEditingController();
  int _selectedDays = 5;
  double _sessionDuration = 60;
  bool _preferencesSynced = false;

  @override
  void dispose() {
    _customRequestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(workoutPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de treino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(workoutPlanProvider.notifier).refresh(),
          ),
        ],
      ),
      body: planState.when(
        data: (plan) => _buildPlan(context, plan),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _PlanError(onRetry: () => ref.read(workoutPlanProvider.notifier).refresh(), message: error.toString()),
      ),
    );
  }

  Widget _buildPlan(BuildContext context, WorkoutPlan? plan) {
    if (plan == null && _preferencesSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _preferencesSynced = false;
        });
      });
    } else if (plan != null && !_preferencesSynced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedDays = plan.desiredDays ?? _selectedDays;
          _sessionDuration = (plan.sessionDurationMinutes ?? _sessionDuration.round()).toDouble();
          _preferencesSynced = true;
        });
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferências do plano', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _selectedDays,
                  decoration: const InputDecoration(labelText: 'Dias de treino na semana'),
                  items: [
                    for (final days in [3, 4, 5, 6])
                      DropdownMenuItem(value: days, child: Text('$days dias')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedDays = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Duração média desejada: ${_sessionDuration.round()} minutos'),
                Slider(
                  value: _sessionDuration,
                  min: 30,
                  max: 120,
                  divisions: 18,
                  label: '${_sessionDuration.round()} min',
                  onChanged: (value) {
                    setState(() {
                      _sessionDuration = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'As preferências serão usadas ao gerar o próximo plano com a IA.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (plan == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nenhum plano disponível', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Gere um treino personalizado com base na sua última avaliação e histórico.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Gerar treino com IA'),
                    onPressed: () => _generatePlan(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('Conversar com IA para criar treino'),
                    onPressed: () => _startConversation(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Inserir meu treino'),
                    onPressed: () => _openManualEntry(context),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.source == 'manual'
                          ? 'Treino manual'
                          : 'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(plan.generatedAt)}',
                    ),
                  ),
                  _SourceBadge(source: plan.source),
                ],
              ),
              subtitle: Text(_buildPlanSubtitle(plan)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'generate') _generatePlan(context);
                  if (value == 'chat') _startConversation(context);
                  if (value == 'manual') _openManualEntry(context);
                  if (value == 'edit' && plan.source == 'manual') {
                    _openManualEntry(context, basePlan: plan);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'generate',
                    child: ListTile(
                      leading: Icon(Icons.auto_fix_high),
                      title: Text('Gerar novo com IA'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'chat',
                    child: ListTile(
                      leading: Icon(Icons.chat),
                      title: Text('Conversar com IA'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manual',
                    child: ListTile(
                      leading: Icon(Icons.edit_note),
                      title: Text('Inserir meu treino'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (plan.source == 'manual')
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Editar treino manual'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final day in plan.days)
            Card(
              child: ExpansionTile(
                title: Text('${day.dayLabel} • ${day.muscleGroup}'),
                subtitle: Text('${day.exercises.length} exercícios'),
                children: [
                  ...day.exercises.map((exercise) => ListTile(
                        title: Text(exercise.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${exercise.series} séries x ${exercise.repetitions} reps'),
                            if (exercise.combinedExercises != null && exercise.combinedExercises!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.double_arrow, size: 12, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Em sequência:',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      for (var combinedEx in exercise.combinedExercises!)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 16, top: 2),
                                          child: Text(
                                            '→ $combinedEx',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (exercise.substituteExercise != null && exercise.substituteExercise!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz, size: 14, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Substituto: ${exercise.substituteExercise}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: exercise.suggestedLoad != null
                            ? Text('${exercise.suggestedLoad!.toStringAsFixed(1)} kg')
                            : null,
                      )),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 12),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WorkoutSessionScreen(day: day, plan: plan),
                            ),
                          );
                        },
                        child: const Text('Iniciar treino'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        _CreateWorkoutCard(
          onManual: () => _openManualEntry(context),
          onChat: () => _startConversation(context),
          onGenerate: () => _generatePlan(context, customRequest: _customRequestController.text.trim()),
          customRequestController: _customRequestController,
        ),
      ],
    );
  }

  Future<void> _generatePlan(BuildContext context, {String? customRequest}) async {
    final messenger = ScaffoldMessenger.of(context);
    final request = (customRequest != null && customRequest.isNotEmpty) ? customRequest : null;

    try {
      await ref.read(workoutPlanProvider.notifier).generateNewPlan(
            customRequest: request,
            desiredDays: _selectedDays,
            sessionDurationMinutes: _sessionDuration.round(),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Plano gerado com sucesso.')));
      if (request != null && mounted) {
        _customRequestController.clear();
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Erro ao gerar plano: $error')));
    }
  }

  String _buildPlanSubtitle(WorkoutPlan plan) {
    final parts = <String>[];
    if (plan.focus != null && plan.focus!.isNotEmpty) {
      parts.add(plan.focus!);
    } else {
      parts.add('Objetivo: ${plan.objective}');
    }
    if (plan.desiredDays != null) {
      parts.add('${plan.desiredDays} dias desejados');
    }
    if (plan.sessionDurationMinutes != null) {
      parts.add('${plan.sessionDurationMinutes} min por sessão');
    }
    return parts.join(' • ');
  }

  void _startConversation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationalWorkoutScreen(
          initialDesiredDays: _selectedDays,
          initialSessionDuration: _sessionDuration.round(),
        ),
      ),
    );
  }

  void _openManualEntry(BuildContext context, {WorkoutPlan? basePlan}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualWorkoutEntryScreen(basePlan: basePlan),
      ),
    );
  }
}

class _CreateWorkoutCard extends StatelessWidget {
  const _CreateWorkoutCard({
    required this.onManual,
    required this.onChat,
    required this.onGenerate,
    required this.customRequestController,
  });

  final VoidCallback onManual;
  final VoidCallback onChat;
  final VoidCallback onGenerate;
  final TextEditingController customRequestController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Criar novo treino', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            // Destaque para entrada manual
            InkWell(
              onTap: onManual,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.primaryContainer.withOpacity(0.15),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_note,
                          color: colorScheme.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inserir meu treino',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Monte sua própria ficha de exercícios',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('Gerar com IA',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: customRequestController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'Ajustes desejados (opcional): foco em pernas, evitar ombro...',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Conversar com IA'),
                    onPressed: onChat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.auto_graph, size: 18),
                    label: const Text('Gerar plano'),
                    onPressed: onGenerate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (source) {
      'manual' => 'Manual',
      'auto' => 'Auto',
      _ => 'IA',
    };
    final color = switch (source) {
      'manual' => colorScheme.tertiaryContainer,
      'auto' => colorScheme.secondaryContainer,
      _ => colorScheme.primaryContainer,
    };
    final textColor = switch (source) {
      'manual' => colorScheme.onTertiaryContainer,
      'auto' => colorScheme.onSecondaryContainer,
      _ => colorScheme.onPrimaryContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Não foi possível carregar o plano.', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
