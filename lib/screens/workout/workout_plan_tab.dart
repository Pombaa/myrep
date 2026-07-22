import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/workout_plan.dart';
import '../../providers/workout_providers.dart';
import 'import_workout_screen.dart';
import 'manual_workout_entry_screen.dart';
import 'workout_session_screen.dart';

class WorkoutPlanTab extends ConsumerWidget {
  const WorkoutPlanTab({super.key, this.onOpenTrainer});

  final VoidCallback? onOpenTrainer;

  String _abbreviateDayLabel(String dayLabel) {
    final abbreviations = {
      'Segunda-feira': 'Seg',
      'Terça-feira': 'Ter',
      'Quarta-feira': 'Qua',
      'Quinta-feira': 'Qui',
      'Sexta-feira': 'Sex',
      'Sábado': 'Sáb',
      'Domingo': 'Dom',
      'Segunda': 'Seg',
      'Terça': 'Ter',
      'Quarta': 'Qua',
      'Quinta': 'Qui',
      'Sexta': 'Sex',
    };
    return abbreviations[dayLabel] ?? dayLabel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(workoutPlanProvider);

    return planState.when(
      data: (plan) => plan == null ? _buildNoPlan(context) : _buildPlanView(context, plan, ref),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildError(context, error.toString(), ref),
    );
  }

  Widget _buildNoPlan(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.fitness_center, size: 72, color: colorScheme.primary.withOpacity(0.4)),
        const SizedBox(height: 20),
        Text(
          'Nenhum plano de treino',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Crie seu treino manualmente ou deixe a IA montar um plano personalizado para você.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _ManualEntryButton(onTap: () => _openManualEntry(context)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Importar treino (JSON)'),
          onPressed: () => _openImport(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.psychology),
          label: const Text('Criar com Treinador IA'),
          onPressed: onOpenTrainer,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeletePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: const Text('O plano atual será removido. Você pode criar um novo a qualquer momento.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(workoutPlanProvider.notifier).deletePlan();
    }
  }

  void _openManualEntry(BuildContext context, {WorkoutPlan? basePlan}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualWorkoutEntryScreen(basePlan: basePlan),
      ),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportWorkoutScreen()),
    );
  }

  Widget _buildPlanView(BuildContext context, WorkoutPlan plan, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.source == 'manual' ? 'Treino manual' : 'Seu Plano',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 8),
                              _SourceChip(source: plan.source),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.source == 'manual'
                                ? 'Criado em ${DateFormat('dd/MM/yyyy').format(plan.generatedAt)}'
                                : 'Gerado em ${DateFormat('dd/MM/yyyy').format(plan.generatedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'manual') _openManualEntry(context);
                        if (value == 'import') _openImport(context);
                        if (value == 'edit') _openManualEntry(context, basePlan: plan);
                        if (value == 'refresh') ref.read(workoutPlanProvider.notifier).refresh();
                        if (value == 'delete') await _confirmDeletePlan(context, ref);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'manual',
                          child: ListTile(
                            leading: Icon(Icons.edit_note),
                            title: Text('Inserir meu treino'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'import',
                          child: ListTile(
                            leading: Icon(Icons.upload_file_outlined),
                            title: Text('Importar JSON'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (plan.source == 'manual')
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Editar treino'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'refresh',
                          child: ListTile(
                            leading: Icon(Icons.refresh),
                            title: Text('Atualizar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline, color: Colors.red),
                            title: Text('Excluir treino', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_buildPlanInfo(plan).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _buildPlanInfo(plan),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                _ManualEntryButton(onTap: () => _openManualEntry(context)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final day in plan.days)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(_abbreviateDayLabel(day.dayLabel)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_abbreviateDayLabel(day.dayLabel)} · ${day.muscleGroup}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              day.exercises.isEmpty
                                  ? 'Descanso'
                                  : '${day.exercises.length} exercícios',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (day.exercises.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                WorkoutSessionScreen(day: day, plan: plan),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          'Ver exercícios',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                        children: [
                          for (var index = 0; index < day.exercises.length; index++)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Text(
                                '${index + 1}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: colorScheme.primary,
                                    ),
                              ),
                              title: Text(day.exercises[index].name),
                              subtitle: Text(
                                '${day.exercises[index].series}×${day.exercises[index].repetitions}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar plano',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(workoutPlanProvider.notifier).refresh(),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPlanInfo(WorkoutPlan plan) {
    final parts = <String>[];
    if (plan.focus != null && plan.focus!.isNotEmpty) {
      parts.add('Foco: ${plan.focus}');
    }
    if (plan.objective.isNotEmpty) {
      parts.add('Objetivo: ${plan.objective}');
    }
    if (plan.desiredDays != null) {
      parts.add('${plan.desiredDays} dias/semana');
    }
    if (plan.sessionDurationMinutes != null) {
      parts.add('~${plan.sessionDurationMinutes} min/treino');
    }
    return parts.join(' • ');
  }
}

class _ManualEntryButton extends StatelessWidget {
  const _ManualEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.primaryContainer.withOpacity(0.2),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inserir meu treino',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                  ),
                  Text(
                    'Monte sua própria ficha de exercícios',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    if (source == 'ai') return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final label = source == 'manual' ? 'Manual' : 'Auto';
    final bg = source == 'manual'
        ? colorScheme.tertiaryContainer
        : colorScheme.secondaryContainer;
    final fg = source == 'manual'
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
