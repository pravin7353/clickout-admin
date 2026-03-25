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

      // Note: SaaS Best Practice -> Isolate Barcode ID by Tenant
      final String docId = '${tenantId}_$barcode';
      final docRef = _db.collection('products').doc(docId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          throw "FRAUD ALERT: Barcode $barcode already exists in your store! 🚨";
        }

        final cleanData = {
          'barcode': barcode,
          'name': productData['name'],
          'price': double.tryParse(productData['price'].toString()) ?? 0.0,
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
        };

        transaction.set(docRef, cleanData);

        final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
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
      final String? tenantId = ref.read(adminRoleProvider).value?['tenantId'];
      final String docId = '${tenantId}_$barcode';
      final docRef = _db.collection('products').doc(docId);

      final cleanData = {
        'name': updatedData['name'],
        'price': double.tryParse(updatedData['price'].toString()) ?? 0.0,
        'gst': updatedData['gst'] ?? '0',
        'weight': updatedData['weight'],
        'searchKey': updatedData['name'].toString().toLowerCase(),
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

      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
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
      final String? tenantId = ref.read(adminRoleProvider).value?['tenantId'];
      final String docId = '${tenantId}_$barcode';

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
