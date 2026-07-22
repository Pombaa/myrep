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
        receiveTimeout: const Duration(seconds: 60),
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
  }) async {
    try {
      final responseFormat = useStructuredOutput
          ? {
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
                          'enum': ['injury', 'preference', 'equipment', 'schedule', 'other'],
                        },
                      },
                    },
                  },
                },
              },
            }
          : {'type': 'json_object'};

      final response = await _client.post<Map<String, dynamic>>(
        baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'response_format': responseFormat,
        }),
      );

      final choices = response.data?['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const OpenAiException('Resposta da IA vazia.');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content is String) {
        return content.trim();
      }

      throw const OpenAiException('Formato de resposta inesperado.');
    } on DioException catch (error) {
      // Log detalhado do erro para debug
      print('DioException tipo: ${error.type}');
      print('DioException mensagem: ${error.message}');
      print('DioException response: ${error.response?.statusCode}');
      print('DioException error: ${error.error}');
      
      if (error.response?.statusCode == 401) {
        throw const OpenAiException('Chave da API OpenAI inválida. Verifique a chave nas configurações.');
      } else if (error.response?.statusCode == 429) {
        throw const OpenAiException('Limite de requisições excedido. Tente novamente mais tarde.');
      } else if (error.type == DioExceptionType.connectionTimeout || 
                 error.type == DioExceptionType.receiveTimeout ||
                 error.type == DioExceptionType.sendTimeout) {
        throw OpenAiException('Tempo esgotado (${error.type}). A API da OpenAI pode estar sobrecarregada. Tente novamente.');
      } else if (error.type == DioExceptionType.connectionError) {
        throw OpenAiException('Erro de conexão: ${error.message ?? "desconhecido"}');
      } else if (error.type == DioExceptionType.badCertificate) {
        throw const OpenAiException('Erro de certificado SSL. Verifique a data/hora do dispositivo.');
      } else if (error.type == DioExceptionType.unknown) {
        throw OpenAiException('Erro de rede: ${error.error?.toString() ?? error.message ?? "desconhecido"}');
      }
      
      final message = error.response?.data is Map<String, dynamic>
          ? (error.response!.data['error']?['message'] as String? ?? 'Erro ao chamar a API da OpenAI')
          : 'Erro ao chamar a API da OpenAI';
      throw OpenAiException(message);
    } catch (error) {
      throw OpenAiException('Erro inesperado: ${error.toString()}');
    }
  }
}
