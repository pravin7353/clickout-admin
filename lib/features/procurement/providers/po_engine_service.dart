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

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }

      final lowStockSnaps = await query.get();
      if (lowStockSnaps.docs.isEmpty) {
        state = false;
        return 0;
      }

      Map<String, List<Map<String, dynamic>>> supplierGroups = {};
      for (var doc in lowStockSnaps.docs) {
        // 🚀 THE FIX: Dart ko batao ki ye Map hai!
        final data = doc.data() as Map<String, dynamic>;

        if (data['isBlocked'] == true || data['isDeleted'] == true) continue;

        String supplier = data['supplierId'] ?? 'DEFAULT_SUPPLIER';
        int reorderQty = 50;

        if (!supplierGroups.containsKey(supplier)) {
          supplierGroups[supplier] = [];
        }
        supplierGroups[supplier]!.add({
          'productId': doc.id,
          'name': data['name'],
          'orderQty': reorderQty,
        });
      }

      for (var supplierId in supplierGroups.keys) {
        final items = supplierGroups[supplierId]!;
        await _db.collection('purchase_orders').add({
          'supplierId': supplierId,
          'items': items,
          'totalItems': items.length,
          'status': 'DRAFT',
          'createdAt': FieldValue.serverTimestamp(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
          'generatedBy': 'AI_ENGINE',
        });
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

  // 🚀 3. MANUAL PO ENGINE
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

      await poRef.set({
        'poId': poRef.id,
        'supplierId': supplierId.toUpperCase(),
        'status': 'PENDING_APPROVAL',
        'branchCode': branchCode.toUpperCase(),
        'expectedDelivery': Timestamp.fromDate(deliveryDate),
        'notes': notes ?? '',
        'items': [
          {'productId': productId, 'name': productName, 'orderQty': orderQty},
        ],
        'totalItems': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'generatedBy': adminEmail,
        'tenantId':
            tenantId, // 🚀 SAAS INJECTION (Added here as well for safety)
      });

      await _db.collection('mail').add({
        'to': 'orders@${supplierId.toString().toLowerCase()}.com',
        'message': {
          'subject':
              'URGENT: Purchase Order #${poRef.id} from ClickOut', // 🛠️ Bracket formatting fixed
          'html':
              '<h3>Purchase Order: #${poRef.id}</h3><p>Please deliver <b>$orderQty Units</b> of <b>$productName</b> to $branchCode by ${deliveryDate.toLocal().toString().split(' ')[0]}.</p>',
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

      final poRef = await _db.collection('purchase_orders').add({
        'supplierId': supplierId,
        'status': 'APPROVED',
        'branchCode': branchCode,
        'expectedDelivery': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 3)),
        ),
        'items': [
          {
            'productId': suggestionData['productId'],
            'name': productName,
            'orderQty': orderQty,
          },
        ],
        'totalItems': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'approvedBy': 'AI_engine_CONFIRMED_BY_$adminEmail',
        'approvedAt': FieldValue.serverTimestamp(),
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });

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
