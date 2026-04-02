import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/manpower_provider.dart';

class ManpowerRadarWidget extends ConsumerWidget {
  const ManpowerRadarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intel = ref.watch(manpowerAiProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF111811) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B3674);
    final adviceTextColor = isDark ? Colors.white70 : Colors.black87;

    // 🎯 TACTICAL COLOR CODING
    Color threatColor;
    IconData threatIcon;

    switch (intel.rushLevel) {
      case 'CRITICAL':
        threatColor = isDark ? Colors.purpleAccent : Colors.purple.shade700;
        threatIcon = Icons.warning;
        break;
      case 'HIGH':
        threatColor = Colors.redAccent;
        threatIcon = Icons.local_fire_department;
        break;
      case 'MEDIUM':
        threatColor = Colors.orange;
        threatIcon = Icons.groups;
        break;
      case 'LOW':
      default:
        threatColor = isDark ? const Color(0xFF00C853) : Colors.green;
        threatIcon = Icons.coffee;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: threatColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: threatColor.withOpacity(isDark ? 0.05 : 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 RADAR HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tactical Staffing Radar 🤖",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
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
                  "${intel.rushLevel} RUSH",
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

          // 📊 DEPLOYMENT STATS
          Row(
            children: [
              Expanded(
                child: _buildIntelCard(
                  "Expected Footfall",
                  "${intel.expectedFootfall} /hr",
                  Icons.directions_walk,
                  Colors.blueAccent,
                  isDark,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildIntelCard(
                  "Cashiers Needed",
                  "${intel.recommendedCashiers}",
                  Icons.point_of_sale,
                  threatColor,
                  isDark,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildIntelCard(
                  "Guards Needed",
                  "${intel.recommendedGuards}",
                  Icons.security,
                  threatColor,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🛡️ COMMANDER'S ADVICE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: threatColor.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: threatColor.withOpacity(isDark ? 0.3 : 0),
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
                        intel.tacticalAdvice,
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
        color: color.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey,
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
