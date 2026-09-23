import 'exchange_rate_data_source.dart';

/// Seam prepared for the future Supabase backend.
///
/// Deliberately NOT implemented: this phase is fully offline and local-first.
/// When the cloud arrives, a data source satisfying [RemoteExchangeRateDataSource]
/// (e.g. a `SupabaseExchangeRateDataSource`) replaces or augments the local one
/// in `main.dart` — domain and presentation do not change, because both only
/// know about [ExchangeRateRepository].
abstract interface class RemoteExchangeRateDataSource
    implements ExchangeRateDataSource {
  /// Pulls fresh rates and writes them into the local cache so the app stays
  /// usable offline. To be implemented together with the Supabase client.
  Future<void> refreshRateCache();
}

// -----------------------------------------------------------------------------
// Intended future wiring (example only, nothing implemented yet):
//
// class SupabaseExchangeRateDataSource
//     implements RemoteExchangeRateDataSource {
//   const SupabaseExchangeRateDataSource({required this.client});
//   final SupabaseClient client; // package:supabase_flutter
//
//   @override
//   Future<void> refreshRateCache() async {
//     final rows = await client.from('rates').select('*');
//     // ... cache into LocalExchangeRateDataSource
//   }
// }
//
// In main.dart:
//   final remote = SupabaseExchangeRateDataSource(client: supabase);
//   final local  = LocalExchangeRateDataSource(seedSource: mock);
//   final repo   = ExchangeRateRepositoryImpl(dataSource: local);
//   await remote.refreshRateCache(); // prime cache before runApp
// -----------------------------------------------------------------------------