import 'package:divisas_cup/core/constants/fake_rates.dart';
import 'package:divisas_cup/features/cup_price/presentation/providers/cup_price_provider.dart';
import 'package:divisas_cup/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('CupPriceProvider', () {
    test('loads current, last week and computes the delta', () async {
      final provider =
          CupPriceProvider(repository: FakeExchangeRateRepository());
      await provider.load();

      final today = DateTime.now();
      final series = FakeRates.series(relativeTo: today);
      final lastWeekPoint = series.firstWhere(
        (p) => p.date == CurrencyFormatter.dayShift(today, -7),
      );

      expect(provider.isLoading, isFalse);
      expect(provider.current!.cupPerUsd, closeTo(720, 1e-6));
      expect(provider.lastWeek!.cupPerUsd, lastWeekPoint.cupPerUsd);
      expect(
        provider.deltaCup!,
        closeTo(provider.current!.cupPerUsd - lastWeekPoint.cupPerUsd, 1e-6),
      );
      expect(
        provider.deltaPercent!,
        closeTo(
          (provider.current!.cupPerUsd - lastWeekPoint.cupPerUsd) /
              lastWeekPoint.cupPerUsd *
              100,
          1e-6,
        ),
      );
      expect(provider.history, hasLength(FakeRates.seriesDays));
      expect(provider.cupCurrency?.code, 'CUP');
      expect(provider.usdCurrency?.code, 'USD');
    });

    test('refresh reports success and reloads', () async {
      final provider =
          CupPriceProvider(repository: FakeExchangeRateRepository());
      await provider.load();

      final ok = await provider.refresh();
      expect(ok, isTrue);
      expect(provider.error, isNull);
    });

    test('surfaces failures and keeps the loading flag false', () async {
      final provider = CupPriceProvider(
        repository: FakeExchangeRateRepository(failOnSeries: true),
      );
      await provider.load();

      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    });
  });
}