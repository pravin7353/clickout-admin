import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION IMPORT

// ==========================================
// 🚨 PART 1: THE PRE-CRIME RADAR
// ==========================================

// 🕵️‍♂️ STAFF WATCHLIST
final suspectStaffProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  // 🚀 SAAS INJECTION: Fetch Context
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  Query query = FirebaseFirestore.instance
      .collection('employees')
      .where('trustScore', isLessThan: 80);

  final String? branchCode = adminData?['branchCode'];

  // 🚀 SAAS ISOLATION (Level 1 & 2)
  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }
  if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
    query = query.where('branchCode', isEqualTo: branchCode);
  }

  return query
      .orderBy('trustScore', descending: false)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// 🚨 HIGH-RISK TRANSACTIONS
final highRiskOrdersProvider = StreamProvider<List<QueryDocumentSnapshot>>((
  ref,
) {
  // 🚀 SAAS INJECTION: Fetch Context
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  final now = DateTime.now();
  final last7Days = now.subtract(const Duration(days: 7));

  Query query = FirebaseFirestore.instance
      .collection('orders')
      .where('riskLevel', isEqualTo: 'HIGH')
      .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(last7Days),
      );

  // 🚀 SAAS ISOLATION
  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }

  return query
      .orderBy('timestamp', descending: true)
      .limit(30)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// ==========================================
// ⏱️ PART 2: THE LEAKAGE KANBAN
// ==========================================
class PendingOrder {
  final String orderId;
  final DateTime paidAt;
  final double amount;
  PendingOrder({
    required this.orderId,
    required this.paidAt,
    required this.amount,
  });
}

final pendingOrdersStreamProvider = StreamProvider<List<PendingOrder>>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String? branchCode = adminData?['branchCode'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  Query query = FirebaseFirestore.instance
      .collection('orders')
      .where('paymentStatus', isEqualTo: 'PAID')
      .where('exitStatus', whereIn: ['PENDING', 'READY_FOR_EXIT']);

  // 🚀 SAAS ISOLATION (Level 1 & 2): Stops global read explosion
  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }
  if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
    query = query.where('branchCode', isEqualTo: branchCode);
  }

  return query.snapshots().map((snapshot) {
    final now = DateTime.now();
    List<PendingOrder> pendingList = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime paidTime = now;

      if (data['timestamp'] != null) {
        paidTime = (data['timestamp'] as Timestamp).toDate();
      } else if (data['paidAt'] != null) {
        paidTime = (data['paidAt'] as Timestamp).toDate();
      }

      double amount =
          double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
      DateTime? expiresAt = (data['qrExpiresAt'] as Timestamp?)?.toDate();
      bool isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);

      if (!isExpired) {
        pendingList.add(
          PendingOrder(orderId: doc.id, amount: amount, paidAt: paidTime),
        );
      }
    }
    pendingList.sort((a, b) => a.paidAt.compareTo(b.paidAt));
    return pendingList;
  });
});

class LeakageBuckets {
  final List<PendingOrder> normal, warning, critical, escalated;
  LeakageBuckets({
    this.normal = const [],
    this.warning = const [],
    this.critical = const [],
    this.escalated = const [],
  });
}

final heartbeatProvider = StreamProvider<void>((ref) {
  return Stream.periodic(const Duration(minutes: 1));
});

final leakageBucketProvider = Provider<LeakageBuckets>((ref) {
  final orders = ref.watch(pendingOrdersStreamProvider).value ?? [];
  ref.watch(heartbeatProvider);

  final now = DateTime.now();
  final normal = <PendingOrder>[];
  final warning = <PendingOrder>[];
  final critical = <PendingOrder>[];
  final escalated = <PendingOrder>[];

  for (var order in orders) {
    final elapsed = now.difference(order.paidAt).inMinutes.clamp(0, 999999);

    if (elapsed < 5) {
      normal.add(order);
    } else if (elapsed < 30) {
      warning.add(order);
    } else if (elapsed < 120) {
      critical.add(order);
    } else {
      escalated.add(order);
    }
  }

  return LeakageBuckets(
    normal: normal,
    warning: warning,
    critical: critical,
    escalated: escalated,
  );
});
