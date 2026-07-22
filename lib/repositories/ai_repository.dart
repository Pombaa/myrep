import '../models/ai_interaction.dart';
import '../services/database_service.dart';

class AiRepository {
  AiRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<AiInteraction> saveInteraction(AiInteraction interaction) async {
    final id = await _databaseService.insert('ai_interactions', interaction.toMap());
    return interaction.copyWith(id: id);
  }

  Future<List<AiInteraction>> fetchHistory({int limit = 20}) async {
    final rows = await _databaseService.query(
      'ai_interactions',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AiInteraction.fromMap).toList();
  }
}
