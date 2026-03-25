import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';

const double mobileBreakpoint = 768;
const double tabletBreakpoint = 1024;

// --- EXACT THEME SPEC ENFORCEMENT ---
const Color bgDarkTheme = Color(0xFF080B08); // 🚀 Background
const Color cardDarkTheme = Color(0xFF111811); // 🚀 Card/Sidebar
const Color accentGreenTheme = Color(0xFF00C853); // 🚀 Accent

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
    final adminName = adminData?['name'] ?? 'Loading...';
    final rawRole = (adminData?['role'] ?? 'Admin').toString().toUpperCase();
    final adminRoleUI = rawRole.replaceAll('_', ' ');

    final isSuperAdmin = rawRole == 'SUPER_ADMIN';
    final isTenantAdmin = rawRole == 'TENANT_ADMIN';
    final isManager = rawRole == 'MANAGER';
    final roleColor = _getRoleColor(rawRole);

    // 🎨 STRICT THEME ENFORCEMENT
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgMain = isDark ? bgDarkTheme : const Color(0xFFF4F6F8);
    final bgSidebar = isDark ? cardDarkTheme : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = Colors.grey;

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
                  backgroundColor: bgSidebar,
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
                    color: bgSidebar,
                    border: Border(
                      right: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
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
                    textPrimary,
                    textSecondary,
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (!isMobile)
                      _buildTopNavBar(
                        context,
                        adminName,
                        adminRoleUI,
                        roleColor,
                        ref,
                        bgSidebar,
                        textPrimary,
                        textSecondary,
                        isDark,
                      ),

                    _buildCriticalAlertsStrip(),

                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        color: bgMain,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
    Color roleColor,
    WidgetRef ref,
    Color bgTopBar,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: bgTopBar,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Command Center",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: accentGreenTheme,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 5),
              IconButton(
                icon: Icon(Icons.notifications_none, color: textSecondary),
                onPressed: () {},
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: roleColor,
                child: const Icon(Icons.person, color: Colors.white, size: 18),
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
                  Text(
                    roleUI,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
                          isTenantAdmin
                              ? '/'
                              : currentPath, // Fix: Tenant Admin default is /
                          tenantHqColor,
                        ),
                        _buildNavItem(
                          context,
                          Icons.account_tree,
                          "Org Structure",
                          isExpanded,
                          '/org-structure',
                          tenantHqColor,
                        ),
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

              // ==========================================
              // 🏪 3. OPERATIONS
              // ==========================================
              if (isExpanded)
                _buildSectionHeader(
                  "OPERATIONS",
                  operationsColor,
                  showViewOnly: isSuperAdmin,
                ),
              // 🚀 Super Admin ko bhi Dashboard dikhega (View Only mode mein)
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
              _buildNavItem(
                context,
                Icons.inventory_2,
                "Procurement",
                isExpanded,
                '/procurement',
                operationsColor,
                isReadOnly: isSuperAdmin,
              ),
              _buildNavItem(
                context,
                Icons.trending_up,
                "Growth Radar",
                isExpanded,
                '/growth',
                operationsColor,
                isReadOnly: isSuperAdmin,
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
              ),
              _buildNavItem(
                context,
                Icons.gpp_good,
                "Super Guard",
                isExpanded,
                '/guard',
                staffAuditColor,
                isReadOnly: isSuperAdmin,
              ),
              _buildNavItem(
                context,
                Icons.point_of_sale,
                "Cashier Terminals",
                isExpanded,
                '/cashier',
                staffAuditColor,
                isReadOnly: isSuperAdmin,
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
              ),
              _buildNavItem(
                context,
                Icons.gpp_bad_rounded,
                "Fraud Control",
                isExpanded,
                '/fraud',
                financeRiskColor,
                isReadOnly: isSuperAdmin,
              ),
              _buildNavItem(
                context,
                Icons.qr_code_scanner,
                "QR Bailout",
                isExpanded,
                '/qr-reactivation',
                financeRiskColor,
                isReadOnly: isSuperAdmin,
              ),
              _buildNavItem(
                context,
                Icons.currency_exchange,
                "Refund Engine",
                isExpanded,
                '/refunds',
                financeRiskColor,
                isReadOnly: isSuperAdmin,
              ),
              const SizedBox(height: 20),
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
  }) {
    bool isActive = false;

    // 🛡️ SMART HIGHLIGHT LOGIC
    if (route == '/') {
      isActive = currentPath == '/';
    } else {
      isActive = currentPath.startsWith(route);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 15,
            horizontal: isExpanded ? 20 : 0,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? sectionColor.withOpacity(0.1)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive ? sectionColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          alignment: isExpanded ? Alignment.centerLeft : Alignment.center,
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? sectionColor : const Color(0xFF666666),
                size: 24,
              ),
              if (isExpanded) const SizedBox(width: 15),
              if (isExpanded)
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? sectionColor : Colors.grey,
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (isExpanded && isReadOnly)
                const Tooltip(
                  message: 'View-only access',
                  child: Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Color(0xFF666666),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
