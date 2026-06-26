// lib/core/subscription/widgets/trial_countdown_badge.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/access_control_provider.dart';
import 'upgrade_popup.dart';

class TrialCountdownBadge extends ConsumerWidget {
  const TrialCountdownBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysRemaining = ref.watch(trialDaysRemainingProvider);
    final plan = ref.watch(currentPlanProvider);

    // Paid plan hai ya trial khatam — badge mat dikhao
    if (daysRemaining < 0) return const SizedBox.shrink();
    if (plan != 'trial') return const SizedBox.shrink();

    final isUrgent = daysRemaining <= 1;
    final badgeColor = isUrgent ? Colors.redAccent : Colors.amber;

    return GestureDetector(
      onTap: () => showUpgradePopup(context: context, route: '/growth'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUrgent
                  ? Icons.warning_amber_rounded
                  : Icons.access_time_rounded,
              color: badgeColor,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              daysRemaining == 0
                  ? 'Trial ends today!'
                  : 'Trial: $daysRemaining day${daysRemaining == 1 ? '' : 's'} left',
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '→ Upgrade',
              style: TextStyle(
                color: badgeColor.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
