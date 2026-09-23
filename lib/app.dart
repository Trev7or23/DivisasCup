import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/domain/repositories/exchange_rate_repository.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/cup_price/presentation/providers/cup_price_provider.dart';
import 'features/currency_calculator/presentation/providers/currency_calculator_provider.dart';
import 'features/price_comparison/presentation/providers/price_comparison_provider.dart';
import 'l10n/generated/app_localizations.dart';

/// Spanish first, English second. For any other device locale the resolution
/// falls back to the first entry (`es`), matching the project's i18n decision.
const List<Locale> appSupportedLocales = [Locale('es'), Locale('en')];

class DivisasCupApp extends StatelessWidget {
  const DivisasCupApp({super.key, required this.exchangeRateRepository});

  /// Wired once in `main.dart`; the single abstraction point that in the
  /// future will swap SQLite for SQLite + Supabase without changing the app.
  final ExchangeRateRepository exchangeRateRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ExchangeRateRepository>.value(value: exchangeRateRepository),
        ChangeNotifierProvider(
          create: (_) =>
              PriceComparisonProvider(repository: exchangeRateRepository)
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CurrencyCalculatorProvider(repository: exchangeRateRepository)
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CupPriceProvider(repository: exchangeRateRepository)..load(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: appRouter,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: appSupportedLocales,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}