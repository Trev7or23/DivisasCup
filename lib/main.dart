import 'package:flutter/material.dart';

import 'app.dart';
import 'features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite is the local cache every screen reads from. It starts empty; the
  // Supabase client below pulls the real snapshot into it on first launch and
  // on every refresh, so a run with no network and no cache has nothing to
  // show — by design, rather than inventing numbers.
  final localDataSource = LocalExchangeRateDataSource();
  final repository = ExchangeRateRepositoryImpl(dataSource: localDataSource);

  runApp(DivisasCupApp(exchangeRateRepository: repository));
}
