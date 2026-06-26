// lib/core/subscription/widgets/upgrade_popup.dart

import 'package:flutter/material.dart';
import '../engine/subscription_plan.dart';

void showUpgradePopup({required BuildContext context, required String route}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'UpgradePopup',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return const _UpgradePopupContent();
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

class _UpgradePopupContent extends StatefulWidget {
  const _UpgradePopupContent();

  @override
  State<_UpgradePopupContent> createState() => _UpgradePopupContentState();
}

class _UpgradePopupContentState extends State<_UpgradePopupContent> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111811) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black45;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── HEADER ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.07),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFF00C853),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upgrade ClickOut',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scale your retail intelligence',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Billing toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToggleChip(
                            label: 'Monthly',
                            isSelected: !_isYearly,
                            onTap: () => setState(() => _isYearly = false),
                          ),
                          _ToggleChip(
                            label: 'Yearly  🎉 Save 20%',
                            isSelected: _isYearly,
                            onTap: () => setState(() => _isYearly = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── PLAN CARDS ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _PlanCard(
                      plan: SubscriptionPlan.mini,
                      isYearly: _isYearly,
                      isDark: isDark,
                      highlights: [
                        '1 terminal',
                        '100 transactions/month',
                        '2 staff accounts',
                        'Basic revenue dashboard',
                        'IDT deposit validation',
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      plan: SubscriptionPlan.pro,
                      isYearly: _isYearly,
                      isDark: isDark,
                      isRecommended: true,
                      highlights: [
                        '3 terminals',
                        '1000 transactions/month',
                        '4 staff accounts',
                        'Growth Radar + Refund Engine',
                        'Fraud Detection + Procurement',
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      plan: SubscriptionPlan.growth,
                      isYearly: _isYearly,
                      isDark: isDark,
                      highlights: [
                        '5 terminals',
                        'Unlimited transactions',
                        'Unlimited staff',
                        'Risk Engine AI + QR Bailout',
                        'Full Procurement Suite',
                      ],
                    ),
                  ],
                ),
              ),

              // ── FOOTER ──
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(color: subTextColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isYearly;
  final bool isDark;
  final bool isRecommended;
  final List<String> highlights;

  const _PlanCard({
    required this.plan,
    required this.isYearly,
    required this.isDark,
    this.isRecommended = false,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    final price = isYearly ? plan.yearlyPrice : plan.monthlyPrice;
    final cardBg = isDark ? const Color(0xFF1A221A) : Colors.grey.shade50;
    final borderColor = isRecommended
        ? const Color(0xFF00C853)
        : (isDark ? Colors.white12 : Colors.grey.shade200);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    plan.displayName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (isRecommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C853),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '₹$price',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: isYearly ? '/mo' : '/mo',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...highlights.map(
            (h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF00C853),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    h,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Razorpay integration — Task 6
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended
                    ? const Color(0xFF00C853)
                    : Colors.transparent,
                foregroundColor: isRecommended
                    ? Colors.black
                    : (isDark ? Colors.white : Colors.black87),
                side: isRecommended
                    ? null
                    : BorderSide(
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Choose ${plan.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
