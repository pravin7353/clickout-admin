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
  final double expectedLoss; // 🚀 NEW: Predictive Revenue Loss

  VIPCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalSpent,
    required this.totalVisits,
    required this.lastVisit,
    required this.riskLevel,
    required this.winbackSent,
    required this.expectedLoss, // 🚀 NEW
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
      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) return [];

      final tenantId = roleData['tenantId'];
      final role = roleData['role'];
      final userBranch = roleData['branchCode']; // Store Manager ki apni branch

      if (tenantId == null) return [];

      // Check if user is ground-level staff
      final isManager =
          role == 'MANAGER' ||
          role == 'STORE_MANAGER' ||
          role == 'GUARD' ||
          role == 'CASHIER';

      // 🚀 1. FETCH CONFIGS (Isolated if Manager)
      Query configQuery = _db
          .collection('growth_configs')
          .where('tenantId', isEqualTo: tenantId);
      if (isManager && userBranch != null) {
        configQuery = configQuery.where('branchCode', isEqualTo: userBranch);
      }
      final configsSnap = await configQuery.get();

      Map<String, Map<String, dynamic>> storeConfigs = {};
      for (var doc in configsSnap.docs) {
        // 🚀 THE FIX 1: Explicitly cast the config data
        final configData = doc.data() as Map<String, dynamic>;
        storeConfigs[configData['branchCode'] ?? 'UNKNOWN'] = configData;
      }

      // 🚀 2. DYNAMIC QUERY BUILDING WITH LEAK PROTECTION
      Query usersQuery = _db
          .collection('users')
          .where('tenantId', isEqualTo: tenantId);

      // 🔒 SECURITY LOCK: Strictly restrict to their own branch
      if (isManager && userBranch != null) {
        usersQuery = usersQuery.where('branchCode', isEqualTo: userBranch);
      }

      final snapshot = await usersQuery
          .where(
            'totalSpent',
            isGreaterThanOrEqualTo: 500,
          ) // Catch F&B/Salon VIPs
          .orderBy('totalSpent', descending: true)
          .limit(100)
          .get();

      List<VIPCustomer> atRiskCustomers = [];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        // 🚀 THE FIX 2: Explicitly cast the user data
        final data = doc.data() as Map<String, dynamic>;

        final totalVisits = data['totalVisits'] ?? 1;
        if (totalVisits <= 1) continue;

        final String userBranchCode = data['branchCode'] ?? 'UNKNOWN';
        final config = storeConfigs[userBranchCode] ?? {};

        double vipThreshold = (config['vipThreshold'] ?? 2000).toDouble();
        int expectedCycle = config['expectedCycleDays'] ?? 30;
        double highMult = (config['churnMultiplierHigh'] ?? 3.0).toDouble();
        double medMult = (config['churnMultiplierMedium'] ?? 2.0).toDouble();

        double totalSpendAmount =
            double.tryParse(data['totalSpent'].toString()) ?? 0.0;

        if (totalSpendAmount < vipThreshold) continue;

        final lastVisit =
            (data['lastVisit'] as Timestamp?)?.toDate() ??
            now.subtract(const Duration(days: 90));
        int daysSinceLastVisit = now.difference(lastVisit).inDays;

        String risk = 'SAFE';
        if (daysSinceLastVisit > (expectedCycle * highMult)) {
          risk = 'HIGH';
        } else if (daysSinceLastVisit > (expectedCycle * medMult)) {
          risk = 'MEDIUM';
        }

        if (risk != 'SAFE' && data['winbackActive'] != true) {
          double avgSpendPerVisit = totalVisits > 0
              ? (totalSpendAmount / totalVisits)
              : 0.0;
          int missedCycles = expectedCycle > 0
              ? (daysSinceLastVisit ~/ expectedCycle)
              : 1;
          double lossPrediction = avgSpendPerVisit * missedCycles;

          atRiskCustomers.add(
            VIPCustomer(
              id: doc.id,
              name: data['name'] ?? 'VIP User',
              phone: data['phone'] ?? 'N/A',
              totalSpent: totalSpendAmount,
              totalVisits: totalVisits,
              lastVisit: lastVisit,
              riskLevel: risk,
              winbackSent: data['winbackActive'] ?? false,
              expectedLoss: lossPrediction,
            ),
          );
        }

        if (atRiskCustomers.length >= 50) break;
      }
      return atRiskCustomers;
    } catch (e) {
      debugPrint("🚨 Churn Engine Failed: $e");
      throw Exception(
        "Failed to analyze churn data. Please check Debug Console for Firebase Index link.",
      );
    }
  }

  Future<void> sendWinbackCoupon(String userId, String customerName) async {
    try {
      final String promoCode = "COMEBACK20";

      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) {
        throw Exception("CRITICAL ERROR: Security Verification Failed.");
      }

      final tenantId = roleData['tenantId'];
      final branchCode = roleData['branchCode'];

      // 1. UPDATE USER STATUS (Lock them from spam)
      await _db.collection('users').doc(userId).update({
        'winbackActive': true,
        'winbackCoupon': promoCode,
        'winbackSentAt': FieldValue.serverTimestamp(),
      });

      // 🚀 2. THE MAGIC: TRIGGER PUSH NOTIFICATION QUEUE
      // Aapka Firebase Cloud Function is collection ko sunega aur FCM bhejega
      await _db.collection('notifications').add({
        'targetUserId': userId,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN',
        'notificationTitle': 'We Miss You, $customerName! 🥺',
        'notificationBody':
            'Here is a flat 20% OFF on your next visit to our store. Use code: $promoCode',
        'type': 'WINBACK_COUPON',
        'status':
            'PENDING', // Backend will change this to 'SENT' when FCM fires
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. AUDIT LOG
      await _db.collection('admin_audit_logs').add({
        'action': 'PUSH_NOTIFICATION_TRIGGERED',
        'userId': userId,
        'couponCode': promoCode,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ PUSH NOTIFICATION QUEUED for $customerName!");
      ref.invalidateSelf(); // Refresh UI instantly
    } catch (e) {
      debugPrint("🚨 Failed to send push notification: $e");
      throw Exception("Could not send notification. Please try again.");
    }
  }
}

final churnEngineProvider =
    AsyncNotifierProvider<ChurnEngineNotifier, List<VIPCustomer>>(() {
      return ChurnEngineNotifier();
    });

// 🚀 STATE PROVIDER FOR WARNING BANNER (STEP 3)
final growthConfigStatusProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final tenantId = ref.watch(adminRoleProvider).value?['tenantId'];
  if (tenantId == null) return false;
  // 🚀 Checks ROOT collection to see if ANY store under this tenant has configured AI
  final snap = await FirebaseFirestore.instance
      .collection('growth_configs')
      .where('tenantId', isEqualTo: tenantId)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
});
