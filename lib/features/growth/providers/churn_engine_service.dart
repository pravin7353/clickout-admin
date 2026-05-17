import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

class VIPCustomer {
  final String id;
  final String name;
  final String phone;
  final double totalSpent;
  final int totalVisits;
  final DateTime lastVisit;
  final String riskLevel;
  final bool winbackSent;
  final double expectedLoss;
  final String category;
  final String branchCode;
  final bool isPushEnabled;
  final int pushCount;
  final bool hasApp;
  final int maxAllowedPushes;

  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;

  VIPCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalSpent,
    required this.totalVisits,
    required this.lastVisit,
    required this.riskLevel,
    required this.winbackSent,
    required this.expectedLoss,
    this.category = 'VIP',
    this.branchCode = 'UNKNOWN',
    this.isPushEnabled = true,
    this.pushCount = 0,
    this.hasApp = true,
    this.maxAllowedPushes = 3,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
  });

  bool get isNotificationEligible =>
      hasApp == true && fcmToken != null && fcmToken!.isNotEmpty;
}

class ChurnEngineNotifier extends AsyncNotifier<List<VIPCustomer>> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<VIPCustomer>> build() async {
    return _scanForChurn();
  }

  Future<List<VIPCustomer>> _scanForChurn() async {
    try {
      // 🚀 THE REFRESH BUG FIX: Use 'watch' instead of 'read' to auto-reload after page refresh!
      final roleData = ref.watch(adminRoleProvider).value;
      if (roleData == null) return [];

      final tenantId = roleData['tenantId'];
      final role = roleData['role'];
      final userBranch = roleData['branchCode'];

      if (tenantId == null) return [];

      final isManager =
          role == 'MANAGER' ||
          role == 'STORE_MANAGER' ||
          role == 'GUARD' ||
          role == 'CASHIER';

      Query configQuery = _db
          .collection('growth_configs')
          .where('tenantId', isEqualTo: tenantId);
      if (isManager && userBranch != null) {
        configQuery = configQuery.where('branchCode', isEqualTo: userBranch);
      }
      final configsSnap = await configQuery.get();

      Map<String, Map<String, dynamic>> storeConfigs = {};
      for (var doc in configsSnap.docs) {
        final configData = doc.data() as Map<String, dynamic>;
        storeConfigs[configData['branchCode'] ?? 'UNKNOWN'] = configData;
      }

      Query usersQuery = _db
          .collection('users')
          .where('tenantId', isEqualTo: tenantId);

      if (isManager && userBranch != null) {
        usersQuery = usersQuery.where('branchCode', isEqualTo: userBranch);
      }

      final snapshot = await usersQuery.limit(200).get();

      List<VIPCustomer> atRiskCustomers = [];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final storeVisitData =
            (data['storeVisits'] as Map<String, dynamic>?)?[tenantId]
                as Map<String, dynamic>?;
        final String userBranchCode =
            storeVisitData?['branchCode'] ?? data['branchCode'] ?? 'UNKNOWN';

        final config = storeConfigs[userBranchCode] ?? {};

        double vipThreshold = (config['vipThreshold'] ?? 2000).toDouble();
        int expectedCycle = config['expectedCycleDays'] ?? 30;
        double highMult = (config['churnMultiplierHigh'] ?? 3.0).toDouble();
        double medMult = (config['churnMultiplierMedium'] ?? 2.0).toDouble();

        // 🚀 OOM & N+1 FIX: Direct read from user doc (Pre-calculated by Backend Cloud Function)
        double totalSpendAmount =
            double.tryParse(data['totalSpent']?.toString() ?? '0') ?? 0.0;
        int validVisits = (data['totalVisits'] as int?) ?? 0;

        // Use Store Visit Data fallback if specific branch data is required
        if (storeVisitData != null) {
          totalSpendAmount =
              double.tryParse(
                storeVisitData['totalSpent']?.toString() ?? '0',
              ) ??
              totalSpendAmount;
          validVisits = (storeVisitData['totalVisits'] as int?) ?? validVisits;
        }

        if (totalSpendAmount < vipThreshold) continue;

        final lastVisit =
            (storeVisitData?['lastVisit'] as Timestamp?)?.toDate() ??
            (data['lastVisit'] as Timestamp?)?.toDate() ??
            now.subtract(const Duration(days: 90));
        int daysSinceLastVisit = now.difference(lastVisit).inDays;

        String risk = 'SAFE';
        if (daysSinceLastVisit > (expectedCycle * highMult)) {
          risk = 'HIGH';
        } else if (daysSinceLastVisit > (expectedCycle * medMult)) {
          risk = 'MEDIUM';
        }

        if (data['winbackActive'] != true) {
          atRiskCustomers.add(
            VIPCustomer(
              id: doc.id,
              name: data['name'] ?? 'VIP User',
              phone: data['phone'] ?? 'N/A',
              totalSpent: totalSpendAmount,
              totalVisits: validVisits,
              lastVisit: lastVisit,
              riskLevel: risk,
              winbackSent: data['winbackActive'] ?? false,
              expectedLoss: 0.0,
              category: data['category'] ?? 'VIP',
              branchCode: userBranchCode,
              isPushEnabled: true,
              pushCount: data['pushCount'] ?? 0,
              hasApp: data['hasApp'] ?? true,
              maxAllowedPushes: config['maxAllowedPushes'] ?? 3,
              fcmToken: data['fcmToken'] as String?,
              fcmTokenUpdatedAt: (data['fcmTokenUpdatedAt'] as Timestamp?)
                  ?.toDate(),
            ),
          );
        }

        if (atRiskCustomers.length >= 100) break;
      }
      return atRiskCustomers;
    } catch (e) {
      debugPrint("🚨 Churn Engine Failed: $e");
      return [];
    }
  }

  Future<void> sendTargetedOffer({
    required String userId,
    required String customerName,
    required int currentPushCount,
    required String offerName,
    required double discountPercent,
    required String couponCode,
    required int expiryDays,
  }) async {
    try {
      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) return;

      final tenantId = roleData['tenantId'];
      final branchCode = roleData['branchCode'];

      await _db.collection('users').doc(userId).update({
        'pushCount': FieldValue.increment(1),
        'lastPushAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('notifications').add({
        'targetUserId': userId,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN',
        'notificationTitle': offerName,
        'notificationBody':
            'Hi $customerName! Use code $couponCode for $discountPercent% OFF! Valid for $expiryDays days.',
        'couponCode': couponCode,
        'discountPercent': discountPercent,
        'expiryDays': expiryDays,
        'type': 'TARGETED_OFFER',
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ref.invalidateSelf();
    } catch (e) {
      throw Exception("Failed to send targeted offer");
    }
  }

  Future<void> sendBulkOffer({
    required Set<String> targetUserIds,
    required String offerName,
    required double discountPercent,
    required String couponCode,
    required int expiryDays,
  }) async {
    final roleData = ref.read(adminRoleProvider).value;
    if (roleData == null) return;

    final tenantId = roleData['tenantId'];
    final branchCode = roleData['branchCode'];

    final batch = _db.batch();
    int opsCount = 0;

    for (var userId in targetUserIds) {
      try {
        final userRef = _db.collection('users').doc(userId);
        batch.update(userRef, {
          'pushCount': FieldValue.increment(1),
          'lastPushAt': FieldValue.serverTimestamp(),
        });

        final notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'targetUserId': userId,
          'tenantId': tenantId,
          'branchCode': branchCode ?? 'UNKNOWN',
          'notificationTitle': offerName,
          'notificationBody':
              'Special Offer! Use code $couponCode for $discountPercent% OFF! Valid for $expiryDays days.',
          'couponCode': couponCode,
          'discountPercent': discountPercent,
          'expiryDays': expiryDays,
          'type': 'BULK_OFFER',
          'status': 'PENDING',
          'createdAt': FieldValue.serverTimestamp(),
        });

        opsCount++;
        // Firebase limit is 500 ops per batch. (2 ops per loop = 250 users max per commit)
        if (opsCount >= 240) {
          await batch.commit();
          opsCount = 0;
        }
      } catch (e) {
        debugPrint("Bulk Offer Queue Error for $userId: $e");
      }
    }

    if (opsCount > 0) {
      await batch.commit();
    }
    ref.invalidateSelf();
  }

  Future<void> sendWinbackCoupon(String userId, String customerName) async {
    try {
      final String promoCode = "COMEBACK20";
      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) return;
      final tenantId = roleData['tenantId'];
      final branchCode = roleData['branchCode'];

      await _db.collection('users').doc(userId).update({
        'winbackActive': true,
        'winbackCoupon': promoCode,
        'winbackSentAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('notifications').add({
        'targetUserId': userId,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN',
        'notificationTitle': 'We Miss You, $customerName! 🥺',
        'notificationBody':
            'Here is a flat 20% OFF on your next visit to our store. Use code: $promoCode',
        'couponCode': promoCode,
        'discountPercent': 20.0,
        'expiryDays': 7, // Standard 7 days expiry for Winback
        'type': 'WINBACK_COUPON',
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ref.invalidateSelf();
    } catch (e) {
      debugPrint("🚨 Failed to send push notification: $e");
    }
  }
}

final churnEngineProvider =
    AsyncNotifierProvider<ChurnEngineNotifier, List<VIPCustomer>>(() {
      return ChurnEngineNotifier();
    });

final growthConfigStatusProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final tenantId = ref.watch(adminRoleProvider).value?['tenantId'];
  if (tenantId == null) return false;
  final snap = await FirebaseFirestore.instance
      .collection('growth_configs')
      .where('tenantId', isEqualTo: tenantId)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
});
