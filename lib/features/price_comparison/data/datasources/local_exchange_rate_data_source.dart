import 'package:sqflite/sqflite.dart';

import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import '../models/cup_price_point_model.dart';
import '../models/currency_model.dart';
import 'exchange_rate_data_source.dart';

/// SQLite mirror of the Supabase tables: a local cache, never a seed.
///
/// The database is created **empty** — there is no fallback data, so a first
/// run with no network has nothing to show and must report it. [replaceSnapshot]
/// is the only writer: every sync drops the previous contents and stores the
/// fresh ones in a single transaction, so a sync that dies part-way through
/// leaves the last good snapshot intact. Reads are served exclusively from this
/// cache, so no screen ever waits on the network.
///
/// Injectable [factoryOverride]/[databasePath] let unit tests run against an
/// in-memory FFI database instead of the platform plugin.
class LocalExchangeRateDataSource implements ExchangeRateDataSource {
  LocalExchangeRateDataSource({
    this.factoryOverride,
    this.databasePath,
  });

  static const String _dbFileName = 'divisas_cup.db';
  static const int _dbVersion = 3;

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
    await _createCurrencies(db);
    await _createRates(db);
    await _createSeries(db);
  }

  /// v1 had no `cup_price_series`; v2 had it but no `sort_order` and stored
  /// anchors in `exchange_rates(base_code, quote_code, rate)`. Both jump
  /// straight to v3, which mirrors the Supabase schema one-to-one. Existing
  /// rows are dropped rather than migrated: they were sample data, and the next
  /// sync refills the cache from the server anyway.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= _dbVersion) return;
    if (oldVersion < 2) await _createSeries(db);
    await db.execute('DROP TABLE IF EXISTS exchange_rates');
    await db.execute('DROP TABLE IF EXISTS currencies');
    await _createCurrencies(db);
    await _createRates(db);
  }

  Future<void> _createCurrencies(Database db) async {
    await db.execute('''
      CREATE TABLE currencies (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        decimal_digits INTEGER NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createRates(Database db) async {
    await db.execute('''
      CREATE TABLE rates (
        quote_code TEXT PRIMARY KEY,
        price_in_cup REAL NOT NULL,
        cached_at INTEGER
      )
    ''');
  }

  Future<void> _createSeries(Database db) async {
    await db.execute('''
      CREATE TABLE cup_price_series (
        sampled_at INTEGER PRIMARY KEY,
        cup_per_usd REAL NOT NULL
      )
    ''');
  }

  @override
  Future<bool> hasCachedData() async {
    final db = await _open();
    try {
      final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM currencies');
      return (rows.first['total']! as int) > 0;
    } catch (error) {
      throw _asFailure(error, 'Could not inspect the local cache');
    }
  }

  @override
  Future<List<Currency>> getSupportedCurrencies() async {
    final db = await _open();
    try {
      final rows = await db.query('currencies', orderBy: 'sort_order');
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
        'rates',
        columns: ['price_in_cup'],
        where: 'quote_code = ?',
        whereArgs: [currencyCode],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw RateNotFoundException(
          'No CUP anchor rate for "$currencyCode"',
        );
      }
      return (rows.first['price_in_cup']! as num).toDouble();
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

  /// Replaces the entire cache with [currencies], [priceInCup] and [series] in
  /// one transaction.
  ///
  /// The deletes and the inserts commit together, so a failure part-way
  /// through rolls the whole thing back and the previous snapshot survives.
  ///
  /// [currencies] arrives in display order and its position becomes the stored
  /// `sort_order` (1-based, mirroring the server's own ordering), which is what
  /// [getSupportedCurrencies] reads back. Every entry needs a price in
  /// [priceInCup]: a currency without an anchor is a data-integrity problem, so
  /// it fails the entire sync rather than silently shrinking the list.
  ///
  /// `cached_at` records when *this app* stored the row. It is deliberately not
  /// the server's `rates.updated_at` (when the rate last changed upstream):
  /// conflating the two would make a stale-looking row look fresh, and nothing
  /// reads the column yet.
  ///
  /// Inserts use the default conflict strategy on purpose — a duplicated code
  /// from the server should abort the sync, not let the last row win quietly.
  Future<void> replaceSnapshot({
    required List<Currency> currencies,
    required Map<String, double> priceInCup,
    required List<CupPricePoint> series,
  }) async {
    final missing = [
      for (final currency in currencies)
        if (!priceInCup.containsKey(currency.code)) currency.code,
    ];
    if (missing.isNotEmpty) {
      throw DataSourceFailure('Missing CUP anchor for: ${missing.join(', ')}');
    }

    final db = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await db.transaction((txn) async {
        await txn.delete('currencies');
        await txn.delete('rates');
        await txn.delete('cup_price_series');

        final batch = txn.batch();
        for (var index = 0; index < currencies.length; index++) {
          final currency = currencies[index];
          batch.insert(
            'currencies',
            CurrencyModel.fromEntity(currency).toMap(sortOrder: index + 1),
          );
          batch.insert('rates', {
            'quote_code': currency.code,
            'price_in_cup': priceInCup[currency.code],
            'cached_at': now,
          });
        }
        for (final point in series) {
          batch.insert(
            'cup_price_series',
            CupPricePointModel.fromPoint(point).toMap(),
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (error) {
      throw _asFailure(error, 'Could not store the rates snapshot');
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
