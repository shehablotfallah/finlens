import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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
/// Uses flutter_local_notifications for scheduling + permission_handler
/// for requesting the POST_NOTIFICATIONS permission on Android 13+.
/// NO push notifications, NO server component — all reminders are
/// scheduled locally on the device.
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
    // Create the notification channel on Android. Some OEMs (Realme,
    // OPPO, Xiaomi) require a channel to exist before the permission
    // dialog can be shown.
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
        'finlens_bills_channel',
        'Bill reminders',
        description: 'Reminders for upcoming bills',
        importance: Importance.high,
      ));
    }
    _initialized = true;
  }

  /// Requests notification permission using `permission_handler` (which
  /// properly handles the Android 13+ POST_NOTIFICATIONS runtime
  /// permission, including the "permanently denied" state on OEMs like
  /// Realme/OPPO/Xiaomi).
  Future<NotificationPermissionResult> requestPermission() async {
    await init();
    if (!Platform.isAndroid && !Platform.isIOS) {
      return NotificationPermissionResult.granted;
    }
    try {
      // Use permission_handler for a more robust permission request.
      // flutter_local_notifications' built-in requestNotificationsPermission()
      // doesn't handle the "permanently denied" state correctly on some OEMs.
      final status = await Permission.notification.request();
      switch (status) {
        case PermissionStatus.granted:
        case PermissionStatus.limited:
          return NotificationPermissionResult.granted;
        case PermissionStatus.permanentlyDenied:
          return NotificationPermissionResult.permanentlyDenied;
        case PermissionStatus.denied:
        case PermissionStatus.restricted:
        case PermissionStatus.provisional:
          return NotificationPermissionResult.denied;
      }
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

  /// Opens the Android notification settings for this app.
  /// Used when the user has permanently denied notification permission.
  Future<void> openNotificationSettings() async {
    await openAppSettings();
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
