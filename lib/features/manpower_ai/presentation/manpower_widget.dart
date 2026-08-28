import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 🚀 Verify these paths match your folder structure exactly
import '../providers/staffing_forecast_provider.dart';
import '../../coach/widgets/info_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart'; // 🚀 Added
import '../../../core/widgets/error_state.dart'; // 🚀 Added

class ManpowerRadarWidget extends ConsumerWidget {
  const ManpowerRadarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 Consuming the new Phase 3 Predictive Engine[cite: 7, 11]
    final forecastState = ref.watch(staffingForecastProvider);
    final cardBg = context.colors.cardBg;
    final textColor = context.colors.textPrimary;
    final adviceTextColor = context.colors.textSecondary;

    return forecastState.when(
      loading: () => const SkeletonBox(
        width: double.infinity,
        height: 350,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ), // 🚀 MATCHES RADAR CARD SIZE
      error: (err, _) => ErrorState(
        message: "Radar Offline: Failed to load staffing forecast.",
        onRetry: () => ref.invalidate(staffingForecastProvider),
      ),
      data: (forecast) {
        Color threatColor;
        IconData threatIcon;
        switch (forecast.rushLevel) {
          case 'CRITICAL':
            threatColor = Colors.purple.shade400;
            threatIcon = Icons.warning;
            break;
          case 'HIGH':
            threatColor = context.colors.danger;
            threatIcon = Icons.local_fire_department;
            break;
          case 'MEDIUM':
            threatColor = Colors.orange.shade400;
            threatIcon = Icons.groups;
            break;
          case 'LOW':
            threatColor = Colors.green.shade400;
            threatIcon = Icons.coffee;
            break;
          default:
            threatColor = Colors.grey;
            threatIcon = Icons.help_outline;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Predictive Staffing Radar 🤖",
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
                          title: 'Predictive Staffing Radar',
                          en: 'Forecasts footfall, orders and staffing needs from historical same-weekday patterns.',
                          hi: 'Pichle comparable dino ke data se footfall aur staffing ka forecast.',
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
                      forecast.hasSufficientData
                          ? "${forecast.rushLevel} RUSH"
                          : "LEARNING",
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
              const SizedBox(height: 4),
              Text(
                forecast.hasSufficientData
                    ? "Forecast for ${forecast.period} • ${forecast.comparisonPeriod}"
                    : "Not enough history yet for ${forecast.period} (${forecast.sampleCount}/3 samples)",
                style: TextStyle(color: adviceTextColor, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // DEPLOYMENT STATS
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cards = [
                    _buildIntelCard(
                      "Expected Footfall (est.)",
                      "${forecast.expectedFootfall}",
                      forecast.hasSufficientData
                          ? "${forecast.footfallLowerBound}-${forecast.footfallUpperBound}"
                          : "",
                      Icons.directions_walk,
                      Colors.blueAccent,
                      context,
                    ),
                    _buildIntelCard(
                      "Cashiers Needed",
                      "${forecast.cashiersRequired}",
                      forecast.backupStaffRequired > 0 ? "+backup" : "",
                      Icons.point_of_sale,
                      threatColor,
                      context,
                    ),
                    _buildIntelCard(
                      "Guards Needed",
                      "${forecast.guardsRequired}",
                      "",
                      Icons.security,
                      threatColor,
                      context,
                    ),
                  ];

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                        const SizedBox(height: 12),
                        cards[2],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // CONFIDENCE[cite: 11]
              if (forecast.hasSufficientData)
                Row(
                  children: [
                    Icon(Icons.insights, size: 14, color: adviceTextColor),
                    const SizedBox(width: 6),
                    Text(
                      "Confidence: ${forecast.confidence}% (${forecast.sampleCount} historical samples)",
                      style: TextStyle(color: adviceTextColor, fontSize: 11),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // COMMANDER'S ADVICE[cite: 11]
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.scaffoldBg,
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
                            forecast.recommendation,
                            style: TextStyle(
                              color: adviceTextColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (forecast.contributingFactors.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...forecast.contributingFactors.map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  "• $f",
                                  style: TextStyle(
                                    color: adviceTextColor.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🚀 PHASE 4B: HISTORICAL COMPARISON UI
              if (forecast.hasSufficientData)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.scaffoldBg,
                    borderRadius: BorderRadius.circular(12),
                    // Dash border for comparison section
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, size: 14, color: adviceTextColor),
                          const SizedBox(width: 6),
                          Text(
                            "HISTORICAL COMPARISON",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: adviceTextColor,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCompareStat("Current Period", "Today", context),
                          _buildCompareStat(
                            "Baseline Match",
                            forecast.comparisonPeriod,
                            context,
                          ),
                          _buildCompareStat(
                            "Target Vol.",
                            "${forecast.expectedOrders} Orders",
                            context,
                          ),
                        ],
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

  // Helper widget for comparison UI
  Widget _buildCompareStat(String label, String value, BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
        color: context.colors.scaffoldBg,
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
                      fontSize: 11,
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
