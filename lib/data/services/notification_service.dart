import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Result of a notification permission request.
enum NotificationPermissionResult {
  /// Permission granted.
  granted,

  /// Permission denied (user can be asked again).
  denied,

  /// Permission permanently denied (user must open device settings).
  permanentlyDenied,
}

/// Notification service for bill reminders.
///
/// Uses flutter_local_notifications. NO push notifications, NO server
/// component — all reminders are scheduled locally on the device.
///
/// Permission model:
///   * On Android 13+ (API 33+), POST_NOTIFICATIONS is a runtime
///     permission. We request it at the appropriate UX moment
///     (when the user enables bill reminders or creates the first
///     recurring transaction), NOT on app startup.
///   * On Android 12 and below, no runtime permission is required.
///   * We track whether we've already asked (in SharedPreferences) so
///     we don't pester the user repeatedly.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
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
    _initialized = true;
  }

  /// Requests notification permission on Android 13+ / iOS. On Android
  /// 12 and below, this is a no-op (always granted at install time).
  ///
  /// Returns [NotificationPermissionResult.granted] if permission is
  /// already granted or was just granted; otherwise [denied] or
  /// [permanentlyDenied] (only meaningful on iOS — Android always
  /// allows re-prompting).
  Future<NotificationPermissionResult> requestPermission() async {
    await init();
    if (!Platform.isAndroid && !Platform.isIOS) {
      return NotificationPermissionResult.granted;
    }
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission() ??
            false;
        // On Android, requestNotificationsPermission returns false if
        // the user denied; the next call will show the prompt again
        // (Android allows repeated prompts).
        return granted
            ? NotificationPermissionResult.granted
            : NotificationPermissionResult.denied;
      }
      // iOS
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted
          ? NotificationPermissionResult.granted
          : NotificationPermissionResult.denied;
    } catch (_) {
      return NotificationPermissionResult.denied;
    }
  }

  /// Returns whether notifications are currently enabled at the OS level.
  Future<bool> areNotificationsEnabled() async {
    await init();
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Schedules a reminder N days before the due date.
  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
    required int daysBefore,
  }) async {
    await init();
    if (daysBefore <= 0) return;
    final trigger = dueDate.subtract(Duration(days: daysBefore));
    if (trigger.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(trigger, tz.local),
      _androidDetails,
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
