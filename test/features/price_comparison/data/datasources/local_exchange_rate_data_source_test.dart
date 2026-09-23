import 'dart:io';

import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  LocalExchangeRateDataSource buildSource({String? path}) =>
      LocalExchangeRateDataSource(
        seedSource: const MockExchangeRateDataSource(),
        factoryOverride: databaseFactoryFfi,
        databasePath: path ?? inMemoryDatabasePath,
      );

  group('LocalExchangeRateDataSource', () {
    test('seeds currencies and CUP anchors on first open', () async {
      final source = buildSource();

      final currencies = await source.getSupportedCurrencies();
      expect(currencies.map((c) => c.code), ['CUP', 'USD', 'MLC', 'EUR']);

      expect(await source.getPriceInCup('CUP'), 1);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('MLC'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
    });

    test('seeds the CUP price series and exposes current + history', () async {
      final source = buildSource();

      final history = await source.getCupPriceHistory();
      expect(history, hasLength(90));
      expect(history, orderedEquals(
        [...history]..sort((a, b) => a.date.compareTo(b.date)),
      ));

      final current = await source.getCurrentCupPrice();
      expect(current, history.last);
      expect(current.cupPerUsd, closeTo(720, 1e-6));
    });

    test('throws RateNotFoundException for unknown codes', () async {
      final source = buildSource();
      expect(
        source.getPriceInCup('XXX'),
        throwsA(isA<RateNotFoundException>()),
      );
    });

    test('refresh inserts/updates today and re-anchors USD/MLC/EUR', () async {
      final source = buildSource();
      final before = await source.getCurrentCupPrice();

      final point = await source.refreshCupPrice();

      expect(point.date, DateTime.now().dateTruncated);
      expect(point.cupPerUsd,
          closeTo(before.cupPerUsd, before.cupPerUsd * 0.03));

      expect(await source.getPriceInCup('USD'), point.cupPerUsd);
      expect(await source.getPriceInCup('MLC'), point.cupPerUsd);
      expect(await source.getPriceInCup('EUR'),
          closeTo(point.cupPerUsd * 1.08, 1e-9));

      final history = await source.getCupPriceHistory();
      expect(history.last.cupPerUsd, point.cupPerUsd);

      await source.refreshCupPrice();
      expect(await source.getCupPriceHistory(), hasLength(history.length));
    });

    test('does not duplicate the seed when the same file is reopened', () async {
      final dir = await Directory.systemTemp.createTemp('divisas_cup_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/seed.db';

      final first = buildSource(path: path);
      await first.getSupportedCurrencies();
      await first.close();

      final second = buildSource(path: path);
      final currencies = await second.getSupportedCurrencies();
      expect(currencies, hasLength(4));
      final history = await second.getCupPriceHistory();
      expect(history, hasLength(90));
      await second.close();
    });

    test('upgrades a v1 database adding the series table', () async {
      final dir = await Directory.systemTemp.createTemp('divisas_cup_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/migrate.db';

      final factory = databaseFactoryFfi;
      final legacy = await factory.openDatabase(
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
            await db.insert('currencies',
                {'code': 'MXN', 'name': 'Mexican Peso', 'symbol': 'MX\$', 'decimal_digits': 2});
            await db.insert('exchange_rates',
                {'base_code': 'USD', 'quote_code': 'MXN', 'rate': 24.0});
          },
        ),
      );
      await legacy.close();

      final source = buildSource(path: path);
      final history = await source.getCupPriceHistory();
      expect(history, hasLength(90));

      final currencies = await source.getSupportedCurrencies();
      expect(currencies.map((c) => c.code), ['CUP', 'USD', 'MLC', 'EUR']);
      expect(await source.getPriceInCup('USD'), 720);
      expect(await source.getPriceInCup('EUR'), closeTo(777.6, 1e-9));
      await source.close();
    });
  });
}

extension on DateTime {
  DateTime get dateTruncated => DateTime(year, month, day);
}