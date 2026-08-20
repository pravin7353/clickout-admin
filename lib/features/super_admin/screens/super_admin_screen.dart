import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../modules/global_overview_module.dart';
import '../modules/tenant_intelligence_module.dart';
import '../modules/store_network_module.dart';
import '../modules/fraud_security_module.dart';
import '../modules/revenue_analytics_module.dart';
import '../modules/infra_health_module.dart';
import '../modules/ai_insights_module.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ⚡ NEW: Secure Auth Guard Provider
final superAdminGuardProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // Force token refresh to ensure we have the absolute latest custom claims from backend
  final idTokenResult = await user.getIdTokenResult(true);
  final role = idTokenResult.claims?['role']?.toString().toUpperCase();

  return role == 'SUPER_ADMIN';
});

// ─── STATIC COLORS (for use outside BuildContext) ───
class EnterpriseColors {
  static const Color bgBase = Color(0xFF0A0A0A);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
  static const Color borderSubtle = Color(0x1AFFFFFF);
  static const Color accentNeon = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color riskHigh = Color(0xFFFF3B30);
  static const Color riskMedium = Color(0xFFFF9500);
}

// ─── 2. THEME TOKENS ────────────────────────
extension EnterpriseThemeTokens on BuildContext {
  Color get bgBase => colors.scaffoldBg;
  Color get surfaceGlass => colors.cardBg;
  Color get borderSubtle => colors.border;
  Color get accentNeon => colors.success;
  Color get accentNeonGlow => colors.success.withValues(alpha: 0.1);
  Color get textPrimary => colors.textPrimary;
  Color get textSecondary => colors.textSecondary;
  Color get riskHigh => colors.danger;
  Color get riskMedium => colors.warning;
}

// ─── 3. COMMAND CENTER SHELL (Now Stateful) ────────────────────────────────────────
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  // 🚀 Local state for tabs
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    // ⚡ ENFORCE ROLE-BASED AUTH GUARD
    final authGuard = ref.watch(superAdminGuardProvider);

    return authGuard.when(
      loading: () => Scaffold(
        backgroundColor: context.bgBase,
        body: Center(
          child: CircularProgressIndicator(color: context.accentNeon),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.bgBase,
        body: Center(
          child: Text(
            'Auth Check Failed: $e',
            style: TextStyle(color: context.riskHigh),
          ),
        ),
      ),
      data: (isAuthorized) {
        if (!isAuthorized) {
          return Scaffold(
            backgroundColor: context.bgBase,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gpp_bad, size: 80, color: context.riskHigh),
                  const SizedBox(height: 24),
                  Text(
                    'UNAUTHORIZED ACCESS',
                    style: TextStyle(
                      color: context.riskHigh,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This module is strictly restricted to ClickOut Platform Owners.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.surfaceGlass,
                      side: BorderSide(color: context.borderSubtle),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: Icon(Icons.logout, color: context.textPrimary),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 🟢 Authorized: Render the actual Super Admin Shell
        return Scaffold(
          backgroundColor: context.bgBase,
          body: Row(
            children: [
              // 1. ENTERPRISE SIDEBAR
              _buildSidebar(context),

              // 2. MAIN CONTENT AREA
              Expanded(
                child: Column(
                  children: [
                    // TOP NAV (Universal Search & Profile)
                    _buildTopNav(),

                    // DYNAMIC MODULE CONTENT
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                        ),
                        child: Container(
                          // 🚀 FIX: Removed const because context.borderSubtle requires runtime evaluation
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            border: Border(
                              left: BorderSide(color: context.borderSubtle),
                              top: BorderSide(color: context.borderSubtle),
                            ),
                          ),
                          child: _getModule(_activeTab),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ); // Close authGuard.when
  }

  // ─── SIDEBAR ──────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context) {
    final menuItems = [
      {"icon": Icons.dashboard_rounded, "label": "Global Overview"},
      {"icon": Icons.domain_rounded, "label": "Tenant Intelligence"},
      {"icon": Icons.storefront_rounded, "label": "Store Network"},
      {"icon": Icons.payments_rounded, "label": "Revenue Analytics"},
      {"icon": Icons.security_rounded, "label": "Fraud & Security"},
      {"icon": Icons.memory_rounded, "label": "Infra Health"},
      {"icon": Icons.auto_awesome, "label": "AI Insights"},
    ];

    return Container(
      width: 260,
      color: context.bgBase,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.accentNeonGlow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.accentNeon.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(Icons.blur_on, color: context.accentNeon, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                "CLICKOUT C3",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            "COMMAND MODULES",
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(menuItems.length, (index) {
            final isActive = _activeTab == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => setState(() => _activeTab = index),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? context.surfaceGlass : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? context.borderSubtle
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        menuItems[index]['icon'] as IconData,
                        color: isActive
                            ? context.accentNeon
                            : context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        menuItems[index]['label'] as String,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : context.textSecondary,
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TOP NAVIGATION ───────────────────────────────────────────────
  Widget _buildTopNav() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.surfaceGlass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderSubtle),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search,
                      color: context.textSecondary,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            "Search tenants, invoices, fraud logs... (Cmd+K)",
                        hintStyle: TextStyle(color: context.textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "⌘K",
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.notifications_none, color: context.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: context.borderSubtle),
          const SizedBox(width: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                // 🚀 FIX: Replaced EnterpriseColors.accentNeon with context.accentNeon
                backgroundColor: context.accentNeon,
                child: const Text(
                  "SA",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Super Admin",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "System Owner",
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MODULE ROUTER ───────────────────────────────────────────────
  Widget _getModule(int index) {
    switch (index) {
      case 0:
        return const GlobalOverviewModule();
      case 1:
        return const TenantIntelligenceModule();
      case 2:
        return const StoreNetworkModule();
      case 3:
        return const RevenueAnalyticsModule();
      case 4:
        return const FraudSecurityModule();
      case 5:
        return const InfraHealthModule();
      case 6:
        return const AiInsightsModule();
      default:
        return Center(
          child: Text(
            "Module in development",
            style: TextStyle(color: context.textSecondary),
          ),
        );
    }
  }
}
