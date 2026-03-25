import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/org_service.dart';
import '../../auth/auth_provider.dart'; // 🔒 SaaS Context ke liye
import 'package:cloud_firestore/cloud_firestore.dart';

// 🏢 THE ROLE MODEL
class CustomRole {
  final String id;
  final String roleName;
  final String? reportsTo;
  final int level;
  final String tagPrefix;

  CustomRole({
    required this.id,
    required this.roleName,
    this.reportsTo,
    required this.level,
    required this.tagPrefix,
  });

  factory CustomRole.fromMap(Map<String, dynamic> data) {
    return CustomRole(
      id: data['id'] ?? data['roleId'],
      roleName: data['roleName'] ?? 'Unknown Role',
      reportsTo: data['reportsTo'],
      level: data['level'] ?? 99,
      tagPrefix: data['tagPrefix'] ?? 'TAG',
    );
  }
}

// ⚙️ THE ORG TREE ENGINE
class OrgStructureNotifier extends AsyncNotifier<List<CustomRole>> {
  @override
  Future<List<CustomRole>> build() async {
    return _loadTree();
  }

  Future<List<CustomRole>> _loadTree() async {
    // 🔒 1. SECURE TENANT FETCH: Current admin ki company pata karo
    final adminData = ref.watch(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];

    if (tenantId == null || tenantId.isEmpty) {
      return []; // Agar tenant nahi mila, toh khali list do
    }

    // 📡 2. Fetch from Service
    final rawData = await OrgService.fetchTenantRoles(tenantId);
    return rawData.map((e) => CustomRole.fromMap(e)).toList();
  }

  // ➕ ADD NEW ROLE
  Future<void> addCustomRole({
    required String roleName,
    required String? reportsToId,
    required int level,
    required String tagPrefix,
  }) async {
    final adminData = ref.read(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String actorEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Admin';

    if (tenantId == null) throw "Fatal Error: Tenant Identity missing!";

    await OrgService.createCustomRole(
      tenantId: tenantId,
      roleName: roleName,
      reportsToId: reportsToId,
      level: level,
      tagPrefix: tagPrefix,
      actorEmail: actorEmail,
    );

    // Refresh the UI Tree
    ref.invalidateSelf();
  }

  // ✏️ UPDATE EXISTING ROLE
  Future<void> updateCustomRole({
    required String roleId,
    required String roleName,
    required String? reportsToId,
    required int level,
    required String tagPrefix,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('org_structure')
          .doc(roleId)
          .update({
            'roleName': roleName,
            'reportsTo': reportsToId,
            'level': level,
            'tagPrefix': tagPrefix,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      ref.invalidateSelf(); // UI refresh
    } catch (e) {
      throw "Update Failed: $e";
    }
  }

  // 🗑️ DELETE ROLE
  Future<void> deleteCustomRole(String roleId) async {
    try {
      await FirebaseFirestore.instance
          .collection('org_structure')
          .doc(roleId)
          .delete();
      ref.invalidateSelf(); // UI refresh
    } catch (e) {
      throw "Delete Failed: $e";
    }
  }
}

final orgStructureProvider =
    AsyncNotifierProvider<OrgStructureNotifier, List<CustomRole>>(() {
      return OrgStructureNotifier();
    });
