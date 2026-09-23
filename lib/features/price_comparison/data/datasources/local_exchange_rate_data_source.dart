import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/fake_rates.dart';
import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import '../models/cup_price_point_model.dart';
import '../models/currency_model.dart';
import 'exchange_rate_data_source.dart';

/// SQLite-backed source of truth once the app has launched at least once.
///
/// - Creates three tables (`currencies`, `exchange_rates`, `cup_price_series`)
///   on first open and **seeds them** from [seedSource], so the app is fully
///   functional offline from the very first run.
/// - `cup_price_series` seeds a deterministic ~90-day CUP-price history
///   (how many CUP one USD buys each day).
/// - The database is opened lazily on the first read and then cached.
/// - Injectable [DatabaseFactory]/path make unit tests run with an in-memory
///   FFI database (no device or plugin needed).
class LocalExchangeRateDataSource implements ExchangeRateDataSource {
  LocalExchangeRateDataSource({
    required this.seedSource,
    this.factoryOverride,
    this.databasePath,
  });

  static const String _dbFileName = 'divisas_cup.db';
  static const int _dbVersion = 2;
  static const String _cupCode = 'CUP';
  static const double _eurToUsdFactor = 1.08;

  /// Source consulted on first launch to populate the SQLite seed tables.
  final ExchangeRateDataSource seedSource;

  /// Used by tests to point at an in-memory FFI factory instead of the
  /// platform plugin.
  final DatabaseFactory? factoryOverride;
  final String? databasePath;

  Database? _database;

  Future<Database> _open() async {
    final cached = _database;
    if (cached != null) return cached;

    final factory = factoryOverride ?? databaseFactory;
    final path = databasePath ??
        '${await factory.getDatabasesPath()}/$_dbFileName';

    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    _database = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE cup_price_series (
          sampled_at INTEGER PRIMARY KEY,
          cup_per_usd REAL NOT NULL
        )
      ''');
      await db.delete('currencies');
      await db.delete('exchange_rates');
      await _seed(db);
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE currencies (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        decimal_digits INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exchange_rates (
        base_code TEXT NOT NULL,
        quote_code TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at INTEGER,
        PRIMARY KEY (base_code, quote_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE cup_price_series (
        sampled_at INTEGER PRIMARY KEY,
        cup_per_usd REAL NOT NULL
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final currencies = await seedSource.getSupportedCurrencies();
    final batch = db.batch();
    for (final currency in currencies) {
      final price = await seedSource.getPriceInCup(currency.code);
      batch.insert(
        'currencies',
        CurrencyModel.fromEntity(currency).toMap(),
      );
      batch.insert('exchange_rates', {
        'base_code': _cupCode,
        'quote_code': currency.code,
        'rate': price,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit(noResult: true);
    await _seedSeries(db);
  }

  Future<void> _seedSeries(Database db) async {
    final batch = db.batch();
    for (final point in FakeRates.series()) {
      batch.insert(
        'cup_price_series',
        CupPricePointModel.fromPoint(point).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    final db = await _open();
    try {
      final rows = await db.query('currencies');
      return rows.map(CurrencyModel.fromMap).toList();
    } catch (error) {
      throw _asFailure(error, 'Could not read currencies');
    }
  }

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    final db = await _open();
    try {
      final rows = await db.query(
        'exchange_rates',
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, currencyCode],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw RateNotFoundException(
          'No CUP anchor rate for "$currencyCode"',
        );
      }
      return (rows.first['rate'] as num).toDouble();
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not read CUP anchor for "$currencyCode"');
    }
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async {
    final db = await _open();
    try {
      final rows = await db.query(
        'cup_price_series',
        orderBy: 'sampled_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const RateNotFoundException('No CUP price series');
      }
      return CupPricePointModel.fromMap(rows.first).toPoint();
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not read current CUP price');
    }
  }

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async {
    final db = await _open();
    try {
      final rows = await db.query('cup_price_series', orderBy: 'sampled_at ASC');
      return rows
          .map((row) => CupPricePointModel.fromMap(row).toPoint())
          .toList();
    } catch (error) {
      throw _asFailure(error, 'Could not read CUP price history');
    }
  }

  @override
  Future<CupPricePoint> refreshCupPrice() async {
    final db = await _open();
    try {
      final current = await getCurrentCupPrice();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Calendar-anchored day index (UTC midnight of the same day), so the
      // deterministic jitter never collides across a DST transition.
      final dayNum =
          DateTime.utc(today.year, today.month, today.day)
              .millisecondsSinceEpoch ~/ 86400000;
      final sign = dayNum.isEven ? 1.0 : -1.0;
      final pct = 0.005 + (dayNum % 3) * 0.005;
      final next = (current.cupPerUsd * (1 + sign * pct)).clamp(1.0, 100000.0);
      final point = CupPricePoint(date: today, cupPerUsd: next);

      await db.insert(
        'cup_price_series',
        CupPricePointModel.fromPoint(point).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = db.batch();
      batch.update(
        'exchange_rates',
        {'rate': next},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'USD'],
      );
      batch.update(
        'exchange_rates',
        {'rate': next},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'MLC'],
      );
      batch.update(
        'exchange_rates',
        {'rate': next * _eurToUsdFactor},
        where: 'base_code = ? AND quote_code = ?',
        whereArgs: [_cupCode, 'EUR'],
      );
      await batch.commit(noResult: true);
      return point;
    } on Failure {
      rethrow;
    } catch (error) {
      throw _asFailure(error, 'Could not refresh CUP price');
    }
  }

  Failure _asFailure(Object error, String fallback) =>
      error is Failure ? error : DataSourceFailure(fallback);

  /// Closes the cached connection; used mainly in tests.
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}