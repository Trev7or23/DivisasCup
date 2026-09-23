import 'package:flutter/material.dart';

import '../../../../core/domain/entities/exchange_rate.dart';
import '../../../../core/utils/currency_formatter.dart';

/// One comparison row: "1 USD = 24.00 MXN".
///
/// [givenAmount] is the fixed amount in the base currency (1 by default in the
/// comparator) so tiles stay reusable.
class ComparisonTile extends StatelessWidget {
  const ComparisonTile({
    super.key,
    required this.exchangeRate,
    this.givenAmount = 1,
  });

  final ExchangeRate exchangeRate;
  final double givenAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final converted = exchangeRate.convert(givenAmount);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            exchangeRate.quote.code.substring(0, 1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${CurrencyFormatter.amount(givenAmount, exchangeRate.base)} = '
          '${CurrencyFormatter.amount(converted, exchangeRate.quote)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${exchangeRate.quote.name} · '
          '1 ${exchangeRate.quote.code} = '
          '${CurrencyFormatter.rate(1 / exchangeRate.rate)} ${exchangeRate.base.code}',
        ),
        isThreeLine: false,
      ),
    );
  }
}