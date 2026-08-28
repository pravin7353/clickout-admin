// Forecast Engine — Historical Aggregation → Feature Engineering →
// Weighted Forecast → Confidence → Staffing Optimizer
//
// Prediction = Recency-weighted Same-Weekday Pattern × Recent Trend Factor
// Live data yahan sirf secondary signal hai (footfall/order count ke liye),
// primary intelligence history se aata hai — jaisa prompt me maanga gaya tha.
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forecast_result.dart';
import 'historical_operations_provider.dart';
import 'event_intelligence_provider.dart'; // 🚀 Added Event Context

// 🔧 Staffing capacity — configurable, hardcoded nahi.
// Assumption: ~8 operating hours/day. Tenant-level override future me
// store settings se aa sakta hai (Phase 2).
class StaffingCapacityConfig {
  static const int ordersPerCashierPerDay = 160; // ~20/hr * 8hr
  static const int ordersPerGuardPerDay = 400; // ~50/hr * 8hr
}

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

final staffingForecastProvider = FutureProvider.autoDispose<ForecastResult>((
  ref,
) async {
  ref.keepAlive();

  final history = await ref.watch(historicalOperationsProvider.future);
  final today = DateTime.now();
  final weekdayName = _weekdayNames[today.weekday - 1];

  // Same-weekday samples (date field format: YYYY-MM-DD)
  final sameWeekday =
      history.where((d) {
          final dateStr = d['date']?.toString();
          if (dateStr == null) return false;
          final parsed = DateTime.tryParse(dateStr);
          return parsed != null && parsed.weekday == today.weekday;
        }).toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

  const int minSamplesRequired = 3;
  if (sameWeekday.length < minSamplesRequired) {
    return ForecastResult.insufficientData(
      forecastDate: today,
      period: weekdayName,
      sampleCount: sameWeekday.length,
    );
  }

  final samples = sameWeekday.length > 8
      ? sameWeekday.sublist(sameWeekday.length - 8)
      : sameWeekday; // last up to 8, oldest→newest

  // Recency-weighted average (recent weeks weigh more)
  double weightSum = 0, ordersWeighted = 0, revenueWeighted = 0;
  final orderValues = <double>[];
  for (int i = 0; i < samples.length; i++) {
    final w = (i + 1).toDouble(); // oldest=1 ... newest=n
    final orders = (samples[i]['totalOrders'] as num?)?.toDouble() ?? 0;
    final revenue = (samples[i]['totalRevenue'] as num?)?.toDouble() ?? 0;
    orderValues.add(orders);
    ordersWeighted += orders * w;
    revenueWeighted += revenue * w;
    weightSum += w;
  }
  final avgOrders = ordersWeighted / weightSum;
  final avgRevenue = revenueWeighted / weightSum;

  // Variability (coefficient of variation) → drives bounds + confidence
  final mean = orderValues.reduce((a, b) => a + b) / orderValues.length;
  final variance = mean == 0
      ? 0.0
      : orderValues.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            orderValues.length;
  final cv = mean > 0 ? sqrt(variance) / mean : 0.3;

  // Recent trend: last 14 days vs previous 14 days (any weekday)
  double trendFactor = 1.0;
  final last14 = history.where((d) {
    final p = DateTime.tryParse(d['date']?.toString() ?? '');
    return p != null && today.difference(p).inDays <= 14;
  }).toList();
  final prev14 = history.where((d) {
    final p = DateTime.tryParse(d['date']?.toString() ?? '');
    if (p == null) return false;
    final diff = today.difference(p).inDays;
    return diff > 14 && diff <= 28;
  }).toList();

  if (last14.isNotEmpty && prev14.isNotEmpty) {
    final last14Avg =
        last14
            .map((d) => (d['totalOrders'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) /
        last14.length;
    final prev14Avg =
        prev14
            .map((d) => (d['totalOrders'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a + b) /
        prev14.length;
    if (prev14Avg > 0) {
      trendFactor = (last14Avg / prev14Avg).clamp(0.75, 1.25);
    }
  }

  // 🚀 PHASE 5: EVENT INTELLIGENCE INJECTION
  final eventContext = ref.watch(eventIntelligenceProvider);
  final finalMultiplier = trendFactor * eventContext.trafficMultiplier;

  final predictedOrders = (avgOrders * finalMultiplier).round();
  final predictedRevenue = avgRevenue * finalMultiplier;

  final spread = cv.clamp(0.08, 0.35);
  final ordersLower = (predictedOrders * (1 - spread)).round();
  final ordersUpper = (predictedOrders * (1 + spread)).round();
  final revenueLower = predictedRevenue * (1 - spread);
  final revenueUpper = predictedRevenue * (1 + spread);

  // Confidence: more samples + less variability = higher confidence
  int confidence = (100 - (cv * 120) - max(0, (8 - samples.length) * 6))
      .round()
      .clamp(30, 92);

  // Staffing from predicted (not live) footfall
  int cashiers = max(
    1,
    (predictedOrders / StaffingCapacityConfig.ordersPerCashierPerDay).ceil(),
  );
  int guards = max(
    1,
    (predictedOrders / StaffingCapacityConfig.ordersPerGuardPerDay).ceil(),
  );
  final backupStaffRequired = ordersUpper > predictedOrders * 1.15 ? 1 : 0;

  String rushLevel = 'LOW';
  if (predictedOrders >= 500) {
    rushLevel = 'CRITICAL';
    cashiers += 2;
    guards += 1;
  } else if (predictedOrders >= 250) {
    rushLevel = 'HIGH';
    cashiers += 1;
  } else if (predictedOrders >= 100) {
    rushLevel = 'MEDIUM';
  }

  final trendPct = ((trendFactor - 1) * 100).toStringAsFixed(0);
  final factors = <String>[
    'Last ${samples.length} $weekdayName${samples.length > 1 ? 's' : ''} '
        'averaged ${avgOrders.round()} orders '
        '(range ${orderValues.reduce(min).round()}-${orderValues.reduce(max).round()}).',
    if (last14.isNotEmpty && prev14.isNotEmpty)
      'Recent 14-day trend vs previous 14 days: ${trendPct.startsWith('-') ? '' : '+'}$trendPct%.',
    if (eventContext.eventName != null)
      'EVENT DETECTED: ${eventContext.eventName} is expected to drive higher traffic.',
    if (eventContext.isSalaryWeek)
      'SALARY PERIOD: Traffic historically increases during early-month salary weeks.',
    if (backupStaffRequired > 0)
      'Upper-bound estimate ($ordersUpper orders) is notably above expected — spike risk flagged.',
  ];

  String recommendation = rushLevel == 'CRITICAL'
      ? 'CRITICAL: Predicted rush based on history. Deploy maximum counters for $weekdayName.'
      : rushLevel == 'HIGH'
      ? 'HIGH TRAFFIC EXPECTED: Deploy backup cashiers proactively for $weekdayName.'
      : rushLevel == 'MEDIUM'
      ? 'MODERATE: Standard deployment with 1 backup cashier on standby.'
      : 'NOMINAL: Historical pattern shows steady, low traffic for $weekdayName.';

  if (eventContext.trafficMultiplier > 1.1) {
    recommendation = "EVENT ALERT: " + recommendation;
  }

  return ForecastResult(
    hasSufficientData: true,
    sampleCount: samples.length,
    forecastDate: today,
    period: weekdayName,
    // Footfall = estimated proxy from order count (no real visitor-count data source yet)
    expectedFootfall: predictedOrders,
    footfallLowerBound: ordersLower,
    footfallUpperBound: ordersUpper,
    expectedOrders: predictedOrders,
    ordersLowerBound: ordersLower,
    ordersUpperBound: ordersUpper,
    expectedRevenue: predictedRevenue,
    revenueLowerBound: revenueLower,
    revenueUpperBound: revenueUpper,
    cashiersRequired: cashiers,
    guardsRequired: guards,
    backupStaffRequired: backupStaffRequired,
    rushLevel: rushLevel,
    confidence: confidence,
    contributingFactors: factors,
    recommendation: recommendation,
    comparisonPeriod:
        'vs last ${samples.length} $weekdayName${samples.length > 1 ? 's' : ''}',
  );
});
