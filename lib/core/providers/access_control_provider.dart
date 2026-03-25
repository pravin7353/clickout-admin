import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: Adjust import path to your actual auth_provider file
import '../../features/auth/auth_provider.dart';

// 🔒 Global Read-Only State for Super Admin
final isReadOnlyProvider = Provider<bool>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;

  if (adminData == null) return true; // Safe default

  final role = adminData['role'].toString().toUpperCase();
  // Super Admin has view-only access to store operations
  return role == 'SUPER_ADMIN';
});

// ✏️ Global Edit Permission State
final canEditProvider = Provider<bool>((ref) {
  return !ref.watch(isReadOnlyProvider);
});
