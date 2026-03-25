import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

// 📊 CA-LEVEL FINANCIAL MODEL (Realized Accounting)
class DailyFinancials {
  final double totalRevenue;
  final double cashExpected;
  final double digitalExpected;

  final double totalLeakage;
  final double cashLeakage;
  final double digitalLeakage;

  final int totalOrders;
  final int rejectedCount;
  final int pendingCount;

  final int refundCount;
  final double refundAmount;

  final List<String> activeAlerts;

  DailyFinancials({
    this.totalRevenue = 0,
    this.cashExpected = 0,
    this.digitalExpected = 0,
    this.totalLeakage = 0,
    this.cashLeakage = 0,
    this.digitalLeakage = 0,
    this.totalOrders = 0,
    this.rejectedCount = 0,
    this.pendingCount = 0,
    this.refundCount = 0,
    this.refundAmount = 0,
    this.activeAlerts = const [],
  });
}

// 🚀 THE FINANCIAL INTELLIGENCE ENGINE
final dailyFinancialsProvider = StreamProvider<DailyFinancials>((ref) {
  // 🚀 SAAS INJECTION: Fetch Current Admin Role & Tenant
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  Query query = FirebaseFirestore.instance
      .collection('orders')
      .where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );

  // 🚀 SAAS ISOLATION: Super Admin sees all, Tenant Admin sees only their data
  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }

  return query.snapshots().map((snapshot) {
    double revTotal = 0, revCash = 0, revUpi = 0;
    double leakTotal = 0, leakCash = 0, leakUpi = 0;
    int orders = 0, rejected = 0, pendingCount = 0;
    int refunds = 0;
    double refAmount = 0;
    List<String> alerts = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final double amount = (data['totalAmount'] ?? 0).toDouble();
      final String mode = data['paymentMode'] ?? '';
      final String pStatus = data['paymentStatus'] ?? '';
      final String eStatus = data['exitStatus'] ?? '';

      orders++;

      if (eStatus == 'REJECTED') {
        rejected++;
      }

      bool isRefund = (pStatus == 'REFUNDED');
      bool isExited = (eStatus == 'EXITED' || eStatus == 'APPROVED');
      bool isPending =
          (eStatus == 'PENDING' ||
          eStatus == 'EXPIRED_BY_SYSTEM' ||
          eStatus == '');

      if (isRefund) {
        refunds++;
        refAmount += amount;
      } else if (pStatus == 'PAID' || pStatus == 'SUCCESS') {
        if (isExited) {
          revTotal += amount;
          if (mode == 'CASH') {
            revCash += amount;
          } else {
            revUpi += amount;
          }
        } else if (isPending) {
          // 🔴 FINANCIAL LEAKAGE
          leakTotal += amount;
          pendingCount++;
          if (mode == 'CASH') {
            leakCash += amount;
          } else {
            leakUpi += amount;
          }
        }
      }
    }

    if (rejected >= 3) {
      alerts.add("CRITICAL: $rejected Guard Rejections detected today!");
    }
    if (leakTotal > 0) {
      alerts.add(
        "LEAKAGE ALERT: ₹${leakTotal.toStringAsFixed(0)} stuck at exit verification.",
      );
    }
    if (refunds >= 2) {
      alerts.add(
        "FRAUD SPIKE: $refunds Refunds (₹${refAmount.toStringAsFixed(0)}) triggered today.",
      );
    }

    return DailyFinancials(
      totalRevenue: revTotal,
      cashExpected: revCash + leakCash,
      digitalExpected: revUpi + leakUpi,
      totalLeakage: leakTotal,
      cashLeakage: leakCash,
      digitalLeakage: leakUpi,
      totalOrders: orders,
      rejectedCount: rejected,
      pendingCount: pendingCount,
      refundCount: refunds,
      refundAmount: refAmount,
      activeAlerts: alerts,
    );
  });
});
