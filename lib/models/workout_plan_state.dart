import 'workout_chat_message.dart';
import 'workout_plan.dart';

class WorkoutPlanState {
  const WorkoutPlanState({
    this.plan,
    this.conversation = const [],
    this.basePrompt,
    this.isProcessing = false,
  });

  final WorkoutPlan? plan;
  final List<WorkoutChatMessage> conversation;
  final String? basePrompt;
  final bool isProcessing;

  WorkoutPlanState copyWith({
    WorkoutPlan? plan,
    List<WorkoutChatMessage>? conversation,
    String? basePrompt,
    bool? isProcessing,
  }) {
    return WorkoutPlanState(
      plan: plan ?? this.plan,
      conversation: conversation ?? this.conversation,
      basePrompt: basePrompt ?? this.basePrompt,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  static const empty = WorkoutPlanState();
}
