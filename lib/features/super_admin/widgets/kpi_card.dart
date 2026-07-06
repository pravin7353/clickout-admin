import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';
import '../screens/super_admin_screen.dart'; // For EnterpriseColors/Tokens

class GlassKpiWidget extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final bool isGood;
  final bool isWarning;

  const GlassKpiWidget({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.isGood,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isWarning
        ? context.riskHigh
        : (isGood ? context.accentNeon : context.textSecondary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWarning
                  ? mainColor.withOpacity(0.3)
                  : context.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(icon, color: mainColor, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trend,
                style: TextStyle(
                  color: mainColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
