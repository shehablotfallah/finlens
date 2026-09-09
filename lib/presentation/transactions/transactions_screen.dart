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
import 'transaction_edit_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _filterType;

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
          PopupMenuButton<TransactionType?>(
            icon: const Icon(LucideIcons.filter),
            onSelected: (v) => setState(() => _filterType = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(LucideIcons.layoutGrid,
                        size: 18,
                        color: _filterType == null
                            ? theme.colorScheme.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(l.commonAll),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TransactionType.expense,
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowDownLeft,
                        size: 18,
                        color: _filterType == TransactionType.expense
                            ? theme.colorScheme.primary
                            : null),
                    const SizedBox(width: 8),
                    Text(l.txTypeExpense),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TransactionType.income,
                child: Row(
                  children: [
                    Icon(LucideIcons.arrowUpRight,
                        size: 18,
                        color: _filterType == TransactionType.income
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
            // CRITICAL FIX: The StreamBuilder must NOT be recreated
            // on every setState. Extract it into a separate widget
            // that receives the filter as a parameter.
            return _TransactionList(
              repo: repo,
              filterType: _filterType,
              currency: ref.watch(appSettingsProvider).baseCurrency,
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
/// The StreamBuilder subscribes to `repo.watchAll()` ONCE in initState
/// and does NOT re-subscribe when the filter changes. This fixes the
/// "All" filter bug where switching back to All showed an empty list.
class _TransactionList extends StatefulWidget {
  const _TransactionList({
    required this.repo,
    required this.filterType,
    required this.currency,
  });

  final dynamic repo;
  final TransactionType? filterType;
  final String currency;

  @override
  State<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<_TransactionList> {
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
          return const Center(child: CircularProgressIndicator());
        }
        var list = snap.data!;
        if (widget.filterType != null) {
          list = list.where((t) => t.type == widget.filterType).toList();
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
