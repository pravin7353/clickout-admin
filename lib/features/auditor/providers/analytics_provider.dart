import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

// 📊 CA-LEVEL HOURLY MATRIX MODEL
class HourlyData {
  final String timeLabel;
  final double hourlySales;
  final double hourlyCash;
  final double hourlyUpi;
  final double hourlyLeakage;
  final double hourlyRefunds;
  final double fraudRisk;

  HourlyData(
    this.timeLabel,
    this.hourlySales,
    this.hourlyCash,
    this.hourlyUpi,
    this.hourlyLeakage,
    this.hourlyRefunds,
    this.fraudRisk,
  );
}

final timeAnalyticsProvider = StreamProvider<List<HourlyData>>((ref) {
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

  final String? branchCode = adminData?['branchCode'];

  // 🚀 SAAS ISOLATION: Super Admin sees all, Tenant Admin sees only their data
  if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
    query = query.where('tenantId', isEqualTo: tenantId);
  }
  if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
    query = query.where('branchCode', isEqualTo: branchCode);
  }

  return query.snapshots().map((snapshot) {
    Map<int, double> hSales = {};
    Map<int, double> hCash = {};
    Map<int, double> hUpi = {};
    Map<int, double> hLeakage = {};
    Map<int, double> hRefunds = {};
    Map<int, int> hOrderCount = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp? ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;

      int hour = ts.toDate().hour;
      double amt = (data['totalAmount'] ?? 0).toDouble();
      String mode = data['paymentMode'] ?? '';
      String pStatus = data['paymentStatus'] ?? '';
      String eStatus = data['exitStatus'] ?? '';

      hOrderCount[hour] = (hOrderCount[hour] ?? 0) + 1;

      bool isRefund = (pStatus == 'REFUNDED');
      bool isExited = (eStatus == 'EXITED' || eStatus == 'APPROVED');
      bool isPending =
          (eStatus == 'PENDING' ||
          eStatus == 'EXPIRED_BY_SYSTEM' ||
          eStatus == '');

      if (isRefund) {
        hRefunds[hour] = (hRefunds[hour] ?? 0) + amt;
      } else if (pStatus == 'PAID' || pStatus == 'SUCCESS') {
        if (isExited) {
          hSales[hour] = (hSales[hour] ?? 0) + amt;
          if (mode == 'CASH') {
            hCash[hour] = (hCash[hour] ?? 0) + amt;
          } else {
            hUpi[hour] = (hUpi[hour] ?? 0) + amt;
          }
        } else if (isPending) {
          hLeakage[hour] = (hLeakage[hour] ?? 0) + amt;
        }
      }
    }

    List<HourlyData> chartData = [];
    // Map from 9 AM to 10 PM
    for (int i = 9; i <= 22; i++) {
      int displayHour = i > 12 ? i - 12 : i;
      String amPm = i >= 12 ? "PM" : "AM";
      String label = "${displayHour.toString().padLeft(2, '0')} $amPm";

      chartData.add(
        HourlyData(
          label,
          hSales[i] ?? 0.0,
          hCash[i] ?? 0.0,
          hUpi[i] ?? 0.0,
          hLeakage[i] ?? 0.0,
          hRefunds[i] ?? 0.0,
          0.0, // Default fraudRisk placeholder
        ),
      );
    }
    return chartData;
  });
});
