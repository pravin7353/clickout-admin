import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 SAAS INJECTION: Added auth_provider import
import 'package:clickout_admin/features/auth/auth_provider.dart';

class RefundEngineNotifier extends Notifier<AsyncValue<Map<String, dynamic>?>> {
  final _db = FirebaseFirestore.instance;

  @override
  AsyncValue<Map<String, dynamic>?> build() {
    return const AsyncData(null);
  }

  // 🔍 1. SEARCH THE ORDER & FETCH FRAUD SCORE
  Future<void> searchOrderForRefund(String orderId) async {
    state = const AsyncLoading();
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) throw "Order Not Found!";

      final data = doc.data()!;
      data['id'] = doc.id;

      // MOCK FRAUD SCORE
      data['trustScore'] = 85;

      state = AsyncData(data);
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
    }
  }

  // ⚖️ 2. EXECUTE THE REFUND (Idempotent Transaction)
  Future<void> processRefund({
    required String orderId,
    required String refundTier, // 'WALLET', 'SOURCE', or 'PARTIAL'
    required double refundAmount,
    required String reason,
  }) async {
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'System';
      final orderRef = _db.collection('orders').doc(orderId);
      final refundDocId = 'ref_$orderId'; // 🛡️ IDEMPOTENCY KEY
      final refundRef = _db.collection('refunds').doc(refundDocId);

      // 🚀 SAAS INJECTION: Get current tenant ID
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      await _db.runTransaction((transaction) async {
        // 1. Check if refund already exists (IDEMPOTENCY CHECK)
        final existingRefund = await transaction.get(refundRef);
        if (existingRefund.exists) {
          throw "FRAUD SHIELD: A refund for this order has already been initiated!";
        }

        final orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) throw "Order vanished!";
        final orderData = orderSnap.data()!;

        // 2. Validate Exit Status
        final exitStatus = (orderData['exitStatus'] ?? '')
            .toString()
            .toUpperCase();
        if (exitStatus == 'COMPLETED' || exitStatus == 'EXITED') {
          throw "Cannot refund! The customer has already exited with the items.";
        }

        // 3. Create the Refund Record (The Source of Truth)
        transaction.set(refundRef, {
          'orderId': orderId,
          'amount': refundAmount,
          'tier': refundTier,
          'status': refundTier == 'WALLET' ? 'COMPLETED' : 'PROCESSING',
          'reason': reason,
          'processedBy': adminEmail,
          'timestamp': FieldValue.serverTimestamp(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
        });

        // 4. Update the Order Status
        transaction.update(orderRef, {
          'status': 'REFUNDED',
          'exitStatus': 'CANCELLED_AND_REFUNDED',
          'refundId': refundDocId,
        });

        // 5. Audit Trail for Finance Team
        final auditRef = _db.collection('admin_audit_logs').doc();
        transaction.set(auditRef, {
          'action': 'REFUND_INITIATED',
          'orderId': orderId,
          'amount': refundAmount,
          'tier': refundTier,
          'adminId': adminEmail,
          'timestamp': FieldValue.serverTimestamp(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
        });
      });

      // Refresh UI
      await searchOrderForRefund(orderId);
    } catch (e) {
      throw e.toString();
    }
  }

  void reset() => state = const AsyncData(null);
}

final refundEngineProvider =
    NotifierProvider<RefundEngineNotifier, AsyncValue<Map<String, dynamic>?>>(
      () {
        return RefundEngineNotifier();
      },
    );
