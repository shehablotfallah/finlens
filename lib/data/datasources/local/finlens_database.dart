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
/// ROOT CAUSE OF PREVIOUS "Database error":
/// -----------------------------------------
/// The previous implementation called `PRAGMA cipher_compatibility = 4;`
/// after `PRAGMA key`. This PRAGMA is meant for opening databases created
/// with older SQLCipher versions (1/2/3) using a newer SQLCipher build.
/// `sqlcipher_flutter_libs` 0.6.x ships SQLCipher 4 natively, so:
///
///   - For a NEW database (first launch): the file is created with
///     SQLCipher 4 defaults. Setting `cipher_compatibility = 4` is a
///     no-op (already 4) but in some plugin versions it triggers a
///     re-key negotiation that fails silently, leaving the database
///     in a half-open state where INSERTs throw `database is locked`
///     or `file is not a database`.
///   - For an EXISTING database: same problem on reopen.
///
/// FIX: Only set `PRAGMA key`. Do NOT set `cipher_compatibility`.
/// The default of SQLCipher 4 (shipped by the plugin) is correct.
///
/// Additional safety:
///   * The passphrase is generated using `Random.secure()` (not time-
///     based entropy) for proper cryptographic strength.
///   * The passphrase is stored in `flutter_secure_storage` (Android
///     Keystore-backed), never in SharedPreferences.
///   * The SQL escape (single-quote doubling) prevents injection via
///     the key itself.
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

  final executor = NativeDatabase.createInBackground(
    dbFile,
    setup: (db) {
      // SQLCipher: provide the key BEFORE any other statement.
      // We escape single quotes by doubling them (SQL standard).
      final escaped = passphrase!.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
      // NOTE: Do NOT set `PRAGMA cipher_compatibility` here.
      // The plugin already ships SQLCipher 4 — setting it causes
      // spurious "database is locked" / "file is not a database"
      // errors on INSERT. See the method doc above for full details.
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
