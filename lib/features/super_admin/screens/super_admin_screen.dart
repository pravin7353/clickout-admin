import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── 1. CORE PROVIDERS ───────────
final saasTenantsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('tenants')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => {'docId': doc.id, ...doc.data()})
                .where((t) => t['isDeleted'] != true)
                .toList();
          });
    });

// 🚀 FIX: StateProvider hata diya hai, ab local state use karenge

// ─── 2. THEME TOKENS ────────────────────────
class EnterpriseColors {
  static const Color bgBase = Color(0xFF0A0A0A);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
  static const Color borderSubtle = Color(0x1AFFFFFF);
  static const Color accentNeon = Color(0xFF00C853);
  static const Color accentNeonGlow = Color(0x3300C853);
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color riskHigh = Color(0xFFFF3B30);
  static const Color riskMedium = Color(0xFFFF9500);
}

// ─── 3. COMMAND CENTER SHELL (Now Stateful) ────────────────────────────────────────
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  // 🚀 FIX: Local state for tabs
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnterpriseColors.bgBase,
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF111111),
                        border: Border(
                          left: BorderSide(
                            color: EnterpriseColors.borderSubtle,
                          ),
                          top: BorderSide(color: EnterpriseColors.borderSubtle),
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
      color: EnterpriseColors.bgBase,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: EnterpriseColors.accentNeonGlow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: EnterpriseColors.accentNeon.withOpacity(0.5),
                  ),
                ),
                child: const Icon(
                  Icons.blur_on,
                  color: EnterpriseColors.accentNeon,
                  size: 24,
                ),
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
          const Text(
            "COMMAND MODULES",
            style: TextStyle(
              color: EnterpriseColors.textSecondary,
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
                onTap: () => setState(
                  () => _activeTab = index,
                ), // 🚀 FIX: Updating local state
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? EnterpriseColors.surfaceGlass
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? EnterpriseColors.borderSubtle
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        menuItems[index]['icon'] as IconData,
                        color: isActive
                            ? EnterpriseColors.accentNeon
                            : EnterpriseColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        menuItems[index]['label'] as String,
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : EnterpriseColors.textSecondary,
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
                color: EnterpriseColors.surfaceGlass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: EnterpriseColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search,
                      color: EnterpriseColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            "Search tenants, invoices, fraud logs... (Cmd+K)",
                        hintStyle: TextStyle(
                          color: EnterpriseColors.textSecondary,
                        ),
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
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "⌘K",
                      style: TextStyle(
                        color: EnterpriseColors.textSecondary,
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
            icon: const Icon(
              Icons.notifications_none,
              color: EnterpriseColors.textSecondary,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: EnterpriseColors.borderSubtle),
          const SizedBox(width: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: EnterpriseColors.accentNeon,
                child: Text(
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
                children: const [
                  Text(
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
                      color: EnterpriseColors.textSecondary,
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

  // ─── MODULE ROUTER ────────────────────────────────────────────────
  Widget _getModule(int index) {
    switch (index) {
      case 0:
        return const GlobalOverviewModule();
      case 1:
        return const Center(
          child: Text(
            "Tenant Intelligence (Coming Phase 2)",
            style: TextStyle(color: Colors.white),
          ),
        );
      case 4:
        return const Center(
          child: Text(
            "Fraud & Security Center (Coming Phase 3)",
            style: TextStyle(color: Colors.redAccent),
          ),
        );
      default:
        return const Center(
          child: Text(
            "Module in Development",
            style: TextStyle(color: EnterpriseColors.textSecondary),
          ),
        );
    }
  }
}

// ─── MODULE 1: GLOBAL OVERVIEW (BAKI SAB WAISE KA WAISA HAIN) ──────────────────────────────────────
class GlobalOverviewModule extends ConsumerWidget {
  const GlobalOverviewModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(saasTenantsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live Operations Overview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Real-time aggregation of all global ClickOut platform metrics.",
            style: TextStyle(
              color: EnterpriseColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          tenantsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: EnterpriseColors.accentNeon,
              ),
            ),
            error: (err, stack) => Text(
              'Error: $err',
              style: const TextStyle(color: EnterpriseColors.riskHigh),
            ),
            data: (tenants) {
              int activeTenants = tenants
                  .where((t) => t['isActive'] == true)
                  .length;
              int totalBranches = tenants.fold(
                0,
                (sum, t) => sum + ((t['totalBranches'] as num?)?.toInt() ?? 0),
              );

              return Row(
                children: [
                  Expanded(
                    child: GlassKpiWidget(
                      title: "Active Tenants",
                      value: activeTenants.toString(),
                      trend: "+12% this week",
                      icon: Icons.domain,
                      isGood: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassKpiWidget(
                      title: "Live Branches",
                      value: totalBranches.toString(),
                      trend: "All systems nominal",
                      icon: Icons.storefront,
                      isGood: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: GlassKpiWidget(
                      title: "Platform MRR",
                      value: "₹4.2M",
                      trend: "+5.2% vs last month",
                      icon: Icons.currency_rupee,
                      isGood: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: GlassKpiWidget(
                      title: "System Threats",
                      value: "3 Alerts",
                      trend: "Requires attention",
                      icon: Icons.security,
                      isGood: false,
                      isWarning: true,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: EnterpriseColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EnterpriseColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Global Transaction Volume (24h)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Text(
                          "[ ENTERPRISE LINE CHART PLUG-IN HERE ]\nShows UPI vs Card vs Cash splits",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: EnterpriseColors.textSecondary.withOpacity(
                              0.5,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: EnterpriseColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: EnterpriseColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: EnterpriseColors.accentNeon,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Live Audit Ticker",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          children: const [
                            ActivityFeedItem(
                              time: "Just now",
                              text:
                                  "Suspicious login attempt blocked (IP: 192.168.x.x)",
                              color: EnterpriseColors.riskHigh,
                            ),
                            ActivityFeedItem(
                              time: "2m ago",
                              text:
                                  "New Tenant 'Reliance Retail' onboarded successfully.",
                              color: EnterpriseColors.accentNeon,
                            ),
                            ActivityFeedItem(
                              time: "15m ago",
                              text:
                                  "Store JAI_001 completed ₹12,000 transaction (Card).",
                              color: Colors.blueAccent,
                            ),
                            ActivityFeedItem(
                              time: "1h ago",
                              text:
                                  "Daily settlement batch processed for 450 stores.",
                              color: EnterpriseColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── REUSABLE WIDGETS ───────────────────────────────────────────────
class GlassKpiWidget extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final bool isGood;
  final bool isWarning;

  const GlassKpiWidget({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.isGood,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isWarning
        ? EnterpriseColors.riskHigh
        : (isGood
              ? EnterpriseColors.accentNeon
              : EnterpriseColors.textSecondary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: EnterpriseColors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWarning
                  ? mainColor.withOpacity(0.3)
                  : EnterpriseColors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EnterpriseColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(icon, color: mainColor, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trend,
                style: TextStyle(
                  color: mainColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityFeedItem extends StatelessWidget {
  final String time;
  final String text;
  final Color color;
  const ActivityFeedItem({
    super.key,
    required this.time,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: const TextStyle(
                color: EnterpriseColors.textSecondary,
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: EnterpriseColors.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
