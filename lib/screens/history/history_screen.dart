import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/ai_interaction.dart';
import '../../models/body_measurement.dart';
import '../../models/workout_session.dart';
import '../../providers/ai_providers.dart';
import '../../providers/measurement_providers.dart';
import '../../providers/progress_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsState = ref.watch(bodyMeasurementsProvider);
    final sessionsState = ref.watch(workoutSessionsProvider);
    final aiHistoryState = ref.watch(aiHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')), 
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bodyMeasurementsProvider.notifier).refresh();
          ref.invalidate(workoutSessionsProvider);
          ref.invalidate(aiHistoryProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(
              title: 'Avaliações corporais',
              trailing: IconButton(
                icon: const Icon(Icons.table_view_outlined),
                onPressed: () => _showMeasurementsDialog(context, measurementsState.valueOrNull ?? []),
              ),
            ),
            measurementsState.when(
              data: (measurements) => measurements.isEmpty
                  ? const Text('Nenhuma avaliação registrada ainda.')
                  : Column(
                      children: measurements
                          .take(5)
                          .map((measurement) => _MeasurementTile(measurement: measurement))
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro ao carregar: $error'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Treinos executados'),
            sessionsState.when(
              data: (sessions) => sessions.isEmpty
                  ? const Text('Nenhum treino registrado ainda.')
                  : Column(
                      children: sessions
                          .map((session) => _SessionTile(session: session))
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro ao carregar: $error'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Interações com a IA'),
            aiHistoryState.when(
              data: (interactions) => interactions.isEmpty
                  ? const Text('Nenhum histórico ainda.')
                  : Column(
                      children: interactions
                          .take(10)
                          .map((interaction) => _AiInteractionTile(interaction: interaction))
                          .toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Erro ao carregar: $error'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMeasurementsDialog(BuildContext context, List<BodyMeasurement> measurements) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Histórico completo de avaliações'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: measurements.length,
              itemBuilder: (context, index) {
                final measurement = measurements[index];
                return ListTile(
                  title: Text(DateFormat('dd/MM/yyyy').format(measurement.recordedAt)),
                  subtitle: Text(
                    'Peso: ${measurement.weight.toStringAsFixed(1)} kg • Gordura: ${measurement.bodyFatPercent.toStringAsFixed(1)}% • Massa magra: ${measurement.leanMass.toStringAsFixed(1)} kg',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile({required this.measurement});

  final BodyMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insights_outlined),
        title: Text(DateFormat('dd/MM/yyyy').format(measurement.recordedAt)),
        subtitle: Text(
          'Peso ${measurement.weight.toStringAsFixed(1)} kg, gordura ${measurement.bodyFatPercent.toStringAsFixed(1)}%, massa magra ${measurement.leanMass.toStringAsFixed(1)} kg',
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.fitness_center),
        title: Text('${session.dayLabel} • ${DateFormat('dd/MM/yyyy').format(session.executedAt)}'),
        subtitle: Text('${session.exercises.length} exercícios'),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: session.exercises.length,
            itemBuilder: (context, i) {
              final ex = session.exercises[i];
              final loadStr = (ex.suggestedLoad ?? 0) > 0
                  ? ' · ${ex.suggestedLoad!.toStringAsFixed(1)} kg'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ex.name, style: textTheme.bodySmall)),
                    Text(
                      '${ex.series}×${ex.repetitions}$loadStr',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiInteractionTile extends StatelessWidget {
  const _AiInteractionTile({required this.interaction});

  final AiInteraction interaction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Show a short excerpt of the AI response (first 120 chars)
    final responseExcerpt = interaction.response.length > 120
        ? '${interaction.response.substring(0, 120)}…'
        : interaction.response;

    return Card(
      child: ExpansionTile(
        title: Text(DateFormat('dd/MM/yyyy HH:mm').format(interaction.createdAt)),
        subtitle: Text(
          responseExcerpt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resposta completa', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(interaction.response, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
