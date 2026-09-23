import 'package:go_router/go_router.dart';

import '../../features/currency_calculator/presentation/pages/currency_calculator_page.dart';
import '../../features/cup_price/presentation/pages/cup_price_history_page.dart';
import '../../features/cup_price/presentation/pages/cup_price_page.dart';
import '../../features/price_comparison/presentation/pages/price_comparison_page.dart';
import '../widgets/home_shell.dart';

/// Central route table. The CUP price screen is the boot destination; both
/// other features share one shell that renders the Material 3 [NavigationBar]
/// (see [HomeShell]). The history is pushed over the shell (no bottom bar).
abstract final class AppRoutes {
  static const String home = '/cup-price';
  static const String history = '/cup-price/history';
  static const String comparator = '/comparator';
  static const String calculator = '/calculator';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const CupPricePage(),
        ),
        GoRoute(
          path: AppRoutes.comparator,
          builder: (context, state) => const PriceComparisonPage(),
        ),
        GoRoute(
          path: AppRoutes.calculator,
          builder: (context, state) => const CurrencyCalculatorPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const CupPriceHistoryPage(),
    ),
  ],
);