import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../router/app_router.dart';

const _routes = [AppRoutes.home, AppRoutes.comparator, AppRoutes.calculator];

/// Scaffold shared by every feature: renders the child page (via the router's
/// [ShellRoute]) plus a Material 3 navigation bar for the three features.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).uri.path;
    final index = _routes.indexWhere((r) => path == r);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: l10n.priceLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.compare_arrows_outlined),
            selectedIcon: const Icon(Icons.compare_arrows),
            label: l10n.homeLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: l10n.calculatorLabel,
          ),
        ],
      ),
    );
  }
}

