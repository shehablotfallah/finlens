import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification service for bill reminders.
///
/// Uses flutter_local_notifications. NO push notifications, NO server
/// component — all reminders are scheduled locally on the device.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onTap,
    );
  }

  /// Schedules a reminder N days before the due date.
  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
    required int daysBefore,
  }) async {
    if (daysBefore <= 0) return;
    final trigger = dueDate.subtract(Duration(days: daysBefore));
    if (trigger.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(trigger, tz.local),
      _androidDetails,
      // Schedule for next occurrence if it already passed
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  NotificationDetails get _androidDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          'finlens_bills_channel',
          'Bill reminders',
          channelDescription: 'Reminders for upcoming bills',
          importance: Importance.high,
          priority: Priority.high,
          // Subtle, non-disruptive default.
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      );

  void Function(NotificationResponse)? onTapHandler;

  void _onTap(NotificationResponse response) {
    debugPrint('[Notifications] tapped: ${response.payload}');
    onTapHandler?.call(response);
  }
}
