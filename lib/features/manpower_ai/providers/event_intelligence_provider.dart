import 'package:flutter_riverpod/flutter_riverpod.dart';

// Phase 5: Event Context Layer
class EventContext {
  final bool isSalaryWeek;
  final bool isHoliday;
  final String? eventName;
  final double trafficMultiplier;

  EventContext({
    required this.isSalaryWeek,
    required this.isHoliday,
    this.eventName,
    this.trafficMultiplier = 1.0,
  });
}

final eventIntelligenceProvider = Provider.autoDispose<EventContext>((ref) {
  final today = DateTime.now();

  // Salary week logic (typically 1st to 5th of the month)
  bool isSalary = today.day >= 1 && today.day <= 5;

  // Stubbing a local event calendar for baseline
  // In production, this can sync with a 'store_events' Firestore collection
  String? event;
  double multiplier = 1.0;
  bool isHol = false;

  // Example static rules for Event Intelligence
  if (today.month == 10 && today.day == 31) {
    event = "Diwali Eve";
    isHol = true;
    multiplier = 1.35; // 35% expected bump
  } else if (today.weekday == 6 || today.weekday == 7) {
    multiplier = 1.15; // Standard weekend bump
  }

  if (isSalary) {
    multiplier *= 1.15; // 15% bump for salary week
  }

  return EventContext(
    isSalaryWeek: isSalary,
    isHoliday: isHol,
    eventName: event,
    trafficMultiplier: multiplier,
  );
});
