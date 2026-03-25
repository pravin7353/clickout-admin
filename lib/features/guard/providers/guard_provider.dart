import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION

final pendingExitsProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  // 🚀 SAAS INJECTION: Get Tenant
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  Query query = FirebaseFirestore.instance
      .collection('orders')
      .where('paymentStatus', isEqualTo: 'PAID')
      .where('exitStatus', isEqualTo: 'PENDING')
      .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );

  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }

  return query
      .orderBy('timestamp', descending: true)
      .limit(30)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// Added 'FORCE_OVERRIDDEN' so overrides show up in the Recent Gate Activity Table
final gateHistoryProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  // 🚀 SAAS INJECTION: Get Tenant
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  Query query = FirebaseFirestore.instance
      .collection('orders')
      .where(
        'exitStatus',
        whereIn: ['APPROVED', 'REJECTED', 'COMPLETED', 'FORCE_OVERRIDDEN'],
      )
      .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );

  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }

  return query
      .orderBy('timestamp', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});
