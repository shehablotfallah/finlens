import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/categories.dart';
import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';
import '../common/inline_error_banner.dart';

/// Bottom-sheet used for both quick-add and edit of a transaction.
///
/// FORM STATE ISOLATION (CRITICAL FIX):
/// When the user switches between Expense and Income, the form state
/// is FULLY RESET — the category, amount, note, and all other fields
/// are cleared so that Expense and Income drafts do NOT contaminate
/// each other. The only exception is the `prefill` (edit mode), where
/// we're editing an existing transaction and want to preserve its values.
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
  late DateTime _date;
  late String? _categoryId; // null = not selected (required)
  late String _currency;
  late bool _recurring;
  late RecurrenceInterval _interval;
  late int _customDays;
  late int _reminderDays;

  bool _isEdit = false;
  bool _saving = false;
  String? _amountError;
  String? _categoryError;
  String? _dbError;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _isEdit = p?.id.isNotEmpty == true;
    _type = p?.type ?? TransactionType.expense;
    _amountCtrl = TextEditingController(
        text: p?.amount == 0 || p?.amount == null ? '' : p!.amount.toString());
    _noteCtrl = TextEditingController(text: p?.note ?? '');
    _date = p?.date ?? DateTime.now();
    // Category: if editing an existing transaction, use its category.
    // If creating a new one, start with NO category selected (null)
    // so the user must explicitly choose one — category is REQUIRED.
    _categoryId = p?.categoryId;
    _currency = p?.currency ?? 'EGP';
    _recurring = p?.isRecurring ?? false;
    _interval = p?.recurrenceInterval ?? RecurrenceInterval.monthly;
    _customDays = p?.recurrenceCustomDays ?? 14;
    _reminderDays =
        p?.reminderDaysBefore ?? AppConstants.defaultReminderDaysBefore;
    _amountCtrl.addListener(() {
      if (_amountError != null && _amountCtrl.text.trim().isNotEmpty) {
        setState(() => _amountError = null);
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Switches between Expense and Income with FULL STATE RESET.
  ///
  /// This is the fix for the form state leak bug. When switching types:
  ///   - Category is reset to null (must re-select)
  ///   - Amount is cleared
  ///   - Note is cleared
  ///   - Recurring is reset to false
  ///   - Date stays (reasonable)
  ///   - Currency stays (reasonable)
  void _switchType(TransactionType newType) {
    if (_type == newType) return;
    if (_isEdit) return; // Don't reset when editing
    setState(() {
      _type = newType;
      _categoryId = null;
      _amountCtrl.clear();
      _noteCtrl.clear();
      _recurring = false;
      _amountError = null;
      _categoryError = null;
      _dbError = null;
    });
  }

  bool _isFormValid() {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    final amountValid = raw.isNotEmpty && amount != null && amount > 0;
    final categoryValid = _categoryId != null && _categoryId!.isNotEmpty;
    return amountValid && categoryValid;
  }

  bool _validate(AppLocalizations l) {
    bool valid = true;
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (raw.isEmpty) {
      setState(() => _amountError = l.errorAmountRequired);
      valid = false;
    } else if (amount == null || amount <= 0) {
      setState(() => _amountError = l.errorAmountInvalid);
      valid = false;
    } else {
      setState(() => _amountError = null);
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      setState(() => _categoryError = l.errorCategoryRequired);
      valid = false;
    } else {
      setState(() => _categoryError = null);
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
      final amount = double.parse(_amountCtrl.text.trim());
      final settings = ref.read(appSettingsProvider);
      final rateProv = ref.read(exchangeRateProvider);
      rateProv.setInitialRate('USD', settings.usdToEgpRate);
      final rate = await rateProv.rateFor(_currency);
      final base = _currency == 'EGP' ? amount : amount * rate;

      final tx = Transaction(
        id: widget.prefill?.id ?? const Uuid().v4(),
        type: _type,
        amount: amount,
        currency: _currency,
        amountInBase: base,
        exchangeRateAtTime: rate,
        categoryId: _categoryId!,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        isRecurring: _recurring,
        recurrenceInterval: _recurring ? _interval : null,
        recurrenceCustomDays:
            _recurring && _interval == RecurrenceInterval.custom
                ? _customDays
                : null,
        reminderDaysBefore: _recurring ? _reminderDays : null,
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
          final id = tx.hashCode & 0x7FFFFFFF;
          await notif.scheduleBillReminder(
            id: id,
            title:
                '${_type == TransactionType.expense ? l.txTypeExpense : l.txTypeIncome} • ${Format.money(tx.amount, tx.currency)}',
            body: tx.note ?? '',
            dueDate: tx.date,
            daysBefore: tx.reminderDaysBefore ?? 2,
          );
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
                      errorText: _amountError,
                    ),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: InputDecoration(labelText: l.commonCurrency),
                    items: const [
                      DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _currency = v!),
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
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _categoryError!,
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
                final selected = c.id == _categoryId;
                return ChoiceChip(
                  label: Text(_categoryLabel(l, c.id)),
                  avatar: Icon(c.icon, color: c.colorValue, size: 18),
                  selected: selected,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                            _categoryId = c.id;
                            _categoryError = null;
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
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.commonDate,
                  prefixIcon: const Icon(LucideIcons.calendar),
                ),
                child: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _recurring,
              onChanged: _saving ? null : (v) => setState(() => _recurring = v),
              title: Text(l.txRecurringLabel),
            ),
            if (_recurring) ...[
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
                selected: {_interval},
                onSelectionChanged:
                    _saving ? null : (s) => setState(() => _interval = s.first),
              ),
              if (_interval == RecurrenceInterval.custom) ...[
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: '$_customDays',
                  decoration: InputDecoration(labelText: l.txIntervalCustom),
                  keyboardType: TextInputType.number,
                  enabled: !_saving,
                  onChanged: (v) =>
                      _customDays = int.tryParse(v) ?? _customDays,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(l.txReminderDays)),
                  DropdownButton<int>(
                    value: _reminderDays,
                    items: [0, 1, 2, 3, 5, 7]
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d'),
                            ))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _reminderDays = v ?? 2),
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
