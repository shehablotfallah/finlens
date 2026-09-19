import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';
import '../common/inline_error_banner.dart';

/// Draft container to guarantee strict form state isolation between Expense and Income.
class _TransactionDraft {
  String? categoryId;
  String amountText;
  String noteText;
  String currency;
  DateTime date;
  bool recurring;
  RecurrenceInterval interval;
  int customDays;
  int reminderDays;
  String? amountError;
  String? categoryError;

  _TransactionDraft({
    this.categoryId,
    this.amountText = '',
    this.noteText = '',
    this.currency = 'EGP',
    DateTime? date,
    this.recurring = false,
    this.interval = RecurrenceInterval.monthly,
    this.customDays = 14,
    this.reminderDays = AppConstants.defaultReminderDaysBefore,
    this.amountError,
    this.categoryError,
  }) : date = date ?? DateTime.now();
}

/// Bottom-sheet used for both quick-add and edit of a transaction.
///
/// FORM STATE ISOLATION:
/// Expense and Income maintain completely independent draft states.
/// Switching between Expense and Income preserves user input for both
/// without leaking selected categories, notes, amounts, or errors.
class TransactionEditSheet extends ConsumerStatefulWidget {
  const TransactionEditSheet({super.key, this.prefill});
  final Transaction? prefill;

  @override
  ConsumerState<TransactionEditSheet> createState() =>
      _TransactionEditSheetState();
}

class _TransactionEditSheetState extends ConsumerState<TransactionEditSheet> {
  late TransactionType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  late final _TransactionDraft _expenseDraft;
  late final _TransactionDraft _incomeDraft;

  bool _isEdit = false;
  bool _saving = false;
  String? _dbError;

  _TransactionDraft get _activeDraft =>
      _type == TransactionType.expense ? _expenseDraft : _incomeDraft;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _isEdit = p?.id.isNotEmpty == true;
    _type = p?.type ?? TransactionType.expense;

    final baseCurrency = ref.read(appSettingsProvider).baseCurrency;

    final initialAmount =
        p?.amount == 0 || p?.amount == null ? '' : p!.amount.toString();
    final initialNote = p?.note ?? '';
    final initialDate = p?.date ?? DateTime.now();
    final initialCategory = p?.categoryId;
    final initialCurrency = p?.currency ?? baseCurrency;
    final initialRecurring = p?.isRecurring ?? false;
    final initialInterval =
        p?.recurrenceInterval ?? RecurrenceInterval.monthly;
    final initialCustomDays = p?.recurrenceCustomDays ?? 14;
    final initialReminderDays =
        p?.reminderDaysBefore ?? AppConstants.defaultReminderDaysBefore;

    if (_type == TransactionType.expense) {
      _expenseDraft = _TransactionDraft(
        categoryId: initialCategory,
        amountText: initialAmount,
        noteText: initialNote,
        currency: initialCurrency,
        date: initialDate,
        recurring: initialRecurring,
        interval: initialInterval,
        customDays: initialCustomDays,
        reminderDays: initialReminderDays,
      );
      _incomeDraft = _TransactionDraft(
        currency: baseCurrency,
        date: DateTime.now(),
      );
    } else {
      _expenseDraft = _TransactionDraft(
        currency: baseCurrency,
        date: DateTime.now(),
      );
      _incomeDraft = _TransactionDraft(
        categoryId: initialCategory,
        amountText: initialAmount,
        noteText: initialNote,
        currency: initialCurrency,
        date: initialDate,
        recurring: initialRecurring,
        interval: initialInterval,
        customDays: initialCustomDays,
        reminderDays: initialReminderDays,
      );
    }

    _amountCtrl = TextEditingController(text: _activeDraft.amountText);
    _noteCtrl = TextEditingController(text: _activeDraft.noteText);

    _amountCtrl.addListener(() {
      _activeDraft.amountText = _amountCtrl.text;
      if (_activeDraft.amountError != null &&
          _amountCtrl.text.trim().isNotEmpty) {
        setState(() => _activeDraft.amountError = null);
      } else {
        setState(() {}); // refresh formValid state for Save button
      }
    });

