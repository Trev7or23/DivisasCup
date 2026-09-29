import 'dart:io';

import 'package:divisas_cup/core/domain/entities/cup_price_point.dart';
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  // `inMemoryDatabasePath` is NOT isolated under sqflite_common_ffi: it maps to
  // one process-wide in-memory database, so state leaks between tests. Every
  // test therefore gets its own throwaway file.
  Future<String> newDbPath() async {
    final dir = await Directory.systemTemp.createTemp('divisas_cup_test');
    addTearDown(() => dir.delete(recursive: true));
    return '${dir.path}/cache.db';
  }

  LocalExchangeRateDataSource sourceAt(String path) =>
      LocalExchangeRateDataSource(
        factoryOverride: databaseFactoryFfi,
        databasePath: path,
      );

  Future<LocalExchangeRateDataSource> newSource() async =>
      sourceAt(await newDbPath());

  const cup = Currency(
    code: 'CUP',
    name: 'Cuban Peso',
    symbol: r'$',
    decimalDigits: 2,
  );
  const usd = Currency(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    decimalDigits: 2,
  );
  const eur = Currency(
    code: 'EUR',
    name: 'Euro',
    symbol: '€',
    decimalDigits: 2,
  );
  const currencies = [cup, usd, eur];
  const priceInCup = {'CUP': 1.0, 'USD': 720.0, 'EUR': 777.6};

  List<CupPricePoint> series(int days) => [
        for (var day = 0; day < days; day++)
          CupPricePoint(
            date: DateTime(2026, 1, 1).add(Duration(days: day)),
            cupPerUsd: 720.0 + day,
          ),
      ];

  group('LocalExchangeRateDataSource', () {
    test('starts empty: no seed, no cached data', () async {
      final source = await newSource();

      expect(await source.hasCachedData(), isFalse);
      expect(await source.getSupportedCurrencies(), isEmpty);
      expect(await source.getCupPriceHistory(), isEmpty);
    });

    test('an empty cache reports RateNotFoundException, not silent zero',
        () async {
      final source = await newSource();

      expect(
        source.getPriceInCup('USD'),
        throwsA(isA<RateNotFoundException>()),
      );
      expect(
        source.getCurrentCupPrice(),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('replaceSnapshot stores currencies, anchors and series', () async {
      final source = await newSource();

      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(3),
      );

      expect(await source.hasCachedData(), isTrue);
      expect(
        (await source.getSupportedCurrencies()).map((c) => c.code),
        ['CUP', 'USD', 'EUR'],
      );
      expect(await source.getPriceInCup('CUP'), 1);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
      expect(await source.getCupPriceHistory(), hasLength(3));
    });

    test('reads currencies back in stored display order', () async {
      final source = await newSource();

      await source.replaceSnapshot(
        currencies: const [eur, cup, usd],
        priceInCup: priceInCup,
        series: series(1),
      );

      expect(
        (await source.getSupportedCurrencies()).map((c) => c.code),
        ['EUR', 'CUP', 'USD'],
      );
    });

    test('replaceSnapshot drops the previous snapshot instead of merging',
        () async {
      final source = await newSource();
      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(5),
      );

      await source.replaceSnapshot(
        currencies: const [cup],
        priceInCup: const {'CUP': 1.0},
        series: series(1),
      );

      expect(
        (await source.getSupportedCurrencies()).map((c) => c.code),
        ['CUP'],
      );
      expect(await source.getCupPriceHistory(), hasLength(1));
      expect(
        source.getPriceInCup('USD'),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('replaceSnapshot is idempotent across repeated syncs', () async {
      final source = await newSource();

      for (var i = 0; i < 3; i++) {
        await source.replaceSnapshot(
          currencies: currencies,
          priceInCup: priceInCup,
          series: series(4),
        );
      }

      expect(await source.getSupportedCurrencies(), hasLength(3));
      expect(await source.getCupPriceHistory(), hasLength(4));
    });

    test('a failed replace rolls back and keeps the last good snapshot',
        () async {
      final source = await newSource();
      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(3),
      );

      // Duplicate `sampled_at` violates the cup_price_series primary key, so
      // the batch fails after the currencies/rates deletes and inserts.
      final duplicate = series(1).first;
      await expectLater(
        source.replaceSnapshot(
          currencies: const [],
          priceInCup: const {},
          series: [duplicate, duplicate],
        ),
        throwsA(isA<DataSourceFailure>()),
      );

      expect(
        (await source.getSupportedCurrencies()).map((c) => c.code),
        ['CUP', 'USD', 'EUR'],
      );
      expect(await source.getCupPriceHistory(), hasLength(3));
      expect(await source.getPriceInCup('USD'), 720);
    });

    test('a currency without an anchor fails the whole sync', () async {
      final source = await newSource();

      await expectLater(
        source.replaceSnapshot(
          currencies: currencies,
          priceInCup: const {'CUP': 1.0, 'USD': 720.0},
          series: series(1),
        ),
        throwsA(
          isA<DataSourceFailure>().having(
            (f) => f.message,
            'message',
            allOf(contains('EUR'), isNot(contains('USD'))),
          ),
        ),
      );
      expect(await source.getSupportedCurrencies(), isEmpty);
      expect(await source.getCupPriceHistory(), isEmpty);
    });

    test('throws RateNotFoundException for unknown codes', () async {
      final source = await newSource();
      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(1),
      );

      expect(
        source.getPriceInCup('XXX'),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('the snapshot survives closing and reopening the same file',
        () async {
      final path = await newDbPath();

      final first = sourceAt(path);
      await first.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(6),
      );
      await first.close();

      final second = sourceAt(path);
      expect(await second.hasCachedData(), isTrue);
      expect(await second.getSupportedCurrencies(), hasLength(3));
      expect(await second.getCupPriceHistory(), hasLength(6));
      await second.close();
    });

    test('upgrades a v2 database: anchors reset, price series preserved',
        () async {
      final path = await newDbPath();

      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
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
            await db.insert('currencies', {
              'code': 'MXN',
              'name': 'Mexican Peso',
              'symbol': r'MX$',
              'decimal_digits': 2,
            });
            await db.insert('exchange_rates',
                {'base_code': 'CUP', 'quote_code': 'MXN', 'rate': 24.0});
            await db.insert('cup_price_series',
                {'sampled_at': 1767225600000, 'cup_per_usd': 700.0});
          },
        ),
      );
      await legacy.close();

      final source = sourceAt(path);

      // Sample rows are dropped: the next sync refills them from the server.
      expect(await source.getSupportedCurrencies(), isEmpty);
      expect(await source.hasCachedData(), isFalse);
      // The series itself is still valid data, so it is carried over.
      expect(await source.getCupPriceHistory(), hasLength(1));
      expect(
        (await source.getCupPriceHistory()).single.cupPerUsd,
        closeTo(700.0, 1e-9),
      );

      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(2),
      );
      expect(
        (await source.getSupportedCurrencies()).map((c) => c.code),
        ['CUP', 'USD', 'EUR'],
      );
      expect(await source.getPriceInCup('USD'), 720);
      await source.close();
    });

    test('upgrades a v1 database, creating the price series table', () async {
      final path = await newDbPath();

      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
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
            await db.insert('currencies', {
              'code': 'MXN',
              'name': 'Mexican Peso',
              'symbol': r'MX$',
              'decimal_digits': 2,
            });
          },
        ),
      );
      await legacy.close();

      final source = sourceAt(path);

      expect(await source.getSupportedCurrencies(), isEmpty);
      expect(await source.getCupPriceHistory(), isEmpty);

      await source.replaceSnapshot(
        currencies: currencies,
        priceInCup: priceInCup,
        series: series(2),
      );
      expect(await source.getCupPriceHistory(), hasLength(2));
      await source.close();
    });
  });
}
