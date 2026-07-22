import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/workout_reminder.dart';
import '../../providers/reminder_providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(allWorkoutRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes de treino')),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum lembrete salvo.\n\nQuando você conversar com a IA sobre treinos e mencionar restrições importantes (como lesões ou preferências), ela sugerirá salvar como lembrete.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return _ReminderCard(reminder: reminder);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context, ref),
        label: const Text('Adicionar'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context, WidgetRef ref) {
    final contentController = TextEditingController();
    String selectedCategory = 'preference';

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Novo lembrete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Conteúdo do lembrete',
                  hintText:
                      'Ex: Evitar exercícios de impacto por lesão no joelho',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: const [
                  DropdownMenuItem(
                    value: 'injury',
                    child: Text('Lesão/Restrição'),
                  ),
                  DropdownMenuItem(
                    value: 'preference',
                    child: Text('Preferência'),
                  ),
                  DropdownMenuItem(
                    value: 'equipment',
                    child: Text('Equipamento'),
                  ),
                  DropdownMenuItem(
                    value: 'schedule',
                    child: Text('Horário/Agenda'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Outro')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final content = contentController.text.trim();
                if (content.isEmpty) return;

                Navigator.of(context).pop();
                try {
                  await ref
                      .read(reminderManagerProvider)
                      .saveReminder(content, selectedCategory);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lembrete salvo!')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $error')));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder});

  final WorkoutReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryIcons = {
      'injury': Icons.healing,
      'preference': Icons.favorite,
      'equipment': Icons.fitness_center,
      'schedule': Icons.schedule,
      'other': Icons.label,
    };

    final categoryLabels = {
      'injury': 'Lesão',
      'preference': 'Preferência',
      'equipment': 'Equipamento',
      'schedule': 'Horário',
      'other': 'Outro',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          categoryIcons[reminder.category] ?? Icons.label,
          color: reminder.isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        title: Text(
          reminder.content,
          style: TextStyle(
            decoration: reminder.isActive ? null : TextDecoration.lineThrough,
            color: reminder.isActive
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          '${categoryLabels[reminder.category] ?? 'Outro'} • ${DateFormat('dd/MM/yyyy').format(reminder.createdAt)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'toggle') {
              await ref
                  .read(reminderManagerProvider)
                  .toggleReminder(reminder.id!, !reminder.isActive);
            } else if (value == 'delete') {
              await ref
                  .read(reminderManagerProvider)
                  .deleteReminder(reminder.id!);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(reminder.isActive ? 'Desativar' : 'Ativar'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}
