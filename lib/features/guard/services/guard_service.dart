import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuardService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🟢 AUTHORIZE EXIT ENGINE (🚀 SAAS INJECTED - LEVEL 1 & 2 ISOLATION)
  static Future<Map<String, dynamic>> processValidScan(
    String rawInput,
    String? tenantId,
    String? branchCode, // 🚀 LEVEL 2 ISOLATION ADDED
  ) async {
    final guardEmail = _auth.currentUser?.email ?? 'UNKNOWN_EMAIL';
    final guardId = _auth.currentUser?.uid ?? 'UNKNOWN_GUARD';

    try {
      String cleanId = rawInput.trim();
      if (cleanId.startsWith('{')) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(cleanId);
          cleanId = decoded['orderId']?.toString().trim() ?? cleanId;
        } catch (e) {}
      }

      if (cleanId.isEmpty) {
        return {'success': false, 'msg': 'Invalid Input: Empty Order ID'};
      }

      final orderRef = _db.collection('orders').doc(cleanId);
      final orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        return {'success': false, 'msg': 'INVALID QR: ORDER NOT FOUND'};
      }

      final data = orderDoc.data()!;
      if (data['paymentStatus'] != 'PAID') {
        return {'success': false, 'msg': 'STOP! Payment is not completed.'};
      }

      final eStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
      if (['COMPLETED', 'APPROVED', 'EXITED'].contains(eStatus)) {
        return {'success': false, 'msg': 'WARNING: Pass already used!'};
      }

      DateTime? expiresAt = (data['qrExpiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'msg': 'QR EXPIRED: Pass is no longer valid.',
        };
      }

      final WriteBatch batch = _db.batch();

      // 1. UPDATE ORDER
      batch.set(orderRef, {
        'exitStatus': 'APPROVED',
        'verifiedByGuardId': guardEmail,
        'verifiedAt': FieldValue.serverTimestamp(),
        'qrConsumed': true,
      }, SetOptions(merge: true));

      // 2. NAYI COLLECTION: 'gate_authorized' me full details
      final authorizedRef = _db.collection('gate_authorized').doc();
      batch.set(authorizedRef, {
        'orderId': cleanId,
        'guardId': guardId,
        'guardEmail': guardEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'APPROVED',
        'totalAmount': data['totalAmount'] ?? 0,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN', // 🚀 BRANCH ISOLATION LOCKED
      });

      // 3. AUDIT LOG
      final auditRef = _db.collection('admin_audit_logs').doc();
      batch.set(auditRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'actorId': guardId,
        'actorEmail': guardEmail,
        'actionType': 'AUTHORIZED_EXIT',
        'details': 'Guard successfully verified gate pass for Order: $cleanId',
        'severity': 'INFO',
        'targetCollection': 'gate_authorized',
        'targetId': authorizedRef.id,
        'tenantId': tenantId,
        'branchCode': branchCode ?? 'UNKNOWN', // 🚀 BRANCH ISOLATION LOCKED
      });

      await batch.commit();

      return {'success': true, 'msg': '✅ CLEAR EXIT: Gate Opened!'};
    } catch (e) {
      return {'success': false, 'msg': 'System Error: ${e.toString()}'};
    }
  }

  // 🔴 REJECT GATE PASS (Wapas laya gaya method)
  static Future<bool> rejectGatePass(String orderId, String? tenantId) async {
    try {
      final String guardEmail = _auth.currentUser?.email ?? 'UNKNOWN_EMAIL';
      final DocumentReference orderRef = _db
          .collection('orders')
          .doc(orderId.trim());

      await orderRef.update({
        'exitStatus': 'REJECTED',
        'verifiedByGuardId': guardEmail,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Failed to reject gate pass: $e");
      return false;
    }
  }

  // 🚨 OVERRIDE ENGINE (🚀 SAAS INJECTED)
  static Future<Map<String, dynamic>> processManualOverride(
    String reason,
    String? tenantId, {
    String? linkedOrderId,
  }) async {
    try {
      final String guardId = _auth.currentUser?.uid ?? 'UNKNOWN_GUARD';
      final String guardEmail = _auth.currentUser?.email ?? 'UNKNOWN_EMAIL';

      final WriteBatch batch = _db.batch();

      // 1. DEDICATED OVERRIDE COLLECTION
      final DocumentReference overrideRef = _db
          .collection('gate_overrides')
          .doc();
      batch.set(overrideRef, {
        'guardId': guardId,
        'guardEmail': guardEmail,
        'reason': reason,
        'linkedOrderId': (linkedOrderId == null || linkedOrderId.trim().isEmpty)
            ? 'NONE'
            : linkedOrderId.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'FORCE_OVERRIDDEN',
        'riskLevel': 'CRITICAL',
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });

      // 2. AUDIT LOG FOR OVERRIDE
      final auditRef = _db.collection('admin_audit_logs').doc();
      batch.set(auditRef, {
        'timestamp': FieldValue.serverTimestamp(),
        'actorId': guardId,
        'actorEmail': guardEmail,
        'actionType': 'MANUAL_GATE_OVERRIDE',
        'details': 'Guard forced open the gate. Reason: $reason.',
        'severity': 'CRITICAL',
        'targetCollection': 'gate_overrides',
        'targetId': overrideRef.id,
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });

      // 3. UPDATE ORDER (If Linked)
      if (linkedOrderId != null && linkedOrderId.trim().isNotEmpty) {
        final String cleanId = linkedOrderId.trim();
        final DocumentReference orderRef = _db
            .collection('orders')
            .doc(cleanId);

        batch.set(orderRef, {
          'exitStatus': 'FORCE_OVERRIDDEN',
          'overrideReason': reason,
          'verifiedByGuardId': guardEmail,
          'verifiedAt': FieldValue.serverTimestamp(),
          'riskLevel': 'HIGH',
        }, SetOptions(merge: true));
      }

      await batch.commit();

      return <String, dynamic>{
        'success': true,
        'msg': '🚨 OVERRIDE SUCCESS: Gate Forced Open!',
      };
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'msg': 'System Error: ${e.toString()}',
      };
    }
  }
}
