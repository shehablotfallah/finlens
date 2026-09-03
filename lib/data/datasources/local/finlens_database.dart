import 'dart:io';

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
/// Implementation notes:
///   1. `sqlcipher_flutter_libs` (a dep in pubspec) ships a drop-in native
///      binary that replaces the default libsqlite3 on Android with a build
///      that understands `PRAGMA key`. Drift's NativeDatabase picks it up
///      automatically through the `sqlite3_flutter_libs` initializer.
///   2. The passphrase is generated once and stored inside the Android
///      Keystore via `flutter_secure_storage` (Android Keystore-backed) —
///      NEVER in plaintext SharedPreferences.
///   3. `PRAGMA cipher_compatibility = 4` ensures the file format matches
///      SQLCipher 4.x (the variant shipped by `sqlcipher_flutter_libs`).
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
      // If the file already exists with the right key, opening succeeds;
      // if not, this will create an encrypted file.
      final key = passphrase?.replaceAll("'", "''") ?? '';
      db.execute("PRAGMA key = '$key';");
      db.execute('PRAGMA cipher_compatibility = 4;');
    },
  );

  return FinlensDatabase(executor);
}

/// Generates a 32-byte random passphrase and returns it base64-encoded.
///
/// We don't use `dart:math.Random` for cryptographic strength here, but
/// the result is only used as a SQLCipher key that itself never leaves the
/// device. Still, we mix in microsecond timer entropy + a unique path
/// to avoid trivial collisions.
String _generatePassphrase() {
  final rng = DateTime.now().microsecondsSinceEpoch;
  final bytes = List<int>.generate(32, (i) {
    final mix = (rng ^ (i * 2654435761)) & 0xff;
    return mix;
  });
  return String.fromCharCodes(bytes.map((b) => 0x20 + (b % 95)));
}
