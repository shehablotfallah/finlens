import 'package:drift/drift.dart';
import 'package:finlens/domain/entities/app_notification.dart' as domain;

import '../datasources/local/finlens_database.dart';

/// Drift-backed repository for in-app notifications.
class NotificationRepositoryImpl {
  NotificationRepositoryImpl(this._db);
  final FinlensDatabase _db;

  Stream<List<domain.AppNotification>> watchAll() {
    return (_db.select(_db.appNotifications)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  Stream<int> watchUnreadCount() {
    return (_db.selectOnly(_db.appNotifications)
          ..addColumns([_db.appNotifications.id.count()])
          ..where(_db.appNotifications.isRead.equals(false)))
        .watch()
        .map((rows) {
      final result = rows.first.read(_db.appNotifications.id.count());
      return result ?? 0;
    });
  }

  Future<void> insert(domain.AppNotification notification) async {
    await _db.into(_db.appNotifications).insertOnConflictUpdate(
          AppNotificationsCompanion(
            id: Value(notification.id),
            type: Value(_typeToString(notification.type)),
            title: Value(notification.title),
            body: Value(notification.body),
            createdAt: Value(notification.createdAt),
            isRead: Value(notification.isRead),
            payload: Value(notification.payload),
          ),
        );
  }

  Future<void> markAsRead(String id) async {
    await (_db.update(_db.appNotifications)
          ..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(isRead: const Value(true)));
  }

  Future<void> markAsUnread(String id) async {
    await (_db.update(_db.appNotifications)
          ..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(isRead: const Value(false)));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.appNotifications)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> markAllAsRead() async {
    await (_db.update(_db.appNotifications)
          ..where((t) => t.isRead.equals(false)))
        .write(AppNotificationsCompanion(isRead: const Value(true)));
  }

  domain.AppNotification _toDomain(AppNotification row) {
    return domain.AppNotification(
      id: row.id,
      type: _stringToType(row.type),
      title: row.title,
      body: row.body,
      createdAt: row.createdAt,
      isRead: row.isRead,
      payload: row.payload,
    );
  }

  String _typeToString(domain.NotificationType type) {
    switch (type) {
      case domain.NotificationType.billReminder:
        return 'bill_reminder';
      case domain.NotificationType.insight:
        return 'insight';
      case domain.NotificationType.general:
        return 'general';
    }
  }

  domain.NotificationType _stringToType(String type) {
    switch (type) {
      case 'bill_reminder':
        return domain.NotificationType.billReminder;
      case 'insight':
        return domain.NotificationType.insight;
      default:
        return domain.NotificationType.general;
    }
  }

}
