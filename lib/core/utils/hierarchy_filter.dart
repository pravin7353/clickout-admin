import 'package:cloud_firestore/cloud_firestore.dart';

class HierarchyFilter {
  // 🚀 THE UNIVERSAL QUERY BUILDER
  static Query apply(Query baseQuery, Map<String, dynamic>? adminData) {
    // Agar data nahi hai, toh restricted access do safety ke liye
    if (adminData == null) {
      return baseQuery.where('tenantId', isEqualTo: 'RESTRICTED');
    }

    final String role = (adminData['role'] ?? '').toString().toUpperCase();
    final String? tenantId = adminData['tenantId'];
    final String? zoneId = adminData['zoneId'];
    final String? regionId = adminData['regionId'];
    final String? branchCode = adminData['branchCode'];

    // 1. Super Admin Bypass (Aapke liye)
    if (role == 'SUPER_ADMIN') return baseQuery;

    // 2. Tenant Level Isolation (Har query me tenant match hona MUST hai)
    Query q = baseQuery;
    if (tenantId != null && tenantId.isNotEmpty) {
      q = q.where('tenantId', isEqualTo: tenantId);
    } else {
      return q.where('tenantId', isEqualTo: 'RESTRICTED'); // Block orphan data
    }

    // 3. Drill-down Hierarchy Isolation (Politics & Scope)
    if (role == 'TENANT_ADMIN' || role == 'OWNER') {
      return q; // Can see everything inside their company
    } else if (role == 'ZH') {
      return q.where(
        'zoneId',
        isEqualTo: zoneId,
      ); // Can see all regions in their zone
    } else if (role == 'RH') {
      return q.where(
        'regionId',
        isEqualTo: regionId,
      ); // Can see all branches in their region
    } else if (role == 'BH' ||
        role == 'MANAGER' ||
        role == 'CASHIER' ||
        role == 'GUARD') {
      return q.where(
        'branchCode',
        isEqualTo: branchCode,
      ); // Restricted to their single branch
    }

    // Default fallback for lowest/unknown access
    return q.where('branchCode', isEqualTo: 'RESTRICTED');
  }
}
