import 'package:clickout_admin/features/procurement/po_approval_screen.dart';
import 'package:clickout_admin/features/tenant_admin/screens/tenant_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
import '../../features/tenant_admin/screens/org_structure_screen.dart';
import '../../features/tenant_admin/screens/tenant_onboarding_screen.dart';
import '../../features/tenant_admin/providers/tenant_dashboard_provider.dart';
import '../../features/tenant_admin/screens/client_registration_screen.dart';
import '../../features/super_admin/screens/super_admin_screen.dart';

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
        final role = (adminData.value!['role'] ?? '').toString().toUpperCase();

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

            // If loaded, check status. Fallback to true to prevent accidental lockouts.
            final isComplete =
                profileAsync.value?['isOnboardingComplete'] ?? true;

            if (!isComplete && currentPath != '/tenant-onboarding') {
              return '/tenant-onboarding';
            }
            if (isComplete && currentPath == '/') {
              return '/tenant-dashboard/$tId';
            }
          }
        }

        // 🛡️ 2. SUPER_ADMIN RULES (LEVEL 1 ARCHITECTURE)
        if (role == 'SUPER_ADMIN') {
          // If SA is on root, ensure they see Network Overview
          if (currentPath == '/') return null;
        }

        // 🛡️ 3. MANAGER RULES (LEVEL 3 ARCHITECTURE)
        if (role == 'MANAGER') {
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

        // 4. ORG STRUCTURE PROTECTION
        final isTopLevelAdmin = [
          'SUPER_ADMIN',
          'TENANT_ADMIN',
          'OWNER',
          'ADMIN',
        ].contains(role);
        if (currentPath == '/org-structure' && !isTopLevelAdmin) return '/';
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
            builder: (context, state) => const ManagerScreen(),
          ),
          GoRoute(
            path: '/auditor',
            builder: (context, state) => const AuditorScreen(),
          ),
          GoRoute(
            path: '/risk',
            builder: (context, state) => const RiskEngineScreen(),
          ),
          GoRoute(
            path: '/guard',
            builder: (context, state) => const GuardScreen(),
          ),
          GoRoute(
            path: '/cashier',
            builder: (context, state) => const CashierScreen(),
          ),
          GoRoute(
            path: '/fraud',
            builder: (context, state) => const FraudControlScreen(),
          ),
          GoRoute(
            path: '/qr-reactivation',
            builder: (context, state) => const QrReactivationScreen(),
          ),
          GoRoute(
            path: '/refunds',
            builder: (context, state) => const RefundDecisionScreen(),
          ),
          GoRoute(
            path: '/procurement',
            builder: (context, state) => const POApprovalScreen(),
          ),
          GoRoute(
            path: '/growth',
            builder: (context, state) =>
                const GrowthRadarScreen(), // 🚀 LINKED TO NEW SCREEN
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
          GoRoute(
            path: '/org-structure',
            builder: (context, state) => const OrgStructureScreen(),
          ),
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
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
    ],
  );

  ref.listen(authStateProvider, (_, __) => router.refresh());
  ref.listen(adminRoleProvider, (_, __) => router.refresh());

  return router;
});
