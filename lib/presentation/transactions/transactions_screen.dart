import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';
import '../common/skeleton.dart';
import 'transaction_edit_sheet.dart';

/// Explicit filter enum so PopupMenuButton never receives `null`
/// (which Flutter treats as menu dismissal/cancellation).
enum TransactionFilter {
  all,
  expense,
  income,
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionFilter _filter = TransactionFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      if (!settings.hintsShown.contains(AppConstants.hintTxSwipe)) {
        _showHint(AppConstants.hintTxSwipe);
      }
    });
  }

  void _showHint(String key) {
    final l = AppLocalizations.of(context);
    final message = switch (key) {
      AppConstants.hintTxSwipe => l.hintSwipeRow,
      _ => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l.hintDismiss,
          onPressed: () async {
            await ref.read(appSettingsProvider.notifier).markHintShown(key);
          },
        ),
      ),
    );
    ref.read(appSettingsProvider.notifier).markHintShown(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repoAsync = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTransactions),
        actions: [
          PopupMenuButton<TransactionFilter>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: TransactionFilter.all,
                child: Row(
                  children: [
                    Icon(LucideIcons.layoutGrid,
                        size: 18,
                        color: _filter == TransactionFilter.all
                            ? theme.colorScheme.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(l.commonAll),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TransactionFilter.expense,
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowDownLeft,
                        size: 18,
                        color: _filter == TransactionFilter.expense
                            ? theme.colorScheme.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(l.txTypeExpense),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TransactionFilter.income,
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowUpRight,
                        size: 18,
                        color: _filter == TransactionFilter.income
                            ? theme.colorScheme.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(l.txTypeIncome),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (repo) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: SegmentedButton<TransactionFilter>(
                    segments: [
                      ButtonSegment(
                        value: TransactionFilter.all,
                        label: Text(l.commonAll),
                        icon: const Icon(LucideIcons.layoutGrid, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionFilter.expense,
                        label: Text(l.txTypeExpense),
                        icon: const Icon(LucideIcons.arrowDownLeft, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionFilter.income,
                        label: Text(l.txTypeIncome),
                        icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                ),
                Expanded(
                  child: _TransactionList(
                    repo: repo,
                    filter: _filter,
                    currency: ref.watch(appSettingsProvider).baseCurrency,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const TransactionEditSheet(),
        ),
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}

/// Separate widget for the transaction list.
///
/// The StreamBuilder subscribes to `repo.watchAll()` in initState
/// and does NOT re-subscribe when the filter changes. This preserves
/// cached stream data and ensures instant, glitch-free filtering.
class _TransactionList extends ConsumerStatefulWidget {
  const _TransactionList({
    required this.repo,
    required this.filter,
    required this.currency,
  });

  final dynamic repo;
  final TransactionFilter filter;
  final String currency;

  @override
  ConsumerState<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends ConsumerState<_TransactionList> {
  late Stream<List<Transaction>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.repo.watchAll();
  }

  @override
  void didUpdateWidget(covariant _TransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repo != widget.repo) {
      _stream = widget.repo.watchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return StreamBuilder<List<Transaction>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 6,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (_, __) => const TransactionSkeletonRow(),
          );
        }
        var list = snap.data!;
        if (widget.filter == TransactionFilter.expense) {
          list = list.where((t) => t.type == TransactionType.expense).toList();
        } else if (widget.filter == TransactionFilter.income) {
          list = list.where((t) => t.type == TransactionType.income).toList();
        }
        list.sort((a, b) => b.date.compareTo(a.date));
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.receipt,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text(l.homeNoTransactionsYet,
                    style: theme.textTheme.bodyLarge),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final t = list[i];
            return _SwipeableTxRow(
              tx: t,
              currency: widget.currency,
              onEdit: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => TransactionEditSheet(prefill: t),
                );
              },
              onDelete: () async {
                final confirmed = await _confirmDelete(context);
                if (confirmed == true) {
                  await widget.repo.delete(t.id);
                  if (t.isRecurring) {
                    try {
                      final notif = ref.read(notificationServiceProvider);
                      await notif.cancelReminder(t.hashCode & 0x7FFFFFFF);
                      final notifRepo =
                          await ref.read(notificationRepositoryProvider.future);
                      await notifRepo.delete('bill_${t.id}');
                    } catch (_) {}
                  }
                  ref.invalidate(statsRepositoryProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.txDeleted)),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.txDeleteConfirm),
        content: Text(l.txDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: FinlensColors.expense),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
  }
}

class _SwipeableTxRow extends StatelessWidget {
  const _SwipeableTxRow({
    required this.tx,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });
  final Transaction tx;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final isIncome = tx.type == TransactionType.income;
    final cat = PredefinedCategories.byId(tx.categoryId);
    final color = cat?.colorValue ?? FinlensColors.neutral;
    return Dismissible(
      key: ValueKey(tx.id),
      background: Container(
        color: FinlensColors.income,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(LucideIcons.pencil, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: FinlensColors.expense,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            cat?.icon ?? LucideIcons.circle,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          Format.money(tx.amountInBase, currency),
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          '${_categoryLabel(l, tx.categoryId)} • ${Format.date(tx.date)}'
          '${tx.isRecurring ? '  🔁' : ''}'
          '${tx.note != null && tx.note!.isNotEmpty ? ' • ${tx.note}' : ''}',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${Format.moneyShort(tx.amountInBase, currency)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isIncome ? FinlensColors.income : FinlensColors.expense,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onEdit,
      ),
    );
  }

  String _categoryLabel(AppLocalizations l, String id) {
    return switch (id) {
      'food' => l.txCategoryFood,
      'transport' => l.txCategoryTransport,
      'bills' => l.txCategoryBills,
      'entertainment' => l.txCategoryEntertainment,
      'shopping' => l.txCategoryShopping,
      'health' => l.txCategoryHealth,
      'education' => l.txCategoryEducation,
      'salary' => l.txCategorySalary,
      'freelance' => l.txCategoryFreelance,
      'investment_return' => l.txCategoryInvestmentReturn,
      'other' => l.txCategoryOther,
      _ => id,
    };
  }
}
