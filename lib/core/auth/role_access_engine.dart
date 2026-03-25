// lib/core/auth/role_access_engine.dart
class RoleAccessEngine {
  // ==========================================================
  // 1. APP LEVEL PERMISSIONS (Branch Level)
  // ==========================================================
  static const Map<String, List<String>> _appPermissions = {
    'clickout_cashier': ['CASHIER'],
    'clickout_guard': ['GUARD'],
    'clickout_manager': [
      'MANAGER',
      'SUPER_ADMIN',
      'TENANT_ADMIN',
    ], // Elevated roles can view
    'clickout_admin': ['SUPER_ADMIN', 'TENANT_ADMIN'],
  };

  static bool canAccessApp({
    required String userRole,
    required String currentAppName,
  }) {
    final allowedRoles = _appPermissions[currentAppName] ?? [];
    return allowedRoles.contains(userRole.toUpperCase());
  }

  // ==========================================================
  // 2. FEATURE PERMISSIONS (Flat Architecture Sync)
  // ==========================================================
  static List<String> getFeaturesForRole(String role) {
    switch (role.toUpperCase()) {
      case 'CASHIER':
        return ['BILLING', 'CHECKOUT'];
      case 'GUARD':
        return ['ENTRY_VERIFICATION', 'EXIT_SCAN'];
      case 'AUDITOR':
        return ['VIEW_BRANCH_REPORTS', 'VERIFY_INVENTORY'];
      case 'MANAGER':
        return [
          'MANAGE_BRANCH_STAFF',
          'VIEW_BRANCH_REPORTS',
          'MONITOR_CASHIER',
        ];
      case 'TENANT_ADMIN':
        return [
          'MANAGE_ALL_STORES',
          'MANAGE_TENANT_STAFF',
          'VIEW_TENANT_REPORTS',
          'CONFIGURE_TENANT',
        ];
      case 'SUPER_ADMIN':
        return ['MANAGE_ALL_TENANTS', 'SYSTEM_CONFIG', 'GLOBAL_AUDIT_LOGS'];
      default:
        return [];
    }
  }

  // ==========================================================
  // 3. ENTERPRISE SAAS IAM LOGIC (Helper Booleans)
  // ==========================================================

  static const String superAdmin = 'SUPER_ADMIN';
  static const String tenantAdmin = 'TENANT_ADMIN';
  static const String manager = 'MANAGER';

  /// Only Super Admin can do platform-level changes (System Config)
  static bool isSuperAdmin(String role) {
    return role.toUpperCase() == superAdmin;
  }

  /// Tenant Admins can create/delete stores and manage their own plans
  static bool isTenantAdmin(String role) {
    return role.toUpperCase() == tenantAdmin;
  }

  /// Can they manage stores and tenant-level staff?
  static bool canManageTenantOperations(String role) {
    return [superAdmin, tenantAdmin].contains(role.toUpperCase());
  }

  /// Can they manage operations within a specific branch?
  static bool canManageBranchOperations(String role) {
    return [superAdmin, tenantAdmin, manager].contains(role.toUpperCase());
  }
}
