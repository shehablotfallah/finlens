import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

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
/// The previous implementation was MISSING the critical call to
/// `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)`.
///
/// Without this call, the `sqlite3` package (used by Drift's
/// `NativeDatabase`) opens the DEFAULT sqlite3 library — NOT SQLCipher.
/// The DEFAULT sqlite3 library **silently ignores** `PRAGMA key`:
///   1. It opens the database file as an UNENCRYPTED, EMPTY database
///   2. INSERTs appear to succeed but data goes to the wrong database
///   3. On next open, the data is gone → "transaction not saved"
///
/// FIX: Call `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)`
/// BEFORE creating the NativeDatabase. This tells the `sqlite3` package to
/// load `libsqlcipher.so` instead of `libsqlite3.so`, so `PRAGMA key`
/// is understood and the database is correctly encrypted + decrypted.
///
/// Reference: https://pub.dev/packages/sqlcipher_flutter_libs
/// ------------------------------------------------------------------
Future<FinlensDatabase> openFinlensDatabase() async {
  // STEP 1: On Android, tell the sqlite3 package to use SQLCipher
  // instead of the regular sqlite3 library. This MUST be called before
  // any sqlite3 API is used (including NativeDatabase).
  if (Platform.isAndroid) {
    // Workaround for old Android versions where libsqlcipher.so might
    // not be immediately available.
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    // Override the default sqlite3 library opener to use SQLCipher.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  // STEP 2: Get the database file path.
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'finlens.db');
  final dbFile = File(dbPath);

  // STEP 3: Get or generate the encryption passphrase from secure storage.
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const passKey = 'finlens_db_passphrase';
  var passphrase = await secureStorage.read(key: passKey);
  if (passphrase == null || passphrase.isEmpty) {
    passphrase = _generatePassphrase();
    await secureStorage.write(key: passKey, value: passphrase);
  }

  // STEP 4: Open the database with NativeDatabase, applying PRAGMA key
  // in the setup callback. Because we called open.overrideFor above,
  // NativeDatabase now uses SQLCipher and PRAGMA key is understood.
  final executor = NativeDatabase(
    dbFile,
    setup: (db) {
      // SQLCipher: provide the key BEFORE any other statement.
      // We escape single quotes by doubling them (SQL standard).
      final escaped = passphrase!.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
    },
  );

  return FinlensDatabase(executor);
}

/// Generates a cryptographically random passphrase using `Random.secure()`.
///
/// We use 32 random bytes from the OS CSPRNG, base64-encoded, to ensure
/// the SQLCipher key has full 256-bit entropy.
String _generatePassphrase() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64Encode(bytes);
}
