import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/body_measurement.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/progress_providers.dart';
import '../../providers/services_providers.dart';
import '../../providers/workout_providers.dart';
import '../assessment/body_assessment_screen.dart';
import '../workout/workout_session_screen.dart';

class ActiveDraftCard extends ConsumerWidget {
  const ActiveDraftCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(activeWorkoutDraftProvider).valueOrNull;
    if (draft == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final done = draft.recorded.values.fold<int>(0, (sum, sets) => sum + sets.length);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        child: ListTile(
          leading: Icon(Icons.play_circle_fill_rounded, color: colorScheme.tertiary),
          title: const Text('Treino em andamento'),
          subtitle: Text('${draft.day.dayLabel} · $done séries feitas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final plan = ref.read(workoutPlanProvider).valueOrNull;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutSessionScreen(day: draft.day, plan: plan),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReassessmentCard extends ConsumerStatefulWidget {
  const ReassessmentCard({super.key});

  @override
  ConsumerState<ReassessmentCard> createState() => _ReassessmentCardState();
}

class _ReassessmentCardState extends ConsumerState<ReassessmentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(latestMeasurementProvider);
    if (latest == null || DateTime.now().difference(latest.recordedAt).inDays < 90) {
      return const SizedBox.shrink();
    }
    final days = DateTime.now().difference(latest.recordedAt).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reavaliação',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Faz $days dias da última medida. Atualize o corpo e, se quiser, gere uma proposta de plano. O plano atual só troca se você confirmar.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BodyAssessmentScreen()),
                      );
                    },
                    child: const Text('Nova avaliação'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _propose(latest),
                    child: Text(_busy ? 'Gerando...' : 'Gerar proposta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _propose(BodyMeasurement latest) async {
    setState(() => _busy = true);
    try {
      final proposed = await ref.read(workoutPlanProvider.notifier).composePlan(
            customRequest:
                'Proposta após ${DateTime.now().difference(latest.recordedAt).inDays} dias. Mantenha a divisão que já funciona e ajuste cargas pela progressão registrada.',
          );
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Substituir o plano?'),
          content: Text(
            'A proposta tem ${proposed.days.length} dias. O plano atual sai de cena só se você confirmar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Manter o atual'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Usar a proposta'),
            ),
          ],
        ),
      );
      if (replace == true) {
        await ref.read(workoutPlanProvider.notifier).savePlanDirectly(proposed);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plano atualizado.')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível gerar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class MuscleLoadCard extends ConsumerWidget {
  const MuscleLoadCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bars = ref.watch(muscleLoadProvider).valueOrNull;
    if (bars == null || bars.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final moved = bars.where((bar) => bar.deltaKg != 0).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carga média por grupo',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                moved.isEmpty
                    ? 'Quilos da última série completa. A diferença aparece quando o exercício repetir.'
                    : moved
                        .map((bar) {
                          final sign = bar.deltaKg > 0 ? '+' : '';
                          return '${bar.muscle} $sign${bar.deltaKg} kg';
                        })
                        .join(' · '),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < bars.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: bars[i].averageKg,
                              width: 18,
                              color: colorScheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: textTheme.labelSmall,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= bars.length) {
                              return const SizedBox.shrink();
                            }
                            final name = bars[index].muscle;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                name.length > 6 ? name.substring(0, 6) : name,
                                style: textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
