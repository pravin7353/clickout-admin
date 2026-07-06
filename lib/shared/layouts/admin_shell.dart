import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart'; // 🚀 YE IMPORT MISSING THA
import '../../features/auth/auth_provider.dart';
import '../../features/invoice/invoice_rules_dialog.dart';
import '../../core/store/providers/store_provider.dart';
import '../../features/tenant_admin/screens/edit_store_profile_dialog.dart';
//import '../../features/tenant_admin/screens/edit_tenant_profile_dialog.dart';
import '../../features/manager/widgets/store_entry_qr_card.dart'; // 🚀 NAYA
import '../../core/providers/theme_provider.dart';
import '../../core/providers/access_control_provider.dart';
import '../../core/subscription/widgets/trial_countdown_badge.dart';
import '../../core/subscription/widgets/usage_limit_banner.dart';
import '../../core/subscription/widgets/upgrade_popup.dart';

const double mobileBreakpoint = 768;
const double tabletBreakpoint = 1024;

// --- EXACT THEME SPEC ENFORCEMENT ---
// (We now use Theme.of(context) dynamically, but keeping this for fallback/reference)
const Color bgDarkTheme = Color(0xFF080B08);
const Color cardDarkTheme = Color(0xFF111811);
const Color accentGreenTheme = Color(0xFF00C853);

// --- SECTION COLORS ---
const globalCommandColor = Color(0xFF7F77DD);
const tenantHqColor = accentGreenTheme;
const operationsColor = Color(0xFF378ADD);
const staffAuditColor = Color(0xFFEF9F27);
const financeRiskColor = Color(0xFFE24B4A);

class AdminShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const AdminShell({super.key, required this.child, required this.currentPath});

  Color _getRoleColor(String role) {
    if (role == 'SUPER_ADMIN') return Colors.purpleAccent;
    if (role == 'TENANT_ADMIN') return accentGreenTheme;
    if (role == 'MANAGER') return Colors.blueAccent;
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminData = ref.watch(adminRoleProvider).value;
    final activeStore = ref.watch(activeStoreProvider); // 🚀 Watch Store State

    // 🚀 SMART CLEAR: Jaise hi user wapas HQ (Tenant Dashboard) par aaye, Store lock hata do!
    if (currentPath == '/' && activeStore != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeStoreProvider.notifier).clearStore();
      });
    }

    final adminName = adminData?['name'] ?? 'Loading...';
    final rawRole = (adminData?['role'] ?? 'Admin').toString().toUpperCase();
    final adminRoleUI = rawRole.replaceAll('_', ' ');

    final isSuperAdmin = rawRole == 'SUPER_ADMIN';
    final isTenantAdmin = rawRole == 'TENANT_ADMIN';
    final isManager = rawRole == 'MANAGER';
    final roleColor = _getRoleColor(rawRole);

    // 🎨 STRICT THEME ENFORCEMENT (Using context.colors extension)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgMain = context.colors.scaffoldBg;
    final bgSidebar = context.colors.cardBg;
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < mobileBreakpoint;
        final isDesktop = width >= tabletBreakpoint;

        return Scaffold(
          backgroundColor: bgMain,
          appBar: isMobile
              ? _buildMobileAppBar(context, ref, bgSidebar, textPrimary)
              : null,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: bgSidebar, // 💎 Clean minimal background
                  child: _buildSidebarContent(
                    true,
                    context,
                    adminName,
                    adminRoleUI,
                    rawRole,
                    roleColor,
                    isSuperAdmin,
                    isTenantAdmin,
                    isManager,
                    ref,
                    bgSidebar,
                    textPrimary,
                    textSecondary,
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isDesktop ? 260 : 80,
                  decoration: BoxDecoration(
                    color:
                        bgSidebar, // 💎 Removed Emerald, using semantic cardBg
                    border: Border(
                      right: BorderSide(color: context.colors.border),
                    ),
                  ),
                  child: _buildSidebarContent(
                    isDesktop,
                    context,
                    adminName,
                    adminRoleUI,
                    rawRole,
                    roleColor,
                    isSuperAdmin,
                    isTenantAdmin,
                    isManager,
                    ref,
                    bgSidebar,
                    textPrimary, // 💎 Adapts to light/dark
                    textSecondary, // 💎 Adapts to light/dark
                  ),
                ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final isExpired = ref.watch(isSubscriptionExpiredProvider);
                    return Stack(
                      children: [
                        Column(
                          children: [
                            if (!isMobile)
                              _buildTopNavBar(
                                context,
                                adminName,
                                adminRoleUI,
                                rawRole,
                                adminData?['tenantId']?.toString() ?? '',
                                adminData?['branchCode']?.toString() ?? '',
                                roleColor,
                                ref,
                                bgSidebar,
                                textPrimary,
                                textSecondary,
                                isDark,
                                activeStore,
                              ),

                            _buildCriticalAlertsStrip(),

                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                color: bgMain,
                                child: Column(
                                  children: [
                                    const UsageLimitBanner(),
                                    Expanded(child: child),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 🔒 SUBSCRIPTION EXPIRED OVERLAY
                        if (isExpired)
                          Positioned.fill(
                            child: Stack(
                              children: [
                                Container(
                                  color: Colors.black.withOpacity(0.75),
                                ),
                                // Lock card
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                    ),
                                    padding: const EdgeInsets.all(36),
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
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
                                            color: Colors.amber.withOpacity(
                                              0.1,
                                            ),
                                            border: Border.all(
                                              color: Colors.amber.withOpacity(
                                                0.4,
                                              ),
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
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.04,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              _expiredRow(
                                                'Growth Radar & Churn Intelligence',
                                              ),
                                              _expiredRow(
                                                'Fraud Detection & Risk Engine',
                                              ),
                                              _expiredRow(
                                                'Refund Engine & Smart Auditor',
                                              ),
                                              _expiredRow(
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
                                              showUpgradePopup(
                                                context: context,
                                                route: '/growth',
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF00C853,
                                              ),
                                              foregroundColor: Colors.black,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                          onPressed: () => ref
                                              .read(
                                                authControllerProvider.notifier,
                                              )
                                              .logout(),
                                          child: const Text(
                                            'Sign out',
                                            style: TextStyle(
                                              color: Colors.white38,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _expiredRow(String text) {
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
          Text(
            text,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsStrip() {
    return Container(
      width: double.infinity,
      color: accentGreenTheme.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.shield, color: accentGreenTheme, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "SYSTEM SECURE: No pending operations or fraud anomalies detected.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accentGreenTheme,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildMobileAppBar(
    BuildContext context,
    WidgetRef ref,
    Color bgTopBar,
    Color textPrimary,
  ) {
    return AppBar(
      backgroundColor: bgTopBar,
      title: Text(
        "ClickOut Command",
        style: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      actions: [
        IconButton(
          icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }

  Widget _buildTopNavBar(
    BuildContext context,
    String name,
    String roleUI,
    String rawRole,
    String tenantId,
    String branchCode,
    Color roleColor,
    WidgetRef ref,
    Color bgTopBar,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
    ActiveStoreState? activeStore, // 🚀 NAYA: Store state accepted
  ) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: bgTopBar,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Command Center",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              // 🚀 THE BADGE: Jab bhi user kisi store ke andar hoga, ye chamkega!
              if (activeStore != null) ...[
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeStore.storeName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  tooltip: isDark
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
                  icon: Icon(
                    isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
              ),
              const SizedBox(width: 5),
              const TrialCountdownBadge(),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(width: 10),
              // 🚀 PREMIUM GLASSMORPHIC PROFILE OVERLAY
              GestureDetector(
                onTap: () {
                  _showGlassProfileMenu(
                    context: context,
                    name: name,
                    roleUI: roleUI,
                    rawRole: rawRole,
                    tenantId: tenantId,
                    roleColor: roleColor,
                    isDark: isDark,
                    activeStore: activeStore, // 🚀 ADDED
                    adminData: ref.read(adminRoleProvider).value, // 🚀 ADDED
                  );
                },
                child: CircleAvatar(
                  backgroundColor: roleColor,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        roleUI,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Consumer(
                        builder: (context, ref, _) {
                          final plan = ref
                              .watch(currentPlanProvider)
                              .toUpperCase();
                          final planColor = plan == 'TRIAL'
                              ? Colors.amber
                              : plan == 'MINI'
                              ? Colors.blueGrey
                              : plan == 'PRO'
                              ? Colors.blueAccent
                              : plan == 'GROWTH'
                              ? const Color(0xFF00C853)
                              : Colors.purpleAccent;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: planColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: planColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              plan,
                              style: TextStyle(
                                color: planColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (rawRole == 'TENANT_ADMIN' && tenantId.isNotEmpty)
                    Text(
                      tenantId,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    )
                  else if (rawRole == 'MANAGER' && branchCode.isNotEmpty)
                    Text(
                      "STORE: $branchCode",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
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

  Widget _buildSectionHeader(
    String title,
    Color sectionColor, {
    bool showViewOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 5, top: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: sectionColor, width: 3)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              title,
              style: TextStyle(
                color: sectionColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (showViewOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: sectionColor.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VIEW ONLY',
                style: TextStyle(
                  fontSize: 9,
                  color: sectionColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    bool isExpanded,
    BuildContext context,
    String name,
    String roleUI,
    String rawRole,
    Color roleColor,
    bool isSuperAdmin,
    bool isTenantAdmin,
    bool isManager,
    WidgetRef ref,
    Color bgSidebar,
    Color textPrimary,
    Color textSecondary,
  ) {
    final dividerColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.grey.shade200;

    // 🚀 UPDATED MAGIC TRICK: Tenant Admin in store context OR Manager sees menus
    final activeStore = ref.watch(activeStoreProvider);
    final bool showStoreMenus =
        isManager || (isTenantAdmin && activeStore != null);

    // 🔒 Subscription lock (SUPER_ADMIN ko kabhi lock nahi hoga)
    final bool isProLocked =
        !isSuperAdmin && !ref.watch(isRouteAllowedProvider('/manager'));
    final bool isGrowthLocked =
        !isSuperAdmin && !ref.watch(isRouteAllowedProvider('/guard'));

    return Column(
      children: [
        const SizedBox(height: 20),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'Click',
                      style: TextStyle(color: textPrimary),
                    ),
                    const TextSpan(
                      text: 'Out',
                      style: TextStyle(color: accentGreenTheme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Divider(color: dividerColor, height: 1),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ==========================================
              // 🌍 1. GLOBAL COMMAND (Super Admin Only)
              // ==========================================
              if (isSuperAdmin) ...[
                if (isExpanded)
                  _buildSectionHeader("GLOBAL COMMAND", globalCommandColor),
                _buildNavItem(
                  context,
                  Icons.public,
                  "Network Overview",
                  isExpanded,
                  '/',
                  globalCommandColor,
                ),
                _buildNavItem(
                  context,
                  Icons.domain_add,
                  "Onboard Client",
                  isExpanded,
                  '/register-client',
                  globalCommandColor,
                ),
                // 🚀 SUPER ADMIN EXCLUSIVE: Campaign Manager
                _buildNavItem(
                  context,
                  Icons.campaign_rounded,
                  "Campaign Manager",
                  isExpanded,
                  '/campaign-manager',
                  globalCommandColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: dividerColor, height: 1),
                ),
              ],

              // ==========================================
              // 🏢 2. TENANT HQ
              // ==========================================
              Builder(
                builder: (context) {
                  final bool isInsideTenant = currentPath.startsWith(
                    '/tenant-dashboard/',
                  );
                  final bool showTenantHQ =
                      isTenantAdmin || (isSuperAdmin && isInsideTenant);

                  if (showTenantHQ) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isExpanded)
                          _buildSectionHeader("TENANT HQ", tenantHqColor),
                        _buildNavItem(
                          context,
                          Icons.dashboard_customize,
                          "Tenant Dashboard",
                          isExpanded,
                          isTenantAdmin ? '/' : currentPath,
                          tenantHqColor,
                          onCustomTap: () {
                            ref.read(activeStoreProvider.notifier).clearStore();
                            context.go(isTenantAdmin ? '/' : currentPath);
                          },
                        ),
                        _buildNavItem(
                          context,
                          Icons.analytics_outlined,
                          "Usage",
                          isExpanded,
                          '/usage',
                          tenantHqColor,
                        ),

                        // 🚀 TEMPORARILY DISABLED: Org Structure hidden for now.
                        /*_buildNavItem(
                          context,
                          Icons.account_tree,
                          "Org Structure",
                          isExpanded,
                          '/org-structure',
                          tenantHqColor,
                        ),*/
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(color: dividerColor, height: 1),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),

              // 🚀 MAGIC WRAPPER: Ye condition check karegi tabhi menus dikhenge
              if (showStoreMenus) ...[
                // ==========================================
                // 🏪 3. OPERATIONS
                // ==========================================
                if (isExpanded)
                  _buildSectionHeader(
                    "OPERATIONS",
                    operationsColor,
                    showViewOnly: isSuperAdmin,
                  ),
                _buildNavItem(
                  context,
                  Icons.dashboard,
                  "Dashboard",
                  isExpanded,
                  '/dashboard',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                ),
                _buildNavItem(
                  context,
                  Icons.people_alt,
                  "Super Manager",
                  isExpanded,
                  '/manager',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.inventory,
                  "Product Control",
                  isExpanded,
                  '/inventory',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                ),
                // ✂️ NAYA: SERVICE CONTROL MENU
                _buildNavItem(
                  context,
                  Icons.design_services, // Scissor / Service wala icon
                  "Service Control",
                  isExpanded,
                  '/service-control',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                ),
                // 📦 NAYA: IDT DEPOSITS MENU
                _buildNavItem(
                  context,
                  Icons.move_to_inbox,
                  "IDT Deposits",
                  isExpanded,
                  '/idt-deposits',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                ),
                // 🛒 NAYA: ASSISTED CHECKOUT (POS)
                _buildNavItem(
                  context,
                  Icons.point_of_sale_rounded,
                  "Assisted Checkout",
                  isExpanded,
                  '/cashier',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                ),
                _buildNavItem(
                  context,
                  Icons.inventory_2,
                  "Procurement",
                  isExpanded,
                  '/procurement',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.trending_up,
                  "Growth Radar",
                  isExpanded,
                  '/growth',
                  operationsColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),

                // ==========================================
                // 👮 4. STAFF & AUDIT
                // ==========================================
                if (isExpanded)
                  _buildSectionHeader(
                    "STAFF & AUDIT",
                    staffAuditColor,
                    showViewOnly: isSuperAdmin,
                  ),
                _buildNavItem(
                  context,
                  Icons.account_balance_wallet,
                  "Super Auditor",
                  isExpanded,
                  '/auditor',
                  staffAuditColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.gpp_good,
                  "Super Guard",
                  isExpanded,
                  '/guard',
                  staffAuditColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isGrowthLocked,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: dividerColor, height: 1),
                ),

                // ==========================================
                // 🚨 5. FINANCE & RISK
                // ==========================================
                if (isExpanded)
                  _buildSectionHeader(
                    "FINANCE & RISK",
                    financeRiskColor,
                    showViewOnly: isSuperAdmin,
                  ),
                _buildNavItem(
                  context,
                  Icons.warning_amber_rounded,
                  "Risk Engine",
                  isExpanded,
                  '/risk',
                  financeRiskColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isGrowthLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.gpp_bad_rounded,
                  "Fraud Control",
                  isExpanded,
                  '/fraud',
                  financeRiskColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.qr_code_scanner,
                  "QR Bailout",
                  isExpanded,
                  '/qr-reactivation',
                  financeRiskColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isGrowthLocked,
                ),
                _buildNavItem(
                  context,
                  Icons.currency_exchange,
                  "Refund Engine",
                  isExpanded,
                  '/refunds',
                  financeRiskColor,
                  isReadOnly: isSuperAdmin,
                  isSubscriptionLocked: isProLocked,
                ),
                const SizedBox(height: 20),
              ], // 🚀 WRAPPER CLOSED HERE
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isExpanded,
    String route,
    Color sectionColor, {
    bool isReadOnly = false,
    bool isSubscriptionLocked = false,
    VoidCallback? onCustomTap,
  }) {
    bool isActive = false;

    if (route == '/') {
      isActive = currentPath == '/';
    } else {
      isActive = currentPath.startsWith(route);
    }

    // 💎 Dynamic text colors matching the clean theme
    final inactiveColor = context.colors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCustomTap ?? () => context.go(route),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: isExpanded ? 12 : 0,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? context
                      .colors
                      .cardBg // Subtle active background
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? context.colors.textPrimary : inactiveColor,
                size: 20,
              ),
              if (isExpanded) const SizedBox(width: 12),
              if (isExpanded)
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive
                          ? context.colors.textPrimary
                          : inactiveColor,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (isExpanded && isReadOnly)
                Tooltip(
                  message: 'View-only access',
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: inactiveColor,
                  ),
                ),
              if (isExpanded && isSubscriptionLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'UPGRADE',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (isExpanded && isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade400, // 🟢 Premium Green Dot
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 💎 PROFESSIONAL LINKEDIN-STYLE PROFILE MENU
  void _showGlassProfileMenu({
    required BuildContext context,
    required String name,
    required String roleUI,
    required String rawRole,
    required String tenantId,
    required Color roleColor,
    required bool isDark,
    ActiveStoreState? activeStore,
    Map<String, dynamic>? adminData,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ProfileMenu",
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        // 🚀 LINKEDIN STYLE DESIGN TOKENS
        final bgColor = context.colors.cardBg;
        final borderColor = context.colors.border;
        final iconColor = context.colors.textSecondary;
        final textColor = context.colors.textPrimary;

        return Stack(
          children: [
            Positioned(
              top: 70,
              right: 30,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── HEADER SECTION ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: roleColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 36,
                                color: roleColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              roleUI,
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(color: borderColor, height: 1, thickness: 1),

                      // ── MENU ITEMS ──
                      if (rawRole == 'MANAGER') ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              _buildMenuTile(
                                icon: Icons.edit_note,
                                title: "Edit Profile",
                                iconColor: iconColor,
                                textColor: textColor,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showDialog(
                                    context: context,
                                    builder: (_) => EditStoreProfileDialog(
                                      branchCode:
                                          activeStore?.branchCode ??
                                          adminData?['branchCode'],
                                    ),
                                  );
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.receipt_long,
                                title: "Invoice Rules",
                                iconColor: iconColor,
                                textColor: textColor,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showDialog(
                                    context: context,
                                    builder: (_) => const InvoiceRulesDialog(),
                                  );
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.campaign_rounded,
                                title: "Campaign Manager",
                                iconColor: iconColor,
                                textColor: textColor,
                                onTap: () {
                                  if (MediaQuery.of(context).size.width <
                                      1024) {
                                    if (Navigator.canPop(context))
                                      Navigator.pop(context);
                                  } else {
                                    Navigator.pop(
                                      ctx,
                                    ); // Close desktop dropdown
                                  }
                                  context.go('/campaign-manager');
                                },
                              ),
                              _buildMenuTile(
                                icon: Icons.qr_code_2,
                                title: "Store Entry QR",
                                iconColor: iconColor,
                                textColor: textColor,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showDialog(
                                    context: context,
                                    builder: (_) => const StoreEntryQRCard(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 💎 SLIM & PROFESSIONAL MENU TILE WIDGET
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
