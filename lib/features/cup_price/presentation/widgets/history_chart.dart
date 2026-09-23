import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/entities/cup_price_point.dart';

/// Line chart of the CUP price over time (X = day index, Y = CUP per USD).
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.points});

  final List<CupPricePoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].cupPerUsd),
    ];
    final minY = points.map((p) => p.cupPerUsd).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.cupPerUsd).reduce((a, b) => a > b ? a : b);

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          minY: minY * 0.97,
          maxY: maxY * 1.03,
          gridData: const FlGridData(show: true),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => [
                for (final spot in touchedSpots)
                  LineTooltipItem(
                    '${points[spot.spotIndex].date.day}/${points[spot.spotIndex].date.month} '
                    '${points[spot.spotIndex].cupPerUsd.toStringAsFixed(2)} CUP',
                    const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: scheme.primary,
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: _leftTitle,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: points.length / 5,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final date = points[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _leftTitle(double value, TitleMeta meta) =>
    Text(value.toStringAsFixed(0), textAlign: TextAlign.right);