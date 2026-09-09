import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/finlens_theme.dart';
import '../../domain/entities/app_notification.dart' as domain;
import '../app/providers.dart';

/// Professional notifications screen.
///
/// Features:
///   - Reactive list of in-app notifications from the DB
///   - Unread items have a subtle background + blue dot
///   - Swipe right → mark as read/unread
///   - Swipe left → delete
///   - Empty state with meaningful illustration
///   - "Mark all as read" in AppBar
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final notifAsync = ref.watch(allNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifScreenTitle),
        actions: [
          notifAsync.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () async {
                      final repo = await ref
                          .read(notificationRepositoryProvider.future);
                      await repo.markAllAsRead();
                    },
                    child: Text(l.notifMarkAllRead),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: notifAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (notifications) {
            if (notifications.isEmpty) {
              return _EmptyState(theme: theme, l: l);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 64,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, i) {
                return _NotificationItem(
                  notification: notifications[i],
                  theme: theme,
                  l: l,
                  onMarkRead: () async {
                    final repo = await ref
                        .read(notificationRepositoryProvider.future);
                    await repo.markAsRead(notifications[i].id);
                  },
                  onMarkUnread: () async {
                    final repo = await ref
                        .read(notificationRepositoryProvider.future);
                    await repo.markAsUnread(notifications[i].id);
                  },
                  onDelete: () async {
                    final repo = await ref
                        .read(notificationRepositoryProvider.future);
                    await repo.delete(notifications[i].id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.notifDelete)),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme, required this.l});
  final ThemeData theme;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.bellOff,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l.notifScreenEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.theme,
    required this.l,
    required this.onMarkRead,
    required this.onMarkUnread,
    required this.onDelete,
  });

  final domain.AppNotification notification;
  final ThemeData theme;
  final AppLocalizations l;
  final VoidCallback onMarkRead;
  final VoidCallback onMarkUnread;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (notification.type) {
      case domain.NotificationType.billReminder:
        return LucideIcons.calendarClock;
      case domain.NotificationType.insight:
        return LucideIcons.sparkles;
      case domain.NotificationType.general:
        return LucideIcons.bell;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case domain.NotificationType.billReminder:
        return FinlensColors.warning;
      case domain.NotificationType.insight:
        return FinlensColors.primary;
      case domain.NotificationType.general:
        return FinlensColors.neutral;
    }
  }

  String get _typeLabel {
    switch (notification.type) {
      case domain.NotificationType.billReminder:
        return l.notifTypeBillReminder;
      case domain.NotificationType.insight:
        return l.notifTypeInsight;
      case domain.NotificationType.general:
        return l.notifTypeGeneral;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l.notifJustNow;
    if (diff.inMinutes < 60) return l.notifMinAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.notifHourAgo(diff.inHours);
    return l.notifDayAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Dismissible(
      key: ValueKey(notification.id),
      background: Container(
        color: FinlensColors.primary,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          isUnread ? LucideIcons.checkCheck : LucideIcons.mail,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: FinlensColors.expense,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (isUnread) {
            onMarkRead();
          } else {
            onMarkUnread();
          }
          return false;
        } else {
          return true;
        }
      },
      child: Container(
        color: isUnread
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  notification.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight:
                        isUnread ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsetsDirectional.only(start: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notification.body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _typeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${_formatTime(notification.createdAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            if (isUnread) onMarkRead();
          },
        ),
      ),
    );
  }
}
