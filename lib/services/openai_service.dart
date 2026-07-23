import 'dart:convert';

import 'package:dio/dio.dart';

class OpenAiException implements Exception {
  const OpenAiException(this.message);
  final String message;

  @override
  String toString() => 'OpenAiException: $message';
}

class OpenAiService {
  OpenAiService([Dio? client]) : _client = client ?? _createDefaultClient();

  final Dio _client;

  static Dio _createDefaultClient() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        // NVIDIA / modelos grandes podem demorar mais que 60s.
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  Future<String> generateWorkoutPlan({
    required String apiKey,
    required List<Map<String, String>> messages,
    String model = 'gpt-4o-mini',
    double temperature = 0.4,
    String baseUrl = 'https://api.openai.com/v1/chat/completions',
    bool useStructuredOutput = true,
    /// Shown in user-facing errors (e.g. OpenAI, NVIDIA).
    String providerLabel = 'IA',
  }) async {
    try {
      final body = <String, dynamic>{
        'model': model,
        'messages': messages,
        'temperature': temperature,
      };

      // Structured JSON schema is OpenAI-specific. NVIDIA and others often
      // hang or fail with response_format — rely on the prompt instead.
      if (useStructuredOutput) {
        body['response_format'] = {
          'type': 'json_schema',
          'json_schema': {
            'name': 'workout_plan_schema',
            'schema': {
              'type': 'object',
              'required': ['mensagem', 'treino'],
              'additionalProperties': false,
              'properties': {
                'mensagem': {'type': 'string'},
                'treino': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'required': ['dia', 'grupo_muscular', 'exercicios'],
                    'properties': {
                      'dia': {'type': 'string'},
                      'grupo_muscular': {'type': 'string'},
                      'foco': {'type': 'string'},
                      'exercicios': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'required': ['nome', 'series', 'reps'],
                          'properties': {
                            'nome': {'type': 'string'},
                            'series': {'type': 'integer'},
                            'reps': {'type': 'integer'},
                            'carga_sugerida': {'type': 'number'},
                            'observacoes': {'type': 'string'},
                            'exercicio_substituto': {'type': 'string'},
                            'tecnica': {'type': 'string'},
                            'tempo_excentrica': {'type': 'integer'},
                            'tempo_concentrica': {'type': 'integer'},
                            'descanso_entre_series': {'type': 'integer'},
                            'exercicios_combinados': {
                              'type': 'array',
                              'items': {'type': 'string'},
                            },
                          },
                        },
                      },
                    },
                  },
                },
                'sugestao_lembrete': {
                  'type': 'object',
                  'required': ['conteudo', 'categoria'],
                  'properties': {
                    'conteudo': {'type': 'string'},
                    'categoria': {
                      'type': 'string',
                      'enum': [
                        'injury',
                        'preference',
                        'equipment',
                        'schedule',
                        'other'
                      ],
                    },
                  },
                },
              },
            },
          },
        };
      }

      final response = await _client.post<Map<String, dynamic>>(
        baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(body),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 400 &&
          response.statusCode! < 500) {
        final apiMessage = response.data is Map<String, dynamic>
            ? (response.data!['error']?['message'] as String?)
            : null;
        throw OpenAiException(
          apiMessage ??
              'Erro ${response.statusCode} na API $providerLabel. Verifique a chave e o modelo.',
        );
      }

      final choices = response.data?['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw OpenAiException('Resposta da $providerLabel vazia.');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content is String) {
        return _stripMarkdownFences(content.trim());
      }

      throw OpenAiException('Formato de resposta inesperado ($providerLabel).');
    } on OpenAiException {
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw OpenAiException(
          'Chave da API $providerLabel inválida. Verifique em Ajustes.',
        );
      } else if (error.response?.statusCode == 429) {
        throw OpenAiException(
          'Limite de requisições ($providerLabel) excedido. Tente de novo mais tarde.',
        );
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw OpenAiException(
          'Tempo esgotado na API $providerLabel. O modelo pode estar lento — tente de novo.',
        );
      } else if (error.type == DioExceptionType.connectionError) {
        throw OpenAiException(
          'Erro de conexão ($providerLabel): ${error.message ?? "desconhecido"}',
        );
      } else if (error.type == DioExceptionType.badCertificate) {
        throw const OpenAiException(
          'Erro de certificado SSL. Verifique a data/hora do dispositivo.',
        );
      } else if (error.type == DioExceptionType.unknown) {
        throw OpenAiException(
          'Erro de rede ($providerLabel): ${error.error?.toString() ?? error.message ?? "desconhecido"}',
        );
      }

      final message = error.response?.data is Map<String, dynamic>
          ? (error.response!.data['error']?['message'] as String? ??
              'Erro ao chamar a API $providerLabel')
          : 'Erro ao chamar a API $providerLabel';
      throw OpenAiException(message);
    } catch (error) {
      if (error is OpenAiException) rethrow;
      throw OpenAiException('Erro inesperado: ${error.toString()}');
    }
  }

  /// Removes ```json ... ``` wrappers some models add despite instructions.
  static String _stripMarkdownFences(String content) {
    var text = content.trim();
    final fence = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    );
    final match = fence.firstMatch(text);
    if (match != null) {
      text = match.group(1)!.trim();
    }
    return text;
  }
}
