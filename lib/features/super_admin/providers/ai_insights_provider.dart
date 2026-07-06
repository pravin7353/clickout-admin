import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simulating AI Engine recommendations (usually fetched from a Python/FastAPI microservice)
final aiRecommendationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.keepAlive();
  await Future.delayed(const Duration(milliseconds: 1200));
  return [
    {
      'title': 'High Shrinkage Probability Detected',
      'description':
          'Store JAI_004 showing patterns matching historical fraud events. Recommend enforcing 100% Guard Verification for 48 hours.',
      'risk': 'CRITICAL',
    },
    {
      'title': 'Traffic Surge Forecast',
      'description':
          'Predicting 300% transaction spike across Mumbai branches between 6 PM - 9 PM today. Auto-scaling PG database nodes.',
      'risk': 'INFO',
    },
    {
      'title': 'Tenant Churn Alert',
      'description':
          'Client "FreshMart" shows a 45% drop in active POS terminals over 7 days. Recommend account manager intervention.',
      'risk': 'HIGH',
    },
  ];
});