    _noteCtrl.addListener(() {
      _activeDraft.noteText = _noteCtrl.text;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Switches between Expense and Income with independent draft isolation.
  ///
  /// Preserves the user's progress in both Expense and Income drafts.
  /// Category, amount, notes, and errors never contaminate each other.
  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    _activeDraft.amountText = _amountCtrl.text;
    _activeDraft.noteText = _noteCtrl.text;

    setState(() {
      _type = newType;
      _amountCtrl.text = _activeDraft.amountText;
      _noteCtrl.text = _activeDraft.noteText;
      _dbError = null;
    });
  }

  bool _isCategoryValid(String? catId, TransactionType type) {
    if (catId == null || catId.trim().isEmpty) return false;
    final list = type == TransactionType.expense
        ? PredefinedCategories.expenses
        : PredefinedCategories.incomes;
    return list.any((c) => c.id == catId);
  }

  bool _isFormValid() {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    final amountValid = raw.isNotEmpty && amount != null && amount > 0;
    final categoryValid = _isCategoryValid(_activeDraft.categoryId, _type);
    return amountValid && categoryValid;
  }

  bool _validate(AppLocalizations l) {
    bool valid = true;
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (raw.isEmpty) {
      setState(() => _activeDraft.amountError = l.errorAmountRequired);
      valid = false;
    } else if (amount == null || amount <= 0) {
      setState(() => _activeDraft.amountError = l.errorAmountInvalid);
      valid = false;
    } else {
      setState(() => _activeDraft.amountError = null);
    }

    if (!_isCategoryValid(_activeDraft.categoryId, _type)) {
      setState(() => _activeDraft.categoryError = l.errorCategoryRequired);
      valid = false;
    } else {
      setState(() => _activeDraft.categoryError = null);
    }
    return valid;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_saving) return;
    if (!_validate(l)) return;

    setState(() {
      _saving = true;
      _dbError = null;
    });

    try {
      final draft = _activeDraft;
      final amount = double.parse(_amountCtrl.text.trim());
      final settings = ref.read(appSettingsProvider);
      final rateProv = ref.read(exchangeRateProvider);
      rateProv.setInitialRate('USD', settings.usdToEgpRate);
      final rate = await rateProv.rateFor(draft.currency);
      final base = draft.currency == 'EGP' ? amount : amount * rate;

      final tx = Transaction(
        id: widget.prefill?.id ?? const Uuid().v4(),
        type: _type,
        amount: amount,
        currency: draft.currency,
        amountInBase: base,
        exchangeRateAtTime: rate,
        categoryId: draft.categoryId!,
        date: draft.date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        isRecurring: draft.recurring,
        recurrenceInterval: draft.recurring ? draft.interval : null,
        recurrenceCustomDays:
            draft.recurring && draft.interval == RecurrenceInterval.custom
                ? draft.customDays
                : null,
        reminderDaysBefore: draft.recurring ? draft.reminderDays : null,
        createdAt: widget.prefill?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = await ref.read(transactionRepositoryProvider.future);
      if (_isEdit) {
        await repo.update(tx);
      } else {
        await repo.insert(tx);
      }

      if (tx.isRecurring) {
        try {
          final notif = ref.read(notificationServiceProvider);
          // Request permission politely if not yet granted
          await notif.ensurePermissionWithDialog(context: context, l: l);
          final id = tx.hashCode & 0x7FFFFFFF;
          await notif.scheduleBillReminder(
            id: id,
            title:
                '${_type == TransactionType.expense ? l.txTypeExpense : l.txTypeIncome} • ${Format.money(tx.amount, tx.currency)}',
            body: tx.note ?? '',
            dueDate: tx.date,
            daysBefore: tx.reminderDaysBefore ?? 2,
          );
          // BUG-002: Persist in-app notification record with deterministic ID
          final notifRepo = await ref.read(notificationRepositoryProvider.future);
          await notifRepo.insert(
            AppNotification(
              id: 'bill_${tx.id}',
              type: NotificationType.billReminder,
              title:
                  '${_type == TransactionType.expense ? l.txTypeExpense : l.txTypeIncome} • ${Format.money(tx.amount, tx.currency)}',
              body: tx.note != null && tx.note!.isNotEmpty
                  ? tx.note!
                  : '${Format.date(tx.date)} • ${_categoryLabel(l, tx.categoryId)}',
              createdAt: DateTime.now(),
              isRead: false,
              payload: jsonEncode({
                'type': 'bill',
                'transactionId': tx.id,
                'dueDate': tx.date.toIso8601String(),
                'amount': tx.amount,
                'currency': tx.currency,
              }),
            ),
          );
        } catch (_) {}
      } else if (_isEdit && widget.prefill?.isRecurring == true) {
        // User disabled recurring on an existing transaction: clean up scheduled & in-app notification
        try {
          final notif = ref.read(notificationServiceProvider);
          await notif.cancelReminder(widget.prefill.hashCode & 0x7FFFFFFF);
          final notifRepo = await ref.read(notificationRepositoryProvider.future);
          await notifRepo.delete('bill_${widget.prefill!.id}');
        } catch (_) {}
      }

      ref.invalidate(statsRepositoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? l.txUpdated : l.txAdded)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbError = l.errorSaveTransactionBody);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    if (widget.prefill == null) return;

    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _dbError = null;
    });
    try {
      final repo = await ref.read(transactionRepositoryProvider.future);
      await repo.delete(widget.prefill!.id);
      if (widget.prefill!.isRecurring) {
        try {
          final notif = ref.read(notificationServiceProvider);
          await notif.cancelReminder(widget.prefill.hashCode & 0x7FFFFFFF);
          final notifRepo = await ref.read(notificationRepositoryProvider.future);
          await notifRepo.delete('bill_${widget.prefill!.id}');
        } catch (_) {}
      }
      ref.invalidate(statsRepositoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.txDeleted)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbError = l.errorSaveTransactionBody);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = _activeDraft;
    final formValid = _isFormValid();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? l.txTitleEdit : l.txTitleAdd,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                if (_isEdit)
                  IconButton(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(LucideIcons.trash2,
                        color: FinlensColors.expense),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l.txTypeExpense),
                  icon: const Icon(LucideIcons.arrowDownLeft),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l.txTypeIncome),
                  icon: const Icon(LucideIcons.arrowUpRight),
                ),
              ],
              selected: {_type},
              onSelectionChanged:
                  _saving ? null : (s) => _switchType(s.first),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l.commonAmount,
                      hintText: l.txHintAmount,
                      prefixIcon: const Icon(LucideIcons.wallet),
                      errorText: draft.amountError,
                    ),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: draft.currency,
                    decoration: InputDecoration(labelText: l.commonCurrency),
                    items: const [
                      DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => draft.currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Category selection — REQUIRED
            Row(
              children: [
                Text(l.commonCategory, style: theme.textTheme.bodySmall),
                const SizedBox(width: 4),
                Text('*',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
            ),
            if (draft.categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  draft.categoryError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_type == TransactionType.expense
                      ? PredefinedCategories.expenses
                      : PredefinedCategories.incomes)
                  .map((c) {
                final selected = c.id == draft.categoryId;
                return ChoiceChip(
                  label: Text(_categoryLabel(l, c.id)),
                  avatar: Icon(c.icon, color: c.colorValue, size: 18),
                  selected: selected,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                            draft.categoryId = c.id;
                            draft.categoryError = null;
                          }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l.commonNote,
                hintText: l.txHintNote,
                prefixIcon: const Icon(LucideIcons.fileText),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => draft.date = picked);
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.commonDate,
                  prefixIcon: const Icon(LucideIcons.calendar),
                ),
                child: Text(
                  '${draft.date.day}/${draft.date.month}/${draft.date.year}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: draft.recurring,
              onChanged:
                  _saving ? null : (v) => setState(() => draft.recurring = v),
              title: Text(l.txRecurringLabel),
            ),
            if (draft.recurring) ...[
              const SizedBox(height: 8),
              Text(l.txRecurringInterval, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              SegmentedButton<RecurrenceInterval>(
                segments: [
                  ButtonSegment(
                      value: RecurrenceInterval.weekly,
                      label: Text(l.txIntervalWeekly)),
                  ButtonSegment(
                      value: RecurrenceInterval.monthly,
                      label: Text(l.txIntervalMonthly)),
                  ButtonSegment(
                      value: RecurrenceInterval.custom,
                      label: Text(l.txIntervalCustom)),
                ],
                selected: {draft.interval},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => draft.interval = s.first),
              ),
              if (draft.interval == RecurrenceInterval.custom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('custom_days_${_type.name}'),
                  initialValue: '${draft.customDays}',
                  decoration: InputDecoration(labelText: l.txIntervalCustom),
                  keyboardType: TextInputType.number,
                  enabled: !_saving,
                  onChanged: (v) =>
                      draft.customDays = int.tryParse(v) ?? draft.customDays,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(l.txReminderDays)),
                  DropdownButton<int>(
                    value: draft.reminderDays,
                    items: [0, 1, 2, 3, 5, 7]
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d'),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => draft.reminderDays = v ?? 2),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (_dbError != null) ...[
              InlineErrorBanner(
                message: _dbError!,
                onRetry: _save,
                retryLabel: l.errorRetry,
                onDismiss: () => setState(() => _dbError = null),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: (_saving || !formValid) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.commonSave),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
