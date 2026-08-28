// Predictive Staffing Radar - Forecast Output Model
// Har number Firestore ke daily_store_stats se calculate hota hai.
// Kabhi fabricate/invent nahi hota - agar data kam hai to hasSufficientData=false.
class ForecastResult {
  final bool hasSufficientData;
  final int sampleCount;
  final DateTime forecastDate;
  final String period; // e.g. "Wednesday"

  // Footfall = estimated proxy (order count based), NOT actual visitor count
  final int expectedFootfall;
  final int footfallLowerBound;
  final int footfallUpperBound;

  final int expectedOrders;
  final int ordersLowerBound;
  final int ordersUpperBound;

  final double expectedRevenue;
  final double revenueLowerBound;
  final double revenueUpperBound;

  final int cashiersRequired;
  final int guardsRequired;
  final int backupStaffRequired;

  final String rushLevel; // LOW, MEDIUM, HIGH, CRITICAL

  final int confidence; // 0-100
  final List<String> contributingFactors;
  final String recommendation;
  final String comparisonPeriod;

  const ForecastResult({
    required this.hasSufficientData,
    required this.sampleCount,
    required this.forecastDate,
    required this.period,
    required this.expectedFootfall,
    required this.footfallLowerBound,
    required this.footfallUpperBound,
    required this.expectedOrders,
    required this.ordersLowerBound,
    required this.ordersUpperBound,
    required this.expectedRevenue,
    required this.revenueLowerBound,
    required this.revenueUpperBound,
    required this.cashiersRequired,
    required this.guardsRequired,
    required this.backupStaffRequired,
    required this.rushLevel,
    required this.confidence,
    required this.contributingFactors,
    required this.recommendation,
    required this.comparisonPeriod,
  });

  factory ForecastResult.insufficientData({
    required DateTime forecastDate,
    required String period,
    required int sampleCount,
  }) {
    return ForecastResult(
      hasSufficientData: false,
      sampleCount: sampleCount,
      forecastDate: forecastDate,
      period: period,
      expectedFootfall: 0,
      footfallLowerBound: 0,
      footfallUpperBound: 0,
      expectedOrders: 0,
      ordersLowerBound: 0,
      ordersUpperBound: 0,
      expectedRevenue: 0,
      revenueLowerBound: 0,
      revenueUpperBound: 0,
      // Safe minimum baseline staffing jab tak enough history na ho
      cashiersRequired: 1,
      guardsRequired: 1,
      backupStaffRequired: 0,
      rushLevel: 'UNKNOWN',
      confidence: 0,
      contributingFactors: const [],
      recommendation:
          'Insufficient historical data for a reliable forecast. Minimum baseline staffing shown.',
      comparisonPeriod: 'N/A',
    );
  }
}
