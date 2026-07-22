import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workout_providers.dart';
import 'conversational_workout_screen.dart';

class WorkoutTrainerTab extends ConsumerStatefulWidget {
  const WorkoutTrainerTab({super.key});

  @override
  ConsumerState<WorkoutTrainerTab> createState() => _WorkoutTrainerTabState();
}

class _WorkoutTrainerTabState extends ConsumerState<WorkoutTrainerTab> {
  final _customRequestController = TextEditingController();
  int _selectedDays = 5;
  double _sessionDuration = 60;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final planState = ref.read(workoutPlanProvider);
    planState.whenData((plan) {
      if (plan != null && mounted) {
        setState(() {
          _selectedDays = plan.desiredDays ?? _selectedDays;
          _sessionDuration = (plan.sessionDurationMinutes ?? _sessionDuration.round()).toDouble();
        });
      }
    });
  }

  @override
  void dispose() {
    _customRequestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cabeçalho
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.psychology,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Treinador IA',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure suas preferências e gere treinos personalizados com inteligência artificial',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Preferências
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Preferências do Plano',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedDays,
                  decoration: const InputDecoration(
                    labelText: 'Dias de treino na semana',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
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
                const SizedBox(height: 20),
                Text(
                  'Duração desejada por treino',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
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
                    ),
                    Text(
                      '${_sessionDuration.round()} min',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'As preferências serão usadas ao gerar o próximo plano com a IA',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Ajustes personalizados
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ajustes Personalizados',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Descreva ajustes ou preferências específicas para o seu treino',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customRequestController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Ex: Foco maior em pernas, evitar exercícios de ombro, integrar exercícios de mobilidade...',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Botões de ação
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_isGenerating ? 'Gerando...' : 'Gerar Novo Plano com IA'),
                  onPressed: _isGenerating ? null : _generatePlan,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Conversar com IA Treinador'),
                  onPressed: _isGenerating ? null : _startConversation,
                ),
                const SizedBox(height: 16),
                Text(
                  '💡 Dica: Use a conversa com IA para criar treinos mais específicos e personalizados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePlan() async {
    setState(() => _isGenerating = true);
    
    final messenger = ScaffoldMessenger.of(context);
    final request = _customRequestController.text.trim();

    try {
      await ref.read(workoutPlanProvider.notifier).generateNewPlan(
            customRequest: request.isEmpty ? null : request,
            desiredDays: _selectedDays,
            sessionDurationMinutes: _sessionDuration.round(),
          );
      
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✓ Plano gerado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        _customRequestController.clear();
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar plano: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _startConversation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationalWorkoutScreen(
          initialDesiredDays: _selectedDays,
          initialSessionDuration: _sessionDuration.round(),
        ),
      ),
    );
  }
}
