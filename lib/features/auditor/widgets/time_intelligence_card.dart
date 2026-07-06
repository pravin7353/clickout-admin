import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../../../core/theme/app_theme.dart';

class TimeIntelligenceCard extends ConsumerWidget {
  const TimeIntelligenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(timeAnalyticsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hourly Financial Matrix 📈",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    "Realized Sales (Bars) vs Leakage Risk (Line)",
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegend(Colors.blueAccent, "UPI"),
                  const SizedBox(width: 12),
                  _buildLegend(Colors.green, "Cash"),
                  const SizedBox(width: 12),
                  _buildLegend(Colors.redAccent, "Leakage"),
                ],
              ),
            ],
          ),
          const Divider(height: 30, color: Colors.white10),

          analyticsState.when(
            loading: () => const SizedBox(
              height: 250,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            error: (err, stack) => SizedBox(
              height: 250,
              child: Center(
                child: Text(
                  "Radar Error: $err",
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
            data: (analyticsData) {
              if (analyticsData.isEmpty) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: Text(
                      "No Data",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }

              double maxRev = 0;
              List<BarChartGroupData> barGroups = [];
              List<FlSpot> leakageSpots = [];

              for (int i = 0; i < analyticsData.length; i++) {
                final data = analyticsData[i];
                double totalHour = data.hourlyCash + data.hourlyUpi;
                if (totalHour > maxRev) maxRev = totalHour;
                if (data.hourlyLeakage > maxRev) maxRev = data.hourlyLeakage;

                barGroups.add(
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totalHour,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            data.hourlyUpi,
                            Colors.blueAccent,
                          ), // Bottom: UPI
                          BarChartRodStackItem(
                            data.hourlyUpi,
                            totalHour,
                            Colors.green,
                          ), // Top: Cash
                        ],
                      ),
                    ],
                  ),
                );
                leakageSpots.add(FlSpot(i.toDouble(), data.hourlyLeakage));
              }

              double yAxisMax = maxRev * 1.2;
              if (yAxisMax == 0) yAxisMax = 1000;

              return SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    // 📊 LAYER 1: REVENUE BARS
                    BarChart(
                      BarChartData(
                        maxY: yAxisMax,
                        barGroups: barGroups,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white10,
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
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) {
                                if (v.toInt() < 0 ||
                                    v.toInt() >= analyticsData.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    analyticsData[v.toInt()].timeLabel.split(
                                      ' ',
                                    )[0],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
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
                                "${analyticsData[group.x.toInt()].timeLabel}\n",
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        "UPI: ₹${analyticsData[group.x.toInt()].hourlyUpi.toStringAsFixed(0)}\n",
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        "Cash: ₹${analyticsData[group.x.toInt()].hourlyCash.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // 🔴 LAYER 2: LEAKAGE LINE
                    LineChart(
                      LineChartData(
                        maxY: yAxisMax,
                        lineBarsData: [
                          LineChartBarData(
                            spots: leakageSpots,
                            isCurved: true,
                            color: Colors.redAccent,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            shadow: const Shadow(
                              color: Colors.red,
                              blurRadius: 10,
                            ), // Glow Effect
                          ),
                        ],
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => Colors.black87,
                            getTooltipItems: (spots) => spots
                                .map(
                                  (s) => LineTooltipItem(
                                    "Leakage: ₹${s.y.toStringAsFixed(0)}",
                                    const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
