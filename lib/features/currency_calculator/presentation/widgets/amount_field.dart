import 'package:flutter/material.dart';

/// Numeric input for the amount to convert. The parent owns the
/// [TextEditingController] so typed text survives rebuilds; each keystroke is
/// forwarded parsed as a [double].
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      onChanged: (raw) => onChanged(double.tryParse(raw) ?? 0),
    );
  }
}