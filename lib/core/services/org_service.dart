import 'package:cloud_firestore/cloud_firestore.dart';

class OrgService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📡 FETCH COMPANY ROLES
  static Future<List<Map<String, dynamic>>> fetchTenantRoles(
    String tenantId,
  ) async {
    try {
      final snap = await _db
          .collection('org_structure')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('level', descending: false) // Level 1 (Top) se start hoga
          .get();

      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Failed to fetch Org Structure: $e");
    }
  }

  // 🚀 CREATE A NEW CUSTOM ROLE
  static Future<void> createCustomRole({
    required String tenantId,
    required String roleName, // e.g., "Wealth Head"
    required String? reportsToId, // Pata chalega kiske under aata hai
    required int level, // e.g., Level 3
    required String
    tagPrefix, // e.g., "WEALTH" (Aage chal ke WEALTH_MUMBAI banega)
    required String actorEmail, // Audit ke liye
  }) async {
    try {
      // Clean up inputs to make standard IDs
      String cleanRoleName = roleName.trim().toUpperCase().replaceAll(' ', '_');
      String roleId = "${tenantId}_$cleanRoleName";

      final roleRef = _db.collection('org_structure').doc(roleId);
      final auditRef = _db.collection('admin_audit_logs').doc();

      final batch = _db.batch();

      // 1. Save the new Role in the Tree
      batch.set(roleRef, {
        'roleId': roleId,
        'tenantId': tenantId,
        'roleName': roleName.trim(),
        'reportsTo': reportsToId, // Agar Top level hai toh null hoga
        'level': level,
        'tagPrefix': tagPrefix.trim().toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Audit Trail
      batch.set(auditRef, {
        'action': 'CUSTOM_ROLE_CREATED',
        'tenantId': tenantId,
        'roleName': roleName,
        'actor': actorEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw "Failed to create Role: $e";
    }
  }
}
