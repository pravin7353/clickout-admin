import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/db_collections.dart';
import '../models/tenant_model.dart';

class TenantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createNewTenant(String tenantId, Tenant tenantData) async {
    try {
      await _db
          .collection(DbCollections.tenants)
          .doc(tenantId)
          .set(tenantData.toFirestore());

      print('[SUCCESS] Tenant $tenantId provisioned successfully.');
    } catch (e) {
      print('[ERROR] Failed to create tenant $tenantId: $e');
      throw Exception('Tenant creation failed: $e');
    }
  }

  // Example: Get Tenant Details
  Future<Tenant?> getTenantDetails(String tenantId) async {
    try {
      DocumentSnapshot doc = await _db
          .collection(DbCollections.tenants)
          .doc(tenantId)
          .get();
      if (doc.exists) {
        return Tenant.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('[ERROR] Error fetching tenant: $e');
      return null;
    }
  }
}
