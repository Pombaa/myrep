const List<Map<String, String>> kExerciseLibrary = [
  // Peito
  {'name': 'Supino Reto', 'muscle': 'Peito'},
  {'name': 'Supino Inclinado', 'muscle': 'Peito'},
  {'name': 'Supino Declinado', 'muscle': 'Peito'},
  {'name': 'Crucifixo Reto', 'muscle': 'Peito'},
  {'name': 'Crucifixo Inclinado', 'muscle': 'Peito'},
  {'name': 'Crossover', 'muscle': 'Peito'},
  {'name': 'Flexão de Braços', 'muscle': 'Peito'},
  {'name': 'Peck Deck', 'muscle': 'Peito'},
  // Costas
  {'name': 'Puxada Frontal', 'muscle': 'Costas'},
  {'name': 'Puxada Supinada', 'muscle': 'Costas'},
  {'name': 'Remada Curvada', 'muscle': 'Costas'},
  {'name': 'Remada Unilateral', 'muscle': 'Costas'},
  {'name': 'Remada Máquina', 'muscle': 'Costas'},
  {'name': 'Pulldown com Corda', 'muscle': 'Costas'},
  {'name': 'Barra Fixa', 'muscle': 'Costas'},
  {'name': 'Levantamento Terra', 'muscle': 'Costas'},
  {'name': 'Serrote', 'muscle': 'Costas'},
  // Pernas
  {'name': 'Agachamento', 'muscle': 'Pernas'},
  {'name': 'Agachamento Hack', 'muscle': 'Pernas'},
  {'name': 'Leg Press', 'muscle': 'Pernas'},
  {'name': 'Extensora', 'muscle': 'Pernas'},
  {'name': 'Flexora Deitada', 'muscle': 'Pernas'},
  {'name': 'Flexora em Pé', 'muscle': 'Pernas'},
  {'name': 'Stiff', 'muscle': 'Pernas'},
  {'name': 'Avanço', 'muscle': 'Pernas'},
  {'name': 'Cadeira Adutora', 'muscle': 'Pernas'},
  {'name': 'Cadeira Abdutora', 'muscle': 'Pernas'},
  {'name': 'Agachamento Sumô', 'muscle': 'Pernas'},
  // Glúteo
  {'name': 'Hip Thrust', 'muscle': 'Glúteo'},
  {'name': 'Glúteo no Cabo', 'muscle': 'Glúteo'},
  {'name': 'Elevação Pélvica', 'muscle': 'Glúteo'},
  {'name': 'Agachamento Bulgaro', 'muscle': 'Glúteo'},
  // Ombro
  {'name': 'Desenvolvimento com Halteres', 'muscle': 'Ombro'},
  {'name': 'Desenvolvimento na Máquina', 'muscle': 'Ombro'},
  {'name': 'Desenvolvimento Militar', 'muscle': 'Ombro'},
  {'name': 'Elevação Lateral', 'muscle': 'Ombro'},
  {'name': 'Elevação Frontal', 'muscle': 'Ombro'},
  {'name': 'Remada Alta', 'muscle': 'Ombro'},
  {'name': 'Crucifixo Inverso', 'muscle': 'Ombro'},
  // Bíceps
  {'name': 'Rosca Direta', 'muscle': 'Bíceps'},
  {'name': 'Rosca Alternada', 'muscle': 'Bíceps'},
  {'name': 'Rosca Martelo', 'muscle': 'Bíceps'},
  {'name': 'Rosca Concentrada', 'muscle': 'Bíceps'},
  {'name': 'Rosca 21', 'muscle': 'Bíceps'},
  {'name': 'Rosca Scot', 'muscle': 'Bíceps'},
  {'name': 'Rosca com Cabo', 'muscle': 'Bíceps'},
  // Tríceps
  {'name': 'Tríceps Corda', 'muscle': 'Tríceps'},
  {'name': 'Tríceps Testa', 'muscle': 'Tríceps'},
  {'name': 'Tríceps Francês', 'muscle': 'Tríceps'},
  {'name': 'Tríceps Mergulho', 'muscle': 'Tríceps'},
  {'name': 'Tríceps no Cabo', 'muscle': 'Tríceps'},
  {'name': 'Extensão de Tríceps', 'muscle': 'Tríceps'},
  {'name': 'Supino Fechado', 'muscle': 'Tríceps'},
  // Panturrilha
  {'name': 'Panturrilha em Pé', 'muscle': 'Panturrilha'},
  {'name': 'Panturrilha Sentado', 'muscle': 'Panturrilha'},
  {'name': 'Panturrilha no Leg Press', 'muscle': 'Panturrilha'},
  // Abdômen
  {'name': 'Abdominal Crunch', 'muscle': 'Abdômen'},
  {'name': 'Prancha', 'muscle': 'Abdômen'},
  {'name': 'Elevação de Pernas', 'muscle': 'Abdômen'},
  {'name': 'Rotação Russa', 'muscle': 'Abdômen'},
  {'name': 'Abdominal na Polia', 'muscle': 'Abdômen'},
  {'name': 'Abdominal Infra', 'muscle': 'Abdômen'},
  // Cardio / Funcional
  {'name': 'Corrida na Esteira', 'muscle': 'Cardio'},
  {'name': 'Bicicleta Ergométrica', 'muscle': 'Cardio'},
  {'name': 'Elíptico', 'muscle': 'Cardio'},
  {'name': 'Burpee', 'muscle': 'Funcional'},
  {'name': 'Polichinelo', 'muscle': 'Funcional'},
  {'name': 'Mountain Climber', 'muscle': 'Funcional'},
];

String? muscleGroupForExercise(String exerciseName) {
  final lower = exerciseName.toLowerCase();
  for (final entry in kExerciseLibrary) {
    if (entry['name']!.toLowerCase() == lower) {
      return entry['muscle'];
    }
  }
  return null;
}

List<String> autocompleteExercises(String query) {
  if (query.trim().isEmpty) return [];
  final lower = query.toLowerCase();
  return kExerciseLibrary
      .where((e) => e['name']!.toLowerCase().contains(lower))
      .map((e) => e['name']!)
      .toList();
}

const List<String> kMuscleGroups = [
  'Peito',
  'Costas',
  'Pernas',
  'Glúteo',
  'Ombro',
  'Bíceps',
  'Tríceps',
  'Panturrilha',
  'Abdômen',
  'Funcional',
  'Cardio',
  'Peito e Tríceps',
  'Costas e Bíceps',
  'Pernas e Glúteo',
  'Membros Superiores',
  'Full Body',
];
