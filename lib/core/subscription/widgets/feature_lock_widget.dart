// lib/core/subscription/widgets/feature_lock_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/subscription_access_engine.dart';
import '../../providers/access_control_provider.dart';
import 'upgrade_popup.dart';

class FeatureLockWidget extends ConsumerWidget {
  final String route;
  final Widget child;

  const FeatureLockWidget({
    super.key,
    required this.route,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isReadOnlyProvider);
    if (isSuperAdmin) return child;

    // Single source of truth — same logic as sidebar
    final isAllowed = ref.watch(isRouteAllowedProvider(route));
    if (isAllowed) return child;

    // ─── LOCKED STATE ───
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bullets = SubscriptionAccessEngine.getFeatureBullets(route);
    final requiredPlan = SubscriptionAccessEngine.getRequiredPlanName(route);
    final upgradeMessage = SubscriptionAccessEngine.getUpgradeMessage(route);

    return SizedBox.expand(
      child: Stack(
        children: [
          // Blurred background (actual screen barely visible)
          IgnorePointer(child: Opacity(opacity: 0.15, child: child)),

          // Lock overlay
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111811) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Required plan badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Text(
                      '$requiredPlan PLAN',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Upgrade message
                  Text(
                    upgradeMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Feature bullets
                  if (bullets.isNotEmpty)
                    Column(
                      children: bullets
                          .map(
                            (b) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF00C853),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),

                  const SizedBox(height: 28),

                  // Upgrade CTA button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          showUpgradePopup(context: context, route: route),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Upgrade Plan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
