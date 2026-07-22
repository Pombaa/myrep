import '../../models/body_measurement.dart';
import '../../models/exercise_progression_suggestion.dart';
import '../../models/progress_summary.dart';
import '../../models/user_profile.dart';
import '../../models/workout_plan.dart';
import '../../models/workout_session.dart';

class WorkoutPromptBuilder {
  const WorkoutPromptBuilder();

  String build({
    required UserProfile profile,
    required BodyMeasurement latestMeasurement,
    BodyMeasurement? previousMeasurement,
    WorkoutPlan? lastPlan,
    WorkoutSession? lastSession,
    ProgressSummary? progressSummary,
    String? objectiveOverride,
    String? customRequest,
    int? desiredDays,
    int? sessionDurationMinutes,
    Map<String, List<ExerciseHistoryEntry>>? progressionHistory,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Você é um personal trainer virtual especializado em periodização e progressão de carga.');
    buffer.writeln();
    buffer.writeln('Contexto do usuário:');
    buffer.writeln('- Nome: ${profile.name}');
    buffer.writeln('- Idade: ${profile.age} anos');
    buffer.writeln('- Sexo: ${profile.sex}');
    buffer.writeln('- Altura: ${profile.height.toStringAsFixed(2)} m');
    buffer.writeln('- Peso atual: ${latestMeasurement.weight.toStringAsFixed(1)} kg');
    buffer.writeln('- Percentual de gordura: ${latestMeasurement.bodyFatPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Massa magra: ${latestMeasurement.leanMass.toStringAsFixed(1)} kg');
    buffer.writeln('- Nível: ${profile.activityLevel}');
    buffer.writeln('- Objetivo: ${objectiveOverride ?? profile.objective}');
    if ((profile.restrictions ?? '').trim().isNotEmpty) {
      buffer.writeln('- Restrições: ${profile.restrictions}');
    }

    if (previousMeasurement != null) {
      buffer.writeln();
      buffer.writeln('Última avaliação corporal (${_formatDate(previousMeasurement.recordedAt)}):');
      buffer.writeln('- Peso: ${previousMeasurement.weight.toStringAsFixed(1)} kg');
      buffer.writeln('- Percentual de gordura: ${previousMeasurement.bodyFatPercent.toStringAsFixed(1)}%');
      buffer.writeln('- Massa magra: ${previousMeasurement.leanMass.toStringAsFixed(1)} kg');
    }

    buffer.writeln();
    buffer.writeln('Avaliação atual (${_formatDate(latestMeasurement.recordedAt)}):');
    buffer.writeln('- Peso: ${latestMeasurement.weight.toStringAsFixed(1)} kg');
    buffer.writeln('- Percentual de gordura: ${latestMeasurement.bodyFatPercent.toStringAsFixed(1)}%');
    buffer.writeln('- Massa magra: ${latestMeasurement.leanMass.toStringAsFixed(1)} kg');

    if (lastSession != null) {
      buffer.writeln();
      buffer.writeln('Último treino executado (${_formatDate(lastSession.executedAt)}):');
      buffer.writeln('Dia: ${lastSession.dayLabel}');
      for (final exercise in lastSession.exercises) {
        buffer.writeln('  - ${exercise.name}: ${exercise.series}x${exercise.repetitions} ${exercise.suggestedLoad != null ? 'carga_utilizada: ${exercise.suggestedLoad}' : ''}'.trim());
      }
    } else if (lastPlan != null) {
      buffer.writeln();
      buffer.writeln('Último plano de treino (${_formatDate(lastPlan.generatedAt)}):');
      for (final day in lastPlan.days) {
        buffer.writeln('Dia ${day.dayLabel} - ${day.muscleGroup}');
        for (final exercise in day.exercises) {
          buffer.writeln('  - ${exercise.name}: ${exercise.series}x${exercise.repetitions}');
        }
      }
    }

    if (progressSummary != null && progressSummary.hasProgressData) {
      buffer.writeln();
      buffer.writeln('Histórico resumido:');
      buffer.writeln('- Peso corporal: ${_formatDelta(progressSummary.weightDelta)} kg');
      buffer.writeln('- Percentual de gordura: ${_formatDelta(progressSummary.bodyFatDelta)}%');
      buffer.writeln('- Massa magra: ${_formatDelta(progressSummary.leanMassDelta)} kg');
      buffer.writeln('- Carga média estimada: ${_formatDelta(progressSummary.averageLoadDelta)} kg');
    }

    if (progressionHistory != null && progressionHistory.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Histórico de progressão dos últimos 4 treinos por exercício:');
      for (final entry in progressionHistory.entries) {
        final exerciseName = entry.key;
        final sessions = entry.value;
        if (sessions.isEmpty) continue;
        final progressionStr = sessions.reversed
            .map((s) => s.summaryLine)
            .join(' → ');
        final scheme = sessions.first.repScheme.label;
        final lastDecision = sessions.first.progressionDecisionLabel;
        buffer.write('- $exerciseName: $progressionStr');
        buffer.write(' | Esquema: $scheme');
        if (lastDecision != null && lastDecision.isNotEmpty) {
          buffer.write(' | Última decisão: $lastDecision');
        }
        buffer.writeln();
      }
      buffer.writeln('Ao gerar o novo treino, mantenha a progressão lógica para cada exercício.');
      buffer.writeln('Preserve o esquema de repetições preferido do usuário quando identificável.');
    }

    final targetDays = desiredDays ?? 5;
    final targetDuration = sessionDurationMinutes;
    buffer.writeln();
    buffer.writeln('Preferências atuais do usuário:');
    buffer.writeln('- Número de dias de treino desejado: $targetDays dias por semana');
    if (targetDuration != null) {
      buffer.writeln('- Duração média desejada por sessão: $targetDuration minutos');
    }

    buffer.writeln();
    buffer.writeln('Tarefa:');
    buffer.writeln('Gere um novo plano de treino completo para $targetDays dias por semana, equilibrado, com foco em ${objectiveOverride ?? profile.objective}.');
    if (targetDuration != null) {
      buffer.writeln('Cada sessão deve ter duração aproximada de $targetDuration minutos (incluindo aquecimento e alongamento quando pertinente).');
    }
    buffer.writeln('Inclua progressão gradual e ajuste para as restrições informadas.');
    if (customRequest != null && customRequest.trim().isNotEmpty) {
      buffer.writeln('Solicitação específica do usuário: $customRequest');
    }
  buffer.writeln('Retorne apenas JSON válido com a estrutura:');
  buffer.writeln('{"treino":[{"dia":"Segunda","grupo_muscular":"Peito e Tríceps","exercicios":[{"nome":"Supino Reto","series":4,"reps":10,"carga_sugerida":40}]}]}');

    return buffer.toString();
  }

  String _formatDelta(double value) {
    if (value == 0) {
      return '0';
    }
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }
}
