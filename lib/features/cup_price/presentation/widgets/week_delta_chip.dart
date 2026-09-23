import 'package:flutter/material.dart';

/// Colored chip showing how the CUP price moved in the last 7 days. Positive
/// delta (dollar got more expensive) = red (the peso lost value); negative =
/// green. Always carries text, never color alone.
class WeekDeltaChip extends StatelessWidget {
  const WeekDeltaChip({
    super.key,
    required this.deltaCup,
    required this.deltaPercent,
  });

  final double? deltaCup;
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final delta = deltaCup;
    final percent = deltaPercent;
    if (delta == null || percent == null) return const SizedBox.shrink();

    final rising = delta > 0;
    final color = rising
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF2E7D32);
    final arrow = rising ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${rising ? '▲' : '▼'} '
            '${delta.abs().toStringAsFixed(2)} CUP · '
            '${percent.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}