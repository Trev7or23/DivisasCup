import 'package:flutter/material.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/widgets/currency_dropdown_button.dart';

/// From / swap / To row. Swapping flips both currencies so the next recalc
/// uses the inverse rate — satisfying the "1-to-1 with inverse" requirement.
class CurrencySwapRow extends StatelessWidget {
  const CurrencySwapRow({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.swapTooltip,
    required this.currencies,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSwap,
  });

  final String fromLabel;
  final String toLabel;
  final String swapTooltip;
  final List<Currency> currencies;
  final Currency? from;
  final Currency? to;
  final ValueChanged<Currency> onFromChanged;
  final ValueChanged<Currency> onToChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CurrencyDropdownButton(
            key: const ValueKey('from-currency-dropdown'),
            label: fromLabel,
            items: currencies,
            selected: from,
            onChanged: onFromChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton.filledTonal(
            tooltip: swapTooltip,
            onPressed: onSwap,
            icon: const Icon(Icons.swap_horiz),
          ),
        ),
        Expanded(
          child: CurrencyDropdownButton(
            key: const ValueKey('to-currency-dropdown'),
            label: toLabel,
            items: currencies,
            selected: to,
            onChanged: onToChanged,
          ),
        ),
      ],
    );
  }
}