import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// SAVE FLOW (correct order):
///   1. Validate (amount > 0, currency set, category set)
///   2. Disable Save button (prevent duplicate submission)
///   3. Show inline loading on the Save button
///   4. Await repository write (DB INSERT/UPDATE)
///   5. On success → invalidate providers → snackbar → pop
///   6. On failure → keep user on form → re-enable Save → show localized error
///
/// CRITICAL: _saving is ALWAYS reset in a `finally` block so the UI
/// can never get stuck in a loading state, even if an unexpected
/// exception escapes.
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
  late String _categoryId;
  late String _currency;
  late bool _recurring;
  late RecurrenceInterval _interval;
  late int _customDays;
  late int _reminderDays;

  bool _isEdit = false;
  bool _saving = false;
  String? _amountError;
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
    _categoryId = p?.categoryId ??
        (_type == TransactionType.expense
            ? PredefinedCategories.expenses.first.id
            : PredefinedCategories.incomes.first.id);
    _currency = p?.currency ?? 'EGP';
    _recurring = p?.isRecurring ?? false;
    _interval = p?.recurrenceInterval ?? RecurrenceInterval.monthly;
    _customDays = p?.recurrenceCustomDays ?? 14;
    _reminderDays =
        p?.reminderDaysBefore ?? AppConstants.defaultReminderDaysBefore;
    // Clear amount error as the user types.
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

  /// Validates the form and returns true if it can be saved.
  bool _validate(AppLocalizations l) {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw);
    if (raw.isEmpty) {
      setState(() => _amountError = l.errorAmountRequired);
      return false;
    }
    if (amount == null || amount <= 0) {
      setState(() => _amountError = l.errorAmountInvalid);
      return false;
    }
    setState(() => _amountError = null);
    return true;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_saving) return; // Prevent duplicate submission
    if (!_validate(l)) return;

    // Clear any previous DB error.
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
        categoryId: _categoryId,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        isRecurring: _recurring,
        recurrenceInterval: _recurring ? _interval : null,
        recurrenceCustomDays: _recurring && _interval == RecurrenceInterval.custom
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

      // If recurring, schedule a reminder (best-effort; failure here
      // shouldn't fail the save).
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
        } catch (_) {
          // Notification scheduling failure is non-fatal.
        }
      }

      // Force refresh of any stream-based providers so the dashboard /
      // transactions list reflects the new row immediately.
      ref.invalidate(statsRepositoryProvider);

      if (mounted) {
        // Success → snackbar (lightweight transient feedback is OK here)
        // then navigate away.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? l.txUpdated : l.txAdded)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Database/validation failure → show INLINE error banner above
      // the Save button (NOT a transient SnackBar). The user stays on
      // the form with their data preserved so they can retry.
      if (mounted) {
        setState(() => _dbError = l.errorSaveTransactionBody);
      }
    } finally {
      // ALWAYS clear the loading state, even if an unexpected exception
      // escaped the try block. This prevents the UI from being stuck
      // in loading forever.
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
                    icon: const Icon(Icons.delete_outline,
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
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l.txTypeIncome),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _saving ? null : (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            // Amount + currency
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
                      prefixIcon: const Icon(Icons.attach_money),
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
            const SizedBox(height: 12),
            // Category grid
            Text(l.commonCategory, style: theme.textTheme.bodySmall),
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
                  onSelected: _saving ? null : (_) => setState(() => _categoryId = c.id),
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
                prefixIcon: const Icon(Icons.notes),
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
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
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
            // Inline error banner — shown only when a DB error occurs.
            // NOT a SnackBar: this stays visible until the user retries
            // or dismisses it.
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
              onPressed: _saving ? null : _save,
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
      'other' => l.txCategoryOther,
      _ => id,
    };
  }
}
