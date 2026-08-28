// Historical Repository Layer
// daily_store_stats se pichle 12 weeks (84 din) ka data padhta hai —
// poori 'orders' collection kabhi download nahi karta (cost optimization).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

final historicalOperationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.keepAlive();

      final adminData = ref.watch(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String? branchCode = adminData?['branchCode'];

      if (tenantId == null || tenantId.isEmpty) return [];

      final since = DateTime.now().subtract(const Duration(days: 84));
      final sinceStr =
          '${since.year.toString().padLeft(4, '0')}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';

      Query query = FirebaseFirestore.instance
          .collection('daily_store_stats')
          .where('tenantId', isEqualTo: tenantId)
          .where('date', isGreaterThanOrEqualTo: sinceStr)
          .orderBy('date', descending: true);

      if (branchCode != null && branchCode.isNotEmpty) {
        query = query.where('branchCode', isEqualTo: branchCode);
      }

      final snap = await query.get();
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    });
