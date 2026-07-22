import 'package:flutter/services.dart';

class WorkoutForegroundService {
  static const _channel = MethodChannel('com.example.treinai/workout_service');
  
  Function()? onCompleteSet;
  Function()? onStopRest;
  Function()? onRestComplete;
  Function()? onWorkoutCancelled;
  
  WorkoutForegroundService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCompleteSet':
        onCompleteSet?.call();
        break;
      case 'onStopRest':
        onStopRest?.call();
        break;
      case 'onRestComplete':
        onRestComplete?.call();
        break;
      case 'onWorkoutCancelled':
        onWorkoutCancelled?.call();
        break;
    }
  }
  
  Future<void> startService({
    required String title,
    required String content,
    required bool isResting,
  }) async {
    try {
      await _channel.invokeMethod('startService', {
        'title': title,
        'content': content,
        'isResting': isResting,
      });
    } catch (e) {
      print('Erro ao iniciar serviço: $e');
    }
  }
  
  Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopService');
    } catch (e) {
      print('Erro ao parar serviço: $e');
    }
  }
  
  Future<void> updateNotification({
    required String title,
    required String content,
    required bool isResting,
  }) async {
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'content': content,
        'isResting': isResting,
      });
    } catch (e) {
      print('Erro ao atualizar notificação: $e');
    }
  }
  
  Future<void> startRestTimer({
    required int seconds,
    required String exerciseName,
    required int currentSet,
    required int totalSets,
  }) async {
    try {
      await _channel.invokeMethod('startRestTimer', {
        'seconds': seconds,
        'exerciseName': exerciseName,
        'currentSet': currentSet,
        'totalSets': totalSets,
      });
    } catch (e) {
      print('Erro ao iniciar timer: $e');
    }
  }
}
