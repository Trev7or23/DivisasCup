import 'package:flutter/material.dart';

import '../../../../core/domain/entities/currency.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Displays the conversion summary: the main result plus the direct and
/// inverse rates, so the user can sanity-check any 1-to-1 conversion.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.label,
    required this.amount,
    required this.from,
    required this.to,
    this.result,
    this.rate,
  });

  final String label;
  final double amount;
  final Currency from;
  final Currency to;
  final double? result;
  final double? rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    final rate = this.rate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            if (result != null)
              Text(
                '${CurrencyFormatter.amount(amount, from)} = '
                '${CurrencyFormatter.amount(result, to)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Text(
                '—',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            const SizedBox(height: 12),
            if (rate != null) ...[
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 12),
              _RateLine(
                text:
                    '1 ${from.code} = '
                    '${CurrencyFormatter.rate(rate)} ${to.code}',
              ),
              _RateLine(
                text:
                    '1 ${to.code} = '
                    '${CurrencyFormatter.rate(1 / rate)} ${from.code}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}