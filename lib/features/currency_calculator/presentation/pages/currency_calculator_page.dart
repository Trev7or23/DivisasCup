import 'package:divisas_cup/core/widgets/app_snack_bar.dart';
import 'package:divisas_cup/features/currency_calculator/presentation/widgets/amount_field.dart';
import 'package:divisas_cup/features/currency_calculator/presentation/widgets/currency_swap_row.dart';
import 'package:divisas_cup/features/currency_calculator/presentation/widgets/result_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../providers/currency_calculator_provider.dart';

/// 1-to-1 calculator: enter an amount, pick From/To (or swap them) and read
/// the result plus both rate directions.
class CurrencyCalculatorPage extends StatelessWidget {
  const CurrencyCalculatorPage({super.key});

  @override
  build(BuildContext context) {
    final provider = context.watch<CurrencyCalculatorProvider>();
    final l10n = AppLocalizations.of(context);

    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.calculatorTitle)),

        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calculatorTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              provider.setAmount(0);
            },
          ),
        ],
      ),
      body: _CurrencyCalculatorView(),
    );
  }
}

class _CurrencyCalculatorView extends StatefulWidget {
  @override
  State<_CurrencyCalculatorView> createState() =>
      _CurrencyCalculatorViewState();
}

class _CurrencyCalculatorViewState extends State<_CurrencyCalculatorView> {
  late final TextEditingController _amountController;
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final amountText = context.read<CurrencyCalculatorProvider>().amountText;

    _amountController = TextEditingController(text: amountText);
  }

  @override
  build(BuildContext context) {
    final provider = context.read<CurrencyCalculatorProvider>();
    final l10n = AppLocalizations.of(context);
    final from = provider.from;
    final to = provider.to;

    return ListView(
      physics: ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        AmountField(
          controller: _amountController,
          label: l10n.amount,
          hint: l10n.enterAmount,
          onChanged: provider.setAmount,
        ),
        const SizedBox(height: 16),
        CurrencySwapRow(
          fromLabel: l10n.from,
          toLabel: l10n.to,
          swapTooltip: l10n.swap,
          currencies: provider.currencies,
          from: from,
          to: to,
          onFromChanged: provider.selectFrom,
          onToChanged: provider.selectTo,
          onSwap: () async {
            final before = provider.from;
            await provider.swap();
            if (!context.mounted) return;
            AppSnackBar.showInfo(
              context,
              '${before?.code} ⇄ ${provider.from?.code}',
            );
          },
        ),
        const SizedBox(height: 20),
        if (from != null && to != null)
          ResultCard(
            label: l10n.result,
            amount: provider.amount,
            from: from,
            to: to,
            result: provider.result,
            rate: provider.rate?.rate,
          ),
        if (from == null || to == null)
          Text(l10n.convertError, textAlign: TextAlign.center),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.convertError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          l10n.footerHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}
