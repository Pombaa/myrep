import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initializationSettings);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleEvaluationReminder(DateTime lastAssessment) async {
    await initialize();
    var scheduleAt = lastAssessment.add(const Duration(days: 90));
    if (!scheduleAt.isAfter(DateTime.now())) {
      scheduleAt = DateTime.now().add(const Duration(minutes: 5));
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'fitai_reminders',
        'Lembretes FitAI',
        channelDescription: 'Notificações para avaliações físicas e treinos.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      1001,
      'Hora da avaliação física',
      'Atualize suas medidas para manter os treinos personalizados.',
      tz.TZDateTime.from(scheduleAt, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelEvaluationReminder() async {
    await initialize();
    await _plugin.cancel(1001);
  }

  Future<void> showImmediate({required String title, required String body}) async {
    await initialize();
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'fitai_immediate',
        'Alertas FitAI',
        channelDescription: 'Alertas imediatos do FitAI Trainer.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, notificationDetails);
  }
}
