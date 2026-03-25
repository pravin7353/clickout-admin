import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🪖 1. TACTICAL INTEL MODEL (Data Structure)
class StaffingIntel {
  final String rushLevel; // LOW, MEDIUM, HIGH, CRITICAL
  final int expectedFootfall;
  final int recommendedGuards;
  final int recommendedCashiers;
  final String tacticalAdvice;

  StaffingIntel({
    required this.rushLevel,
    required this.expectedFootfall,
    required this.recommendedGuards,
    required this.recommendedCashiers,
    required this.tacticalAdvice,
  });
}

// 🧠 2. THE MILITARY AI ENGINE (Notifier)
class ManpowerAiNotifier extends Notifier<StaffingIntel> {
  @override
  StaffingIntel build() {
    return _generateIntel(DateTime.now());
  }

  // 📡 INTELLIGENCE GATHERING LOGIC
  StaffingIntel _generateIntel(DateTime currentTime) {
    int hour = currentTime.hour;
    int weekday = currentTime.weekday; // 1 = Mon, 7 = Sun

    bool isWeekend = (weekday == 6 || weekday == 7);
    bool isEveningRush = (hour >= 17 && hour <= 21); // 5 PM to 9 PM
    bool isMorningDeadZone = (hour >= 8 && hour <= 11);

    // 🚨 THREAT LEVEL CALCULATION (Rule-Based ML-Lite)
    if (isWeekend && isEveningRush) {
      return StaffingIntel(
        rushLevel: 'CRITICAL',
        expectedFootfall: 500, // Expected customers per hour
        recommendedGuards: 4, // All hands on deck at the gates
        recommendedCashiers: 6,
        tacticalAdvice:
            "CRITICAL ALERT: Weekend evening rush. Deploy maximum troops at exits to prevent theft.",
      );
    } else if (isWeekend || isEveningRush) {
      return StaffingIntel(
        rushLevel: 'HIGH',
        expectedFootfall: 250,
        recommendedGuards: 2,
        recommendedCashiers: 4,
        tacticalAdvice:
            "HIGH ALERT: Crowd building up. Ensure at least 2 guards are actively scanning QRs.",
      );
    } else if (isMorningDeadZone) {
      return StaffingIntel(
        rushLevel: 'LOW',
        expectedFootfall: 50,
        recommendedGuards: 1,
        recommendedCashiers: 1, // Save money!
        tacticalAdvice:
            "STAND DOWN: Low footfall. Keep minimum skeleton crew. Send extra staff for inventory audit.",
      );
    } else {
      return StaffingIntel(
        rushLevel: 'MEDIUM',
        expectedFootfall: 120,
        recommendedGuards: 1,
        recommendedCashiers: 2,
        tacticalAdvice:
            "NOMINAL: Standard deployment. Maintain regular vigilance.",
      );
    }
  }

  // Admin can simulate future intel (e.g. "What will happen at 7 PM today?")
  void simulateFuture(int targetHour) {
    final now = DateTime.now();
    state = _generateIntel(DateTime(now.year, now.month, now.day, targetHour));
  }
}

final manpowerAiProvider = NotifierProvider<ManpowerAiNotifier, StaffingIntel>(
  () {
    return ManpowerAiNotifier();
  },
);
