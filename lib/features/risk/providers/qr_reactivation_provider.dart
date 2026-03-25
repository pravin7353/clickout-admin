import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 1. SEARCH STATE PROVIDER
class BailoutSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }
}

final bailoutSearchQueryProvider =
    NotifierProvider<BailoutSearchNotifier, String>(() {
      return BailoutSearchNotifier();
    });

// 🚀 2. ADMIN PROFILE PROVIDER
final adminProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null || user.email == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('staff')
      .where('email', isEqualTo: user.email)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return snapshot.docs.first.data();
      });
});

// 🚀 3. REAL-TIME EXPIRED ORDERS STREAM
final expiredOrdersProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
      final adminProfile = ref.watch(adminProfileProvider).value;

      if (adminProfile == null) return Stream.value([]);

      final String role = (adminProfile['role'] ?? '').toString().toLowerCase();
      final bool isSuperAdmin = role == 'super_admin' || role == 'admin';
      final String? branchCode = adminProfile['branchCode'];
      final String? tenantId = adminProfile['tenantId']; // 🚀 SAAS INJECTION

      final String searchQuery = ref.watch(bailoutSearchQueryProvider).trim();

      // 🔍 SEARCH MODE
      if (searchQuery.isNotEmpty) {
        // 🚀 FIX: Strictly typed Query to prevent 'Object?' Bracket Errors
        Query<Map<String, dynamic>> searchQ = FirebaseFirestore.instance
            .collection('orders')
            .where(FieldPath.documentId, isEqualTo: searchQuery);

        if (!isSuperAdmin && tenantId != null) {
          searchQ = searchQ.where('tenantId', isEqualTo: tenantId);
        }

        return searchQ.snapshots().map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          return snapshot.docs.where((doc) {
            final data = doc.data(); // 🔥 Ab Dart ko pata hai ye Map hai

            if (!isSuperAdmin && data['branchCode'] != branchCode) {
              return false;
            }

            final pStatus = (data['paymentStatus'] ?? data['status'] ?? '')
                .toString()
                .toUpperCase();
            if (pStatus != 'PAID' && pStatus != 'SUCCESS') return false;

            final eStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
            if ([
              'COMPLETED',
              'APPROVED',
              'EXITED',
              'FORCE_OVERRIDDEN',
            ].contains(eStatus)) {
              return false;
            }

            return true;
          }).toList();
        });
      }

      // 📋 DEFAULT MODE (List View)
      final now = DateTime.now();
      final startOfSearch = now.subtract(const Duration(days: 3));

      // 🚀 FIX: Strictly typed Query to prevent 'Object?' Bracket Errors
      Query<Map<String, dynamic>> defaultQ = FirebaseFirestore.instance
          .collection('orders')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfSearch),
          );

      if (!isSuperAdmin && tenantId != null) {
        defaultQ = defaultQ.where('tenantId', isEqualTo: tenantId);
      }

      return defaultQ.snapshots().map((snapshot) {
        final filteredDocs = snapshot.docs.where((doc) {
          final data = doc.data(); // 🔥 Ab Dart ko pata hai ye Map hai

          if (!isSuperAdmin) {
            if (data['branchCode'] != branchCode) return false;
          }

          final pStatus = (data['paymentStatus'] ?? data['status'] ?? '')
              .toString()
              .toUpperCase();
          if (pStatus != 'PAID' && pStatus != 'SUCCESS') return false;

          final eStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
          if ([
            'COMPLETED',
            'APPROVED',
            'EXITED',
            'FORCE_OVERRIDDEN',
          ].contains(eStatus)) {
            return false;
          }

          final Timestamp? expiresAt = data['qrExpiresAt'];
          if (expiresAt == null || expiresAt.toDate().isAfter(now)) {
            return false;
          }

          return true;
        }).toList();

        filteredDocs.sort((a, b) {
          final aTime = a.data()['qrExpiresAt'] as Timestamp;
          final bTime = b.data()['qrExpiresAt'] as Timestamp;
          return aTime.compareTo(bTime);
        });

        return filteredDocs;
      });
    });

// 🚀 4. THE BAILOUT NOTIFIER (Atomic Transaction Engine)
class QrBailoutNotifier extends Notifier<bool> {
  final _db = FirebaseFirestore.instance;
  final int maxRegenLimit = 2;

  @override
  bool build() => false;

  Future<void> reactivateQR(String orderId, String currentStoreId) async {
    try {
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) throw "Unauthorized. Please login again.";

      final adminEmail = admin.email ?? 'Unknown_Admin';
      final adminUid = admin.uid;
      final docRef = _db.collection('orders').doc(orderId);

      await _db.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) throw "Order vanished from database!";
        final data = doc.data()!;

        final exitStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
        if ([
          'COMPLETED',
          'APPROVED',
          'EXITED',
          'FORCE_OVERRIDDEN',
        ].contains(exitStatus)) {
          throw "FRAUD ALERT: Order has already exited safely! Cannot reactivate.";
        }

        final pStatus = (data['paymentStatus'] ?? data['status'] ?? '')
            .toString()
            .toUpperCase();
        if (pStatus != 'PAID' && pStatus != 'SUCCESS') {
          throw "FRAUD ALERT: Payment not verified! Current Status: $pStatus";
        }

        int currentRegenCount = data['qrRegenCount'] ?? 0;
        if (currentRegenCount >= maxRegenLimit) {
          throw "SYSTEM BLOCK: Max regeneration limit ($maxRegenLimit) reached! Refund required.";
        }

        DateTime newExpiry = DateTime.now().add(const Duration(hours: 1));

        transaction.update(docRef, {
          'exitStatus': 'READY_FOR_EXIT',
          'wasEverRejected': true,
          'reactivatedAt': FieldValue.serverTimestamp(),
          'qrExpiresAt': Timestamp.fromDate(newExpiry),
          'qrRegenCount': FieldValue.increment(1),
          'reactivatedBy': adminEmail,
        });

        final auditRef = _db.collection('admin_audit_logs').doc();
        transaction.set(auditRef, {
          'action': 'QR_REACTIVATION',
          'orderId': orderId,
          'storeId': currentStoreId,
          'adminId': adminUid,
          'adminEmail': adminEmail,
          'timestamp': FieldValue.serverTimestamp(),
          'previousExitStatus': exitStatus,
          'regenCount': currentRegenCount + 1,
          // 🚀 SAAS INJECTION FOR AUDIT TRAIL
          'tenantId': ref.read(adminProfileProvider).value?['tenantId'],
        });
      });
    } catch (e) {
      throw e.toString();
    }
  }
}

final qrBailoutProvider = NotifierProvider<QrBailoutNotifier, bool>(() {
  return QrBailoutNotifier();
});
