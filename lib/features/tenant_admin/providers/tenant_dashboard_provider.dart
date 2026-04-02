import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Tenant Profile Stream
final tenantProfileProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Stream.value(null);
      }

      return FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .snapshots()
          .map((snapshot) => snapshot.data());
    });

// 2. Is Onboarding Complete Provider
final isOnboardingCompleteProvider = Provider.family<bool, String>((
  ref,
  tenantId,
) {
  // Reading from the tenantProfile stream
  final profile = ref.watch(tenantProfileProvider(tenantId)).value;
  return profile?['isOnboardingComplete'] ?? false;
});

// 3. Tenant Stores Provider
final tenantStoresProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, tenantId) {
      if (tenantId.isEmpty) {
        return Stream.value([]);
      }

      return FirebaseFirestore.instance
          .collection('stores')
          .where('tenantId', isEqualTo: tenantId)
          .where('isDeleted', isEqualTo: false) // 🚀 FIX: Ignore deleted stores
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // Injecting document ID for UI operations
              return data;
            }).toList(),
          );
    });

// 4. Tenant Staff Count Provider (Using count() for optimization/cost saving)
final tenantStaffCountProvider = FutureProvider.family<int, String>((
  ref,
  tenantId,
) async {
  if (tenantId.isEmpty) {
    return 0;
  }

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('staff')
        .where('tenantId', isEqualTo: tenantId)
        .count()
        .get();

    return snapshot.count ?? 0;
  } catch (e) {
    return 0; // Handle permission/network errors gracefully
  }
});

// 🚀 5. Bank Settlement Fallback Logic
Future<Map<String, dynamic>> getSettlementBankDetails({
  required String tenantId,
  required String branchCode,
}) async {
  // Step 1: Store bank check
  final storeSnap = await FirebaseFirestore.instance
      .collection('stores')
      .where('tenantId', isEqualTo: tenantId)
      .where('branchCode', isEqualTo: branchCode)
      .limit(1)
      .get();

  if (storeSnap.docs.isNotEmpty) {
    final bank = storeSnap.docs.first.data()['bankDetails'];
    if (bank != null && bank['isCustom'] == true) {
      return {'source': 'STORE', ...bank};
    }
  }

  // Step 2: Fallback → Tenant bank
  final tenantSnap = await FirebaseFirestore.instance
      .collection('tenants')
      .doc(tenantId)
      .get();
  final tenantBank = tenantSnap.data()?['bankDetails'] ?? {};
  return {'source': 'TENANT', ...tenantBank};
}
