import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_interaction.dart';
import 'repository_providers.dart';

final aiHistoryProvider = FutureProvider<List<AiInteraction>>((ref) async {
  final repository = ref.watch(aiRepositoryProvider);
  return repository.fetchHistory(limit: 50);
});
