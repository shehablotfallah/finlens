import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/transaction.dart';

/// Local export service — generates PDF / CSV files on-device and shares
/// them via the Android share sheet. No file leaves the device unless the
/// user explicitly chooses to share it.
class ExportService {
  ExportService();

  Future<File> exportTransactionsCsv({
    required List<Transaction> transactions,
    required String currency,
  }) async {
    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Category', 'Amount', 'Currency', 'Amount ($currency)', 'Note'],
      ...transactions.map((t) => [
            DateFormat('yyyy-MM-dd').format(t.date),
            t.type.name,
            t.categoryId,
            t.amount.toStringAsFixed(2),
            t.currency,
            t.amountInBase.toStringAsFixed(2),
            t.note ?? '',
          ]),
    ];
    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path,
        'finlens_export_${DateTime.now().millisecondsSinceEpoch}.csv'));
    await file.writeAsString(csvData);
    return file;
  }

  Future<File> exportReportPdf({
    required String title,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required double totalSpent,
    required double totalIncome,
    required Map<String, double> spentByCategory,
    required List<Transaction> transactions,
    required String currency,
    required String generatedBy,
  }) async {
    final pdf = pw.Document();

    final fmtDate = DateFormat('yyyy-MM-dd');
    final fmtMoney = NumberFormat('#,##0.00');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Range: ${fmtDate.format(rangeStart)} — ${fmtDate.format(rangeEnd)}',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            pw.Text(
              'Generated: ${fmtDate.format(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),
            _summaryCard(ctx, fmtMoney, currency, totalSpent, totalIncome),
            pw.SizedBox(height: 16),
            pw.Text(
              'Spending by category',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _categoryTable(spentByCategory, fmtMoney, currency),
            pw.SizedBox(height: 16),
            pw.Text(
              'Transactions',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _txTable(transactions, fmtDate, fmtMoney, currency),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              generatedBy,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path,
        'finlens_report_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _summaryCard(
    pw.Context ctx,
    NumberFormat fmt,
    String currency,
    double spent,
    double income,
  ) {
    final net = income - spent;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _stat('Total spent', '${fmt.format(spent)} $currency', PdfColors.red700),
          _stat('Total income', '${fmt.format(income)} $currency', PdfColors.green700),
          _stat('Net', '${fmt.format(net)} $currency',
              net >= 0 ? PdfColors.green700 : PdfColors.red700),
        ],
      ),
    );
  }

  pw.Widget _stat(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  pw.Widget _categoryTable(
      Map<String, double> data, NumberFormat fmt, String currency) {
    final rows = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('Category', bold: true),
            _cell('Amount', bold: true, align: pw.TextAlign.right),
          ],
        ),
        ...rows.map(
          (e) => pw.TableRow(
            children: [
              _cell(e.key),
              _cell('${fmt.format(e.value)} $currency', align: pw.TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _txTable(
      List<Transaction> txs, DateFormat fmt, NumberFormat fmtMoney, String currency) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _cell('Date', bold: true),
            _cell('Category', bold: true),
            _cell('Type', bold: true),
            _cell('Amount', bold: true, align: pw.TextAlign.right),
          ],
        ),
        ...txs.take(50).map(
              (t) => pw.TableRow(
                children: [
                  _cell(fmt.format(t.date)),
                  _cell(t.categoryId),
                  _cell(t.type.name),
                  _cell('${fmtMoney.format(t.amountInBase)} $currency',
                      align: pw.TextAlign.right),
                ],
              ),
            ),
      ],
    );
  }

  pw.Widget _cell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  Future<void> shareFile(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'Finlens export',
    );
  }

  /// Exports all transactions and app settings into a structured JSON backup.
  Future<File> exportAllDataJson({
    required List<Transaction> transactions,
    required Map<String, dynamic> settings,
  }) async {
    final payload = {
      'app': 'Finlens',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(
      dir.path,
      'finlens_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    ));
    await file.writeAsString(jsonString);
    return file;
  }

  /// Parses and validates a JSON backup payload.
  ({List<Transaction> transactions, Map<String, dynamic>? settings}) parseBackupJson(
      String jsonString) {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format');
    }
    final rawTxs = decoded['transactions'];
    if (rawTxs is! List) {
      throw const FormatException('Transactions array missing in backup');
    }
    final list = <Transaction>[];
    for (final item in rawTxs) {
      if (item is Map<String, dynamic>) {
        list.add(Transaction.fromJson(item));
      }
    }
    final rawSettings = decoded['settings'];
    final settingsMap =
        rawSettings is Map<String, dynamic> ? rawSettings : null;
    return (transactions: list, settings: settingsMap);
  }
}
