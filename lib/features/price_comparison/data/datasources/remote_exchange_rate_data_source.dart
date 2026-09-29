import '../models/remote_rates_snapshot.dart';

/// Read-only view of the server snapshot that a sync copies into the cache.
///
/// Deliberately NOT an [ExchangeRateDataSource]: the remote cannot answer
/// derived cross-rates (deriving them from anchors is the repository's job), and
/// it must not write to the local cache itself. Keeping the replace in the
/// repository is what guarantees a failed sync leaves the previous snapshot
/// intact.
abstract interface class RemoteExchangeRateDataSource {
  /// Reads the current server state. The result is a plain value: nothing has
  /// touched the local database yet.
  Future<RemoteRatesSnapshot> fetchSnapshot();
}
