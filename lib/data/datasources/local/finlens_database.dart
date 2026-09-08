import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'finlens_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Table: transactions.
///
/// `amountInBase` and `exchangeRateAtTime` are persisted at insert time so
/// historical reports stay accurate even if the user later updates the
/// USD/EGP exchange rate.
class Transactions extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<TransactionTypeDb>()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  RealColumn get amountInBase => real()();
  RealColumn get exchangeRateAtTime => real()();
  TextColumn get categoryId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get recurrenceInterval =>
      intEnum<RecurrenceIntervalDb>().nullable()();
  IntColumn get recurrenceCustomDays => integer().nullable()();
  IntColumn get reminderDaysBefore => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomCategories extends Table {
  TextColumn get id => text()();
  IntColumn get iconCodePoint => integer()();
  IntColumn get colorValue => integer()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class InstallmentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get providerName => text()();
  RealColumn get totalAmount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get installmentCount => integer()();
  IntColumn get paidCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get intervalDays => integer().withDefault(const Constant(30))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class MonthlyInsights extends Table {
  TextColumn get id => text()();
  TextColumn get monthKey => text()();
  TextColumn get body => text()(); // body — avoids clash with Table.text()
  DateTimeColumn get generatedAt => dateTime()();
  TextColumn get locale => text().withLength(min: 2, max: 8)();

  @override
  Set<Column> get primaryKey => {id};
}

enum TransactionTypeDb { expense, income }
enum RecurrenceIntervalDb { weekly, monthly, custom }

@DriftDatabase(
  tables: [Transactions, CustomCategories, InstallmentPlans, MonthlyInsights],
)
class FinlensDatabase extends _$FinlensDatabase {
  FinlensDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

// ---------------------------------------------------------------------------
// Opener — encrypted SQLite via SQLCipher
// ---------------------------------------------------------------------------

/// Opens the Drift database, encrypting the SQLite file using SQLCipher.
///
/// ROOT CAUSE OF "Database error" (TRANSACTION NOT SAVING):
/// ------------------------------------------------------------------
/// The previous implementation used `NativeDatabase.createInBackground()`
/// which runs the database in a SEPARATE ISOLATE. The `sqlcipher_flutter_libs`
/// native library is only loaded in the MAIN isolate (via `sqlite3_flutter_libs`
/// plugin initialization). In the background isolate, `sqlite3.open()` uses
/// the DEFAULT (non-SQLCipher) sqlite3 library, which:
///   1. Silently ignores `PRAGMA key` (it doesn't understand it)
///   2. Opens the database file as an UNENCRYPTED, EMPTY database
///   3. INSERTs appear to succeed but data goes to a temp/empty database
///   4. On next open, the data is gone → "transaction not saved"
///
/// FIX: Use `NativeDatabase` (NOT `createInBackground`) so the database
/// runs in the MAIN ISOLATE where SQLCipher is properly loaded. The
/// `PRAGMA key` is then understood by SQLCipher and the database is
/// correctly encrypted + decrypted.
///
/// Performance note: Running the DB in the main isolate is slightly
/// slower for large queries, but for a personal finance app with
/// occasional small inserts, the difference is imperceptible.
/// ------------------------------------------------------------------
Future<FinlensDatabase> openFinlensDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'finlens.db');
  final dbFile = File(dbPath);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const passKey = 'finlens_db_passphrase';
  var passphrase = await secureStorage.read(key: passKey);
  if (passphrase == null || passphrase.isEmpty) {
    passphrase = _generatePassphrase();
    await secureStorage.write(key: passKey, value: passphrase);
  }

  // Use NativeDatabase (NOT createInBackground) so SQLCipher is loaded
  // in the main isolate where the native library is registered.
  final executor = NativeDatabase(
    dbFile,
    setup: (db) {
      // SQLCipher: provide the key BEFORE any other statement.
      final escaped = passphrase!.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
    },
  );

  return FinlensDatabase(executor);
}

/// Generates a cryptographically random passphrase using `Random.secure()`.
///
/// We use 32 random bytes from the OS CSPRNG, base64-encoded, to ensure
/// the SQLCipher key has full 256-bit entropy. This replaces the previous
/// time-based entropy generator which was predictable.
String _generatePassphrase() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64Encode(bytes);
}
