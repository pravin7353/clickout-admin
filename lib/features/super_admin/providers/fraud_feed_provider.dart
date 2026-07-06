import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Fetching from admin_audit_logs and filtering FRAUD_ events
// Note: If you have a dedicated 'fraud_alerts' collection, change the collection name here.
final fraudAlertsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.keepAlive();
      return FirebaseFirestore.instance
          .collection('admin_audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(100) // Fetch recent logs
          .snapshots()
          .map((snap) {
            return snap.docs
                .map((d) => {'id': d.id, ...d.data()})
                .where(
                  (d) => (d['action'] ?? '').toString().startsWith('FRAUD_'),
                )
                .toList();
          });
    });
