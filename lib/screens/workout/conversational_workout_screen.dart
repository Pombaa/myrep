import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout_chat_message.dart';
import '../../models/workout_plan.dart';
import '../../providers/conversational_workout_provider.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/workout_providers.dart';

class ConversationalWorkoutScreen extends ConsumerStatefulWidget {
  const ConversationalWorkoutScreen({
    super.key,
    this.initialDesiredDays,
    this.initialSessionDuration,
  });

  final int? initialDesiredDays;
  final int? initialSessionDuration;

  @override
  ConsumerState<ConversationalWorkoutScreen> createState() =>
      _ConversationalWorkoutScreenState();
}

class _ConversationalWorkoutScreenState
    extends ConsumerState<ConversationalWorkoutScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitialConversation();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startInitialConversation() async {
    if (_hasStarted) return;
    _hasStarted = true;

    try {
      await ref.read(conversationalWorkoutProvider.notifier).startConversation(
            desiredDays: widget.initialDesiredDays,
            sessionDurationMinutes: widget.initialSessionDuration,
          );
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      
      final errorMessage = error.toString();
      final isApiKeyError = errorMessage.contains('OpenAI') || errorMessage.contains('chave');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: isApiKeyError
              ? SnackBarAction(
                  label: 'Configurar',
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/settings');
                  },
                )
              : null,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    try {
      await ref.read(conversationalWorkoutProvider.notifier).sendMessage(message);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      
      final errorMessage = error.toString();
      final isApiKeyError = errorMessage.contains('OpenAI') || errorMessage.contains('chave');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: isApiKeyError
              ? SnackBarAction(
                  label: 'Configurar',
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/settings');
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _savePlan() async {
    try {
      await ref.read(conversationalWorkoutProvider.notifier).saveFinalPlan();
      ref.invalidate(workoutPlanProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plano salvo com sucesso!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationalWorkoutProvider);
    final hasConversation = state.conversation.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Trainer IA'),
        actions: [
          if (hasConversation && !state.isProcessing && state.plan != null)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _savePlan,
              tooltip: 'Finalizar e salvar treino',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: hasConversation
                ? _buildConversation(state.conversation)
                : _buildEmptyState(state.isProcessing),
          ),
          if (state.isProcessing) const LinearProgressIndicator(),
          _buildMessageInput(hasConversation && !state.isProcessing),
        ],
      ),
    );
  }

  Widget _buildConversation(List<WorkoutChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message.role == WorkoutChatRole.user;

        // Se for mensagem do assistente, verifica se tem treino para mostrar
        if (!isUser && message.rawContent != null) {
          try {
            final parsed = jsonDecode(message.rawContent!) as Map<String, dynamic>;
            final hasWorkout = parsed.containsKey('treino');

            if (hasWorkout) {
              return _buildAssistantMessageWithWorkout(context, message, parsed);
            }
          } catch (_) {
            // Se falhar o parse, mostra mensagem normal
          }
        }

        return _buildChatBubble(message, isUser);
      },
    );
  }

  Widget _buildChatBubble(WorkoutChatMessage message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantMessageWithWorkout(
      BuildContext context, WorkoutChatMessage message, Map<String, dynamic> parsed) {
    final daysRaw = parsed['treino'] as List<dynamic>? ?? [];
    final days = daysRaw
        .map((dynamic item) =>
            WorkoutDay.fromJson((item as Map).cast<String, Object?>()))
        .toList();
    final hasSuggestion = parsed.containsKey('sugestao_lembrete');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mensagem do personal
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.90,
          ),
          margin: const EdgeInsets.only(bottom: 12, left: 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.fitness_center, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Personal Trainer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(message.content),
            ],
          ),
        ),

        // Card do treino
        Card(
          margin: const EdgeInsets.only(bottom: 12, left: 0, right: 0),
          elevation: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Plano de Treino - ${days.length} dias/semana',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final day = days[index];
                  return ExpansionTile(
                    title: Text(
                      '${day.dayLabel} • ${day.muscleGroup}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${day.exercises.length} exercícios'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            for (var i = 0; i < day.exercises.length; i++) ...[
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  radius: 16,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(day.exercises[i].name),
                                    if (day.exercises[i].combinedExercises != null && 
                                        day.exercises[i].combinedExercises!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              for (var combinedEx in day.exercises[i].combinedExercises!)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.double_arrow,
                                                      size: 10,
                                                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        combinedEx,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          fontSize: 10,
                                                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (day.exercises[i].substituteExercise != null && 
                                        day.exercises[i].substituteExercise!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.swap_horiz,
                                              size: 12,
                                              color: Theme.of(context).colorScheme.tertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                day.exercises[i].substituteExercise!,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.tertiary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${day.exercises[i].series}x${day.exercises[i].repetitions} reps'),
                                    if (day.exercises[i].technique != null ||
                                        day.exercises[i].eccentricSeconds != null ||
                                        day.exercises[i].concentricSeconds != null ||
                                        day.exercises[i].restBetweenSetsSeconds != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (day.exercises[i].technique != null)
                                                _buildCompactInfo(
                                                  context,
                                                  icon: Icons.fitness_center,
                                                  text: day.exercises[i].technique!,
                                                ),
                                              if (day.exercises[i].eccentricSeconds != null ||
                                                  day.exercises[i].concentricSeconds != null) ...[
                                                const SizedBox(height: 2),
                                                _buildCompactInfo(
                                                  context,
                                                  icon: Icons.speed,
                                                  text: '${day.exercises[i].concentricSeconds ?? 1}s/${day.exercises[i].eccentricSeconds ?? 2}s',
                                                ),
                                              ],
                                              if (day.exercises[i].restBetweenSetsSeconds != null) ...[
                                                const SizedBox(height: 2),
                                                _buildCompactInfo(
                                                  context,
                                                  icon: Icons.timer,
                                                  text: '${day.exercises[i].restBetweenSetsSeconds}s descanso',
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: day.exercises[i].suggestedLoad != null
                                    ? Chip(
                                        label: Text(
                                          '${day.exercises[i].suggestedLoad}kg',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      )
                                    : null,
                              ),
                              if (i < day.exercises.length - 1) const Divider(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Dica sobre ajustes de técnicas
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 0, right: 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pode ajustar técnicas, cadências ou descansos conversando comigo!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botão de lembrete se houver sugestão
        if (hasSuggestion) _buildReminderSuggestionChip(context, parsed),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildReminderSuggestionChip(
      BuildContext context, Map<String, dynamic> parsed) {
    final suggestion = parsed['sugestao_lembrete'] as Map<String, dynamic>?;
    if (suggestion == null) return const SizedBox.shrink();

    final content = suggestion['conteudo'] as String?;
    final category = suggestion['categoria'] as String?;
    if (content == null || category == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, bottom: 8),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sugestão de lembrete',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await ref
                          .read(reminderManagerProvider)
                          .saveReminder(content, category);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Lembrete salvo com sucesso!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro: $error')),
                      );
                    }
                  },
                  icon: const Icon(Icons.bookmark_add, size: 18),
                  label: const Text('Lembrar dessa escolha'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfo(BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Conectando com seu personal trainer...'),
          ],
        ),
      );
    }
    return const Center(
      child: Text('Iniciando conversa...'),
    );
  }

  Widget _buildMessageInput(bool enabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: enabled,
              maxLines: null,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Ex: Adiciona mais exercícios para bíceps...'
                    : 'Aguarde...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: enabled ? (_) => _sendMessage() : null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            onPressed: enabled ? _sendMessage : null,
          ),
        ],
      ),
    );
  }
}
