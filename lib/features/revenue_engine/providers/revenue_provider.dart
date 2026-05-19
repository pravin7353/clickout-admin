import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🚀 SAAS INJECTION
import 'package:clickout_admin/features/auth/auth_provider.dart';

// 📊 1. METRICS MODEL (Names EXACTLY matched with your Dashboard UI)
class RevenueMetrics {
  final double grossRevenue;
  final double totalRevenue;
  final double pendingRevenue;
  final double rejectedRevenue;

  final double cashExpected;
  final double digitalExpected;

  final int totalOrders;
  final int successfulExited;
  final int pendingAtVerifier;
  final int rejectedAtVerifier;

  final int refundCount;
  final double refundAmount;
  final int expireCount;
  final double expireAmount;

  final List<Map<String, dynamic>> dailyOrders;
  final Map<int, Map<String, double>> hourlyBreakdown;

  RevenueMetrics({
    this.grossRevenue = 0.0,
    this.totalRevenue = 0.0,
    this.pendingRevenue = 0.0,
    this.rejectedRevenue = 0.0,
    this.cashExpected = 0.0,
    this.digitalExpected = 0.0,
    this.totalOrders = 0,
    this.successfulExited = 0,
    this.pendingAtVerifier = 0,
    this.rejectedAtVerifier = 0,
    this.refundCount = 0,
    this.refundAmount = 0.0,
    this.expireCount = 0,
    this.expireAmount = 0.0,
    this.dailyOrders = const [],
    this.hourlyBreakdown = const {},
  });
}

// ⚙️ 2. THE REVENUE ENGINE
class RevenueEngineNotifier extends AsyncNotifier<RevenueMetrics> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<RevenueMetrics> build() async => _calculateMetrics();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _calculateMetrics());
  }

  // 🧠 THE MASTER STATUS DERIVER
  String _deriveOrderStatus(Map<String, dynamic> order) {
    final pStatus = (order['paymentStatus'] ?? order['status'] ?? '')
        .toString()
        .toUpperCase();
    final eStatus = (order['exitStatus'] ?? '').toString().toUpperCase();
    final bool wasRejected = order['wasEverRejected'] == true;

    bool isExpired = order['systemRemark'] == 'AUTO_MIDNIGHT_EXPIRE';
    if (order['qrExpiresAt'] != null && order['qrExpiresAt'] is Timestamp) {
      isExpired =
          isExpired ||
          (order['qrExpiresAt'] as Timestamp).toDate().isBefore(DateTime.now());
    }

    if (pStatus == 'REFUNDED' || order['refund'] == true) return 'Refund';

    if (pStatus == 'PAID' || pStatus == 'SUCCESS') {
      if (eStatus == 'REJECTED') return 'Reject';
      if (eStatus == 'EXITED' ||
          eStatus == 'COMPLETED' ||
          eStatus == 'APPROVED') {
        if (wasRejected) return 'Fix & Exit';
        return 'Clear Exit';
      }
      if (isExpired) return 'QR Expire';
      return 'Gate Pass Pending';
    }
    return 'Pending';
  }

  Future<RevenueMetrics> _calculateMetrics() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // ✅ BUG FIXED: Changed ref.read to ref.watch
      final adminData = ref.watch(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String? branchCode = adminData?['branchCode']; // 🚀 FETCH BRANCH
      final String role = (adminData?['role'] ?? '').toString().toLowerCase();

      Query query = _db
          .collection('orders')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          );

      // 🚀 SAAS ISOLATION: Tenant AND Branch Separation
      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }
      if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
        query = query.where('branchCode', isEqualTo: branchCode);
      }

      final todayOrders = await query.get();

      double tGross = 0.0, tTotal = 0.0, tPending = 0.0, tRejected = 0.0;
      double tCash = 0.0, tDigital = 0.0;
      double rAmt = 0.0, eAmt = 0.0;
      int cTotal = 0, cExited = 0, cPending = 0, cRejected = 0;
      int rCount = 0, eCount = 0;

      List<Map<String, dynamic>> rawOrders = [];
      Map<int, Map<String, double>> hourly = {};

      for (var doc in todayOrders.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pStatus = (data['paymentStatus'] ?? data['status'] ?? '')
            .toString()
            .toUpperCase();

        // 🛡️ Filter: Only process if it was Paid/Success/Refunded
        if (pStatus != 'PAID' &&
            pStatus != 'SUCCESS' &&
            pStatus != 'REFUNDED' &&
            data['refund'] != true) {
          continue;
        }

        final amount =
            double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
        final status = _deriveOrderStatus(data);
        final mode = (data['paymentMode'] ?? 'UPI').toString().toUpperCase();
        final hour =
            (data['timestamp'] as Timestamp?)?.toDate().hour ?? now.hour;

        rawOrders.add({
          'orderId': doc.id,
          'amount': amount,
          'derivedStatus': status,
          ...data,
        });

        hourly.putIfAbsent(hour, () => {'cash': 0, 'upi': 0, 'risk': 0});

        if (status == 'Refund') {
          rAmt += amount;
          rCount++;
        }

        if (pStatus == 'PAID' || pStatus == 'SUCCESS') {
          tGross += amount;
          cTotal++;

          if (mode == 'CASH') {
            tCash += amount;
            hourly[hour]!['cash'] = hourly[hour]!['cash']! + amount;
          } else {
            tDigital += amount;
            hourly[hour]!['upi'] = hourly[hour]!['upi']! + amount;
          }

          switch (status) {
            case 'Clear Exit':
            case 'Fix & Exit':
              tTotal += amount;
              cExited++;
              break;
            case 'Gate Pass Pending':
              tPending += amount;
              cPending++;
              hourly[hour]!['risk'] = hourly[hour]!['risk']! + amount;
              break;
            case 'QR Expire':
              tPending += amount;
              eAmt += amount;
              eCount++;
              hourly[hour]!['risk'] = hourly[hour]!['risk']! + amount;
              break;
            case 'Reject':
              tRejected += amount;
              cRejected++;
              hourly[hour]!['risk'] = hourly[hour]!['risk']! + amount;
              break;
          }
        }
      }

      return RevenueMetrics(
        grossRevenue: tGross,
        totalRevenue: tTotal,
        pendingRevenue: tPending,
        rejectedRevenue: tRejected,
        cashExpected: tCash,
        digitalExpected: tDigital,
        totalOrders: cTotal,
        successfulExited: cExited,
        pendingAtVerifier: cPending,
        rejectedAtVerifier: cRejected,
        refundCount: rCount,
        refundAmount: rAmt,
        expireCount: eCount,
        expireAmount: eAmt,
        dailyOrders: rawOrders,
        hourlyBreakdown: hourly,
      );
    } catch (e) {
      throw Exception("Failed to aggregate business snapshot: $e");
    }
  }
}

// Exactly same Provider name! Dashboard won't throw any errors.
final revenueEngineProvider =
    AsyncNotifierProvider<RevenueEngineNotifier, RevenueMetrics>(
      () => RevenueEngineNotifier(),
    );
