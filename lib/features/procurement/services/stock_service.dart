import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StockService {
  static final _db = FirebaseFirestore.instance;

  // 🛡️ TASK B1 & B2: ENTERPRISE RESERVATION WITH VELOCITY LIMITS
  static Future<void> reserveStockSafely(
    String productId,
    int quantityToReserve,
    String cartId,
    String userId, // 🚨 Added UserId to track Hijackers
  ) async {
    final docRef = _db.collection('products').doc(productId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Product does not exist!");

        final data = snapshot.data()!;
        final int physicalStock = data['physicalStock'] ?? 0;
        final int currentReserved = data['reservedStock'] ?? 0;
        final int availableStock = physicalStock - currentReserved;

        // 🚨 VELOCITY LIMIT (Fraud Protection)
        if (quantityToReserve > (physicalStock * 0.5) && physicalStock > 10) {
          throw Exception(
            "Bulk reservation blocked! Please contact the counter.",
          );
        }

        if (availableStock < quantityToReserve) {
          throw Exception(
            "Maggi Problem Blocked: Item just went out of stock!",
          );
        }

        // 1. Update Product Reserved Stock
        transaction.update(docRef, {
          'reservedStock': currentReserved + quantityToReserve,
        });

        // 2. Create Reservation Document with Expiry (TTL)
        final reservationRef = _db.collection('reservations').doc();
        transaction.set(reservationRef, {
          'productId': productId,
          'cartId': cartId,
          'userId': userId,
          'qty': quantityToReserve,
          'reservedAt': FieldValue.serverTimestamp(),
          'expiresAt': DateTime.now().add(
            const Duration(minutes: 15),
          ), // ⏳ TTL: 15 Mins
          'status': 'ACTIVE',
        });
      });
      debugPrint("✅ Stock Reserved! Cart holds item for 15 mins.");
    } catch (e) {
      debugPrint("🚨 Reservation Failed: $e");
      rethrow;
    }
  }

  // 🧹 TASK B2: THE AUTO-CLEANER
  static Future<void> releaseExpiredReservations() async {
    final expiredSnaps = await _db
        .collection('reservations')
        .where('status', isEqualTo: 'ACTIVE')
        .where('expiresAt', isLessThan: DateTime.now())
        .get();

    for (var doc in expiredSnaps.docs) {
      debugPrint("Releasing expired cart hold: ${doc.id}");
    }
  }

  // ==========================================
  // 🟢 TASK E1: LEFT SWIPE - CLEARANCE ENGINE (PURANA WALA)
  // ==========================================
  static Future<void> applyClearance(
    String productId,
    String type,
    int value,
  ) async {
    try {
      await _db.collection('products').doc(productId).update({
        'clearanceActive': true,
        'clearanceType': type,
        'clearanceValue': value,
        'clearanceTag': type == 'BOGO'
            ? 'BUY 1 GET 1 FREE 🔥'
            : '$value% OFF 🏷️',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Clearance Applied: $type");
    } catch (e) {
      debugPrint("🚨 Clearance Failed: $e");
      rethrow;
    }
  }

  // ==========================================
  // 🚀 NAYA ENGINE: ADVANCED CLEARANCE MAKER (YE MISSING THA!)
  // ==========================================
  static Future<void> applyAdvancedClearance(
    String productId,
    String type,
    Map<String, dynamic> offerData,
  ) async {
    try {
      Map<String, dynamic> updatePayload = {
        'clearanceActive': true,
        'clearanceType': type,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updatePayload.addAll(offerData);

      // 🚀 FIX: Flash Sale Timer Engine - Calculate exact future expiry time!
      if (type == 'FLASH_SALE' && offerData['durationHours'] != null) {
        int hours = offerData['durationHours'] is int
            ? offerData['durationHours']
            : int.tryParse(offerData['durationHours'].toString()) ?? 0;
        updatePayload['expiresAt'] = Timestamp.fromDate(
          DateTime.now().add(Duration(hours: hours)),
        );
      }

      await _db.collection('products').doc(productId).update(updatePayload);
      debugPrint("✅ Advanced Clearance Applied: $type");
    } catch (e) {
      debugPrint("🚨 Advanced Clearance Failed: $e");
      rethrow;
    }
  }

  static Future<void> undoClearance(String productId) async {
    // 🚀 FIX: Completely wipe all ghost data so old offers don't corrupt new ones!
    await _db.collection('products').doc(productId).update({
      'clearanceActive': FieldValue.delete(),
      'clearanceType': FieldValue.delete(),
      'clearanceValue': FieldValue.delete(),
      'clearanceTag': FieldValue.delete(),
      'buyQty': FieldValue.delete(),
      'freeQty': FieldValue.delete(),
      'freeProductId': FieldValue.delete(),
      'freeProductName': FieldValue.delete(),
      'flatDiscount': FieldValue.delete(),
      'comboProducts': FieldValue.delete(),
      'comboNames': FieldValue.delete(),
      'comboPrice': FieldValue.delete(),
      // Ghost Data Removers
      'value1': FieldValue.delete(),
      'value2': FieldValue.delete(),
      'discountPercent': FieldValue.delete(),
      'discountAmount': FieldValue.delete(),
      'durationHours': FieldValue.delete(),
      'expiresAt': FieldValue.delete(),
      'minQty': FieldValue.delete(),
      'bundleQty': FieldValue.delete(),
      'bundlePrice': FieldValue.delete(),
      'targetProductId': FieldValue.delete(),
      'targetProductName': FieldValue.delete(),
    });
  }

  // ==========================================
  // 🔴 TASK E2: RIGHT SWIPE - BLOCK BATCH & LEDGER
  // ==========================================
  // 🚀 FIX: Added tenantId and adminEmail for Tracking
  static Future<int> blockBatchSafely(
    String productId,
    String tenantId,
    String adminEmail,
  ) async {
    final docRef = _db.collection('products').doc(productId);
    int stockRemoved = 0;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      stockRemoved = snapshot.data()?['physicalStock'] ?? 0;
      final productName = snapshot.data()?['name'] ?? 'Unknown Item';

      transaction.update(docRef, {
        'physicalStock': 0,
        'isBlocked': true,
        'blockedAt': FieldValue.serverTimestamp(),
        'expiredStock': FieldValue.increment(stockRemoved),
        'lastEditedBy': adminEmail, // 🚀 Log in Product
      });

      final ledgerRef = _db.collection('ledger').doc();
      transaction.set(ledgerRef, {
        'productId': productId,
        'productName': productName,
        'quantityRemoved': stockRemoved,
        'reason': 'EXPIRED_BATCH_BLOCKED',
        'tenantId': tenantId, // 🚀 SaaS Bound
        'blockedBy': adminEmail, // 🚀 Anti-Fraud
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return stockRemoved;
  }

  static Future<void> undoBlockBatch(
    String productId,
    int restoredStock,
  ) async {
    final docRef = _db.collection('products').doc(productId);
    await _db.runTransaction((transaction) async {
      transaction.update(docRef, {
        'physicalStock': FieldValue.increment(restoredStock),
        'isBlocked': false,
        // 🚀 FIX: Hum 'expiredStock' ko minus nahi karenge.
        // Naya stock aane se purana expiry khatam nahi hota, wo ledger history hai!
      });
    });
  }
}
