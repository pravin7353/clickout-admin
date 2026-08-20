// lib/features/revenue_engine/providers/industry_benchmark_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚡ NEW: Live anonymized industry-average leakage %, computed nightly by
// the computeIndustryBenchmark Cloud Function. Null = not computed yet
// (first 30 days after deploy) — UI should fall back to static estimate.
final industryBenchmarkProvider = StreamProvider<double?>((ref) {
  return FirebaseFirestore.instance
      .collection('platform_fraud_patterns')
      .doc('industry_benchmark')
      .snapshots()
      .map((snap) {
        if (!snap.exists) return null;
        final data = snap.data();
        return (data?['avgLeakagePct'] as num?)?.toDouble();
      });
});
