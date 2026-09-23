import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/cup_price_provider.dart';
import '../widgets/history_chart.dart';

/// CUP price history screen: line chart pushed over the home screen.
class CupPriceHistoryPage extends StatelessWidget {
  const CupPriceHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CupPriceProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: _buildBody(context, provider, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CupPriceProvider provider,
    AppLocalizations l10n,
  ) {
    if (provider.history.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: ClampingScrollPhysics(),
        children: [
          HistoryChart(points: provider.history),
          const SizedBox(height: 12),
          Text(
            l10n.footerHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      );
    }
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.error?.message ?? l10n.loadError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => unawaited(provider.load()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
