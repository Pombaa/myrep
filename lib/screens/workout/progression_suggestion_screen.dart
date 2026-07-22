import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise_progression_suggestion.dart';
import '../../models/workout_set.dart';

class ProgressionSuggestionScreen extends ConsumerStatefulWidget {
  const ProgressionSuggestionScreen({
    super.key,
    required this.suggestions,
  });

  final List<ExerciseProgressionSuggestion> suggestions;

  @override
  ConsumerState<ProgressionSuggestionScreen> createState() =>
      _ProgressionSuggestionScreenState();
}

class _ProgressionSuggestionScreenState
    extends ConsumerState<ProgressionSuggestionScreen> {
  int _currentIndex = 0;
  final Map<String, ProgressionOption?> _decisions = {};

  ExerciseProgressionSuggestion get _current =>
      widget.suggestions[_currentIndex];

  bool get _isLast => _currentIndex == widget.suggestions.length - 1;

  void _selectOption(ProgressionOption option) {
    setState(() {
      _decisions[_current.exerciseName] = option;
    });
  }

  void _advance() {
    if (_isLast) {
      Navigator.of(context).pop(_decisions);
      return;
    }
    setState(() {
      _currentIndex++;
    });
  }

  void _skip() {
    setState(() {
      _decisions[_current.exerciseName] = null;
      if (_isLast) {
        Navigator.of(context).pop(_decisions);
      } else {
        _currentIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final suggestion = _current;
    final selected = _decisions[suggestion.exerciseName];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progressão de Carga'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_decisions),
            child: const Text('Fechar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressStepBar(
              total: widget.suggestions.length,
              current: _currentIndex,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            suggestion.scheme.label,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            suggestion.muscleGroup,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      suggestion.exerciseName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sessão anterior: ${suggestion.previousSummary}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SetsTable(sets: suggestion.currentSets),
                    const SizedBox(height: 20),
                    Text(
                      'Você completou todas as séries! Pronto para progredir?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...suggestion.allOptions.map((option) {
                      final isSelected =
                          selected?.label == option.label;
                      final isManter = option.label == 'Manter';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OptionCard(
                          option: option,
                          isSelected: isSelected,
                          isManter: isManter,
                          onTap: () => _selectOption(option),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skip,
                      child: const Text('Pular'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: selected != null ? _advance : null,
                      child: Text(_isLast ? 'Confirmar' : 'Próximo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStepBar extends StatelessWidget {
  const _ProgressStepBar({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          final active = i == current;
          final done = i < current;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: done || active
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SetsTable extends StatelessWidget {
  const _SetsTable({required this.sets});

  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('Série',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      )),
                ),
                Expanded(
                  child: Text('Reps',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      )),
                ),
                SizedBox(
                  width: 80,
                  child: Text('Carga',
                      textAlign: TextAlign.right,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      )),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Container(
              color: i.isEven ? Colors.transparent : colorScheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('${i + 1}',
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(
                    child: Text('${s.reps} reps',
                        style: textTheme.bodySmall),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      s.load > 0
                          ? '${s.load.toStringAsFixed(1)} kg'
                          : 'Peso corporal',
                      textAlign: TextAlign.right,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.isSelected,
    required this.isManter,
    required this.onTap,
  });

  final ProgressionOption option;
  final bool isSelected;
  final bool isManter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final borderColor =
        isSelected ? colorScheme.primary : colorScheme.outlineVariant;
    final bgColor = isSelected
        ? colorScheme.primaryContainer.withOpacity(0.4)
        : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isManter
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (option.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.description!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (!isManter && option.projectedSets.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ProjectedSets(sets: option.projectedSets),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectedSets extends StatelessWidget {
  const _ProjectedSets({required this.sets});

  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final uniqueReps = sets.map((s) => s.reps).toSet().length == 1;
    final uniqueLoad = sets.map((s) => s.load).toSet().length == 1;

    String label;
    if (uniqueReps && uniqueLoad) {
      final load = sets.first.load;
      label = '${sets.length}x${sets.first.reps}${load > 0 ? " · ${load.toStringAsFixed(1)}kg" : ""}';
    } else {
      label = sets.map((s) {
        final loadStr = s.load > 0 ? '/${s.load.toStringAsFixed(1)}kg' : '';
        return '${s.reps}$loadStr';
      }).join(' → ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
