import 'package:flutter/material.dart';

import 'app.dart';
import 'features/price_comparison/data/datasources/local_exchange_rate_data_source.dart';
import 'features/price_comparison/data/datasources/mock_exchange_rate_data_source.dart';
import 'features/price_comparison/data/repositories/exchange_rate_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite is the offline source of truth. On first run it seeds itself from
  // the mock source, so the app works fully offline from launch. When Supabase
  // arrives, prime the local cache via RemoteExchangeRateDataSource here.
  final localDataSource = LocalExchangeRateDataSource(
    seedSource: const MockExchangeRateDataSource(),
  );
  final repository = ExchangeRateRepositoryImpl(dataSource: localDataSource);

  runApp(DivisasCupApp(exchangeRateRepository: repository));
}