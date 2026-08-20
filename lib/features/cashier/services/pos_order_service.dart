// lib/cashier/services/pos_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PosOrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createPosOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double gstTotal,
    required String paymentMode,
    required String
    tenantId, // 🚀 FIXED: Directly receiving from Cashier Screen
    required String
    branchCode, // 🚀 FIXED: Directly receiving from Cashier Screen
    String? customerPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Cashier not logged in");

    WriteBatch batch = _db.batch();
    DocumentReference orderRef = _db.collection('orders').doc();

    // ==========================================================
    // 🧠 1. THE SMART INVOICE ENGINE (Admin Configured)
    // ==========================================================
    String prefix = "INV/";
    if (tenantId.isNotEmpty && tenantId != 'ALL' && tenantId != 'GLOBAL') {
      try {
        var tSnap = await _db.collection('tenants').doc(tenantId).get();
        if (tSnap.exists) {
          var config =
              tSnap.data()?['invoiceConfig'] as Map<String, dynamic>? ?? {};
          String adminPrefix = config['invoicePrefix']?.toString().trim() ?? '';
          adminPrefix = adminPrefix.replaceAll(RegExp(r'\d{2}-\d{2}[/-]?'), '');
          if (adminPrefix.isNotEmpty) {
            prefix = adminPrefix;
            if (!prefix.endsWith('/') && !prefix.endsWith('-')) prefix += '/';
          }
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    int startYear = now.month >= 4 ? now.year : now.year - 1;
    String fyStr =
        "${(startYear % 100).toString().padLeft(2, '0')}-${((startYear + 1) % 100).toString().padLeft(2, '0')}";
    String dateStr =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String todayKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    DocumentReference counterRef = _db
        .collection('daily_invoice_counters')
        .doc("${branchCode}_$todayKey");

    int seq = await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
        return 1;
      } else {
        int newCount = (snapshot.data() as Map<String, dynamic>)['count'] + 1;
        transaction.update(counterRef, {'count': newCount});
        return newCount;
      }
    });

    String finalInvoiceNo =
        "$prefix$fyStr/$dateStr-${seq.toString().padLeft(2, '0')}";

    // ==========================================================
    // 🧠 2. MASTER CALCULATION
    // ==========================================================
    double dbTotalSavings = 0.0;
    double dbTaxableValue = 0.0;
    double totalWeight = 0.0;

    for (var item in items) {
      int qty =
          int.tryParse(
            item['quantity']?.toString() ?? item['qty']?.toString() ?? '1',
          ) ??
          1;
      double price =
          double.tryParse(
            item['price']?.toString() ??
                item['unitPrice']?.toString() ??
                item['discountedPrice']?.toString() ??
                '0',
          ) ??
          0.0;
      double originalPrice =
          double.tryParse(
            item['originalPrice']?.toString() ?? item['mrp']?.toString() ?? '0',
          ) ??
          price;

      if (originalPrice > price)
        dbTotalSavings += (originalPrice - price) * qty;

      double itemTotal = price * qty;
      double gstRate = 0.0;
      if (item['gst'] != null) {
        gstRate =
            double.tryParse(
              item['gst'].toString().replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0.0;
      }
      dbTaxableValue += itemTotal / (1 + (gstRate / 100));

      double weight = double.tryParse(item['weight']?.toString() ?? '0') ?? 0.0;
      totalWeight += (weight * qty);
    }

    // ==========================================================
    // 🚀 3. ORDER CREATION (Cashier Instant Exit Mode)
    // ==========================================================
    Map<String, dynamic> orderData = {
      'orderType': 'DIRECT_POS',
      'invoiceNo': finalInvoiceNo,
      'cashierId': user.uid,
      'cashierName':
          user.displayName ??
          'Manager', // 🚀 FIX: Database me Naam save hoga UID ke sath
      'customerPhone': customerPhone,

      'items': items,
      'taxableValue': dbTaxableValue,
      'totalSavings': dbTotalSavings,
      'subtotal': totalAmount - gstTotal,
      'gstTotal': gstTotal,
      'totalAmount': totalAmount,
      'totalWeight': totalWeight,
      'paymentMode': paymentMode,

      'status': 'completed',
      'paymentStatus': 'PAID',
      'exitStatus': 'APPROVED',
      'generatedBy': 'CASHIER',

      'qrConsumed': true,
      'timestamp': FieldValue.serverTimestamp(),
      'paymentCompletedAt': FieldValue.serverTimestamp(),
      'exitTimestamp': FieldValue.serverTimestamp(),

      'wasEverRejected': false,
      'weightVerifiedAtGate': true,
      'weightMismatchFlag': false,
      'totalExpectedWeight': totalWeight,
      'riskLevel': 'LOW',
      'guardRecommendation': 'APPROVE',

      // 🚀 FIXED: Dynamic params injected safely
      'tenantId': tenantId,
      'storeId': branchCode,
      'branchCode': branchCode,
      'isDeleted': false,
    };

    batch.set(orderRef, orderData);

    // ==========================================================
    // 🚀 4. THE BULLETPROOF INVENTORY ENGINE (Deduction)
    // ==========================================================
    for (var item in items) {
      String barcode =
          item['barcode']?.toString() ?? item['id']?.toString() ?? '';
      if (barcode.isEmpty) {
        // ⚡ FIX: Pehle silently skip hota tha — ab audit log banega.
        batch.set(_db.collection('admin_audit_logs').doc(), {
          'timestamp': FieldValue.serverTimestamp(),
          'actionType': 'STOCK_SYNC_SKIPPED',
          'reason': 'Missing barcode/id on cart item',
          'itemName': item['name']?.toString() ?? 'Unknown',
          'orderId': orderRef.id,
          'tenantId': tenantId,
          'branchCode': branchCode,
          'severity': 'WARNING',
        });
        continue;
      }

      int qty =
          int.tryParse(
            item['quantity']?.toString() ?? item['qty']?.toString() ?? '1',
          ) ??
          1;
      String cType = item['clearanceType'] ?? '';
      int buyQty = int.tryParse(item['buyQty']?.toString() ?? '1') ?? 1;
      int freeQty = int.tryParse(item['freeQty']?.toString() ?? '0') ?? 0;
      String freeProductId = item['freeProductId'] ?? '';

      int mainItemDeduction = qty;
      int crossItemDeduction = 0;

      if (cType == 'BOGO') {
        int combos = buyQty > 0 ? (qty ~/ buyQty) : 0;
        mainItemDeduction = qty + (combos * freeQty);
      } else if (cType == 'BUY_X_GET_Y' && freeProductId.isNotEmpty) {
        int combos = buyQty > 0 ? (qty ~/ buyQty) : 0;
        crossItemDeduction = combos * freeQty;
      }

      final pSnap = await _db
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .where('tenantId', isEqualTo: tenantId)
          .where('branchCode', isEqualTo: branchCode)
          .limit(1)
          .get();

      if (pSnap.docs.isNotEmpty) {
        final pDoc = pSnap.docs.first;
        final pData = pDoc.data();
        bool isService =
            (pData['itemType'] ?? '').toString().toUpperCase() == 'SERVICE' ||
            item['isService'] == true;

        if (!isService) {
          batch.update(pDoc.reference, {
            'physicalStock': FieldValue.increment(-mainItemDeduction),
            'soldStock': FieldValue.increment(mainItemDeduction),
          });
        }
      } else {
        // ⚡ FIX: Product na milne pe stock silently out-of-sync reh jata
        // tha bina kisi trace ke — ab audit log banega.
        batch.set(_db.collection('admin_audit_logs').doc(), {
          'timestamp': FieldValue.serverTimestamp(),
          'actionType': 'STOCK_SYNC_FAILED',
          'reason': 'Product not found for barcode+tenant+branch',
          'barcode': barcode,
          'orderId': orderRef.id,
          'tenantId': tenantId,
          'branchCode': branchCode,
          'severity': 'WARNING',
        });
      }

      if (crossItemDeduction > 0) {
        final fSnap = await _db
            .collection('products')
            .where('barcode', isEqualTo: freeProductId)
            .limit(1)
            .get();

        if (fSnap.docs.isNotEmpty) {
          final fDoc = fSnap.docs.first;
          final fData = fDoc.data();
          bool isCrossService =
              (fData['itemType'] ?? '').toString().toUpperCase() == 'SERVICE';

          if (!isCrossService) {
            batch.update(fDoc.reference, {
              'physicalStock': FieldValue.increment(-crossItemDeduction),
              'soldStock': FieldValue.increment(crossItemDeduction),
            });
          }
        }
      }
    }

    await batch.commit();
    return orderRef.id;
  }
}
