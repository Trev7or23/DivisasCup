import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/currency_dropdown_button.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/price_comparison_provider.dart';
import '../widgets/comparison_tile.dart';

/// Currency Comparator screen: pick a base currency and see every other
/// currency expressed as `1 base = X quote`.
class PriceComparisonPage extends StatelessWidget {
  const PriceComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PriceComparisonProvider>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comparatorTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final ok = await provider.refresh();
              if (!context.mounted) return;
              ok
                  ? AppSnackBar.showSuccess(context, l10n.refreshSuccess)
                  : AppSnackBar.showError(context, l10n.loadError);
            },
          ),
        ],
      ),
      body: _buildBody(context, provider, l10n),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PriceComparisonProvider provider,
    AppLocalizations l10n,
  ) {
    final base = provider.base;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (base == null) {
      return _MessageView(
        message: l10n.loadError,
        onRetry: () => unawaited(provider.load()),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: CurrencyDropdownButton(
            label: l10n.baseCurrency,
            items: provider.currencies,
            selected: base,
            onChanged: (currency) {
              unawaited(provider.selectBase(currency));
              AppSnackBar.showInfo(context, l10n.comparingFrom(currency.code));
            },
          ),
        ),
        if (provider.error != null && provider.rates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.loadError,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: provider.rates.isEmpty
              ? _MessageView(
                  message: provider.error == null
                      ? l10n.noRates
                      : l10n.loadError,
                  onRetry: () => unawaited(provider.load()),
                )
              : ListView.builder(
                  physics: ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.rates.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ComparisonTile(exchangeRate: provider.rates[index]),
                  ),
                ),
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

