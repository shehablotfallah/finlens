import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final settings = ref.watch(appSettingsProvider);
    final repoAsync = ref.watch(transactionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navTransactions),
        actions: [
          PopupMenuButton<TransactionType?>(
            icon: const Icon(Icons.filter_list_outlined),
            onSelected: (v) => setState(() => _filterType = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: null, child: Text(l.commonAll)),
              PopupMenuItem(value: TransactionType.expense, child: Text(l.txTypeExpense)),
              PopupMenuItem(value: TransactionType.income, child: Text(l.txTypeIncome)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (repo) {
            return StreamBuilder<List<Transaction>>(
              stream: repo.watchAll(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var list = snap.data!;
                if (_filterType != null) {
                  list = list.where((t) => t.type == _filterType).toList();
                }
                list.sort((a, b) => b.date.compareTo(a.date));
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
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
                      currency: settings.baseCurrency,
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
                          await repo.delete(t.id);
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
        child: const Icon(Icons.add),
      ),
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

/// A row that supports swipe (start and end) to reveal edit / delete actions.
/// Direction of swipe mirrors in RTL: in Arabic, "leading" is right-to-left
/// because the entire layout direction flips.
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
    final color = (PredefinedCategories.byId(tx.categoryId)?.colorValue ?? FinlensColors.neutral);
    return Dismissible(
      key: ValueKey(tx.id),
      background: Container(
        color: FinlensColors.income,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: FinlensColors.expense,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // Don't actually dismiss — opening edit
        } else {
          onDelete();
          return false; // We handle delete manually with confirmation
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            PredefinedCategories.byId(tx.categoryId)?.icon ?? Icons.category,
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
      'other' => l.txCategoryOther,
      _ => id,
    };
  }
}
