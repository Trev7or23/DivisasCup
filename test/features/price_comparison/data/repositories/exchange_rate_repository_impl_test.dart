import 'dart:io';

import 'package:divisas_cup/core/domain/entities/cup_price_point.dart';
import 'package:divisas_cup/core/domain/entities/currency.dart';
import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'package:divisas_cup/features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const cup = Currency(code: 'CUP', name: 'Cuban Peso', symbol: r'$');
const usd = Currency(code: 'USD', name: 'US Dollar', symbol: r'$');
const mlc = Currency(code: 'MLC', name: 'MLC', symbol: r'$');
const eur = Currency(code: 'EUR', name: 'Euro', symbol: r'€');

void main() {
  setUpAll(sqfliteFfiInit);

  // `inMemoryDatabasePath` is process-wide under sqflite_common_ffi, so a
  // throwaway file per test is the only way to keep these isolated.
  Future<LocalExchangeRateDataSource> seededSource() async {
    final dir = await Directory.systemTemp.createTemp('divisas_cup_repo_test');
    addTearDown(() => dir.delete(recursive: true));
    final source = LocalExchangeRateDataSource(
      factoryOverride: databaseFactoryFfi,
      databasePath: '${dir.path}/cache.db',
    );
    addTearDown(source.close);
    await source.replaceSnapshot(
      currencies: const [cup, usd, mlc, eur],
      priceInCup: const {'CUP': 1.0, 'USD': 720.0, 'MLC': 720.0, 'EUR': 777.6},
      series: [
        for (var day = 0; day < 3; day++)
          CupPricePoint(
            date: DateTime(2026, 1, 1).add(Duration(days: day)),
            cupPerUsd: 720.0,
          ),
      ],
    );
    return source;
  }

  group('ExchangeRateRepositoryImpl', () {
    test('derives direct and cross rates from CUP anchors (mock source)',
        () async {
      final repo = ExchangeRateRepositoryImpl(
        dataSource: const MockExchangeRateDataSource(),
      );

      final usdToCup = await repo.getRate(base: usd, quote: cup);
      expect(usdToCup.rate, 720);

      final cupToUsd = await repo.getRate(base: cup, quote: usd);
      expect(cupToUsd.rate, closeTo(1 / 720, 1e-12));

      final usdToMlc = await repo.getRate(base: usd, quote: mlc);
      expect(usdToMlc.rate, 1);

      final usdToEur = await repo.getRate(base: usd, quote: eur);
      expect(usdToEur.rate, closeTo(720 / 777.6, 1e-9));
    });

    test('lists each non-base currency when given a base (local source)',
        () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: await seededSource());
      final rates = await repo.getRatesForBase(usd);

      expect(rates, hasLength(3));
      expect(rates.every((r) => r.base == usd), isTrue);
      expect(
        rates.map((r) => r.quote.code).toSet(),
        {'CUP', 'MLC', 'EUR'},
      );
      final cupRate = rates.firstWhere((r) => r.quote == cup);
      expect(cupRate.rate, closeTo(720, 1e-9));
    });

    test('exposes the CUP price series', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: await seededSource());

      expect(await repo.getCupPriceHistory(), hasLength(3));
      expect(
        (await repo.getCurrentCupPrice()).cupPerUsd,
        closeTo(720, 1e-6),
      );
    });

    test('hasCachedData is false before a sync and true after', () async {
      final dir = await Directory.systemTemp.createTemp('divisas_cup_repo_test');
      addTearDown(() => dir.delete(recursive: true));
      final source = LocalExchangeRateDataSource(
        factoryOverride: databaseFactoryFfi,
        databasePath: '${dir.path}/cache.db',
      );
      addTearDown(source.close);
      final repo = ExchangeRateRepositoryImpl(dataSource: source);

      expect(await repo.hasCachedData(), isFalse);

      await source.replaceSnapshot(
        currencies: const [cup, usd],
        priceInCup: const {'CUP': 1.0, 'USD': 720.0},
        series: const [],
      );
      expect(await repo.hasCachedData(), isTrue);
    });

    test('wraps raw backend errors into DataSourceFailure', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: _ThrowingSource());
      expect(
        repo.hasCachedData(),
        throwsA(isA<DataSourceFailure>()),
      );
      expect(
        repo.getSupportedCurrencies(),
        throwsA(isA<DataSourceFailure>()),
      );
      expect(
        repo.getRate(base: usd, quote: cup),
        throwsA(isA<DataSourceFailure>()),
      );
      expect(
        repo.getCupPriceHistory(),
        throwsA(isA<DataSourceFailure>()),
      );
    });

    test('propagates typed RateNotFoundException unchanged', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: _UnknownCodeSource());
      expect(
        repo.getRate(base: usd, quote: cup),
        throwsA(isA<RateNotFoundException>()),
      );
    });
  });
}

class _ThrowingSource implements ExchangeRateDataSource {
  @override
  Future<bool> hasCachedData() async => throw StateError('boom');

  @override
  Future<List<Currency>> getSupportedCurrencies() async =>
      throw StateError('boom');

  @override
  Future<double> getPriceInCup(String currencyCode) async =>
      throw StateError('boom');

  @override
  Future<CupPricePoint> getCurrentCupPrice() async => throw StateError('boom');

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async =>
      throw StateError('boom');
}

class _UnknownCodeSource implements ExchangeRateDataSource {
  @override
  Future<bool> hasCachedData() async => true;

  @override
  Future<List<Currency>> getSupportedCurrencies() async => const [cup, usd];

  @override
  Future<double> getPriceInCup(String currencyCode) async {
    if (currencyCode == 'USD') return 720;
    throw RateNotFoundException('No CUP anchor rate for "$currencyCode"');
  }

  @override
  Future<CupPricePoint> getCurrentCupPrice() async => throw StateError('boom');

  @override
  Future<List<CupPricePoint>> getCupPriceHistory() async =>
      throw StateError('boom');
}
