import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🚀 FIX: Sahi path lagaya hai (added 'providers' folder)
import 'package:clickout_admin/features/auth/auth_provider.dart';

class POEngineNotifier extends Notifier<bool> {
  final _db = FirebaseFirestore.instance;

  @override
  bool build() => false;

  // ⚙️ 1. AUTO-GENERATOR (🚀 SAAS INJECTED)
  Future<int> generateDraftPOs() async {
    state = true;
    int posCreated = 0;
    try {
      // 🚀 SAAS CONTEXT
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];
      final role = (ref.read(adminRoleProvider).value?['role'] ?? '')
          .toString()
          .toLowerCase();

      Query query = _db
          .collection('products')
          .where('physicalStock', isLessThanOrEqualTo: 20);

      // 🚀 THE WALL: Fetch Branch Code
      final branchCode = ref.read(adminRoleProvider).value?['branchCode'];

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }

      // 🛡️ THE WALL: Branch Isolation for Managers
      if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
        query = query.where('branchCode', isEqualTo: branchCode);
      }

      final lowStockSnaps = await query.get();
      if (lowStockSnaps.docs.isEmpty) {
        state = false;
        return 0;
      }

      // 🚀 CACHE: Store fallback supplier to avoid querying DB inside the loop
      String? fallbackSupplierId;

      Map<String, List<Map<String, dynamic>>> supplierGroups = {};
      for (var doc in lowStockSnaps.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['isBlocked'] == true || data['isDeleted'] == true) continue;

        String supplier = data['supplierId'] ?? '';

        // 🚀 STEP 1 & 2: RESOLVE SUPPLIER SAFELY
        if (supplier.isEmpty || supplier == 'DEFAULT_SUPPLIER') {
          if (fallbackSupplierId == null) {
            Query supQ = _db.collection('suppliers').limit(1);
            if (role != 'super_admin' &&
                tenantId != null &&
                tenantId.isNotEmpty) {
              supQ = supQ.where('tenantId', isEqualTo: tenantId);
            }
            final defaultSupSnap = await supQ.get();
            if (defaultSupSnap.docs.isNotEmpty) {
              fallbackSupplierId = defaultSupSnap.docs.first.id;
            }
          }

          if (fallbackSupplierId != null) {
            supplier = fallbackSupplierId;
            debugPrint(
              "⚠️ WARNING: Product ${doc.id} missing supplier. Auto-assigned fallback: $supplier",
            );
          } else {
            debugPrint(
              "🚨 ERROR: No valid supplier found in DB. Skipping PO for product ${doc.id}",
            );
            continue; // Skip PO creation for this product to prevent "Unknown" bug
          }
        }

        int reorderQty = 50;
        // 💰 FINANCIAL CALCULATION (FIXED: Real unitCost with 30% fallback)
        double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0.0;
        double unitCost =
            double.tryParse(data['unitCost']?.toString() ?? '0') ?? 0.0;
        if (unitCost <= 0) {
          unitCost = price * 0.70; // 🚀 Fallback to 70% of MRP if missing
        }
        double totalItemCost = unitCost * reorderQty;

        if (!supplierGroups.containsKey(supplier)) {
          supplierGroups[supplier] = [];
        }
        supplierGroups[supplier]!.add({
          'productId': doc.id,
          'name': data['name'],
          'orderQty': reorderQty,
          'unitCost': unitCost, // 💰 FINANCIALS
          'totalItemCost': totalItemCost, // 💰 FINANCIALS
        });
      }

      for (var supplierId in supplierGroups.keys) {
        final items = supplierGroups[supplierId]!;

        // Calculate Total PO Value
        double totalOrderValue = 0.0;
        for (var item in items) {
          totalOrderValue += (item['totalItemCost'] as double);
        }

        // 🚀 STEP 3: FETCH AND STORE REAL SUPPLIER NAME FOR FAST UI
        String supplierName = 'Unknown Supplier';
        try {
          final sDoc = await _db.collection('suppliers').doc(supplierId).get();
          if (sDoc.exists) {
            supplierName = sDoc.data()?['name'] ?? 'Unknown Supplier';
          }
        } catch (_) {}

        final docRef = await _db.collection('purchase_orders').add({
          'poId': 'TEMP',
          'supplierId': supplierId,
          'supplierName': supplierName, // 🚀 FAST UI RENDER SUPPORT
          'totalItems': items.length,
          'totalOrderValue': totalOrderValue, // 💰 FINANCIALS
          'status': 'DRAFT',
          'createdAt': FieldValue.serverTimestamp(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
          'generatedBy': 'AI_ENGINE',
          'items': items,
        });
        await docRef.update({'poId': docRef.id});
        posCreated++;
      }
    } catch (e) {
      debugPrint("AI Draft Error: $e");
    } finally {
      state = false;
    }
    return posCreated;
  }

  // ✅ 2. NORMAL APPROVAL SYSTEM
  Future<void> approvePO(String poId) async {
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
      await _db.collection('purchase_orders').doc(poId).update({
        'status': 'APPROVED',
        'approvedBy': adminEmail,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('admin_audit_logs').add({
        'action': 'PO_APPROVED',
        'poId': poId,
        'adminId': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw "Approval Failed: $e";
    }
  }

  // 🚀 3. MANUAL PO ENGINE (ENTERPRISE FINANCIAL SCHEMA)
  Future<void> createManualPO({
    required String productId,
    required String productName,
    required String supplierId,
    required int orderQty,
    required DateTime deliveryDate,
    required String branchCode,
    String? notes,
  }) async {
    state = true;
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
      final poRef = _db.collection('purchase_orders').doc();

      // 🚀 SAAS CONTEXT
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      // 💰 FINANCIAL TRACKING: Fetch Unit Cost dynamically (FIXED)
      final prodSnap = await _db.collection('products').doc(productId).get();
      final prodData = prodSnap.data() ?? {};
      final double price =
          double.tryParse(prodData['price']?.toString() ?? '0') ?? 0.0;
      double unitCost =
          double.tryParse(prodData['unitCost']?.toString() ?? '0') ?? 0.0;
      if (unitCost <= 0) {
        unitCost = price * 0.70; // 🚀 Fallback to 70% of MRP if missing
      }
      final double totalItemCost = unitCost * orderQty;

      await poRef.set({
        'poId': poRef.id,
        'supplierId': supplierId, // 🚀 Real ID Used
        'status': 'PENDING_APPROVAL',
        'branchCode': branchCode.toUpperCase(),
        'expectedDelivery': Timestamp.fromDate(deliveryDate),
        'notes': notes ?? '',
        'totalItems': 1,
        'totalOrderValue': totalItemCost, // 💰 FINANCIAL TRACKING
        'createdAt': FieldValue.serverTimestamp(),
        'generatedBy': adminEmail,
        'tenantId': tenantId, // 🚀 SAAS SECURED
        'items': [
          {
            'productId': productId,
            'name': productName,
            'orderQty': orderQty,
            'unitCost': unitCost, // 💰 FINANCIAL TRACKING
            'totalItemCost': totalItemCost, // 💰 FINANCIAL TRACKING
          },
        ],
      });

      // 🚀 SAAS LOGIC: Fetch REAL Supplier Email
      final supplierSnap = await _db
          .collection('suppliers')
          .doc(supplierId)
          .get();
      final supplierEmail = supplierSnap.data()?['email'];

      // Agar distributor ka email nahi hai, toh testing ke liye aapke email par jayega
      final targetEmail =
          (supplierEmail != null && supplierEmail.toString().isNotEmpty)
          ? supplierEmail
          : 'pravinjaiswal@gmail.com'; // ⚠️ Apna email yahan dal lijiye testing ke liye

      await _db.collection('mail').add({
        'to': targetEmail,
        'message': {
          'subject': 'URGENT: Purchase Order #${poRef.id} from ClickOut',
          'html':
              '<h3>Purchase Order: #${poRef.id}</h3><p>Please deliver <b>$orderQty Units</b> of <b>$productName</b> to <b>$branchCode</b> by ${deliveryDate.toLocal().toString().split(' ')[0]}.</p><br><p>Total Value: ₹$totalItemCost</p>',
        },
      });
    } catch (e) {
      throw "Failed to raise PO: $e";
    } finally {
      state = false;
    }
  }

  // ✅ 4. APPROVE AI SUGGESTION (🚀 SAAS INJECTED)
  Future<void> approveAIPo(
    Map<String, dynamic> suggestionData,
    int orderQty,
    String productName,
  ) async {
    state = true;
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
      final supplierId = suggestionData['supplierId'] ?? 'DEFAULT_SUPPLIER';
      final branchCode = suggestionData['branchCode'] ?? 'HQ';

      // 🚀 SAAS CONTEXT
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      // 💰 FINANCIAL TRACKING (FIXED)
      final prodSnap = await _db
          .collection('products')
          .doc(suggestionData['productId'])
          .get();
      final prodData = prodSnap.data() ?? {};
      final double price =
          double.tryParse(prodData['price']?.toString() ?? '0') ?? 0.0;
      double unitCost =
          double.tryParse(prodData['unitCost']?.toString() ?? '0') ?? 0.0;
      if (unitCost <= 0) {
        unitCost = price * 0.70; // 🚀 Fallback to 70% of MRP if missing
      }
      final double totalItemCost = unitCost * orderQty;

      final poRef = await _db.collection('purchase_orders').add({
        'poId': 'TEMP', // Will update instantly below
        'supplierId': supplierId,
        'status': 'APPROVED',
        'branchCode': branchCode,
        'expectedDelivery': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 3)),
        ),
        'totalItems': 1,
        'totalOrderValue': totalItemCost, // 💰 FINANCIAL TRACKING
        'createdAt': FieldValue.serverTimestamp(),
        'approvedBy': 'AI_engine_CONFIRMED_BY_$adminEmail',
        'approvedAt': FieldValue.serverTimestamp(),
        'tenantId': tenantId, // 🚀 SAAS INJECTION
        'items': [
          {
            'productId': suggestionData['productId'],
            'name': productName,
            'orderQty': orderQty,
            'unitCost': unitCost, // 💰 FINANCIAL TRACKING
            'totalItemCost': totalItemCost, // 💰 FINANCIAL TRACKING
          },
        ],
      });

      await poRef.update({'poId': poRef.id}); // Auto-assign exact ID

      await _db.collection('mail').add({
        'to': 'orders@${supplierId.toString().toLowerCase()}.com',
        'message': {
          'subject':
              'Automated PO: #${poRef.id} from ClickOut Command Center', // 🛠️ Bracket formatting fixed
          'html':
              '<h2>Automated Purchase Order</h2><p>Please deliver <b>$orderQty Units</b> of <b>$productName</b> to $branchCode.</p><p><i>This PO was generated predictively by ClickOut AI.</i></p>',
        },
      });

      await _db
          .collection('ai_po_suggestions')
          .doc(suggestionData['suggestionId'])
          .delete();
    } catch (e) {
      throw "AI Approval Failed: $e";
    } finally {
      state = false;
    }
  }

  // 🗑️ 5. REJECT AI SUGGESTION
  Future<void> rejectAiSuggestion(String suggestionId) async {
    await _db.collection('ai_po_suggestions').doc(suggestionId).delete();
  }
}

final poEngineProvider = NotifierProvider<POEngineNotifier, bool>(() {
  return POEngineNotifier();
});
