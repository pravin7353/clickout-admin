import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../revenue_engine/providers/revenue_provider.dart';
import '../../coach/widgets/info_button.dart';
import '../../../core/theme/app_theme.dart';

class ManpowerRadarWidget extends ConsumerWidget {
  const ManpowerRadarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueState = ref.watch(revenueEngineProvider);
    final cardBg = context.colors.cardBg;
    final textColor = context.colors.textPrimary;
    final adviceTextColor = context.colors.textSecondary;

    return revenueState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          "Radar Offline: $err",
          style: TextStyle(color: context.colors.danger),
        ),
      ),
      data: (metrics) {
        int realFootfall = metrics.totalOrders;

        int cashiers = (realFootfall / 20).ceil();
        if (cashiers < 1) cashiers = 1;

        int guards = (realFootfall / 50).ceil();
        if (guards < 1) guards = 1;

        String rushLevel = 'LOW';
        String tacticalAdvice =
            'NOMINAL: Steady flow of customers. Standard deployment is sufficient.';
        Color threatColor = Colors.green.shade400; // Muted green
        IconData threatIcon = Icons.coffee;

        if (realFootfall >= 100) {
          rushLevel = 'CRITICAL';
          tacticalAdvice =
              'CRITICAL RUSH: Maximum counters must be opened immediately! High risk of queue abandonment.';
          threatColor = Colors.purple.shade400;
          threatIcon = Icons.warning;
          cashiers += 2;
          guards += 1;
        } else if (realFootfall >= 50) {
          rushLevel = 'HIGH';
          tacticalAdvice =
              'HIGH TRAFFIC: Deploy backup cashiers to prevent queue buildup.';
          threatColor = context.colors.danger;
          threatIcon = Icons.local_fire_department;
          cashiers += 1;
        } else if (realFootfall >= 20) {
          rushLevel = 'MEDIUM';
          tacticalAdvice =
              'MODERATE RUSH: Monitor queues closely. Keep 1 backup cashier ready.';
          threatColor = Colors.orange.shade400;
          threatIcon = Icons.groups;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), // Subtle shadow
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 RADAR HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Tactical Staffing Radar 🤖",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const InfoButton(
                          title: 'Tactical Staffing Radar',
                          en: 'AI-powered staffing recommendation based on real footfall.',
                          hi: 'Aaj ke real orders ke hisaab se staff deployment.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: threatColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: threatColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      "$rushLevel RUSH",
                      style: TextStyle(
                        color: threatColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

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
                          "$realFootfall",
                          "/today",
                          Icons.directions_walk,
                          Colors.blueAccent,
                          context,
                        ),
                        const SizedBox(height: 12),
                        _buildIntelCard(
                          "Cashiers Needed",
                          "$cashiers",
                          "",
                          Icons.point_of_sale,
                          threatColor,
                          context,
                        ),
                        const SizedBox(height: 12),
                        _buildIntelCard(
                          "Guards Needed",
                          "$guards",
                          "",
                          Icons.security,
                          threatColor,
                          context,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _buildIntelCard(
                          "Expected Footfall",
                          "$realFootfall",
                          "/today",
                          Icons.directions_walk,
                          Colors.blueAccent,
                          context,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildIntelCard(
                          "Cashiers Needed",
                          "$cashiers",
                          "",
                          Icons.point_of_sale,
                          threatColor,
                          context,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildIntelCard(
                          "Guards Needed",
                          "$guards",
                          "",
                          Icons.security,
                          threatColor,
                          context,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // 🛡️ COMMANDER'S ADVICE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.scaffoldBg, // Darker inset background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(threatIcon, color: threatColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "COMMANDER'S ADVICE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: threatColor,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tacticalAdvice,
                            style: TextStyle(
                              color: adviceTextColor,
                              fontSize: 13,
                              height: 1.4,
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
    String suffix,
    IconData icon,
    Color color,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.scaffoldBg, // Inset effect
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              if (suffix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(
                    suffix,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
