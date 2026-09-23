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
      final local = LocalExchangeRateDataSource(
        seedSource: const MockExchangeRateDataSource(),
        factoryOverride: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(local.close);

      final repo = ExchangeRateRepositoryImpl(dataSource: local);
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
      final repo = ExchangeRateRepositoryImpl(
        dataSource: const MockExchangeRateDataSource(),
      );

      final history = await repo.getCupPriceHistory();
      expect(history, hasLength(90));
      expect((await repo.getCurrentCupPrice()).cupPerUsd, closeTo(720, 1e-6));
      expect((await repo.refreshCupPrice()).cupPerUsd, closeTo(720, 1e-6));
    });

    test('wraps raw backend errors into DataSourceFailure', () async {
      final repo = ExchangeRateRepositoryImpl(dataSource: _ThrowingSource());
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

  @override
  Future<CupPricePoint> refreshCupPrice() async => throw StateError('boom');
}

class _UnknownCodeSource implements ExchangeRateDataSource {
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

  @override
  Future<CupPricePoint> refreshCupPrice() async => throw StateError('boom');
}