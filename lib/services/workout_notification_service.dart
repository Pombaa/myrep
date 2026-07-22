import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WorkoutNotificationService {
  WorkoutNotificationService() {
    _init();
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'workout_session';
  static const String _channelName = 'Sessão de Treino';
  static const String _channelDescription =
      'Notificações para acompanhar o treino em andamento';

  Timer? _restTimer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  
  // Callbacks para ações da notificação
  VoidCallback? _onCompleteSet;
  VoidCallback? _onStopRest;
  VoidCallback? _onRestComplete;

  Future<void> _init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Canal para Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTap(NotificationResponse response) {
    final actionId = response.actionId;
    
    if (actionId == 'complete_set') {
      // Chama o callback sem abrir o app
      _onCompleteSet?.call();
    } else if (actionId == 'stop_rest') {
      stopRestTimer();
      _onStopRest?.call();
    }
  }

  /// Mostra notificação do exercício atual
  Future<void> showExerciseNotification({
    required String exerciseName,
    required int currentSet,
    required int totalSets,
    required int exerciseIndex,
    required int totalExercises,
    List<String>? combinedExercises,
    VoidCallback? onCompleteSet,
  }) async {
    _onCompleteSet = onCompleteSet;
    
    final title = 'Treino em andamento 💪';
    
    String body = 'Série $currentSet/$totalSets: $exerciseName';
    if (combinedExercises != null && combinedExercises.isNotEmpty) {
      body += '\n+ ${combinedExercises.join(", ")}';
    }
    body += '\nExercício ${exerciseIndex + 1}/$totalExercises';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'complete_set',
          '✓ Concluir série',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      details,
      payload: 'complete_exercise',
    );
  }

  /// Mostra notificação de descanso com timer
  Future<void> showRestNotification({
    required int seconds,
    required VoidCallback onRestComplete,
    VoidCallback? onStopRest,
  }) async {
    _onRestComplete = onRestComplete;
    _onStopRest = onStopRest;
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    
    await _updateRestNotification();

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _remainingSeconds--;

      if (_remainingSeconds <= 0) {
        timer.cancel();
        await _playAlarm();
        await _showRestCompleteNotification();
        _onRestComplete?.call();
      } else {
        await _updateRestNotification();
      }
    });
  }

  Future<void> _updateRestNotification() async {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: _totalSeconds > 0 ? (_remainingSeconds * 100 ~/ _totalSeconds).clamp(0, 100) : 0,
      actions: const [
        AndroidNotificationAction(
          'stop_rest',
          '⏹ Parar descanso',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Descanso ⏱️',
      timeStr,
      details,
      payload: 'rest_timer',
    );
  }

  Future<void> _playAlarm() async {
    final androidDetails = AndroidNotificationDetails(
      'workout_alarm',
      'Alarme de Treino',
      channelDescription: 'Alarme quando o descanso termina',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'alarm.aiff',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2,
      '⏰ Descanso concluído!',
      'Toque para continuar o treino',
      details,
    );
  }

  Future<void> _showRestCompleteNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'next_exercise',
          '▶️ Próximo exercício',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '✓ Descanso concluído!',
      'Pronto para o próximo exercício',
      details,
      payload: 'rest_complete',
    );
  }

  Future<void> showWorkoutCompleteNotification() async {
    _restTimer?.cancel();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '🎉 Treino concluído!',
      'Parabéns! Você completou o treino.',
      details,
    );

    // Remove a notificação após 3 segundos
    await Future.delayed(const Duration(seconds: 3));
    await cancelAll();
  }

  void stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  Future<void> cancelAll() async {
    _restTimer?.cancel();
    await _notifications.cancelAll();
  }

  void dispose() {
    _restTimer?.cancel();
  }
}
