// lib/features/super_admin/providers/trust_score_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ⚡ NEW: Per-tenant Trust Score — % of gross revenue jo pichle 30 din mein
// cleanly guard-verified hua (pending/leakage nahi). Same data source jo
// Industry Benchmark aur Monthly Report use karte hain.
final trustScoreProvider = FutureProvider.autoDispose.family<double?, String>((
  ref,
  tenantId,
) async {
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  final sinceStr = thirtyDaysAgo.toIso8601String().split('T')[0];

  final snap = await FirebaseFirestore.instance
      .collection('daily_store_stats')
      .where('tenantId', isEqualTo: tenantId)
      .where('date', isGreaterThanOrEqualTo: sinceStr)
      .get();

  if (snap.docs.isEmpty) return null;

  double totalRevenue = 0;
  double totalLeakage = 0;
  for (final doc in snap.docs) {
    final d = doc.data();
    totalRevenue += (d['totalRevenue'] as num?)?.toDouble() ?? 0;
    totalLeakage += (d['totalLeakage'] as num?)?.toDouble() ?? 0;
  }

  if (totalRevenue == 0) return null;
  return ((totalRevenue - totalLeakage) / totalRevenue) * 100;
});
