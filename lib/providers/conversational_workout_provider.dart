import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/workout_prompt_builder.dart';
import '../models/ai_interaction.dart';
import '../models/workout_chat_message.dart';
import '../models/workout_plan.dart';
import '../models/workout_plan_state.dart';
import '../models/workout_reminder.dart';
import 'measurement_providers.dart';
import 'progress_providers.dart';
import 'reminder_providers.dart';
import 'repository_providers.dart';
import 'services_providers.dart';
import 'settings_providers.dart';
import 'user_providers.dart';

final conversationalWorkoutProvider =
    StateNotifierProvider<ConversationalWorkoutController, WorkoutPlanState>((
      ref,
    ) {
      return ConversationalWorkoutController(ref);
    });

class ConversationalWorkoutController extends StateNotifier<WorkoutPlanState> {
  ConversationalWorkoutController(this._ref) : super(WorkoutPlanState.empty);

  final Ref _ref;

  Future<void> startConversation({
    int? desiredDays,
    int? sessionDurationMinutes,
  }) async {
    state = state.copyWith(isProcessing: true);

    try {
      final profile = _ref.read(userProfileProvider).valueOrNull;
      final latestMeasurement = _ref.read(latestMeasurementProvider);
      if (profile == null) {
        throw Exception('Cadastre seu perfil para gerar um treino.');
      }
      if (latestMeasurement == null) {
        throw Exception(
          'Registre uma avaliação corporal antes de gerar o treino.',
        );
      }

      final aiProvider = _ref.read(selectedAiProviderProvider);
      final apiKeyState = aiProvider == AiProvider.nvidia
          ? _ref.read(nvidiaKeyProvider)
          : _ref.read(openAiKeyProvider);
      final apiKey = apiKeyState.when(
        data: (value) => value,
        loading: () => null,
        error: (_, __) => null,
      );
      if (apiKey == null || apiKey.isEmpty) {
        final name = aiProvider == AiProvider.nvidia ? 'NVIDIA' : 'OpenAI';
        throw Exception('Informe a chave da API $name nas configurações.');
      }

      final workoutRepository = _ref.read(workoutRepositoryProvider);
      final previousMeasurement = _ref.read(previousMeasurementProvider);
      final lastPlan = await workoutRepository.latestPlan();
      final lastSession = await workoutRepository.lastSession();
      final progressSummary = await _ref.read(progressSummaryProvider.future);
      final reminders = await _ref.read(workoutRemindersProvider.future);

      final resolvedDays = desiredDays ?? lastPlan?.desiredDays ?? 5;
      final resolvedDuration =
          sessionDurationMinutes ?? lastPlan?.sessionDurationMinutes ?? 60;

      final historyRepo = _ref.read(exerciseHistoryRepositoryProvider);
      final progressionHistory =
          await historyRepo.getProgressionSummary(profile.id ?? 1, limit: 4);

      const promptBuilder = WorkoutPromptBuilder();
      final basePrompt = promptBuilder.build(
        profile: profile,
        latestMeasurement: latestMeasurement,
        previousMeasurement: previousMeasurement,
        lastPlan: lastPlan,
        lastSession: lastSession,
        progressSummary: progressSummary,
        desiredDays: resolvedDays,
        sessionDurationMinutes: resolvedDuration,
        progressionHistory: progressionHistory.isEmpty ? null : progressionHistory,
      );

      final systemPrompt = _buildSystemPrompt(basePrompt, reminders);

      final messages = [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content':
              'Crie um plano de treino inicial para mim. Retorne JSON com mensagem explicativa e o treino completo.',
        },
      ];

      final openAi = _ref.read(openAiServiceProvider);
      final result = await openAi.generateWorkoutPlan(
        apiKey: apiKey,
        messages: messages,
        baseUrl: aiProvider.baseUrl,
        model: aiProvider == AiProvider.nvidia ? aiProvider.defaultModel : 'gpt-4o',
        temperature: 0.5,
        useStructuredOutput: aiProvider.useStructuredOutput,
      );

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final assistantMessage =
          parsed['mensagem'] as String? ?? 'Plano criado com sucesso.';
      final daysRaw = parsed['treino'] as List<dynamic>? ?? [];

      final days = daysRaw
          .map(
            (dynamic item) =>
                WorkoutDay.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList();

      final plan = WorkoutPlan(
        userId: profile.id ?? 1,
        generatedAt: DateTime.now(),
        objective: profile.objective,
        days: days,
        desiredDays: resolvedDays,
        sessionDurationMinutes: resolvedDuration,
      );

      final conversation = [
        WorkoutChatMessage(
          role: WorkoutChatRole.user,
          content: 'Gerar treino inicial',
          sentAt: DateTime.now(),
        ),
        WorkoutChatMessage(
          role: WorkoutChatRole.assistant,
          content: assistantMessage,
          sentAt: DateTime.now(),
          rawContent: result,
        ),
      ];

      state = WorkoutPlanState(
        plan: plan,
        conversation: conversation,
        basePrompt: basePrompt,
      );
    } catch (error) {
      state = WorkoutPlanState.empty;
      rethrow;
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> sendMessage(String userMessage) async {
    if (state.plan == null || state.basePrompt == null) {
      throw Exception('Inicie uma conversa primeiro.');
    }

    final userMsg = WorkoutChatMessage(
      role: WorkoutChatRole.user,
      content: userMessage,
      sentAt: DateTime.now(),
    );

    state = state.copyWith(
      conversation: [...state.conversation, userMsg],
      isProcessing: true,
    );

    try {
      final aiProvider = _ref.read(selectedAiProviderProvider);
      final msgApiKeyState = aiProvider == AiProvider.nvidia
          ? _ref.read(nvidiaKeyProvider)
          : _ref.read(openAiKeyProvider);
      final msgApiKey = msgApiKeyState.when(
        data: (value) => value,
        loading: () => null,
        error: (_, __) => null,
      );
      if (msgApiKey == null || msgApiKey.isEmpty) {
        final name = aiProvider == AiProvider.nvidia ? 'NVIDIA' : 'OpenAI';
        throw Exception('Chave da API $name não configurada.');
      }

      final reminders = await _ref.read(workoutRemindersProvider.future);
      final systemPrompt = _buildSystemPrompt(state.basePrompt!, reminders);

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      for (final msg in state.conversation) {
        final role = msg.role == WorkoutChatRole.user ? 'user' : 'assistant';
        messages.add({'role': role, 'content': msg.rawContent ?? msg.content});
      }

      final openAi = _ref.read(openAiServiceProvider);
      final result = await openAi.generateWorkoutPlan(
        apiKey: msgApiKey,
        messages: messages,
        baseUrl: aiProvider.baseUrl,
        model: aiProvider == AiProvider.nvidia ? aiProvider.defaultModel : 'gpt-4o',
        temperature: 0.5,
        useStructuredOutput: aiProvider.useStructuredOutput,
      );

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final assistantMessage =
          parsed['mensagem'] as String? ?? 'Plano ajustado.';
      final daysRaw = parsed['treino'] as List<dynamic>? ?? [];

      final days = daysRaw
          .map(
            (dynamic item) =>
                WorkoutDay.fromJson((item as Map).cast<String, Object?>()),
          )
          .toList();

      final updatedPlan = state.plan!.copyWith(
        days: days,
        generatedAt: DateTime.now(),
      );

      final assistantMsg = WorkoutChatMessage(
        role: WorkoutChatRole.assistant,
        content: assistantMessage,
        sentAt: DateTime.now(),
        rawContent: result,
      );

      state = state.copyWith(
        plan: updatedPlan,
        conversation: [...state.conversation, assistantMsg],
        isProcessing: false,
      );
    } catch (error) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  Future<void> saveFinalPlan() async {
    if (state.plan == null) {
      throw Exception('Nenhum plano para salvar.');
    }

    final workoutRepository = _ref.read(workoutRepositoryProvider);
    final aiRepository = _ref.read(aiRepositoryProvider);

    await workoutRepository.savePlan(state.plan!);

    // Save conversation as AI interaction
    final conversationJson = jsonEncode(
      state.conversation
          .map(
            (msg) => {
              'role': msg.role == WorkoutChatRole.user ? 'user' : 'assistant',
              'content': msg.content,
              'sent_at': msg.sentAt.toIso8601String(),
            },
          )
          .toList(),
    );

    await aiRepository.saveInteraction(
      AiInteraction(
        createdAt: DateTime.now(),
        prompt: 'Conversa: ${state.conversation.length} mensagens',
        response: conversationJson,
        metadata: jsonEncode({'type': 'conversational_workout_plan'}),
      ),
    );

    _ref.invalidate(progressSummaryProvider);
    state = WorkoutPlanState.empty;
  }

  void clearConversation() {
    state = WorkoutPlanState.empty;
  }

  String _buildSystemPrompt(
    String basePrompt,
    List<WorkoutReminder> reminders,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Você é um personal trainer virtual especializado em criar e ajustar treinos personalizados.',
    );
    buffer.writeln(
      'Você conversa de forma natural, mas sempre retorna JSON estruturado com suas respostas.',
    );
    buffer.writeln();
    buffer.writeln('CONTEXTO DO USUÁRIO:');
    buffer.writeln(basePrompt);
    buffer.writeln();

    if (reminders.isNotEmpty) {
      buffer.writeln('LEMBRETES IMPORTANTES DO USUÁRIO (considere sempre):');
      for (final reminder in reminders) {
        buffer.writeln(
          '- [${reminder.category.toUpperCase()}] ${reminder.content}',
        );
      }
      buffer.writeln();
    }

    buffer.writeln('INSTRUÇÕES:');
    buffer.writeln(
      '1. SEMPRE considere o NÍVEL DE ATIVIDADE do usuário ao escolher técnicas e cadências.',
    );
    buffer.writeln(
      '   O nível está no contexto acima. Seja conservador com iniciantes!',
    );
    buffer.writeln(
      '2. Quando o usuário pedir ajustes, modifique o treino de acordo mantendo a estrutura geral.',
    );
    buffer.writeln(
      '3. Se identificar uma nova restrição importante (lesão, preferência forte), sugira salvar como lembrete.',
    );
    buffer.writeln(
      '4. SEMPRE forneça um exercício substituto para cada exercício do treino.',
    );
    buffer.writeln(
      '   O substituto deve trabalhar o mesmo grupo muscular com movimento/equipamento diferente.',
    );
    buffer.writeln(
      '4. Para cada exercício, defina técnica apropriada ao NÍVEL DO USUÁRIO e objetivo:',
    );
    buffer.writeln(
      '   IMPORTANTE: Seja ponderado com técnicas avançadas baseado no nível:',
    );
    buffer.writeln(
      '   - INICIANTE: Use principalmente "Tradicional" (90% dos exercícios)',
    );
    buffer.writeln(
      '     Pode usar Drop Set leve apenas em 1-2 exercícios de isolamento',
    );
    buffer.writeln(
      '   - INTERMEDIÁRIO: Misture Tradicional (60-70%) com técnicas moderadas',
    );
    buffer.writeln(
      '     Drop Set, Super Set em 2-3 exercícios por treino',
    );
    buffer.writeln(
      '   - AVANÇADO: Pode usar técnicas avançadas em 40-50% dos exercícios',
    );
    buffer.writeln(
      '     Cluster, Rest-Pause, Tri-Set para maximizar hipertrofia',
    );
    buffer.writeln();
    buffer.writeln(
      '   Técnicas disponíveis:',
    );
    buffer.writeln(
      '   - Tradicional: série normal com descanso completo (padrão para iniciantes)',
    );
    buffer.writeln(
      '   - Drop Set: reduzir peso gradualmente sem descanso (moderado)',
    );
    buffer.writeln(
      '   - Super Set: dois exercícios de grupos DIFERENTES seguidos (moderado)',
    );
    buffer.writeln(
      '     Use "exercicios_combinados": ["nome_do_segundo_exercicio"]',
    );
    buffer.writeln(
      '   - Bi-Set: dois exercícios do MESMO grupo seguidos (avançado)',
    );
    buffer.writeln(
      '     Use "exercicios_combinados": ["nome_do_segundo_exercicio"]',
    );
    buffer.writeln(
      '   - Tri-Set: três exercícios do mesmo grupo seguidos (avançado)',
    );
    buffer.writeln(
      '     Use "exercicios_combinados": ["segundo", "terceiro"]',
    );
    buffer.writeln(
      '   - Rest-Pause: descansos curtos dentro da série (avançado)',
    );
    buffer.writeln(
      '   - Cluster: micro-pausas durante a série para força (avançado)',
    );
    buffer.writeln(
      '   - Piramidal: aumenta/diminui peso progressivamente (intermediário)',
    );
    buffer.writeln(
      '5. Defina tempo de execução (cadência) apropriado ao NÍVEL:',
    );
    buffer.writeln(
      '   - INICIANTE: Cadência controlada e moderada',
    );
    buffer.writeln(
      '     Excêntrica: 2-3s | Concêntrica: 1-2s | Descanso: 60-90s',
    );
    buffer.writeln(
      '   - INTERMEDIÁRIO: Pode variar a cadência conforme exercício',
    );
    buffer.writeln(
      '     Excêntrica: 2-4s | Concêntrica: 1-2s | Descanso: 45-90s',
    );
    buffer.writeln(
      '   - AVANÇADO: Cadência estratégica para maximizar hipertrofia',
    );
    buffer.writeln(
      '     Excêntrica: 3-6s | Concêntrica: 1-2s | Descanso: 30-120s conforme objetivo',
    );
    buffer.writeln();
    buffer.writeln(
      '   Diretrizes gerais de descanso:',
    );
    buffer.writeln(
      '   - 30-45s: Resistência muscular ou técnicas intensas',
    );
    buffer.writeln(
      '   - 60-90s: Hipertrofia (padrão)',
    );
    buffer.writeln(
      '   - 120-180s: Força máxima ou exercícios compostos pesados',
    );
    buffer.writeln('6. Sempre retorne JSON com:');
    buffer.writeln('   - "mensagem": texto natural explicando o que foi feito');
    buffer.writeln('   - "treino": array completo do plano atualizado');
    buffer.writeln(
      '   - "sugestao_lembrete" (opcional): {"conteudo": "texto", "categoria": "injury|preference|equipment|schedule|other"}',
    );
    buffer.writeln();
    buffer.writeln('FORMATO DE RESPOSTA:');
    buffer.writeln('{');
    buffer.writeln(
      '  "mensagem": "Criei um treino balanceado para seu nível...",',
    );
    buffer.writeln(
      '  "treino": [{"dia":"Segunda","grupo_muscular":"Peito","exercicios":[{',
    );
    buffer.writeln(
      '    "nome":"Supino reto","series":4,"reps":10,"exercicio_substituto":"Supino com halteres",',
    );
    buffer.writeln(
      '    "tecnica":"Tradicional","tempo_excentrica":3,"tempo_concentrica":1,"descanso_entre_series":90',
    );
    buffer.writeln(
      '  },{',
    );
    buffer.writeln(
      '    "nome":"Supino inclinado","series":3,"reps":12,"exercicio_substituto":"Supino inclinado com halteres",',
    );
    buffer.writeln(
      '    "tecnica":"Bi-Set","tempo_excentrica":2,"tempo_concentrica":1,"descanso_entre_series":60,',
    );
    buffer.writeln(
      '    "exercicios_combinados":["Peck Deck"]',
    );
    buffer.writeln(
      '  },...]}],',
    );
    buffer.writeln(
      '  "sugestao_lembrete": {"conteudo": "Evitar agachamentos por lesão no joelho", "categoria": "injury"}',
    );
    buffer.writeln('}');

    return buffer.toString();
  }
}
