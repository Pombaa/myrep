class AiInteraction {
  const AiInteraction({
    this.id,
    required this.createdAt,
    required this.prompt,
    required this.response,
    this.metadata,
  });

  final int? id;
  final DateTime createdAt;
  final String prompt;
  final String response;
  final String? metadata;

  AiInteraction copyWith({
    int? id,
    DateTime? createdAt,
    String? prompt,
    String? response,
    String? metadata,
  }) {
    return AiInteraction(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      prompt: prompt ?? this.prompt,
      response: response ?? this.response,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'prompt': prompt,
      'response': response,
      'metadata': metadata,
    };
  }

  factory AiInteraction.fromMap(Map<String, Object?> map) {
    return AiInteraction(
      id: map['id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      prompt: map['prompt'] as String,
      response: map['response'] as String,
      metadata: map['metadata'] as String?,
    );
  }
}
