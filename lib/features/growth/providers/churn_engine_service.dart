import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION IMPORT

class VIPCustomer {
  final String id;
  final String name;
  final String phone;
  final double totalSpent;
  final int totalVisits;
  final DateTime lastVisit;
  final String riskLevel;
  final bool winbackSent;

  VIPCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalSpent,
    required this.totalVisits,
    required this.lastVisit,
    required this.riskLevel,
    required this.winbackSent,
  });
}

class ChurnEngineNotifier extends AsyncNotifier<List<VIPCustomer>> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<VIPCustomer>> build() async {
    return _scanForChurn();
  }

  Future<List<VIPCustomer>> _scanForChurn() async {
    try {
      // 🚀 ZERO-COST MASTERSTROKE: Limit to top 50 VIPs to avoid infinite Firebase Reads!
      final snapshot = await _db
          .collection('users')
          .where('totalSpent', isGreaterThanOrEqualTo: 2000)
          .orderBy('totalSpent', descending: true) // Sort directly in DB
          .limit(50) // ONLY READ 50 DOCS! Maximum Cost Savings.
          .get();

      List<VIPCustomer> atRiskCustomers = [];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastVisit =
            (data['lastVisit'] as Timestamp?)?.toDate() ??
            now.subtract(const Duration(days: 90));
        final totalVisits = data['totalVisits'] ?? 1;
        final totalDaysSinceJoined = now
            .difference((data['createdAt'] as Timestamp?)?.toDate() ?? now)
            .inDays
            .abs();

        int averageCycleDays = totalVisits > 1
            ? (totalDaysSinceJoined ~/ totalVisits)
            : 30;
        if (averageCycleDays == 0) averageCycleDays = 1;

        int daysSinceLastVisit = now.difference(lastVisit).inDays;

        String risk = 'SAFE';
        if (daysSinceLastVisit > (averageCycleDays * 3) &&
            daysSinceLastVisit > 15) {
          risk = 'HIGH';
        } else if (daysSinceLastVisit > (averageCycleDays * 2) &&
            daysSinceLastVisit > 10) {
          risk = 'MEDIUM';
        }

        if (risk != 'SAFE' && data['winbackActive'] != true) {
          atRiskCustomers.add(
            VIPCustomer(
              id: doc.id,
              name: data['name'] ?? 'VIP User',
              phone: data['phone'] ?? 'N/A',
              totalSpent: double.tryParse(data['totalSpent'].toString()) ?? 0.0,
              totalVisits: totalVisits,
              lastVisit: lastVisit,
              riskLevel: risk,
              winbackSent: data['winbackActive'] ?? false,
            ),
          );
        }
      }

      return atRiskCustomers;
    } catch (e) {
      debugPrint("🚨 Churn Engine Failed: $e");
      throw Exception(
        "Failed to analyze churn data. Please create the required index in Firebase if prompted.",
      );
    }
  }

  Future<void> sendWinbackCoupon(String userId, String customerName) async {
    try {
      final String promoCode = "COMEBACK20";

      // 🚀 SAAS INJECTION: Get current tenant
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      await _db.collection('users').doc(userId).update({
        'winbackActive': true,
        'winbackCoupon': promoCode,
        'winbackSentAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('admin_audit_logs').add({
        'action': 'WINBACK_COUPON_SENT',
        'userId': userId,
        'couponCode': promoCode,
        'tenantId': tenantId, // 🚀 SAAS INJECTION
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ SMS TRIGGERED for $customerName: Here is $promoCode!");
      ref.invalidateSelf();
    } catch (e) {
      debugPrint("🚨 Failed to send coupon: $e");
      throw Exception("Could not send coupon. Please try again.");
    }
  }
}

final churnEngineProvider =
    AsyncNotifierProvider<ChurnEngineNotifier, List<VIPCustomer>>(() {
      return ChurnEngineNotifier();
    });
