import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Ensure this path matches your project structure
import '../providers/revenue_provider.dart';

class FinanceDashboardWidget extends ConsumerWidget {
  const FinanceDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueState = ref.watch(revenueEngineProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: revenueState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2B3674)),
        ),
        error: (err, _) => Center(
          child: Text(
            "🚨 Error: $err",
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (metrics) {
          // 🧠 ISRO-LEVEL MATH: Calculate Rates for Smart Insights
          double rejectionRate = metrics.grossRevenue > 0
              ? (metrics.rejectedRevenue / metrics.grossRevenue) * 100
              : 0.0;

          double pendingRate = metrics.grossRevenue > 0
              ? (metrics.pendingRevenue / metrics.grossRevenue) * 100
              : 0.0;

          // 🔥 DYNAMIC HEATMAP: Generated locally from O(1) read data (Zero extra cost)
          Map<String, double> hourlyHeatmap = {};
          for (var order in metrics.dailyOrders) {
            DateTime dt =
                (order['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            String hour = dt.hour.toString();
            double amount = order['amount'] ?? 0.0;
            hourlyHeatmap[hour] = (hourlyHeatmap[hour] ?? 0.0) + amount;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Financial Command Center 💰",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3674),
                ),
              ),
              const SizedBox(height: 15),

              // 🧠 SMART INSIGHTS (Aligned with new Gate-Pass Logic)
              _buildSmartInsights(rejectionRate, pendingRate),
              const SizedBox(height: 20),

              // 📈 KPI CARDS (Aligned with Gross - Pending - Rejected = Total)
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1000
                    ? 4
                    : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildKPI(
                    "Gross Collection",
                    "₹${metrics.grossRevenue.toStringAsFixed(0)}",
                    Colors.blue,
                  ),
                  _buildKPI(
                    "Secured (Exited)",
                    "₹${metrics.totalRevenue.toStringAsFixed(0)}",
                    Colors.green,
                  ),
                  _buildKPI(
                    "Pending Clearance",
                    "₹${metrics.pendingRevenue.toStringAsFixed(0)}",
                    Colors.orange,
                  ),
                  _buildKPI(
                    "Rejected Leakage",
                    "₹${metrics.rejectedRevenue.toStringAsFixed(0)}",
                    Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 📊 HEATMAP CHART (Now entirely cost-free!)
              const Text(
                "Hourly Revenue Heatmap",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3674),
                ),
              ),
              const SizedBox(height: 15),
              _buildHourlyHeatmapChart(hourlyHeatmap),
            ],
          );
        },
      ),
    );
  }

  // 🧠 SMART INSIGHTS ENGINE
  Widget _buildSmartInsights(double rejectionRate, double pendingRate) {
    List<String> insights = [];

    if (rejectionRate > 10.0) {
      insights.add(
        "🚨 CRITICAL: Guard rejection rate is high (>10%). Audit exit process immediately.",
      );
    }
    if (pendingRate > 20.0) {
      insights.add(
        "⚠️ WARNING: 20%+ of today's revenue is pending exit. Guard queue might be blocked.",
      );
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insights
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  i,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // 📈 KPI CARD BUILDER
  Widget _buildKPI(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 📊 HEATMAP CHART BUILDER
  Widget _buildHourlyHeatmapChart(Map<String, double> heatmap) {
    if (heatmap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No heatmap data available yet.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort the hours logically (e.g., "10", "11", "12")
    List<String> sortedHours = heatmap.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "${value.toInt()}:00",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: sortedHours.map((hour) {
            return BarChartGroupData(
              x: int.parse(hour),
              barRods: [
                BarChartRodData(
                  toY: heatmap[hour]!,
                  color: Colors.blueAccent,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
