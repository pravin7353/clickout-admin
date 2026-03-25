import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuditService {
  // 🛡️ THE IMMUTABLE BLACK BOX LOGGER
  static Future<void> logAction({
    required String tenantId, // 🚀 SAAS INJECTION
    required String
    actionType, // e.g., 'CREATE', 'UPDATE', 'SOFT_DELETE', 'BLOCK'
    required String targetCollection,
    required String targetId,
    required String details,
    String? severity, // 'INFO', 'WARNING', 'CRITICAL'
  }) async {
    try {
      // 🕵️ Find out WHO is doing this
      final currentUser = FirebaseAuth.instance.currentUser;
      final actorId = currentUser?.uid ?? 'SYSTEM_OR_UNKNOWN';
      final actorEmail = currentUser?.email ?? 'unknown@system.com';

      // 📝 Write to the tamper-proof vault
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'tenantId': tenantId, // 🚀 SAAS INJECTION
        'timestamp': FieldValue.serverTimestamp(),
        'actorId': actorId,
        'actorEmail': actorEmail,
        'actionType': actionType.toUpperCase(),
        'targetCollection': targetCollection,
        'targetId': targetId,
        'details': details,
        'severity': severity ?? 'INFO',
      });
    } catch (e) {
      // In a banking app, if audit fails, the transaction fails.
      // For retail, we log it to console to avoid blocking operations, but alert the dev.
      debugPrint("🚨 CRITICAL AUDIT FAILURE: $e");
    }
  }
}
