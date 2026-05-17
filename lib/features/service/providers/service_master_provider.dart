import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/store/providers/store_provider.dart';

class ServiceMasterNotifier extends Notifier<bool> {
  final _db = FirebaseFirestore.instance;

  @override
  bool build() => false;

  // ➕ 1. ADD SERVICE (No stock, no weight)
  Future<void> addNewService(Map<String, dynamic> serviceData) async {
    state = true;
    try {
      // 🚀 FIX: Double security on backend! Strip all special chars & force UPPERCASE
      final String barcode = serviceData['barcode']
          .toString()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toUpperCase();

      final adminData = ref.read(adminRoleProvider).value;
      final activeStore = ref.read(activeStoreProvider);

      final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
      final String branchCode =
          activeStore?.branchCode ?? adminData?['branchCode'] ?? 'HQ';
      final String docId = '${tenantId}_${branchCode}_$barcode';

      final cleanData = {
        'barcode': barcode,
        'name': serviceData['name'],
        'price': double.tryParse(serviceData['price'].toString()) ?? 0.0,
        'gst': serviceData['gst'] ?? '0',
        'sac': serviceData['sac'] ?? '',
        'itemType': 'SERVICE', // 🚀 THE MAGIC LABEL FOR CLUBBING
        'searchKey': serviceData['name'].toString().toLowerCase(),
        'tenantId': tenantId,
        'branchCode': branchCode,
        'addedBy': adminData?['name'] ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 🚀 Save in 'products' collection so it clubs in customer cart!
      await _db.collection('products').doc(docId).set(cleanData);
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }

  // 🗑️ 2. DELETE SERVICE
  Future<void> deleteService(String barcode) async {
    state = true;
    try {
      final adminData = ref.read(adminRoleProvider).value;
      final activeStore = ref.read(activeStoreProvider);
      final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
      final String branchCode =
          activeStore?.branchCode ?? adminData?['branchCode'] ?? 'HQ';
      final String docId = '${tenantId}_${branchCode}_$barcode';

      await _db.collection('products').doc(docId).delete();
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }

  // ✏️ 3. UPDATE SERVICE (Paste exactly here)
  Future<void> updateService(
    String barcode,
    Map<String, dynamic> updatedData,
  ) async {
    state = true;
    try {
      final adminData = ref.read(adminRoleProvider).value;
      final activeStore = ref.read(activeStoreProvider);

      // 🛡️ Tenant & Branch Isolation
      final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
      final String branchCode =
          activeStore?.branchCode ?? adminData?['branchCode'] ?? 'HQ';

      // Target correct document
      final String docId = '${tenantId}_${branchCode}_$barcode';

      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection('products').doc(docId).update(updatedData);
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      state = false;
    }
  }
}

final serviceMasterProvider = NotifierProvider<ServiceMasterNotifier, bool>(() {
  return ServiceMasterNotifier();
});
