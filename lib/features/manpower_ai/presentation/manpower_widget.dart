import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 🚀 THE FIX: Importing REAL Revenue Engine instead of fake AI provider
import '../../revenue_engine/providers/revenue_provider.dart';
import '../../coach/widgets/info_button.dart';

class ManpowerRadarWidget extends ConsumerWidget {
  const ManpowerRadarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Fetching REAL live data from today's orders
    final revenueState = ref.watch(revenueEngineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? isDark
              ? const Color(0xFF111811)
              : Colors.white
        : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B3674);
    final adviceTextColor = isDark ? Colors.white70 : Colors.black87;

    return revenueState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          "Radar Offline: $err",
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (metrics) {
        // 🧠 THE REAL AI ALGORITHM (Based on ACTUAL Today's Orders)
        int realFootfall = metrics.totalOrders;

        // Base Requirements Math
        int cashiers = (realFootfall / 20).ceil();
        if (cashiers < 1) cashiers = 1;

        int guards = (realFootfall / 50).ceil();
        if (guards < 1) guards = 1;

        // Default: LOW RUSH
        String rushLevel = 'LOW';
        String tacticalAdvice =
            'NOMINAL: Steady flow of customers. Standard deployment is sufficient.';
        Color threatColor = isDark ? const Color(0xFF00C853) : Colors.green;
        IconData threatIcon = Icons.coffee;

        // Dynamic Scaling based on REAL footfall
        if (realFootfall >= 100) {
          rushLevel = 'CRITICAL';
          tacticalAdvice =
              'CRITICAL RUSH: Maximum counters must be opened immediately! High risk of queue abandonment.';
          threatColor = isDark ? Colors.purpleAccent : Colors.purple.shade700;
          threatIcon = Icons.warning;
          cashiers += 2; // Extra backup
          guards += 1;
        } else if (realFootfall >= 50) {
          rushLevel = 'HIGH';
          tacticalAdvice =
              'HIGH TRAFFIC: Deploy backup cashiers to prevent queue buildup.';
          threatColor = Colors.redAccent;
          threatIcon = Icons.local_fire_department;
          cashiers += 1;
        } else if (realFootfall >= 20) {
          rushLevel = 'MEDIUM';
          tacticalAdvice =
              'MODERATE RUSH: Monitor queues closely. Keep 1 backup cashier ready.';
          threatColor = Colors.orange;
          threatIcon = Icons.groups;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(
                color: threatColor.withOpacity(isDark ? 0.05 : 0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 RADAR HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Tactical Staffing Radar 🤖",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const InfoButton(
                          title: 'Tactical Staffing Radar',
                          en: 'AI-powered staffing recommendation based on real footfall. Shows how many cashiers and guards are needed right now.',
                          hi: 'Aaj ke real orders ke hisaab se batata hai kitne cashier aur guard chahiye. Kam staff = queue jam = customer loss.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: threatColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$rushLevel RUSH",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🚀 DEPLOYMENT STATS
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildIntelCard(
                          "Expected Footfall",
                          "$realFootfall /today",
                          Icons.directions_walk,
                          Colors.blueAccent,
                          isDark,
                        ),
                        const SizedBox(height: 15),
                        _buildIntelCard(
                          "Cashiers Needed",
                          "$cashiers",
                          Icons.point_of_sale,
                          threatColor,
                          isDark,
                        ),
                        const SizedBox(height: 15),
                        _buildIntelCard(
                          "Guards Needed",
                          "$guards",
                          Icons.security,
                          threatColor,
                          isDark,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _buildIntelCard(
                          "Expected Footfall",
                          "$realFootfall /today",
                          Icons.directions_walk,
                          Colors.blueAccent,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildIntelCard(
                          "Cashiers Needed",
                          "$cashiers",
                          Icons.point_of_sale,
                          threatColor,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildIntelCard(
                          "Guards Needed",
                          "$guards",
                          Icons.security,
                          threatColor,
                          isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // 🛡️ COMMANDER'S ADVICE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: threatColor.withOpacity(isDark ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: threatColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(threatIcon, color: threatColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COMMANDER'S ADVICE:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: threatColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tacticalAdvice,
                            style: TextStyle(
                              color: adviceTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntelCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.05 : 0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
