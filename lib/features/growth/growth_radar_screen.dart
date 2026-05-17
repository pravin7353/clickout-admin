import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/features/growth/providers/churn_engine_service.dart';
import 'package:clickout_admin/features/growth/providers/offer_engine_service.dart';
import 'package:google_fonts/google_fonts.dart';

class GrowthRadarScreen extends ConsumerStatefulWidget {
  const GrowthRadarScreen({super.key});

  @override
  ConsumerState<GrowthRadarScreen> createState() => _GrowthRadarScreenState();
}

class _GrowthRadarScreenState extends ConsumerState<GrowthRadarScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final ValueNotifier<Set<String>> _selectedUserIds =
      ValueNotifier<Set<String>>({});

  @override
  void dispose() {
    _searchCtrl.dispose();
    _selectedUserIds.dispose();
    super.dispose();
  }

  String _formatDuration(int minutes) {
    if (minutes < 1) return "Just now";
    if (minutes < 60) return "${minutes}m ago";
    int h = minutes ~/ 60;
    int m = minutes % 60;
    return m > 0 ? "${h}h ${m}m ago" : "${h}h ago";
  }

  void _handleBulkSend() {
    if (_selectedUserIds.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one customer!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // 🚀 DUMMY VIP FOR BULK OFFERS
    final dummyVip = VIPCustomer(
      id: "BULK",
      name: "${_selectedUserIds.value.length} Customers",
      phone: "",
      totalSpent: 0,
      totalVisits: 0,
      lastVisit: DateTime.now(),
      riskLevel: "SAFE",
      winbackSent: false,
      expectedLoss: 0,
    );
    _showOfferBottomSheet(
      context,
      dummyVip,
      ref.read(adminRoleProvider).value,
      Theme.of(context).brightness == Brightness.dark,
      isBulk: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0C10) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF13161C) : Colors.white;
    final adminData = ref.watch(adminRoleProvider).value;
    final role = adminData?['role']?.toString().toUpperCase();

    final churnState = ref.watch(churnEngineProvider);
    final int vipCount = churnState.maybeWhen(
      data: (vips) => vips.length,
      orElse: () => 0,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Growth Radar",
                style: GoogleFonts.syne(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              Text(
                "Total VIPs: $vipCount",
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('growth_configs')
                    .doc(
                      '${adminData?['tenantId']}_${adminData?['branchCode']}',
                    )
                    .get(),
                builder: (context, snap) {
                  String tooltipMsg = "Store AI Config";
                  if (snap.hasData && snap.data!.exists) {
                    final data = snap.data!.data() as Map<String, dynamic>;
                    tooltipMsg =
                        "Config:\nVIP Spend: ₹${data['vipThreshold'] ?? 500}\nMedium Risk: ${((data['expectedCycleDays'] ?? 15) * (data['churnMultiplierMedium'] ?? 1.2)).toInt()} days\nHigh Risk: ${((data['expectedCycleDays'] ?? 15) * (data['churnMultiplierHigh'] ?? 2.1)).toInt()} days";
                  }
                  return Tooltip(
                    message: tooltipMsg,
                    padding: const EdgeInsets.all(12),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings_suggest_rounded,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const ShopGrowthSetupDialog(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: isDark
                ? Colors.white54
                : const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: "Live Shoppers"),
              Tab(text: "Ghost Visitors"),
              Tab(text: "VIP Customers"),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              color: bgColor,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(
                        () => _searchQuery = val.toLowerCase().trim(),
                      ),
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search by Name...",
                        hintStyle: GoogleFonts.inter(
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF10B981),
                        ),
                        filled: true,
                        fillColor: cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: _selectedUserIds,
                      builder: (context, selected, child) {
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _handleBulkSend,
                          icon: const Icon(Icons.campaign_rounded),
                          label: Text(
                            "Send Offer (${selected.length})",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TabBarView(
                  children: [
                    _buildLiveShoppersTab(isDark, cardColor),
                    _buildGhostVisitorsTab(isDark, cardColor),
                    _buildVIPCustomersTab(isDark, cardColor, role, adminData),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: LIVE SHOPPERS (LINKED TO 'CARTS')
  // ==========================================
  Widget _buildLiveShoppersTab(bool isDark, Color cardColor) {
    final adminData = ref.watch(adminRoleProvider).value;
    final tenantId = adminData?['tenantId'];
    final branchCode = adminData?['branchCode'];

    Query query = FirebaseFirestore.instance
        .collection('carts')
        .where('tenantId', isEqualTo: tenantId)
        .where('branchCode', isEqualTo: branchCode);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _emptyState(
            "No Live Shoppers",
            Icons.shopping_cart_checkout,
            isDark,
          );

        final liveCarts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          return items.isNotEmpty;
        }).toList();

        if (liveCarts.isEmpty)
          return _emptyState(
            "No Live Shoppers",
            Icons.shopping_cart_checkout,
            isDark,
          );

        List<DataRow> rows = liveCarts.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];
          final lastUpdated =
              (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
          final minutesActive = DateTime.now()
              .difference(lastUpdated)
              .inMinutes;
          final isStuck = minutesActive >= 120;
          final userId = doc.id;

          return DataRow(
            selected: _selectedUserIds.value.contains(userId),
            onSelectChanged: (selected) {
              final newSet = Set<String>.from(_selectedUserIds.value);
              if (selected == true) {
                newSet.add(userId);
              } else {
                newSet.remove(userId);
              }
              setState(() {
                _selectedUserIds.value = newSet;
              });
            },
            color: isStuck
                ? WidgetStateProperty.all(
                    Colors.redAccent.withOpacity(isDark ? 0.05 : 0.05),
                  )
                : null,
            cells: [
              DataCell(
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting)
                      return const Text("...");
                    final userName =
                        (userSnap.data?.data()
                            as Map<String, dynamic>?)?['name'] ??
                        'Unknown';
                    return Text(
                      userName,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              DataCell(
                Text(
                  "${items.length} items",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              DataCell(
                Text(
                  _formatDuration(minutesActive),
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isStuck
                        ? Colors.redAccent.withOpacity(0.1)
                        : const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isStuck
                          ? Colors.redAccent.withOpacity(0.3)
                          : const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isStuck ? "⚠️ Stuck (2h+)" : "🛒 Shopping",
                    style: GoogleFonts.inter(
                      color: isStuck
                          ? Colors.redAccent
                          : const Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList();

        return _buildPaginatedTable(
          isDark: isDark,
          cardColor: cardColor,
          columns: ["Customer Name", "Items in Cart", "Time Active", "Status"],
          rows: rows,
          allIds: liveCarts.map((e) => e.id).toList(),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: GHOST VISITORS (EXIT LOOP FIXED)
  // ==========================================
  Widget _buildGhostVisitorsTab(bool isDark, Color cardColor) {
    final adminData = ref.watch(adminRoleProvider).value;
    final String userTenantId = adminData?['tenantId'] ?? '';
    final String userBranchCode = adminData?['branchCode'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('tenantId', isEqualTo: userTenantId)
          .where('branchCode', isEqualTo: userBranchCode)
          .where('activeSessionId', isNotEqualTo: null)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        if (!snapshot.hasData)
          return _emptyState(
            "No Ghost Visitors",
            Icons.visibility_off_outlined,
            isDark,
          );

        final activeUsers = snapshot.data!.docs;

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('carts')
              .where('tenantId', isEqualTo: userTenantId)
              .where('branchCode', isEqualTo: userBranchCode)
              .get(),
          builder: (context, cartSnap) {
            if (cartSnap.connectionState == ConnectionState.waiting)
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              );
            final activeCartUserIds =
                cartSnap.data?.docs
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['items']
                              ?.isNotEmpty ==
                          true,
                    )
                    .map((d) => d.id)
                    .toList() ??
                [];

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('orders')
                  .where('tenantId', isEqualTo: userTenantId)
                  .where('branchCode', isEqualTo: userBranchCode)
                  .where(
                    'timestamp',
                    isGreaterThanOrEqualTo: DateTime.now().subtract(
                      const Duration(hours: 3),
                    ),
                  )
                  .get(),
              builder: (context, orderSnap) {
                if (orderSnap.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  );
                final recentlyExitedUserIds =
                    orderSnap.data?.docs
                        .where((d) {
                          final oData = d.data() as Map<String, dynamic>;
                          final payStatus =
                              oData['paymentStatus']
                                  ?.toString()
                                  .toUpperCase() ??
                              '';
                          final exitStatus =
                              oData['exitStatus']?.toString().toUpperCase() ??
                              '';
                          return payStatus == 'PAID' ||
                              exitStatus == 'APPROVED';
                        })
                        .map(
                          (d) => (d.data() as Map<String, dynamic>)['userId']
                              .toString(),
                        )
                        .toList() ??
                    [];

                final adminData = ref.watch(adminRoleProvider).value;
                final String userTenantId = adminData?['tenantId'] ?? '';
                final String userBranchCode = adminData?['branchCode'] ?? '';

                final ghosts = activeUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['tenantId'] != userTenantId) return false;
                  if (data['branchCode'] != userBranchCode) return false;

                  if (activeCartUserIds.contains(doc.id)) return false;
                  if (recentlyExitedUserIds.contains(doc.id)) return false;

                  final storeVisitData =
                      (data['storeVisits']
                              as Map<String, dynamic>?)?[userTenantId]
                          as Map<String, dynamic>?;
                  final lastVisit =
                      (storeVisitData?['lastVisit'] as Timestamp?)?.toDate() ??
                      (data['lastVisit'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final minutesSinceScan = DateTime.now()
                      .difference(lastVisit)
                      .inMinutes;
                  if (minutesSinceScan < 1 || minutesSinceScan > 120)
                    return false;

                  final query = _searchQuery.toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final uid = doc.id.toLowerCase();
                  if (_searchQuery.isNotEmpty &&
                      !(name.contains(query) ||
                          phone.contains(query) ||
                          uid.contains(query))) {
                    return false;
                  }
                  return true;
                }).toList();

                if (ghosts.isEmpty)
                  return _emptyState(
                    "No Ghost Visitors",
                    Icons.visibility_off_outlined,
                    isDark,
                  );

                List<DataRow> rows = ghosts.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastVisit =
                      (data['lastVisit'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final minutesSinceScan = DateTime.now()
                      .difference(lastVisit)
                      .inMinutes;
                  final ghostCustomer = VIPCustomer(
                    id: doc.id,
                    name: data['name'] ?? 'Unknown',
                    phone: '',
                    totalSpent: 0,
                    totalVisits: 1,
                    lastVisit: lastVisit,
                    riskLevel: 'SAFE',
                    winbackSent: false,
                    expectedLoss: 0,
                    fcmToken: data['fcmToken'],
                    hasApp: true,
                  );

                  return DataRow(
                    selected: _selectedUserIds.value.contains(doc.id),
                    onSelectChanged: (selected) {
                      final newSet = Set<String>.from(_selectedUserIds.value);
                      if (selected == true) {
                        newSet.add(doc.id);
                      } else {
                        newSet.remove(doc.id);
                      }
                      setState(() {
                        _selectedUserIds.value = newSet;
                      });
                    },
                    cells: [
                      DataCell(
                        Text(
                          data['name'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          DateFormat('hh:mm a').format(lastVisit),
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatDuration(minutesSinceScan),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.send_to_mobile_rounded,
                            color: Color(0xFF3B82F6),
                          ),
                          onPressed: () => _showOfferBottomSheet(
                            context,
                            ghostCustomer,
                            ref.read(adminRoleProvider).value,
                            isDark,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList();

                return _buildPaginatedTable(
                  isDark: isDark,
                  cardColor: cardColor,
                  columns: [
                    "Customer Name",
                    "Scanned At",
                    "Time Spent",
                    "Action",
                  ],
                  rows: rows,
                  allIds: ghosts.map((e) => e.id).toList(),
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 3: VIP CUSTOMERS
  // ==========================================
  Widget _buildVIPCustomersTab(
    bool isDark,
    Color cardColor,
    String? role,
    Map<String, dynamic>? adminData,
  ) {
    final churnState = ref.watch(churnEngineProvider);

    return churnState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      ),
      error: (err, stack) => Center(
        child: Text("Error: $err", style: const TextStyle(color: Colors.red)),
      ),
      data: (vipList) {
        final filteredVips = vipList.where((customer) {
          final query = _searchQuery.toLowerCase();
          final name = customer.name.toLowerCase();
          final phone = customer.phone.toLowerCase();
          final uid = customer.id.toLowerCase();

          if (_searchQuery.isNotEmpty &&
              !(name.contains(query) ||
                  phone.contains(query) ||
                  uid.contains(query))) {
            return false;
          }
          return true;
        }).toList();

        if (filteredVips.isEmpty)
          return _emptyState("No VIP Customers", Icons.stars_rounded, isDark);

        List<DataRow> rows = filteredVips.map((customer) {
          bool isHighOrMediumRisk =
              customer.riskLevel == 'HIGH' || customer.riskLevel == 'MEDIUM';
          bool canSendOffer =
              customer.isNotificationEligible && isHighOrMediumRisk;

          return DataRow(
            selected: _selectedUserIds.value.contains(customer.id),
            onSelectChanged: (selected) {
              final newSet = Set<String>.from(_selectedUserIds.value);
              if (selected == true) {
                newSet.add(customer.id);
              } else {
                newSet.remove(customer.id);
              }
              setState(() {
                _selectedUserIds.value = newSet;
              });
            },
            color: customer.riskLevel == 'HIGH'
                ? WidgetStateProperty.all(
                    Colors.redAccent.withOpacity(isDark ? 0.05 : 0.03),
                  )
                : null,
            cells: [
              DataCell(
                Text(
                  customer.name,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataCell(
                Text(
                  "₹${customer.totalSpent.toStringAsFixed(0)}",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              DataCell(_buildRiskBadge(customer.riskLevel)),
              DataCell(
                Text(
                  DateFormat('dd MMM yyyy').format(customer.lastVisit),
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              DataCell(
                canSendOffer
                    ? IconButton(
                        icon: const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFF59E0B),
                        ),
                        onPressed: () => _showOfferBottomSheet(
                          context,
                          customer,
                          adminData,
                          isDark,
                        ),
                      )
                    : Tooltip(
                        message: "Locked: Customer is SAFE.",
                        child: IconButton(
                          icon: Icon(
                            Icons.lock_rounded,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          onPressed: null,
                        ),
                      ),
              ),
            ],
          );
        }).toList();

        return _buildPaginatedTable(
          isDark: isDark,
          cardColor: cardColor,
          columns: [
            "Customer Name",
            "Total Spent",
            "Risk Level",
            "Last Visit",
            "Action",
          ],
          rows: rows,
          allIds: filteredVips.map((e) => e.id).toList(),
        );
      },
    );
  }

  // 🚀 SMART UI: Custom Horizontal Scrollable Table with INSTANT Checkboxes
  Widget _buildPaginatedTable({
    required bool isDark,
    required Color cardColor,
    required List<String> columns,
    required List<DataRow> rows,
    required List<String> allIds,
  }) {
    if (rows.isEmpty) {
      return _emptyState("No data available", Icons.data_array_rounded, isDark);
    }

    bool allSelected =
        _selectedUserIds.value.length == allIds.length && allIds.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ScrollController horizontalController = ScrollController();
            return Scrollbar(
              controller: horizontalController,
              thumbVisibility: true,
              thickness: 8,
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth > 800
                        ? constraints.maxWidth
                        : 800,
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    thickness: 8,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      child: StatefulBuilder(
                        builder: (context, setTableState) {
                          return DataTable(
                            headingRowHeight: 56,
                            dataRowMinHeight: 65,
                            dataRowMaxHeight: 65,
                            headingRowColor: WidgetStateProperty.all(
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                            ),
                            dividerThickness: 0.5,
                            columnSpacing: 40,
                            headingTextStyle: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                            columns: [
                              DataColumn(
                                label: Checkbox(
                                  value: allSelected,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    final newSet = Set<String>.from(
                                      _selectedUserIds.value,
                                    );
                                    if (val == true) {
                                      newSet.addAll(allIds);
                                    } else {
                                      newSet.removeAll(allIds);
                                    }
                                    setState(() {
                                      _selectedUserIds.value = newSet;
                                    });
                                    setTableState(() {
                                      allSelected = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              ...columns
                                  .map(
                                    (col) => DataColumn(
                                      label: Text(col.toUpperCase()),
                                    ),
                                  )
                                  .toList(),
                            ],
                            rows: rows.asMap().entries.map((entry) {
                              int idx = entry.key;
                              DataRow originalRow = entry.value;
                              String currentId = allIds[idx];
                              bool isRowSelected = _selectedUserIds.value
                                  .contains(currentId);

                              return DataRow(
                                color: originalRow.color,
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      value: isRowSelected,
                                      activeColor: const Color(0xFF10B981),
                                      onChanged: (val) {
                                        final newSet = Set<String>.from(
                                          _selectedUserIds.value,
                                        );
                                        if (val == true) {
                                          newSet.add(currentId);
                                        } else {
                                          newSet.remove(currentId);
                                        }
                                        setState(() {
                                          _selectedUserIds.value = newSet;
                                        });
                                        setTableState(() {
                                          allSelected =
                                              _selectedUserIds.value.length ==
                                                  allIds.length &&
                                              allIds.isNotEmpty;
                                        });
                                      },
                                    ),
                                  ),
                                  ...originalRow.cells,
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ), // Closes inner Scrollbar
                ), // Closes ConstrainedBox
              ), // Closes outer SingleChildScrollView
            ); // Closes outer Scrollbar
          },
        ),
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color chipColor;
    String icon;
    if (riskLevel == 'HIGH') {
      chipColor = Colors.redAccent;
      icon = "🚨";
    } else if (riskLevel == 'MEDIUM') {
      chipColor = const Color(0xFFF59E0B);
      icon = "⚠️";
    } else {
      chipColor = const Color(0xFF10B981);
      icon = "✅";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            riskLevel,
            style: GoogleFonts.inter(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfferBottomSheet(
    BuildContext context,
    VIPCustomer customer,
    Map<String, dynamic>? adminData,
    bool isDark, {
    bool isBulk = false,
  }) {
    double discount = 10.0;
    int expiryDays = 3;
    final promoCtrl = TextEditingController(
      text: "DEAL${Random().nextInt(9000) + 1000}",
    );
    bool isSending = false;

    final surfaceColor = isDark ? const Color(0xFF13161C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        isBulk
                            ? "Send Offer to ${customer.name}"
                            : "Send Offer to ${customer.name}",
                        style: GoogleFonts.syne(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  "Discount: ${discount.toInt()}%",
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: discount,
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: "${discount.toInt()}%",
                  onChanged: (v) => setModalState(() => discount = v),
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: isDark ? Colors.white10 : Colors.black12,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promoCtrl,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: "Promo Code",
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: expiryDays,
                  dropdownColor: surfaceColor,
                  items: [1, 3, 7]
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            "$d Days",
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setModalState(() => expiryDays = v!),
                  decoration: InputDecoration(
                    labelText: "Expiry Days",
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isSending
                        ? null
                        : () async {
                            setModalState(() => isSending = true);
                            try {
                              if (isBulk) {
                                await ref
                                    .read(churnEngineProvider.notifier)
                                    .sendBulkOffer(
                                      targetUserIds: _selectedUserIds.value,
                                      offerName: "Special Bulk Offer! 🎁",
                                      discountPercent: discount,
                                      couponCode: promoCtrl.text,
                                      expiryDays: expiryDays,
                                    );
                              } else {
                                await OfferEngineService().writeOfferToFirestore(
                                  targetUserId: customer.id,
                                  tenantId: adminData?['tenantId'] ?? '',
                                  branchCode:
                                      adminData?['branchCode'] ?? 'UNKNOWN',
                                  offerType: OfferType.growthRadar,
                                  notificationTitle:
                                      "Special Offer just for you! 🎁",
                                  notificationBody:
                                      "Hi ${customer.name}, use code ${promoCtrl.text} to get ${discount.toInt()}% OFF!",
                                  couponCode: promoCtrl.text,
                                  discountPercent: discount,
                                  expiryDays: expiryDays,
                                  fcmToken: customer.fcmToken,
                                );
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                setState(() => _selectedUserIds.value = {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "✅ Offers Sent Successfully!",
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setModalState(() => isSending = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("🚨 Target un-reachable"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      isSending ? "Sending..." : "Send Push Notification",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ShopGrowthSetupDialog extends ConsumerStatefulWidget {
  const ShopGrowthSetupDialog({super.key});
  @override
  ConsumerState<ShopGrowthSetupDialog> createState() =>
      _ShopGrowthSetupDialogState();
}

class _ShopGrowthSetupDialogState extends ConsumerState<ShopGrowthSetupDialog> {
  double _highRiskMult = 2.1;
  double _medRiskMult = 1.2;

  final List<double> _vipSteps = [
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
    200000,
    500000,
    1000000,
  ];
  int _vipSliderIndex = 1;
  double get _vipThreshold => _vipSteps[_vipSliderIndex];

  String _businessType = "General Retail";
  final int _expectedCycleDays = 15;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _mumbaiCategories = [
    "General Retail",
    "Kirana & Supermarket",
    "Medical & Pharmacy",
    "Mobile & Electronics",
    "Hardware & Sanitary",
    "Garments & Boutique",
    "Jewellery & Gems",
    "Salon, Spa & Beauty",
    "Bakery & Sweets",
    "Restaurant & Cafe",
    "Dairy & FMCG",
    "Stationery & Books",
    "Footwear & Shoes",
    "Opticals & Eyewear",
    "Automobile Spare Parts",
    "Perfumes & Cosmetics",
    "Bags & Luggage",
    "Toys & Gifts",
    "Furniture & Decor",
    "Pet Supplies",
    "Sports & Fitness",
    "Tailor & Fabrics",
    "Utensils & Kitchenware",
    "Pooja Samagri",
    "Dry Fruits & Spices",
    "Hardware & Paints",
    "Mobile Accessories",
    "Watches & Clocks",
    "Fast Food & Snacks",
    "Ice Cream & Desserts",
    "Optician & Lens Clinic",
    "Lingerie & Innerwear",
    "Sarees & Ethnic Wear",
    "Men's Formals & Casuals",
    "Kids Clothing",
    "Baby Care & Toys",
    "Computer & Laptops",
    "CCTV & Security Systems",
    "Electrical & Wiring",
    "Plumbing Supplies",
    "Ceramics & Tiles",
    "Plywood & Timber",
    "Glass & Mirrors",
    "Pest Control Services",
    "Laundry & Dry Cleaning",
    "Photo Studio & Printing",
    "Travel Agency",
    "Real Estate Broker",
    "Astrology & Vastu",
    "Tattoo Studio",
    "Gym & Health Club",
    "Yoga & Meditation Center",
    "Dentist Clinic",
    "Physiotherapy Clinic",
    "Veterinary Clinic",
    "Florist & Bouquets",
    "Gifts & Novelties",
    "Party Supplies",
    "Musical Instruments",
    "Art & Craft Supplies",
    "Tailoring Materials",
    "Bags & Backpacks",
    "Umbrellas & Rainwear",
    "Watches & Repairs",
    "Bicycle Shop",
    "Auto Repair & Garage",
    "Car Wash & Detailing",
    "Tyres & Batteries",
    "Helmet & Bike Accessories",
    "Hardware & Tools",
    "Industrial Supplies",
    "Safety Equipment",
    "Packaging Materials",
    "Paper & Disposables",
    "Plastic Houseware",
    "Cleaning Supplies",
    "Mithai & Farsan",
    "Namkeen & Wafers",
    "Chocolates & Imported Foods",
    "Organic & Health Foods",
    "Tea & Coffee Merchants",
    "Tobacco & Pan Shop",
    "Juice Center",
    "Meat & Poultry",
    "Fish & Seafood",
    "Vegetables & Fruits",
    "Caterers",
    "Tiffin Services",
    "Boutique (Women)",
    "Men's Tailor",
    "Bridal Wear",
    "Uniforms & Workwear",
    "Shoes & Chappals",
    "Bags & Purses",
    "Belts & Wallets",
    "Imitation Jewellery",
    "Silverware",
    "Gold & Diamond Jewellery",
    "Cosmetics & Perfumes",
    "Beauty Parlour",
    "Barber Shop",
    "Mehendi Artist",
    "Homeopathic Doctor",
    "Ayurvedic Doctor",
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) return;
      final tenantId = roleData['tenantId'];
      final branchCode = roleData['branchCode'] ?? 'UNKNOWN';

      final doc = await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc('${tenantId}_$branchCode')
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _highRiskMult = (data['churnMultiplierHigh'] ?? 2.1).toDouble();
          _medRiskMult = (data['churnMultiplierMedium'] ?? 1.2).toDouble();
          _businessType = data['businessType'] ?? "General Retail";
          if (_highRiskMult <= _medRiskMult) _highRiskMult = _medRiskMult + 0.5;
          double loadedVip = (data['vipThreshold'] ?? 1000).toDouble();
          _vipSliderIndex = _vipSteps.indexWhere((val) => val >= loadedVip);
          if (_vipSliderIndex == -1) _vipSliderIndex = _vipSteps.length - 1;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final roleData = ref.read(adminRoleProvider).value;
      final tenantId = roleData?['tenantId'];
      final branchCode = roleData?['branchCode'] ?? 'UNKNOWN';

      await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc('${tenantId}_$branchCode')
          .set({
            'tenantId': tenantId,
            'branchCode': branchCode,
            'businessType': _businessType,
            'churnMultiplierHigh': _highRiskMult,
            'churnMultiplierMedium': _medRiskMult,
            'vipThreshold': _vipThreshold,
            'expectedCycleDays': _expectedCycleDays,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      ref.invalidate(growthConfigStatusProvider);
      ref.invalidate(churnEngineProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatCurrency(double amount) {
    var formatter = NumberFormat.decimalPattern('en_IN');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF13161C) : Colors.white;
    final branchCode =
        ref.watch(adminRoleProvider).value?['branchCode'] ?? 'UNKNOWN';

    if (_isLoading)
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          ),
        ),
      );

    return AlertDialog(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "AI Growth Setup",
                style: GoogleFonts.syne(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            "Configure AI churn rules per specific store branch",
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Target Store (Auto-Assigned)",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            branchCode,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "LOCKED",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Business Category",
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _businessType),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty)
                        return _mumbaiCategories;
                      return _mumbaiCategories.where(
                        (String option) => option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        ),
                      );
                    },
                    onSelected: (String selection) =>
                        setState(() => _businessType = selection),
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) => _businessType = val,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search or type custom category...",
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          child: SizedBox(
                            width: 450,
                            height: 200,
                            child: ListView.builder(
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option,
                                    style: TextStyle(color: textColor),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSliderRow(
                "High risk trigger (beyond cycle)",
                _highRiskMult,
                1.5,
                4.0,
                (val) {
                  setState(() {
                    if (val <= _medRiskMult) {
                      _medRiskMult = val - 0.5;
                      if (_medRiskMult < 1.0) _medRiskMult = 1.0;
                    }
                    _highRiskMult = val;
                  });
                },
                "${_highRiskMult.toStringAsFixed(1)}x",
                isDark,
                textColor,
              ),
              const SizedBox(height: 16),
              _buildSliderRow(
                "Medium risk trigger (beyond cycle)",
                _medRiskMult,
                1.0,
                3.5,
                (val) {
                  setState(() {
                    if (val >= _highRiskMult) {
                      _highRiskMult = val + 0.5;
                      if (_highRiskMult > 4.0) _highRiskMult = 4.0;
                    }
                    _medRiskMult = val;
                  });
                },
                "${_medRiskMult.toStringAsFixed(1)}x",
                isDark,
                textColor,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "VIP spend threshold (₹)",
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "₹${_formatCurrency(_vipThreshold)}",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: isDark
                          ? Colors.white10
                          : Colors.black12,
                      thumbColor: const Color(0xFF10B981),
                    ),
                    child: Slider(
                      value: _vipSliderIndex.toDouble(),
                      min: 0,
                      max: (_vipSteps.length - 1).toDouble(),
                      divisions: _vipSteps.length - 1,
                      onChanged: (val) =>
                          setState(() => _vipSliderIndex = val.toInt()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "RISK THRESHOLDS (AUTO-CALCULATED)",
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildCalcRow(
                "High risk fires after",
                "${(_expectedCycleDays * _highRiskMult).toInt()} days no visit",
                Colors.redAccent,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Medium risk fires after",
                "${(_expectedCycleDays * _medRiskMult).toInt()} days no visit",
                Colors.orangeAccent,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Coupon - high risk",
                "20% off",
                textColor,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Coupon - medium risk",
                "10% off",
                textColor,
                textColor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  )
                : Text(
                    "Save AI config for this store ↗",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String trailing,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              trailing,
              style: GoogleFonts.inter(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF10B981),
            inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
            thumbColor: const Color(0xFF10B981),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildCalcRow(
    String label,
    String value,
    Color valueColor,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: textColor, fontSize: 13)),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
