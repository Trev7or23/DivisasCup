import 'package:divisas_cup/core/constants/fake_rates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeRates', () {
    test('seed exposes CUP-anchored prices for the Cuban set', () {
      expect(FakeRates.seed.map((s) => s.$1), ['CUP', 'USD', 'MLC', 'EUR']);
      expect(FakeRates.priceInCup['CUP'], 1);
      expect(FakeRates.priceInCup['USD'], 720);
      expect(FakeRates.priceInCup['MLC'], 720);
      expect(FakeRates.priceInCup['EUR'], closeTo(777.6, 1e-9));
      expect(FakeRates.priceInCup.containsKey('MXN'), isFalse);
    });

    test('series is deterministic, daily and ends at the current USD price',
        () {
      final today = DateTime(2026, 9, 23);
      final series = FakeRates.series(relativeTo: today);

      expect(series, hasLength(FakeRates.seriesDays));
      expect(series.first.date, DateTime(2026, 6, 26));
      expect(series.last.date, today);
      expect(series.first.cupPerUsd, 480);
      expect(series.last.cupPerUsd, closeTo(720, 1e-6));
      expect(series.map((p) => p.date).toSet().length, FakeRates.seriesDays);
    });

    test('series has a point on exactly today minus 7 days', () {
      final today = DateTime(2026, 9, 23);
      final series = FakeRates.series(relativeTo: today);
      final lastWeek = DateTime(2026, 9, 16);
      expect(series.where((p) => p.date == lastWeek), hasLength(1));
    });
  });
}
