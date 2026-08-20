import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final recentTransactionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.keepAlive();
      return FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
          );
    });

// ⚡ NEW: Real-time MRR and Subscription Aggregation
final revenueMetricsProvider = StreamProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    ref.keepAlive();
    return FirebaseFirestore.instance
        .collection('tenants')
        // 🚀 COST FIX: MRR aggregation poore tenants collection ko bina limit
        // ke stream karta tha. Safety cap laga diya; agar tenants 2000 se
        // zyada ho jayein, isse server-side aggregation (Cloud Function jo
        // 'platform_metrics' doc maintain kare) me convert karna better hoga.
        .limit(2000)
        .snapshots()
        .map((
      snap,
    ) {
      int mrr = 0;
      int activeSubs = 0;
      int pendingDues = 0;

      for (var doc in snap.docs) {
        final data = doc.data();
        final amount = (data['monthlyAmount'] as num?)?.toInt() ?? 0;

        if (data['isActive'] == true && data['billingStatus'] == 'ACTIVE') {
          activeSubs++;
          mrr += amount;
        }

        if (data['billingStatus'] == 'EXPIRED' ||
            data['billingStatus'] == 'SUSPENDED') {
          pendingDues += amount;
        }
      }

      return {'mrr': mrr, 'activeSubs': activeSubs, 'pendingDues': pendingDues};
    });
  },
);
