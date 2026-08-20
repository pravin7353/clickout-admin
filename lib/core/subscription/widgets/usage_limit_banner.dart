// lib/core/subscription/widgets/usage_limit_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';
import '../engine/subscription_plan.dart';
import 'upgrade_popup.dart';

class UsageLimitBanner extends ConsumerWidget {
  const UsageLimitBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransactionWarning = ref.watch(isTransactionWarningProvider);
    final isCampaignLimitReached = ref.watch(isCampaignLimitReachedProvider);
    final isStaffLimitReached = ref.watch(isStaffLimitReachedProvider);
    final plan = ref.watch(subscriptionPlanProvider);
    final usageAsync = ref.watch(usageLedgerProvider);

    // Koi bhi warning nahi hai to kuch mat dikhao
    if (!isTransactionWarning &&
        !isCampaignLimitReached &&
        !isStaffLimitReached) {
      return const SizedBox.shrink();
    }

    String message = '';
    String subMessage = '';
    IconData icon = Icons.warning_amber_rounded;
    Color bannerColor = Colors.amber;

    if (isTransactionWarning) {
      final usage = usageAsync.value;
      final current = usage?.transactionCount ?? 0;
      final max = plan.maxTransactions;
      message = '⚡ You\'re growing fast — $current/$max transactions used';
      subMessage = 'Upgrade to PRO for 1000 transactions + customer analytics';
    } else if (isCampaignLimitReached) {
      message = '🚫 Campaign limit reached (10/10)';
      subMessage = 'Upgrade to GROWTH for unlimited offer campaigns';
      bannerColor = Colors.redAccent;
    } else if (isStaffLimitReached) {
      message = '🚫 Staff limit reached for ${plan.displayName} plan';
      subMessage = 'Upgrade to add more team members';
      bannerColor = Colors.redAccent;
    }

    return GestureDetector(
      onTap: () => showUpgradePopup(context: context, route: '/growth'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: bannerColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: bannerColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subMessage,
                    style: TextStyle(
                      color: bannerColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Upgrade',
                style: TextStyle(
                  color: bannerColor == Colors.amber
                      ? Colors.black
                      : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
