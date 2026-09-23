import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/cup_price_provider.dart';
import '../widgets/price_display_card.dart';
import '../widgets/week_delta_chip.dart';

/// CUP home screen: current dollar price in CUP against last week, plus a
/// shortcut to the full history.
class CupPricePage extends StatelessWidget {
  const CupPricePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CupPriceProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cupPriceTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(context, provider, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CupPriceProvider provider,
    AppLocalizations l10n,
  ) {
    final current = provider.current;
    final cup = provider.cupCurrency;
    final usd = provider.usdCurrency;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (current == null || cup == null || usd == null) {
      return _MessageView(
        message: provider.error?.message ?? l10n.loadError,
        onRetry: () => unawaited(provider.load()),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: ClampingScrollPhysics(),
      children: [
        PriceDisplayCard(
          label: l10n.currentPrice,
          cupPerUsd: current.cupPerUsd,
          cup: cup,
          usd: usd,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.lastWeek,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (provider.lastWeek != null)
                  Text(
                    CurrencyFormatter.amount(provider.lastWeek!.cupPerUsd, cup),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const SizedBox(height: 12),
                Center(
                  child: WeekDeltaChip(
                    deltaCup: provider.deltaCup,
                    deltaPercent: provider.deltaPercent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => context.push(AppRoutes.history),
          icon: const Icon(Icons.show_chart),
          label: Text(l10n.viewHistory),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
