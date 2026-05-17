import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION

class ProductMasterNotifier extends Notifier<bool> {
  final _db = FirebaseFirestore.instance;

  @override
  bool build() => false;

  // ➕ 1. ADD PRODUCT (Strict Document Schema)
  Future<void> addNewProduct(Map<String, dynamic> productData) async {
    state = true;
    try {
      final String barcode = productData['barcode'].toString().trim();
      if (barcode.isEmpty) throw "Barcode is strictly required! 🛑";

      // 🚀 SAAS INJECTION: Fetch Context
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String branchCode = adminData?['branchCode'] ?? 'HQ';
      final String adminName =
          adminData?['name'] ?? 'Unknown Manager'; // 🚀 NEW: Fraud Tracking
      final String adminEmail =
          adminData?['email'] ?? 'Unknown Email'; // 🚀 NEW: Fraud Tracking

      // Note: SaaS Best Practice -> Isolate Barcode ID by Tenant & Store
      final String docId =
          '${tenantId}_${branchCode}_$barcode'; // 🚀 FIXED: Store isolation
      final docRef = _db.collection('products').doc(docId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          throw "FRAUD ALERT: Barcode $barcode already exists in your store! 🚨";
        }

        final cleanData = {
          'barcode': barcode,
          'name': productData['name'],
          'itemType':
              'PRODUCT', // 🚀 FIX: Yaha tag lagana zaroori tha DB me save hone ke liye!
          'price': double.tryParse(productData['price'].toString()) ?? 0.0,
          'unitCost':
              double.tryParse(productData['unitCost']?.toString() ?? '0') ??
              0.0, // 🚀 NAYA: Kharidi Bhav sidha DB mein feed hoga!
          'gst': productData['gst'] ?? '0',
          'physicalStock':
              int.tryParse(productData['physicalStock'].toString()) ?? 0,
          'openingStock':
              int.tryParse(productData['physicalStock'].toString()) ?? 0,
          'purchasedStock': 0,
          'soldStock': 0,
          'damagedStock': 0,
          'expiredStock': 0,
          'reservedStock': 0,
          'weight': productData['weight'] ?? '',
          'expiryDate': productData['expiryDate'] != null
              ? Timestamp.fromDate(productData['expiryDate'])
              : null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'searchKey': productData['name'].toString().toLowerCase(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
          'branchCode': branchCode, // 🚀 NEW: Saved to DB for Hierarchy Filter
          'addedBy': adminName, // 🚀 FIX: Fraud Accountability Name
          'addedByEmail': adminEmail, // 🚀 FIX: Fraud Accountability Email
        };

        transaction.set(docRef, cleanData);

        // 🚀 FIX: Removed the duplicate 'adminEmail' declaration.
        // It will now safely use the one we defined at the top of the function.
        transaction.set(_db.collection('admin_audit_logs').doc(), {
          'action': 'NEW_MASTER_PRODUCT_ADDED',
          'barcode': barcode,
          'adminId': adminEmail,
          'timestamp': FieldValue.serverTimestamp(),
          'tenantId': tenantId, // 🚀 SAAS INJECTION
        });
      });
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }

  // ✏️ 2. EDIT PRODUCT (Strict Update Schema)
  Future<void> updateProduct(
    String barcode,
    Map<String, dynamic> updatedData,
  ) async {
    state = true;
    try {
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String branchCode = adminData?['branchCode'] ?? 'HQ';
      final String docId = '${tenantId}_${branchCode}_$barcode'; // 🚀 FIXED
      final docRef = _db.collection('products').doc(docId);

      // 🚀 FETCH CURRENT ADMIN DETAILS FOR FRAUD TRACKING
      final adminName = adminData?['name'] ?? 'Unknown Admin';
      final adminEmail = adminData?['email'] ?? 'Unknown Email';

      final cleanData = {
        'name': updatedData['name'],
        'price': double.tryParse(updatedData['price'].toString()) ?? 0.0,
        if (updatedData.containsKey('unitCost'))
          'unitCost':
              double.tryParse(updatedData['unitCost']?.toString() ?? '0') ??
              0.0,
        'gst': updatedData['gst'] ?? '0',
        'weight': updatedData['weight'],
        'searchKey': updatedData['name'].toString().toLowerCase(),
        'lastEditedBy': adminName, // 🚀 NEW: Logs directly in product doc
        'lastEditedByEmail': adminEmail, // 🚀 NEW: Logs directly in product doc
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updatedData.containsKey('physicalStock')) {
        cleanData['physicalStock'] =
            int.tryParse(updatedData['physicalStock'].toString()) ?? 0;
      }

      if (updatedData.containsKey('expiryDate')) {
        cleanData['expiryDate'] = updatedData['expiryDate'] != null
            ? Timestamp.fromDate(updatedData['expiryDate'])
            : FieldValue.delete();
      }

      await docRef.update(cleanData);

      // 🚀 FIX: Purana duplicate adminEmail line hata diya. Ab ye upar wale (accurate) email ko use karega.
      await _db.collection('admin_audit_logs').doc().set({
        'action': 'MASTER_PRODUCT_UPDATED',
        'barcode': barcode,
        'adminId': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }

  // 🗑️ 3. DELETE PRODUCT
  Future<void> deleteProduct(String barcode, String productName) async {
    state = true;
    try {
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String branchCode = adminData?['branchCode'] ?? 'HQ';
      final String docId = '${tenantId}_${branchCode}_$barcode'; // 🚀 FIXED

      await _db.collection('products').doc(docId).delete();

      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
      await _db.collection('admin_audit_logs').doc().set({
        'action': 'MASTER_PRODUCT_DELETED',
        'barcode': barcode,
        'productName': productName,
        'adminId': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }
}

final productMasterProvider = NotifierProvider<ProductMasterNotifier, bool>(() {
  return ProductMasterNotifier();
});
