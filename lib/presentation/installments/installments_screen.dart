import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/finlens_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/transaction.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/providers.dart';

class InstallmentsScreen extends ConsumerStatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  ConsumerState<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends ConsumerState<InstallmentsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repoAsync = ref.watch(installmentPlanRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.installmentsTitle)),
      body: SafeArea(
        child: repoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l.commonError)),
          data: (repo) {
            return StreamBuilder(
              stream: repo.watchAll(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final plans = snap.data!;
                if (plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(l.installmentsEmpty, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = plans[i];
                    final progress = p.installmentCount == 0
                        ? 0.0
                        : p.paidCount / p.installmentCount;
                    final nextDue = p.nextDueDate;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.providerName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  Format.money(p.remainingAmount, p.currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: FinlensColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.installmentsPaid(p.paidCount, p.installmentCount),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.event_outlined,
                                    size: 16, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${l.installmentsNextDue}: ${DateFormat.yMMMd().format(nextDue)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                if (!p.isComplete)
                                  TextButton.icon(
                                    onPressed: () async {
                                      await repo.markInstallmentPaid(p.id);
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: Text(l.installmentsMarkPaid),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(context),
        icon: const Icon(Icons.add),
        label: Text(l.installmentsAdd),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _InstallmentAddSheet(),
    );
  }
}

class _InstallmentAddSheet extends ConsumerStatefulWidget {
  const _InstallmentAddSheet();

  @override
  ConsumerState<_InstallmentAddSheet> createState() =>
      _InstallmentAddSheetState();
}

class _InstallmentAddSheetState extends ConsumerState<_InstallmentAddSheet> {
  final _providerCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '12');
  final _intervalCtrl = TextEditingController(text: '30');
  DateTime _startDate = DateTime.now();
  String _currency = 'EGP';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _providerCtrl.dispose();
    _totalCtrl.dispose();
    _countCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final plan = InstallmentPlan(
      id: const Uuid().v4(),
      providerName: _providerCtrl.text.trim(),
      totalAmount: double.parse(_totalCtrl.text),
      currency: _currency,
      installmentCount: int.parse(_countCtrl.text),
      paidCount: 0,
      startDate: _startDate,
      intervalDays: int.parse(_intervalCtrl.text),
    );
    final repo = await ref.read(installmentPlanRepositoryProvider.future);
    await repo.insert(plan);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.txAdded)),
      );
      Navigator.pop(context);
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
      child: Form(
        key: _formKey,
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
              Text(l.installmentsAdd, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _providerCtrl,
                decoration: InputDecoration(
                  labelText: l.installmentsProvider,
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l.commonRequired : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _totalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.installmentsTotal,
                      ),
                      validator: (v) =>
                          (double.tryParse(v ?? '') ?? 0) <= 0
                              ? l.errorAmountInvalid
                              : null,
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
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.installmentsCount,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _intervalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.txIntervalCustom,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.commonDate,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_startDate),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(l.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
