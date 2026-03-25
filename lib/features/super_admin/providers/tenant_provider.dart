import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🏢 1. TENANT MODEL
class TenantModel {
  final String id;
  final String companyName;
  final String plan;
  final int maxStores;
  final bool isActive;
  final DateTime createdAt;

  TenantModel({
    required this.id,
    required this.companyName,
    required this.plan,
    required this.maxStores,
    required this.isActive,
    required this.createdAt,
  });

  factory TenantModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TenantModel(
      id: doc.id,
      companyName: data['companyName'] ?? 'Unknown',
      plan: (data['subscriptionPlan'] ?? 'BASIC').toString().toUpperCase(),
      maxStores: data['maxStores'] ?? 1,
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ⚙️ 2. TENANT MASTER ENGINE
class TenantMasterNotifier extends AsyncNotifier<List<TenantModel>> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<TenantModel>> build() async {
    return _fetchTenants();
  }

  Future<List<TenantModel>> _fetchTenants() async {
    try {
      final snap = await _db
          .collection('tenants')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => TenantModel.fromDoc(doc)).toList();
    } catch (e) {
      throw Exception("Failed to load tenants: $e");
    }
  }

  // 🚀 CORE SAAS ONBOARDING (Atomic Transaction)
  Future<void> onboardNewTenant({
    required String companyName,
    required String plan,
    required String adminName,
    required String adminPhone,
    required String adminEmail,
  }) async {
    try {
      // 1. Generate unique Tenant ID (e.g., clickout_reliance)
      String baseId = companyName
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      String tenantId =
          "tenant_${baseId}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

      // 2. Determine Plan Limits
      int maxStores = plan == 'ENTERPRISE' ? 1000 : (plan == 'PRO' ? 50 : 5);

      final tenantRef = _db.collection('tenants').doc(tenantId);
      final adminStaffRef = _db.collection('staff').doc(); // First Admin
      final auditRef = _db.collection('admin_audit_logs').doc();

      // 3. ATOMIC BATCH WRITE (SaaS Best Practice)
      final batch = _db.batch();

      // A. Create Company (Tenant)
      batch.set(tenantRef, {
        'tenantId': tenantId,
        'companyName': companyName.trim(),
        'subscriptionPlan': plan,
        'billingStatus': 'ACTIVE',
        'maxStores': maxStores,
        'maxUsers': maxStores * 20, // Avg 20 staff per store
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // B. Create the First Admin Account for this Company
      batch.set(adminStaffRef, {
        'docId': adminStaffRef.id,
        'empId': 'ADMIN-001',
        'role': 'TENANT_ADMIN', // 👑 Master of their own company
        'name': adminName.trim(),
        'phone': adminPhone.trim(),
        'email': adminEmail.trim().toLowerCase(),
        'branchCode': 'HQ', // Headquarters
        'status': 'ACTIVE',
        'isActive': true,
        'isDeleted': false,
        'tenantId': tenantId, // 🔒 Locked to their new company
        'createdAt': FieldValue.serverTimestamp(),
      });

      // C. Super Admin Audit Log
      final superAdminEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'SuperAdmin';
      batch.set(auditRef, {
        'action': 'TENANT_ONBOARDED',
        'tenantId': tenantId,
        'companyName': companyName,
        'adminCreated': adminEmail,
        'actor': superAdminEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Refresh the list
      ref.invalidateSelf();
    } catch (e) {
      throw "Onboarding Failed: $e";
    }
  }
}

final tenantMasterProvider =
    AsyncNotifierProvider<TenantMasterNotifier, List<TenantModel>>(() {
      return TenantMasterNotifier();
    });
