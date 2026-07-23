import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/workout_day_matcher.dart';
import '../../models/body_measurement.dart';
import '../../models/progress_summary.dart';
import '../../models/user_profile.dart';
import '../../models/workout_plan.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/progress_providers.dart';
import '../../providers/user_providers.dart';
import '../../providers/workout_providers.dart';
import '../assessment/body_assessment_screen.dart';
import '../workout/one_off_workout_screen.dart';
import '../workout/workout_session_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final measurementsState = ref.watch(bodyMeasurementsProvider);
    final progressState = ref.watch(progressSummaryProvider);
    final planState = ref.watch(workoutPlanProvider);
    final UserProfile? profile = profileState.valueOrNull;
    final measurements = measurementsState.valueOrNull ?? [];
    final plan = planState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile != null ? 'Olá, ${profile.name.split(' ').first}' : 'FitAI Trainer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(bodyMeasurementsProvider.notifier).refresh();
              ref.invalidate(progressSummaryProvider);
              ref.read(workoutPlanProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bodyMeasurementsProvider.notifier).refresh();
          ref.invalidate(progressSummaryProvider);
          await ref.read(workoutPlanProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _TodayWorkoutCard(plan: plan),
            const SizedBox(height: 16),
            if (measurements.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo ao FitAI Trainer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registre sua primeira avaliação corporal para que a IA possa criar um treino personalizado.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BodyAssessmentScreen()),
                          );
                        },
                        child: const Text('Registrar avaliação'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _LatestMeasurementHeader(profile: profile, measurement: measurements.first),
              const SizedBox(height: 16),
              progressState.when(
                data: (summary) => _ProgressCards(summary: summary),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Não foi possível carregar o progresso: $error'),
              ),
              const SizedBox(height: 16),
              _MeasurementsChart(measurements: measurements),
            ],
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Registrar nova avaliação'),
                subtitle: const Text('Atualize suas medidas e acompanhe a evolução.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BodyAssessmentScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.plan});

  final WorkoutPlan? plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todayName = weekdayLabelPt();

    if (plan == null) {
      return Card(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Treino de hoje', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Nenhum plano ainda. Crie ou importe em Treinos.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final day = findPlanDayForDate(plan!);
    if (day == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Treino de hoje · $todayName',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Hoje não está no plano. Abra Treinos para escolher outro dia.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final isRest = day.exercises.isEmpty;
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Treino de hoje',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.dayLabel} · ${day.muscleGroup}',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isRest
                  ? 'Dia de descanso'
                  : '${day.exercises.length} exercícios',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isRest) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar treino'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutSessionScreen(day: day, plan: plan),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OneOffWorkoutScreen()),
                );
              },
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Fazer treino avulso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestMeasurementHeader extends StatelessWidget {
  const _LatestMeasurementHeader({this.profile, required this.measurement});

  final UserProfile? profile;
  final BodyMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile != null)
              Text(
                'Perfil atual',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricTile(title: 'Peso', value: '${measurement.weight.toStringAsFixed(1)} kg'),
                _MetricTile(title: 'Gordura corporal', value: '${measurement.bodyFatPercent.toStringAsFixed(1)}%'),
                _MetricTile(title: 'Massa magra', value: '${measurement.leanMass.toStringAsFixed(1)} kg'),
                _MetricTile(title: 'IMC', value: measurement.bmi.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCards extends StatelessWidget {
  const _ProgressCards({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ProgressTile(label: 'Peso', delta: summary.weightDelta, isLowerBetter: true),
        _ProgressTile(label: 'Gordura %', delta: summary.bodyFatDelta, suffix: '%', isLowerBetter: true),
        _ProgressTile(label: 'Massa magra', delta: summary.leanMassDelta),
        _ProgressTile(label: 'Carga média', delta: summary.averageLoadDelta),
      ],
    );
  }
}

class _MeasurementsChart extends StatelessWidget {
  const _MeasurementsChart({required this.measurements});

  final List<BodyMeasurement> measurements;

  @override
  Widget build(BuildContext context) {
    if (measurements.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Registre pelo menos duas avaliações para visualizar os gráficos de evolução.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sorted = [...measurements]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final spotsLean = <FlSpot>[];
    final spotsFat = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      spotsLean.add(FlSpot(i.toDouble(), sorted[i].leanMass));
      spotsFat.add(FlSpot(i.toDouble(), sorted[i].bodyFatPercent));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolução corporal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sorted.length) {
                            return const SizedBox.shrink();
                          }
                          final date = sorted[index].recordedAt;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('${date.day}/${date.month}'),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(enabled: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsLean,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      isCurved: true,
                    ),
                    LineChartBarData(
                      spots: spotsFat,
                      color: Theme.of(context).colorScheme.secondary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      isCurved: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 14, height: 3, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                const Text('Massa magra (kg)'),
                const SizedBox(width: 16),
                Container(width: 14, height: 3, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 6),
                const Text('% Gordura'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.label,
    required this.delta,
    this.suffix = ' kg',
    this.isLowerBetter = false,
  });

  final String label;
  final double delta;
  final String suffix;
  final bool isLowerBetter;

  @override
  Widget build(BuildContext context) {
    final isGood = isLowerBetter ? delta <= 0 : delta >= 0;
    final color = delta == 0 ? Colors.grey : (isGood ? Colors.green : Colors.red);
    final signal = delta > 0 ? '+' : '';
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(
                '$signal${delta.toStringAsFixed(1)}$suffix',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
