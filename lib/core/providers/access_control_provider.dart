import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: Adjust import path to your actual auth_provider file
import '../../features/auth/auth_provider.dart';
import '../../features/tenant_admin/providers/tenant_dashboard_provider.dart';
import '../subscription/engine/feature_flag_matrix.dart';

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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🔒 SUBSCRIPTION ACCESS PROVIDERS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Current plan of logged-in tenant
final currentPlanProvider = Provider<String>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  if (adminData == null) return 'mini';
  final tenantId = adminData['tenantId']?.toString() ?? '';
  if (tenantId.isEmpty) return 'mini';
  final tenantAsync = ref.watch(tenantProfileProvider(tenantId));
  final tenantData = tenantAsync.value;
  if (tenantData == null) return 'mini';
  final plan = tenantData.entries
      .firstWhere(
        (e) => e.key.trim() == 'subscriptionPlan',
        orElse: () => const MapEntry('subscriptionPlan', 'mini'),
      )
      .value
      .toString()
      .trim();
  final status = tenantData['billingStatus']?.toString() ?? 'active';
  // ignore: avoid_print
  print('🔍 PLAN DEBUG → tenantId: $tenantId | plan: $plan | status: $status');
  if (status == 'expired' || status == 'suspended') return 'mini';
  return plan;
});

// Trial days remaining. -1 = not on trial or expired trial.
final trialDaysRemainingProvider = Provider<int>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  if (adminData == null) return -1;
  final tenantId = adminData['tenantId']?.toString() ?? '';
  if (tenantId.isEmpty) return -1;
  final tenantData = ref.watch(tenantProfileProvider(tenantId)).value;
  final trialEndsAt = tenantData?['trialEndsAt'];
  if (trialEndsAt == null) return -1;
  final endDate = (trialEndsAt as Timestamp).toDate();
  final remaining = endDate.difference(DateTime.now()).inDays;
  return remaining >= 0 ? remaining : -1;
});

// Is subscription expired or suspended?
final isSubscriptionExpiredProvider = Provider<bool>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  if (adminData == null) return false;
  final tenantId = adminData['tenantId']?.toString() ?? '';
  if (tenantId.isEmpty) return false;
  final tenantData = ref.watch(tenantProfileProvider(tenantId)).value;
  if (tenantData == null) return false;

  final billingStatus = tenantData['billingStatus']?.toString() ?? 'active';
  if (billingStatus == 'expired' || billingStatus == 'suspended') return true;

  // Trial expiry check — billingStatus change na ho tab bhi kaam kare
  final plan = tenantData['subscriptionPlan']?.toString() ?? 'trial';
  if (plan == 'trial') {
    final trialEndsAt = tenantData['trialEndsAt'];
    if (trialEndsAt == null) return false;
    final endDate = (trialEndsAt as Timestamp).toDate();
    return DateTime.now().isAfter(endDate);
  }

  return false;
});

// Is a specific route accessible for current plan?
// Usage: ref.watch(isRouteAllowedProvider('/growth'))
final isRouteAllowedProvider = Provider.family<bool, String>((ref, route) {
  final planString = ref.watch(currentPlanProvider);
  if (planString == 'trial') {
    final trialDays = ref.watch(trialDaysRemainingProvider);
    if (trialDays >= 0) return true;
  }
  final minPlanString = kRouteMinPlan[route];
  if (minPlanString == null) return true;
  final userIndex = kPlanHierarchy.indexOf(planString);
  final requiredIndex = kPlanHierarchy.indexOf(minPlanString);
  if (userIndex == -1 || requiredIndex == -1) return false;
  return userIndex >= requiredIndex;
});

// What plan is required to unlock this route? (for popup message)
final requiredPlanForRouteProvider = Provider.family<String, String>((
  ref,
  route,
) {
  const growthOnlyRoutes = ['/guard', '/risk', '/qr-reactivation'];
  return growthOnlyRoutes.contains(route) ? 'GROWTH' : 'PRO';
});
