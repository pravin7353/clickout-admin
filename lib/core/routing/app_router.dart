import 'package:clickout_admin/features/procurement/po_approval_screen.dart';
import 'package:clickout_admin/features/tenant_admin/screens/tenant_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../store/providers/store_provider.dart';
import '../../shared/layouts/admin_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/manager/manager_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auditor/auditor_screen.dart';
import '../../features/risk/risk_screen.dart';
import '../../features/guard/guard_screen.dart';
import '../../features/cashier/cashier_screen.dart';
import '../../features/fraud_control/presentation/fraud_control_screen.dart';
import '../../features/risk/presentation/qr_reactivation_screen.dart';
import '../../features/refund/refund_decision_screen.dart';
import '../../features/growth/growth_radar_screen.dart'; // 🚀 NAYA IMPORT (Linked to New UI)
import '../../features/growth/campaign_manager_screen.dart'; // 🚀 NAYA IMPORT
import '../../features/inventory/presentation/product_control_screen.dart';
import '../../features/service/service_control_screen.dart'; // 🚀 NAYA: Service Control Import
import '../../features/idt/screens/idt_deposits_screen.dart'; // 🚀 NAYA: IDT Deposits
import '../../features/tenant_admin/screens/tenant_onboarding_screen.dart';
import '../../features/tenant_admin/providers/tenant_dashboard_provider.dart';
import '../../features/tenant_admin/screens/client_registration_screen.dart';
import '../../features/super_admin/screens/super_admin_screen.dart';
import '../../features/onboarding/screens/retail_simulator_screen.dart';
import '../../core/subscription/widgets/feature_lock_widget.dart';
import '../../core/subscription/widgets/usage_dashboard_screen.dart'; // 🚀 NAYA IMPORT: Retail Simulator

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final adminData = ref.read(adminRoleProvider);

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.path == '/login'; // 🚀 FIXED
      if (authState.isLoading || adminData.isLoading) return null;

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';

      if (isLoggedIn && adminData.value != null) {
        String role = (adminData.value!['role'] ?? '').toString().toUpperCase();

        // 🚀 DEV BYPASS EMERGENCY FALLBACK: Prevent stale DB references from kicking out root admin
        if (role.isEmpty && authState.value?.email == 'dev@clickout.local') {
          role = 'SUPER_ADMIN';
        }

        if (role.isEmpty) {
          FirebaseAuth.instance.signOut();
          ref.read(authControllerProvider.notifier).logout();
          return '/login';
        }

        final currentPath = state.uri.path; // 🚀 FIXED
        // 🛡️ 1. TENANT_ADMIN RULES (LEVEL 2 ARCHITECTURE)
        if (role == 'TENANT_ADMIN') {
          final tenantAdminBlockedPaths = ['/register-client'];
          if (tenantAdminBlockedPaths.contains(currentPath)) return '/';

          final tId = adminData.value!['tenantId']?.toString() ?? '';
          if (tId.isNotEmpty) {
            // 🚀 BUG FIX: Prevent synchronous read from forcing false-positive onboarding
            final profileAsync = ref.read(tenantProfileProvider(tId));

            // Wait for DB to load. Do not redirect yet!
            if (profileAsync.isLoading) return null;

            // 🚀 PROTECTION GUARD: Check if tenant doc is missing or uncompleted
            if (profileAsync.value == null) {
              return '/simulator';
            }

            final isComplete =
                profileAsync.value?['isOnboardingComplete'] ??
                false; // 🚀 Default to false to handle uncompleted steps safely

            if (!isComplete &&
                currentPath != '/simulator' &&
                currentPath != '/tenant-onboarding') {
              return '/simulator';
            }
            if (isComplete && currentPath == '/') {
              return '/tenant-dashboard/$tId';
            }

            // 🔒 SUBSCRIPTION EXPIRY GATE
            final billingStatus =
                profileAsync.value?['billingStatus']?.toString() ?? 'active';
            final plan =
                profileAsync.value?['subscriptionPlan']?.toString() ?? 'trial';
            final trialEndsAt = profileAsync.value?['trialEndsAt'];

            bool isExpired =
                billingStatus == 'expired' || billingStatus == 'suspended';

            if (!isExpired && plan == 'trial' && trialEndsAt != null) {
              final endDate = (trialEndsAt as Timestamp).toDate();
              isExpired = DateTime.now().isAfter(endDate);
            }

            // Expiry handled by AdminShell overlay — no redirect needed
          }
        }

        // 🛡️ 2. SUPER_ADMIN RULES (LEVEL 1 ARCHITECTURE)
        if (role == 'SUPER_ADMIN') {
          // If SA is on root, ensure they see Network Overview
          if (currentPath == '/') return null;
        }

        // 🛡️ 3. MANAGER RULES (LEVEL 3 ARCHITECTURE)
        // 🚀 UPDATED: Tenant Admin in store context also follows manager rules
        final activeStore = ref.read(activeStoreProvider);
        final isManager = role == 'MANAGER' || role == 'STORE_MANAGER';
        final isTenantInStore = role == 'TENANT_ADMIN' && activeStore != null;

        if (isManager || isTenantInStore) {
          // 🚀 HARD PROTECTION: Only Managers blocked from HQ
          if (isManager &&
              (currentPath.contains('/tenant-dashboard') ||
                  currentPath.contains('/tenant-onboarding'))) {
            return '/dashboard';
          }

          final managerAllowedPaths = [
            '/',
            '/dashboard',
            '/manager',
            '/auditor',
            '/risk',
            '/fraud',
            '/qr-reactivation',
            '/refunds',
            '/procurement',
            '/growth',
            '/inventory',
            '/service-control',
            '/idt-deposits',
            '/guard',
            '/cashier',
          ];
          if (!managerAllowedPaths.contains(currentPath)) {
            return '/dashboard'; // Force to Level 3 Dashboard
          }
          if (currentPath == '/') return '/dashboard';
        }

        // 🚀 ORG STRUCTURE: Temporarily disabled for infra scaling reduction
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AdminShell(currentPath: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, child) {
                  final adminState = ref.watch(adminRoleProvider);

                  // 🚀 FIX: Wait for Firebase data to load on refresh
                  if (adminState.isLoading || adminState.value == null) {
                    return const Scaffold(
                      backgroundColor: Color(0xFF080B08), // bgDarkTheme
                      body: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C853),
                        ),
                      ),
                    );
                  }

                  final role = (adminState.value?['role'] ?? '')
                      .toString()
                      .toUpperCase();

                  if (role == 'SUPER_ADMIN') return const SuperAdminScreen();
                  if (role == 'TENANT_ADMIN') {
                    final tId = adminState.value?['tenantId']?.toString() ?? '';
                    return TenantDashboardScreen(tenantId: tId);
                  }
                  return const DashboardScreen(); // Level 3 Fallback
                },
              );
            },
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/manager',
            builder: (context, state) => const FeatureLockWidget(
              route: '/manager',
              child: ManagerScreen(),
            ),
          ),
          GoRoute(
            path: '/auditor',
            builder: (context, state) => const FeatureLockWidget(
              route: '/auditor',
              child: AuditorScreen(),
            ),
          ),
          GoRoute(
            path: '/risk',
            builder: (context, state) => const FeatureLockWidget(
              route: '/risk',
              child: RiskEngineScreen(),
            ),
          ),
          GoRoute(
            path: '/guard',
            builder: (context, state) =>
                const FeatureLockWidget(route: '/guard', child: GuardScreen()),
          ),
          GoRoute(
            path: '/cashier',
            builder: (context, state) => const CashierScreen(),
          ),
          GoRoute(
            path: '/fraud',
            builder: (context, state) => const FeatureLockWidget(
              route: '/fraud',
              child: FraudControlScreen(),
            ),
          ),
          GoRoute(
            path: '/qr-reactivation',
            builder: (context, state) => const FeatureLockWidget(
              route: '/qr-reactivation',
              child: QrReactivationScreen(),
            ),
          ),
          GoRoute(
            path: '/refunds',
            builder: (context, state) => const FeatureLockWidget(
              route: '/refunds',
              child: RefundDecisionScreen(),
            ),
          ),
          GoRoute(
            path: '/procurement',
            builder: (context, state) => const FeatureLockWidget(
              route: '/procurement',
              child: POApprovalScreen(),
            ),
          ),
          GoRoute(
            path: '/growth',
            builder: (context, state) => const FeatureLockWidget(
              route: '/growth',
              child: GrowthRadarScreen(),
            ),
          ),
          // 🚀 NAYA ROUTE: Campaign Manager Screen
          GoRoute(
            path: '/campaign-manager',
            builder: (context, state) => const CampaignManagerScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const ProductControlScreen(),
          ),
          GoRoute(
            path: '/idt-deposits',
            builder: (context, state) => const IdtDepositsScreen(),
          ),
          GoRoute(
            path: '/service-control',
            builder: (context, state) => const ServiceControlScreen(),
          ),
          // 🚀 Temporarily disabled for future enterprise release
          // GoRoute(
          //   path: '/org-structure',
          //   builder: (context, state) => const OrgStructureScreen(),
          // ),
          GoRoute(
            path: '/tenant-onboarding',
            builder: (context, state) => const TenantOnboardingScreen(),
          ),
          GoRoute(
            path: '/tenant-dashboard/:tenantId',
            builder: (context, state) => TenantDashboardScreen(
              tenantId: state.pathParameters['tenantId']!,
            ),
          ),
          GoRoute(
            path: '/register-client',
            builder: (context, state) => const ClientRegistrationScreen(),
          ),
          // 🚀 RETAIL SIMULATOR ONBOARDING ROUTE
          GoRoute(
            path: '/simulator',
            builder: (context, state) => const RetailSimulatorScreen(),
          ),
          // 🔒 SUBSCRIPTION EXPIRED — placeholder (Task 4 mein replace hoga)
          GoRoute(
            path: '/subscription-expired',
            builder: (context, state) => Stack(
              children: [
                // Portal background — blurred
                IgnorePointer(
                  child: Opacity(
                    opacity: 0.08,
                    child: Container(color: const Color(0xFF080B08)),
                  ),
                ),
                // Lock overlay
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(36),
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111811),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_clock,
                            color: Colors.amber,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Trial Expired',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your free trial has ended. Upgrade to continue using ClickOut.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Plan highlights
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _expiredFeatureRow(
                                'Growth Radar & Churn Intelligence',
                              ),
                              _expiredFeatureRow(
                                'Fraud Detection & Risk Engine',
                              ),
                              _expiredFeatureRow(
                                'Refund Engine & Smart Auditor',
                              ),
                              _expiredFeatureRow(
                                'Procurement & Vendor Intelligence',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Razorpay — Task 6
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Upgrade Now',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            FirebaseAuth.instance.signOut();
                          },
                          child: const Text(
                            'Sign out',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/usage',
            builder: (context, state) => const UsageDashboardScreen(),
          ),
        ],
      ),
    ],
  );

  ref.listen(authStateProvider, (_, __) => router.refresh());
  ref.listen(adminRoleProvider, (_, __) => router.refresh());

  return router;
});

Widget _expiredFeatureRow(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF00C853),
          size: 16,
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13)),
      ],
    ),
  );
}
