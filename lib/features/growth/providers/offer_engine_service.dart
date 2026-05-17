import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Enum for Offer Types
enum OfferType { welcomeOffer, growthRadar, negotiationOffer }

class OfferEngineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Write offer to Firestore (EXISTING - Bhejta hai)
  Future<void> writeOfferToFirestore({
    required String targetUserId,
    required String tenantId,
    required String branchCode,
    required OfferType offerType,
    required String notificationTitle,
    required String notificationBody,
    required String couponCode,
    required double discountPercent,
    required int expiryDays,
    required String? fcmToken,
  }) async {
    // FCM Eligibility Check Bypassed
    // We allow saving the offer to DB so the user can use it in-app at checkout
    // even if push notification delivery fails or token is missing.

    // Write Document to Firestore
    await _db.collection('notifications').add({
      'targetUserId': targetUserId,
      'tenantId': tenantId,
      'branchCode': branchCode,
      'offerType': offerType.name,
      'notificationTitle': notificationTitle,
      'notificationBody': notificationBody,
      'couponCode': couponCode,
      'discountPercent': discountPercent,
      'expiryDays': expiryDays,
      'status': 'PENDING',
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. 🚀 NEW: Validate Promo Code (Cart me APPLY button dabane pe ye chalega)
  Future<Map<String, dynamic>?> validatePromoCode({
    required String userId,
    required String promoCode,
    required String tenantId,
    required String branchCode,
  }) async {
    final querySnap = await _db
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('tenantId', isEqualTo: tenantId)
        .where('branchCode', isEqualTo: branchCode)
        .where('couponCode', isEqualTo: promoCode)
        .where('status', isEqualTo: 'PENDING')
        .get();

    if (querySnap.docs.isEmpty) {
      return null; // Invalid, already used, ya kisi aur user ka code hai
    }

    final doc = querySnap.docs.first;
    final data = doc.data();

    // 🕒 Check Expiry Date
    Timestamp? createdAtTS = data['createdAt'] as Timestamp?;
    if (createdAtTS != null) {
      DateTime createdAt = createdAtTS.toDate();
      int expiryDays = data['expiryDays'] ?? 3;
      DateTime expiryDate = createdAt.add(Duration(days: expiryDays));

      if (DateTime.now().isAfter(expiryDate)) {
        // Offer expire ho chuka hai, DB me status update kardo
        await _db.collection('notifications').doc(doc.id).update({
          'status': 'EXPIRED',
        });
        return null;
      }
    }

    // 🛡️ STRICT MEMORY-LEVEL SECURITY CHECK
    if (data['tenantId'] != tenantId || data['branchCode'] != branchCode) {
      return null;
    }

    // Agar valid hai toh Data return karo UI ke liye
    return {
      'docId': doc.id,
      'discountPercent': data['discountPercent'],
      'couponCode': data['couponCode'],
    };
  }

  // 3. 🚀 NEW: Redeem/Delete Promo Code (Order Place hone ke baad ye chalega)
  Future<void> redeemPromoCode({
    required String docId,
    required String tenantId,
    required String branchCode,
  }) async {
    final docRef = _db.collection('notifications').doc(docId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Promo code document not found.");

      final data = snapshot.data()!;
      // 🛡️ SECURITY: Ensure tenant hasn't leaked docId to another store
      if (data['tenantId'] != tenantId || data['branchCode'] != branchCode) {
        throw Exception("Unauthorized redemption attempt.");
      }

      transaction.update(docRef, {
        'status': 'USED',
        'usedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
