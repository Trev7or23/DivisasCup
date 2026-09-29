import 'dart:convert';

import 'package:divisas_cup/core/errors/failure.dart';
import 'package:divisas_cup/features/price_comparison/data/datasources/supabase_exchange_rate_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

void main() {
  /// Canned PostgREST responses keyed by the table in the request path.
  Map<String, Object> buildPayload({
    List<Map<String, Object>>? currencies,
    List<Map<String, Object>>? rates,
    List<Map<String, Object>>? series,
  }) =>
      {
        if (currencies != null) 'currencies': currencies,
        if (rates != null) 'rates': rates,
        if (series != null) 'cup_price_series': series,
      };

  const cupRow = {
    'code': 'CUP',
    'name': 'Cuban Peso',
    'symbol': r'$',
    'decimal_digits': 2,
    'sort_order': 1,
  };
  const usdRow = {
    'code': 'USD',
    'name': 'US Dollar',
    'symbol': r'$',
    'decimal_digits': 2,
    'sort_order': 2,
  };
  const eurRow = {
    'code': 'EUR',
    'name': 'Euro',
    'symbol': '€',
    'decimal_digits': 2,
    'sort_order': 3,
  };

  ({SupabaseExchangeRateDataSource source, List<String> requests}) buildSource(
    Map<String, Object> payload, {
    int status = 200,
  }) {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        final table = request.url.path.split('/').last;
        requests.add('$table?${request.url.query}');
        if (status != 200) {
          return http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}),
            status,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(payload[table] ?? const []),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return (
      source: SupabaseExchangeRateDataSource(client),
      requests: requests,
    );
  }

  group('SupabaseExchangeRateDataSource', () {
    test('maps all three tables into a snapshot', () async {
      final built = buildSource(buildPayload(
        currencies: [cupRow, usdRow, eurRow],
        rates: [
          {'quote_code': 'CUP', 'price_in_cup': 1},
          {'quote_code': 'EUR', 'price_in_cup': 777.6},
          {'quote_code': 'USD', 'price_in_cup': 720},
        ],
        series: [
          {'sampled_on': '2026-01-02', 'cup_per_usd': 721.5},
          {'sampled_on': '2026-01-01', 'cup_per_usd': 720.0},
        ],
      ));

      final snapshot = await built.source.fetchSnapshot();

      expect(snapshot.isUsable, isTrue);
      expect(snapshot.currencies.map((c) => c.code), ['CUP', 'USD', 'EUR']);
      expect(snapshot.currencies.last.symbol, '€');
      expect(snapshot.currencies.last.decimalDigits, 2);
      expect(snapshot.priceInCup, {'CUP': 1.0, 'EUR': 777.6, 'USD': 720.0});
      expect(snapshot.series.map((p) => p.cupPerUsd), [720.0, 721.5]);
      expect(snapshot.series.first.date, DateTime(2026, 1, 1));
      expect(snapshot.series.last.date, DateTime(2026, 1, 2));
    });

    test('requests currencies in sort_order and series newest-first',
        () async {
      final built = buildSource(buildPayload(
        currencies: [cupRow],
        rates: const [],
        series: const [],
      ));

      await built.source.fetchSnapshot();

      expect(
        built.requests,
        contains('currencies?select=*&order=sort_order.asc'),
      );
      expect(
        built.requests,
        contains(
          'cup_price_series?select=sampled_on%2Ccup_per_usd'
          '&order=sampled_on.desc&limit=90',
        ),
      );
    });

    test('accepts numeric sent back as a string', () async {
      final built = buildSource(buildPayload(
        currencies: [cupRow, usdRow],
        rates: [
          {'quote_code': 'CUP', 'price_in_cup': '1.000000'},
          {'quote_code': 'USD', 'price_in_cup': '720.500000'},
        ],
        series: [
          {'sampled_on': '2026-01-01', 'cup_per_usd': '720.25'},
        ],
      ));

      final snapshot = await built.source.fetchSnapshot();

      expect(snapshot.priceInCup['USD'], closeTo(720.5, 1e-9));
      expect(snapshot.series.single.cupPerUsd, closeTo(720.25, 1e-9));
    });

    test('reads sampled_on as a local-midnight calendar day', () async {
      final built = buildSource(buildPayload(
        currencies: [cupRow, usdRow],
        rates: const [
          {'quote_code': 'CUP', 'price_in_cup': 1},
          {'quote_code': 'USD', 'price_in_cup': 720},
        ],
        series: [
          {'sampled_on': '2026-03-05', 'cup_per_usd': 720},
        ],
      ));

      final snapshot = await built.source.fetchSnapshot();
      final date = snapshot.series.single.date;

      // Not 2026-03-04 20:00, which is what a raw UTC parse would give in
      // UTC-4, and not 2026-03-05 00:00 UTC either.
      expect(date, DateTime(2026, 3, 5));
      expect(date.isUtc, isFalse);
      expect(date.hour, 0);
    });

    test('an empty series is still a usable snapshot', () async {
      final built = buildSource(buildPayload(
        currencies: [cupRow, usdRow],
        rates: const [
          {'quote_code': 'CUP', 'price_in_cup': 1},
          {'quote_code': 'USD', 'price_in_cup': 720},
        ],
        series: const [],
      ));

      final snapshot = await built.source.fetchSnapshot();

      expect(snapshot.isUsable, isTrue);
      expect(snapshot.series, isEmpty);
    });

    test('rejects a zero-currency read instead of reporting it as empty',
        () async {
      final built = buildSource(buildPayload(
        currencies: const [],
        rates: const [],
        series: const [],
      ));

      await expectLater(
        built.source.fetchSnapshot(),
        throwsA(
          isA<DataSourceFailure>().having(
            (f) => f.message,
            'message',
            contains('no currencies'),
          ),
        ),
      );
    });

    test('maps a PostgREST error into DataSourceFailure', () async {
      final built = buildSource(const {}, status: 401);

      await expectLater(
        built.source.fetchSnapshot(),
        throwsA(isA<DataSourceFailure>()),
      );
    });

    test('maps a network error into DataSourceFailure', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        httpClient: MockClient((_) async => throw http.ClientException(
              'Connection closed before full header was received',
            )),
      );
      final source = SupabaseExchangeRateDataSource(client);

      await expectLater(
        source.fetchSnapshot(),
        throwsA(
          isA<DataSourceFailure>().having(
            (f) => f.message,
            'message',
            contains('rates server'),
          ),
        ),
      );
    });
  });
}
