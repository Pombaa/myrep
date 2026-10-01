import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/month_progress.dart';
import '../../models/workout_session.dart';
import '../../providers/progress_providers.dart';

const _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class HistoryMonthPanel extends ConsumerStatefulWidget {
  const HistoryMonthPanel({super.key, required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  ConsumerState<HistoryMonthPanel> createState() => _HistoryMonthPanelState();
}

class _HistoryMonthPanelState extends ConsumerState<HistoryMonthPanel> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(exerciseHistoryMonthProvider(_month));
    final trained = widget.sessions
        .where((session) =>
            session.executedAt.year == _month.year &&
            session.executedAt.month == _month.month)
        .map((session) => DateTime(
              session.executedAt.year,
              session.executedAt.month,
              session.executedAt.day,
            ))
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _isCurrentMonth
                  ? null
                  : () => setState(() {
                        _month = DateTime(_month.year, _month.month + 1);
                      }),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _MonthGrid(month: _month, trainedDays: trained),
        const SizedBox(height: 12),
        history.when(
          data: (entries) {
            final lines = monthProgressLines(entries);
            if (lines.isEmpty) {
              return Text(
                trained.isEmpty
                    ? 'Nenhum treino neste mês.'
                    : 'Primeira vez de cada exercício neste mês — a diferença aparece na próxima.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No mês',
                  style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.exerciseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          line.change,
                          style: textTheme.labelLarge?.copyWith(
                            color: line.change.startsWith('+')
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (error, _) => Text('Não foi possível ler o mês: $error'),
        ),
      ],
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.trainedDays});

  final DateTime month;
  final Set<DateTime> trainedDays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final today = DateTime.now();
    final cells = leading + days;

    return Column(
      children: [
        Row(
          children: [
            for (final label in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 36,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = index - leading + 1;
            final date = DateTime(month.year, month.month, day);
            final trained = trainedDays.contains(date);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            return Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trained ? colorScheme.primary : null,
                  border: isToday && !trained
                      ? Border.all(color: colorScheme.primary)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: textTheme.labelMedium?.copyWith(
                    color: trained ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontWeight: trained ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
