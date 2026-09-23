import 'package:flutter/material.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Big "720.00 CUP = 1.00 USD" card shown on the CUP home screen.
class PriceDisplayCard extends StatelessWidget {
  const PriceDisplayCard({
    super.key,
    required this.label,
    required this.cupPerUsd,
    required this.cup,
    required this.usd,
  });

  final String label;
  final double cupPerUsd;
  final Currency cup;
  final Currency usd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(
              '${CurrencyFormatter.amount(cupPerUsd, cup)} = '
              '${CurrencyFormatter.amount(1, usd)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}