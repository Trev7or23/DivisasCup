import 'package:flutter/material.dart';

import '../domain/entities/currency.dart';

/// Material 3 currency picker used by both feature screens. Items display the
/// ISO code (symbols collide: $, R$, ...) with the full name as tooltip/label.
///
/// Uses `initialValue` (the non-deprecated replacement for `value`); the form
/// field re-syncs whenever a new [selected] currency arrives via
/// `didUpdateWidget`.
class CurrencyDropdownButton extends StatelessWidget {
  const CurrencyDropdownButton({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<Currency> items;
  final Currency? selected;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Currency>(

      decoration: InputDecoration(labelText: label),
      initialValue: selected,
      items: [
        for (final currency in items)
          DropdownMenuItem(
            value: currency,
            child: Text(currency.code, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
      onChanged: (currency) {
        if (currency != null) onChanged(currency);
      },
    );
  }
}