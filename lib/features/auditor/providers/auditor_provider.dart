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

// 🚀 THE FINANCIAL INTELLIGENCE ENGINE (O(1) SAAS OPTIMIZED)
final dailyFinancialsProvider = StreamProvider<DailyFinancials>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String? branchCode = adminData?['branchCode'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();

  // For Super Admins or invalid states, return empty to prevent crash
  if (tenantId == null ||
      tenantId.isEmpty ||
      role == 'super_admin' ||
      branchCode == null) {
    return Stream.value(DailyFinancials());
  }

  final now = DateTime.now();
  String dateStr =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  String statDocId = "${tenantId}_${branchCode}_$dateStr";

  return FirebaseFirestore.instance
      .collection('daily_store_stats')
      .doc(statDocId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return DailyFinancials();

        final data = snapshot.data() as Map<String, dynamic>;

        double leakTotal = (data['totalLeakage'] ?? 0).toDouble();
        int rejected = (data['rejectedCount'] ?? 0).toInt();
        int refunds = (data['refundCount'] ?? 0).toInt();
        double refAmount = (data['refundAmount'] ?? 0).toDouble();

        List<String> alerts = [];
        if (rejected >= 3)
          alerts.add("CRITICAL: $rejected Guard Rejections detected today!");
        if (leakTotal > 0)
          alerts.add(
            "LEAKAGE ALERT: ₹${leakTotal.toStringAsFixed(0)} stuck at exit verification.",
          );
        if (refunds >= 2)
          alerts.add(
            "FRAUD SPIKE: $refunds Refunds (₹${refAmount.toStringAsFixed(0)}) triggered today.",
          );

        return DailyFinancials(
          totalRevenue: (data['totalRevenue'] ?? 0).toDouble(),
          cashExpected:
              (data['cashRevenue'] ?? 0).toDouble() +
              (data['cashLeakage'] ?? 0).toDouble(),
          digitalExpected:
              (data['upiRevenue'] ?? 0).toDouble() +
              (data['upiLeakage'] ?? 0).toDouble(),
          totalLeakage: leakTotal,
          cashLeakage: (data['cashLeakage'] ?? 0).toDouble(),
          digitalLeakage: (data['upiLeakage'] ?? 0).toDouble(),
          totalOrders: (data['totalOrders'] ?? 0).toInt(),
          rejectedCount: rejected,
          pendingCount: (data['pendingCount'] ?? 0).toInt(),
          refundCount: refunds,
          refundAmount: refAmount,
          activeAlerts: alerts,
        );
      });
});
