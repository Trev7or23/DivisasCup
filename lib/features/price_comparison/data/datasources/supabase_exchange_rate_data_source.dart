import 'package:supabase/supabase.dart';

import '../../../../core/domain/entities/cup_price_point.dart';
import '../../../../core/domain/entities/currency.dart';
import '../../../../core/errors/failure.dart';
import '../models/remote_rates_snapshot.dart';
import 'remote_exchange_rate_data_source.dart';

/// Read-only Supabase implementation: three `anon` SELECTs and no writes.
///
/// The `anon` role is SELECT-only by policy (see `supabase/migrations`), so
/// this client cannot write even if asked. The `refresh_cup_price` RPC that
/// maintains `cup_price_series` is `service_role`-only and runs server-side, so
/// the app never needs a writable key.
///
/// [httpClient] is injected by [SupabaseClient] itself, which is what lets the
/// tests exercise this class against canned PostgREST responses.
class SupabaseExchangeRateDataSource implements RemoteExchangeRateDataSource {
  const SupabaseExchangeRateDataSource(this._client);

  /// Newest daily points to pull; the chart window.
  static const int _seriesDays = 90;

  final SupabaseClient _client;

  @override
  Future<RemoteRatesSnapshot> fetchSnapshot() async {
    // The three reads start together, so the cost is the slowest one rather
    // than the sum. Each is individually guarded, which means `Future.wait`
    // rethrows an already-typed [Failure] instead of a `ParallelWaitError`
    // bundling three raw transport errors together.
    final results = await Future.wait<Object>([
      _guard(_selectCurrencies()),
      _guard(_selectAnchors()),
      _guard(_selectSeries()),
    ]);
    final currencies = results[0]! as List<Currency>;
    final anchors = results[1]! as Map<String, double>;
    final newestFirstSeries = results[2]! as List<CupPricePoint>;

    if (currencies.isEmpty) {
      throw const DataSourceFailure(
        'The rates server returned no currencies',
      );
    }

    return RemoteRatesSnapshot(
      currencies: currencies,
      priceInCup: anchors,
      // Queried newest-first to honour the limit, stored oldest-first because
      // that is the order the local cache and the chart both expect.
      series: newestFirstSeries.reversed.toList(),
    );
  }

  /// Converts a transport-level error into the app's own vocabulary, so callers
  /// never have to know that PostgREST or `http` exist.
  static Future<T> _guard<T>(Future<T> future) async {
    try {
      return await future;
    } catch (error) {
      throw _asFailure(error);
    }
  }

  static Failure _asFailure(Object error) => switch (error) {
        final Failure failure => failure,
        final PostgrestException postgrest => DataSourceFailure(
            'The rates server rejected the query (${postgrest.code})',
          ),
        _ => const DataSourceFailure('Could not reach the rates server'),
      };

  Future<List<Currency>> _selectCurrencies() async {
    final rows = await _client.from('currencies').select().order('sort_order');
    return [
      for (final row in rows)
        Currency(
          code: row['code']! as String,
          name: row['name']! as String,
          symbol: row['symbol']! as String,
          decimalDigits: (row['decimal_digits']! as num).toInt(),
        ),
    ];
  }

  Future<Map<String, double>> _selectAnchors() async {
    final rows = await _client
        .from('rates')
        .select('quote_code, price_in_cup')
        .order('quote_code');
    return {
      for (final row in rows)
        row['quote_code']! as String: _toDouble(row['price_in_cup']),
    };
  }

  Future<List<CupPricePoint>> _selectSeries() async {
    final rows = await _client
        .from('cup_price_series')
        .select('sampled_on, cup_per_usd')
        .order('sampled_on', ascending: false)
        .limit(_seriesDays);
    return [
      for (final row in rows)
        CupPricePoint(
          date: _parseDay(row['sampled_on']),
          cupPerUsd: _toDouble(row['cup_per_usd']),
        ),
    ];
  }

  /// `sampled_on` is a Postgres `date`: a calendar day with no timezone, so
  /// `DateTime.parse` yields UTC midnight. Re-anchor it to the device's local
  /// midnight, which is what [CurrencyFormatter.dayShift] and the provider's
  /// day-equality lookups compare against. Without this, a device west of UTC
  /// would read every sample as the previous day.
  static DateTime _parseDay(Object? value) {
    final utc = DateTime.parse(value! as String);
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Postgres `numeric` arrives as a JSON number, but string values are legal
  /// too, so accept both rather than crash on a proxy's re-encoding.
  static double _toDouble(Object? value) => switch (value) {
        final num number => number.toDouble(),
        final String text => double.parse(text),
        _ => throw FormatException('Expected a number, got $value'),
      };
}
