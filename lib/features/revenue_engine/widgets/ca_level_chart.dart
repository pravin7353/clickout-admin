import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class CaLevelMatrixChart extends StatelessWidget {
  final Map<int, Map<String, double>> hourlyData;

  const CaLevelMatrixChart({super.key, required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
      return const Center(child: Text("No financial data to render."));
    }

    double maxRev = 0;
    double totalRev = 0;
    List<int> sortedHours = hourlyData.keys.toList()..sort();

    List<BarChartGroupData> barGroups = [];
    List<FlSpot> riskSpots = [];

    for (int i = 0; i < sortedHours.length; i++) {
      int hour = sortedHours[i];
      double cash = hourlyData[hour]!['cash'] ?? 0;
      double upi = hourlyData[hour]!['upi'] ?? 0;
      double risk = hourlyData[hour]!['risk'] ?? 0;

      double totalHour = cash + upi;
      if (totalHour > maxRev) maxRev = totalHour;
      totalRev += totalHour;

      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: totalHour,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              rodStackItems: [
                BarChartRodStackItem(0, upi, Colors.blueAccent), // UPI Bottom
                BarChartRodStackItem(upi, totalHour, Colors.green), // Cash Top
              ],
            ),
          ],
        ),
      );
      riskSpots.add(FlSpot(hour.toDouble(), risk));
    }

    double avgRev = sortedHours.isEmpty ? 0 : totalRev / sortedHours.length;
    double yAxisMax = maxRev * 1.3; // 30% headroom for visuals

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Stack(
        children: [
          // LAYER 1: BARS (REVENUE)
          BarChart(
            BarChartData(
              maxY: yAxisMax,
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: context.colors.border,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                      "₹${v.toInt()}",
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(
                      "${v.toInt()}:00",
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, _, rod, __) {
                    return BarTooltipItem(
                      "Hour: ${group.x}:00\n",
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text:
                              "UPI: ₹${rod.rodStackItems[0].toY.toStringAsFixed(0)}\n",
                          style: const TextStyle(color: Colors.blueAccent),
                        ),
                        TextSpan(
                          text:
                              "Cash: ₹${(rod.toY - rod.rodStackItems[0].toY).toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // LAYER 2: RISK LINE & AVERAGE OVERLAY
          LineChart(
            LineChartData(
              maxY: yAxisMax,
              lineBarsData: [
                LineChartBarData(
                  spots: riskSpots,
                  isCurved: true,
                  color: Colors.redAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  shadow: const Shadow(
                    color: Colors.red,
                    blurRadius: 10,
                  ), // Anomaly Glow
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: avgRev,
                    color: Colors.amber.withOpacity(0.5),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      style: const TextStyle(color: Colors.amber, fontSize: 10),
                      labelResolver: (_) => "AVG: ₹${avgRev.toInt()}",
                    ),
                  ),
                ],
              ),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ],
      ),
    );
  }
}
