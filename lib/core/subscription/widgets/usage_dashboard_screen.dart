// lib/core/subscription/widgets/usage_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../engine/subscription_plan.dart';

class UsageDashboardScreen extends ConsumerWidget {
  const UsageDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(subscriptionPlanProvider);
    final usageAsync = ref.watch(usageLedgerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF080B08) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF111811) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bgColor,
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (usage) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usage Dashboard',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current billing period',
                          style: TextStyle(color: subColor, fontSize: 13),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Plan badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _planColor(plan).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _planColor(plan).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '${plan.displayName.toUpperCase()} PLAN',
                        style: TextStyle(
                          color: _planColor(plan),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Usage Cards
                _UsageCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Transactions',
                  current: usage.transactionCount,
                  max: plan.maxTransactions,
                  color: Colors.blueAccent,
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                ),
                const SizedBox(height: 16),
                _UsageCard(
                  icon: Icons.people_rounded,
                  title: 'Staff Accounts',
                  current: usage.staffCount,
                  max: plan.maxStaff,
                  color: Colors.purpleAccent,
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                ),
                const SizedBox(height: 16),
                _UsageCard(
                  icon: Icons.campaign_rounded,
                  title: 'Offer Campaigns',
                  current: usage.campaignCount,
                  max: plan.maxCampaigns,
                  color: Colors.orangeAccent,
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                ),
                const SizedBox(height: 16),
                _UsageCard(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Terminals',
                  current: 1, // TODO: dynamic terminal count
                  max: plan.maxTerminals,
                  color: const Color(0xFF00C853),
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                ),

                const SizedBox(height: 32),

                // Plan comparison hint
                if (plan != SubscriptionPlan.growth &&
                    plan != SubscriptionPlan.enterprise)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00C853).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Plan Benefits',
                          style: TextStyle(
                            color: const Color(0xFF00C853),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._nextPlanBenefits(plan).map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFF00C853),
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  b,
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _planColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.trial:
        return Colors.amber;
      case SubscriptionPlan.mini:
        return Colors.blueGrey;
      case SubscriptionPlan.pro:
        return Colors.blueAccent;
      case SubscriptionPlan.growth:
        return const Color(0xFF00C853);
      case SubscriptionPlan.enterprise:
        return Colors.purpleAccent;
    }
  }

  List<String> _nextPlanBenefits(SubscriptionPlan plan) {
    if (plan == SubscriptionPlan.mini || plan == SubscriptionPlan.trial) {
      return [
        'PRO: 1000 transactions/month',
        'PRO: 4 staff accounts',
        'PRO: Growth Radar + Refund Engine',
        'PRO: Fraud Detection + Procurement',
      ];
    }
    return [
      'GROWTH: Unlimited transactions',
      'GROWTH: Unlimited staff',
      'GROWTH: Risk Engine AI + QR Bailout',
      'GROWTH: Full Procurement Suite',
    ];
  }
}

class _UsageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int current;
  final int max;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subColor;

  const _UsageCard({
    required this.icon,
    required this.title,
    required this.current,
    required this.max,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlimited = max == 999999;
    final percent = isUnlimited ? 0.0 : (current / max).clamp(0.0, 1.0);
    final isWarning = !isUnlimited && percent >= 0.9;
    final isMaxed = !isUnlimited && current >= max;
    final displayColor = isMaxed
        ? Colors.redAccent
        : isWarning
        ? Colors.amber
        : color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMaxed
              ? Colors.redAccent.withValues(alpha: 0.4)
              : isWarning
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: displayColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (isMaxed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIMIT REACHED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$current',
                      style: TextStyle(
                        color: displayColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: isUnlimited ? ' / ∞' : ' / $max',
                      style: TextStyle(color: subColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Text(
                isUnlimited
                    ? 'Unlimited'
                    : '${((1 - percent) * max).round()} remaining',
                style: TextStyle(color: subColor, fontSize: 13),
              ),
            ],
          ),
          if (!isUnlimited) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: displayColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(percent * 100).round()}% used',
              style: TextStyle(color: subColor, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
