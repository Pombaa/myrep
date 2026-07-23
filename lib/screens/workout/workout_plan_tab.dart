import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/workout_day_matcher.dart';
import '../../models/workout_plan.dart';
import '../../providers/workout_providers.dart';
import 'import_workout_screen.dart';
import 'manual_workout_entry_screen.dart';
import 'one_off_workout_screen.dart';
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
      data: (plan) =>
          plan == null ? _buildNoPlan(context) : _buildPlanView(context, plan, ref),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildError(context, error.toString(), ref),
    );
  }

  Widget _buildNoPlan(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      children: [
        Icon(
          Icons.fitness_center_rounded,
          size: 56,
          color: colorScheme.primary.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 20),
        Text(
          'Monte seu treino',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Importe um JSON, digite a ficha ou peça pra IA montar.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Importar JSON'),
          onPressed: () => _openImport(context),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Treino avulso (só agora)'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OneOffWorkoutScreen()),
            );
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_note),
          label: const Text('Criar manualmente'),
          onPressed: () => _openManualEntry(context),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.psychology_outlined),
          label: const Text('Criar com Treinador IA'),
          onPressed: onOpenTrainer,
        ),
      ],
    );
  }

  Future<void> _confirmDeletePlan(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: const Text(
          'O plano atual será removido. Você pode criar um novo a qualquer momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
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

  void _startDay(BuildContext context, WorkoutDay day, WorkoutPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(day: day, plan: plan),
      ),
    );
  }

  Widget _buildPlanView(BuildContext context, WorkoutPlan plan, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todayDay = findPlanDayForDate(plan);
    final trainingDays =
        plan.days.where((d) => d.exercises.isNotEmpty).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Slim header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Seu treino',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SourceChip(source: plan.source),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '$trainingDays dias de treino',
                      DateFormat('dd/MM/yyyy').format(plan.generatedAt),
                      if (_buildPlanInfo(plan).isNotEmpty) _buildPlanInfo(plan),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções',
              onSelected: (value) async {
                if (value == 'manual') _openManualEntry(context);
                if (value == 'import') _openImport(context);
                if (value == 'edit') {
                  _openManualEntry(context, basePlan: plan);
                }
                if (value == 'trainer') onOpenTrainer?.call();
                if (value == 'refresh') {
                  ref.read(workoutPlanProvider.notifier).refresh();
                }
                if (value == 'delete') {
                  await _confirmDeletePlan(context, ref);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.upload_file_outlined),
                    title: Text('Importar JSON'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'manual',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_note),
                    title: Text('Criar outro treino'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (plan.source == 'manual')
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar treino'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'trainer',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.psychology_outlined),
                    title: Text('Treinador IA'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.refresh),
                    title: Text('Atualizar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'Excluir',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // One-off workout — does not touch the saved plan
        Material(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OneOffWorkoutScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: colorScheme.onTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Treino avulso',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Só pra hoje — não altera o plano',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Day cards — today first visually (keep plan order, highlight today)
        for (final day in plan.days) ...[
          _DayCard(
            day: day,
            abbreviate: _abbreviateDayLabel,
            isToday: todayDay != null && day.dayLabel == todayDay.dayLabel,
            onStart: day.exercises.isEmpty
                ? null
                : () => _startDay(context, day, plan),
          ),
          const SizedBox(height: 10),
        ],
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar plano',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(workoutPlanProvider.notifier).refresh(),
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
      parts.add(plan.focus!);
    }
    if (plan.sessionDurationMinutes != null) {
      parts.add('~${plan.sessionDurationMinutes} min');
    }
    return parts.join(' · ');
  }
}

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.day,
    required this.abbreviate,
    required this.isToday,
    this.onStart,
  });

  final WorkoutDay day;
  final String Function(String) abbreviate;
  final bool isToday;
  final VoidCallback? onStart;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final day = widget.day;
    final isRest = day.exercises.isEmpty;
    final abbr = widget.abbreviate(day.dayLabel);
    final preview = day.exercises.take(3).map((e) => e.name).toList();
    final extra = day.exercises.length - preview.length;

    final bg = widget.isToday
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final border = widget.isToday
        ? Border.all(color: colorScheme.primary.withValues(alpha: 0.45), width: 1.5)
        : null;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: border,
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.isToday
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    abbr,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: widget.isToday
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              day.muscleGroup,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (widget.isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Hoje',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRest
                            ? '${day.dayLabel} · Descanso'
                            : '${day.dayLabel} · ${day.exercises.length} exercícios',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!isRest) ...[
              const SizedBox(height: 12),
              // Exercise preview (always visible — less expand needed)
              ...[
                for (final name in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '· $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (extra > 0 && !_expanded)
                  Text(
                    '+$extra mais',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
              if (_expanded)
                for (var i = 3; i < day.exercises.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '· ${day.exercises[i].name}  ·  ${day.exercises[i].series}×${day.exercises[i].repetitions}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              if (day.exercises.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Ver menos' : 'Ver todos'),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(widget.isToday ? 'Iniciar treino de hoje' : 'Iniciar'),
                onPressed: widget.onStart,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(widget.isToday ? 52 : 46),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Recuperação — sem exercícios hoje.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (source) {
      'manual' => 'Manual',
      'ai' => 'IA',
      _ => 'Auto',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
