import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise_library.dart';
import '../../models/workout_plan.dart' show WorkoutDay, WorkoutExercise, WorkoutPlan, EquipmentType, EquipmentTypeX;
import '../../providers/user_providers.dart';
import '../../providers/workout_providers.dart';

class ManualWorkoutEntryScreen extends ConsumerStatefulWidget {
  const ManualWorkoutEntryScreen({super.key, this.basePlan});

  final WorkoutPlan? basePlan;

  @override
  ConsumerState<ManualWorkoutEntryScreen> createState() =>
      _ManualWorkoutEntryScreenState();
}

class _ManualWorkoutEntryScreenState
    extends ConsumerState<ManualWorkoutEntryScreen> {
  final _nameController = TextEditingController();
  final List<_ExerciseEntry> _exercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.basePlan != null) {
      final day = widget.basePlan!.days.isNotEmpty
          ? widget.basePlan!.days.first
          : null;
      if (day != null) {
        _nameController.text = day.dayLabel;
        for (final e in day.exercises) {
          _exercises.add(_ExerciseEntry(
            name: e.name,
            series: e.series,
            reps: e.repetitions,
            load: e.suggestedLoad ?? 0,
            equipmentType: e.equipmentType,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addOrEditExercise([int? editIndex]) async {
    final entry = editIndex != null ? _exercises[editIndex] : null;
    final result = await showModalBottomSheet<_ExerciseEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseSheet(initial: entry),
    );
    if (result == null) return;
    setState(() {
      if (editIndex != null) {
        _exercises[editIndex] = result;
      } else {
        _exercises.add(result);
      }
    });
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome ao treino.')),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um exercício.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile == null) throw Exception('Perfil não encontrado.');

      final muscleGroup = _exercises.isNotEmpty
          ? (muscleGroupForExercise(_exercises.first.name) ?? 'Misto')
          : 'Misto';

      final day = WorkoutDay(
        dayLabel: name,
        muscleGroup: muscleGroup,
        exercises: _exercises
            .map((e) => WorkoutExercise(
                  name: e.name,
                  series: e.series,
                  repetitions: e.reps,
                  suggestedLoad: e.load > 0 ? e.load : null,
                  equipmentType: e.equipmentType,
                ))
            .toList(),
      );

      final plan = WorkoutPlan(
        userId: profile.id ?? 1,
        generatedAt: DateTime.now(),
        objective: profile.objective,
        days: [day],
        source: 'manual',
      );

      await ref.read(workoutPlanProvider.notifier).savePlanDirectly(plan);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meu Treino'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Nome do treino  (ex: Peito e Tríceps)',
                prefixIcon: const Icon(Icons.label_outline),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _exercises.isEmpty
                ? _EmptyState(onAdd: _addOrEditExercise)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _exercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _exercises.removeAt(oldIndex);
                        _exercises.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, i) {
                      final e = _exercises[i];
                      return _ExerciseTile(
                        key: ValueKey(e),
                        entry: e,
                        index: i,
                        onTap: () => _addOrEditExercise(i),
                        onDelete: () => _removeExercise(i),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _exercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addOrEditExercise,
              icon: const Icon(Icons.add),
              label: const Text('Exercício'),
            ),
    );
  }
}

// ─── Modelo de dados interno ──────────────────────────────────────────────────

class _ExerciseEntry {
  _ExerciseEntry({
    required this.name,
    required this.series,
    required this.reps,
    required this.load,
    this.equipmentType,
  });

  String name;
  int series;
  int reps;
  double load;
  EquipmentType? equipmentType;

  String get subtitle {
    final loadStr = load > 0 ? ' · ${load.toStringAsFixed(load % 1 == 0 ? 0 : 1)}kg' : '';
    final equipStr = equipmentType != null ? ' · ${equipmentType!.label}' : '';
    return '$series × $reps reps$loadStr$equipStr';
  }
}

// ─── Tile de exercício na lista ───────────────────────────────────────────────

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final _ExerciseEntry entry;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muscle = muscleGroupForExercise(entry.name);

    return Dismissible(
      key: ValueKey(entry),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(entry.subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (muscle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    muscle,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: 'Remover',
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline,
              size: 64, color: colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Nenhum exercício ainda',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Toque para adicionar o primeiro',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar exercício'),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet de adicionar / editar exercício ─────────────────────────────

class _ExerciseSheet extends StatefulWidget {
  const _ExerciseSheet({this.initial});

  final _ExerciseEntry? initial;

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  final _nameController = TextEditingController();
  final _loadController = TextEditingController();
  final _customSeriesController = TextEditingController();
  final _customRepsController = TextEditingController();
  final _nameFocus = FocusNode();
  int _series = 3;
  int _reps = 10;
  bool _customSeriesMode = false;
  bool _customRepsMode = false;
  EquipmentType? _equipmentType;
  List<String> _suggestions = [];

  static const _presetSeries = [2, 3, 4, 5];
  static const _presetReps = [6, 8, 10, 12, 15, 20];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final e = widget.initial!;
      _nameController.text = e.name;
      _series = e.series;
      _reps = e.reps;
      _equipmentType = e.equipmentType;
      _loadController.text =
          e.load > 0 ? e.load.toStringAsFixed(e.load % 1 == 0 ? 0 : 1) : '';
      if (!_presetSeries.contains(_series)) {
        _customSeriesMode = true;
        _customSeriesController.text = '$_series';
      }
      if (!_presetReps.contains(_reps)) {
        _customRepsMode = true;
        _customRepsController.text = '$_reps';
      }
    }
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final query = _nameController.text;
    setState(() {
      _suggestions = autocompleteExercises(query).take(5).toList();
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _loadController.dispose();
    _customSeriesController.dispose();
    _customRepsController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final load =
        double.tryParse(_loadController.text.trim().replaceAll(',', '.')) ?? 0;
    Navigator.of(context).pop(
      _ExerciseEntry(
        name: name,
        series: _series,
        reps: _reps,
        load: load,
        equipmentType: _equipmentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initial == null ? 'Adicionar exercício' : 'Editar exercício',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Nome com autocomplete inline
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome do exercício',
                hintText: 'Ex: Supino Reto',
                prefixIcon: const Icon(Icons.fitness_center),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _nameController.clear();
                          _nameFocus.requestFocus();
                        },
                      )
                    : null,
              ),
            ),

            // Sugestões de autocomplete
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: _suggestions.map((s) {
                    final muscle = muscleGroupForExercise(s);
                    return InkWell(
                      onTap: () {
                        _nameController.text = s;
                        _nameFocus.unfocus();
                        setState(() => _suggestions = []);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(s, style: textTheme.bodyMedium),
                            ),
                            if (muscle != null)
                              Text(
                                muscle,
                                style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),

            // Equipamento
            Text('Equipamento', style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: EquipmentType.values.map((eq) {
                final selected = _equipmentType == eq;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _SelectChip(
                      label: eq.label,
                      selected: selected,
                      onTap: () => setState(() {
                        _equipmentType = selected ? null : eq;
                      }),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Séries
            Text('Séries', style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                ..._presetSeries.map((s) {
                  final selected = !_customSeriesMode && _series == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _SelectChip(
                        label: '$s',
                        selected: selected,
                        onTap: () => setState(() {
                          _series = s;
                          _customSeriesMode = false;
                        }),
                      ),
                    ),
                  );
                }),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _SelectChip(
                      label: 'outro',
                      selected: _customSeriesMode,
                      onTap: () => setState(() {
                        _customSeriesMode = !_customSeriesMode;
                        if (_customSeriesMode) {
                          _customSeriesController.text = '$_series';
                        }
                      }),
                    ),
                  ),
                ),
              ],
            ),
            if (_customSeriesMode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customSeriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Qtd de séries',
                  isDense: true,
                  prefixIcon: Icon(Icons.edit_outlined, size: 18),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n > 0) setState(() => _series = n);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Repetições
            Text('Repetições', style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._presetReps.map((r) {
                  final selected = !_customRepsMode && _reps == r;
                  return _SelectChip(
                    label: '$r',
                    selected: selected,
                    onTap: () => setState(() {
                      _reps = r;
                      _customRepsMode = false;
                    }),
                  );
                }),
                _SelectChip(
                  label: 'outro',
                  selected: _customRepsMode,
                  onTap: () => setState(() {
                    _customRepsMode = !_customRepsMode;
                    if (_customRepsMode) {
                      _customRepsController.text = '$_reps';
                    }
                  }),
                ),
              ],
            ),
            if (_customRepsMode) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customRepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Qtd de repetições',
                  isDense: true,
                  prefixIcon: Icon(Icons.edit_outlined, size: 18),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n > 0) setState(() => _reps = n);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Carga
            TextField(
              controller: _loadController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Carga (kg)',
                hintText: 'Deixe vazio para peso corporal',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _nameController.text.trim().isEmpty ? null : _confirm,
                child: Text(
                  widget.initial == null ? 'Adicionar' : 'Salvar',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
