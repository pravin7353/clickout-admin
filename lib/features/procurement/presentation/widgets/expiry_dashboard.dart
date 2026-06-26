import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/utils/hierarchy_filter.dart';

import '../../services/stock_service.dart';
import 'offer_creation_dialog.dart';
import 'create_po_dialog.dart';
import '../../../coach/widgets/info_button.dart';

// 🚀 CHANGED: StatefulWidget to ConsumerStatefulWidget
class ExpiryAlertDashboard extends ConsumerStatefulWidget {
  const ExpiryAlertDashboard({super.key});

  @override
  ConsumerState<ExpiryAlertDashboard> createState() =>
      _ExpiryAlertDashboardState();
}

class _ExpiryAlertDashboardState extends ConsumerState<ExpiryAlertDashboard> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  int _currentPage = 0;
  final int _pageSize = 10;
  String _selectedSort = 'Trending';
  bool _isSorting = false;

  Map<String, int> _salesDataCache = {};
  DateTime? _lastCacheTime;
  final ScrollController _horizontalScrollController = ScrollController();

  // 🎨 DYNAMIC PREMIUM THEME (Simple & Clean Look)
  Color get bgDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF080B08)
      : const Color(0xFFF4F5F7); // 🚀 Light Gray (Clean look)
  Color get cardDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF111811)
      : const Color(0xFFFFFFFF); // 🚀 Pure White
  Color get accentGreen => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF00C853)
      : const Color(0xFF2E7D32);
  Color get accentOrange => const Color(0xFFFF6D00); // 🚀 Deep Sunset Orange
  Color get textPrimary =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get textSecondary =>
      Theme.of(context).textTheme.labelLarge?.color ?? Colors.grey;
  Color get accentRed => const Color(0xFFFE8181);

  // 🧠 SMART DATE PARSER: 100% Crash-Proof (Handles Timestamp, MM/YYYY, DD/MM/YYYY)
  DateTime? _parseExpiryDate(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is String) {
      if (rawDate.trim().isEmpty) return null;
      try {
        final parts = rawDate.replaceAll('-', '/').split('/');
        if (parts.length == 2) {
          // Format: MM/YYYY
          return DateTime(
            int.parse(parts[1]),
            int.parse(parts[0]) + 1,
            0,
          ); // End of month
        } else if (parts.length == 3) {
          // Format: DD/MM/YYYY
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
        return DateTime.tryParse(rawDate);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  final List<Map<String, dynamic>> _sortOptions = [
    {
      'name': 'Trending',
      'icon': Icons.local_fire_department,
      'filter': 'Trending',
    },
    {'name': 'Expiry', 'icon': Icons.hourglass_bottom, 'filter': 'Expiry'},
    {'name': 'Stock', 'icon': Icons.inventory, 'filter': 'Stock'},
    {'name': 'ATL', 'icon': Icons.trending_down, 'filter': 'ATL'},
    {
      'name': 'Offers',
      'icon': Icons.local_offer,
      'filter': 'Offers',
    }, // 🚀 ADDED: Offers sorting option
  ];

  @override
  void initState() {
    super.initState();
    _analyzeRecentTransactions();
  }

  Stream<QuerySnapshot> get _engineStream {
    final query = _searchQuery.trim().toLowerCase();

    // 🚀 SAAS INJECTION: The Wall is Active Here!
    final adminData = ref.watch(adminRoleProvider).value;
    Query baseQuery = HierarchyFilter.apply(
      FirebaseFirestore.instance.collection('products'),
      adminData,
    );

    // 🚀 FIX 1: Forced Cache Engine (includeMetadataChanges) so it loads instantly from local device memory
    if (query.isNotEmpty) {
      if (double.tryParse(query) != null) {
        return baseQuery
            .where('barcode', isEqualTo: query)
            .snapshots(includeMetadataChanges: true);
      }
      return baseQuery
          .where('searchKey', isGreaterThanOrEqualTo: query)
          .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .snapshots(includeMetadataChanges: true);
    }
    return baseQuery.snapshots(includeMetadataChanges: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _analyzeRecentTransactions() async {
    // 🚀 CACHE REDUCED TO 15 SECONDS FOR REAL-TIME REFLECTION
    if (_lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!).inSeconds < 15) {
      return;
    }

    setState(() => _isSorting = true);
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final adminData = ref.read(adminRoleProvider).value;

      Query ordersQuery = HierarchyFilter.apply(
        FirebaseFirestore.instance.collection('orders'),
        adminData,
      );

      final ordersSnap = await ordersQuery
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .get();

      Map<String, int> salesCount = {};
      for (var doc in ordersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // 🚀 FIX: Catching all POS and App successful order statuses
        final pStatus = data['paymentStatus']?.toString().toUpperCase() ?? '';
        final status = data['status']?.toString().toUpperCase() ?? '';

        if (pStatus == 'PAID' ||
            pStatus == 'SUCCESS' ||
            status == 'COMPLETED' ||
            status == 'DELIVERED') {
          final items = data['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            String prodId = item['productId']?.toString() ?? '';
            String barcode = item['barcode']?.toString() ?? '';
            int qty =
                int.tryParse(
                  item['quantity']?.toString() ??
                      item['orderQty']?.toString() ??
                      '1',
                ) ??
                1;

            if (prodId.isNotEmpty)
              salesCount[prodId] = (salesCount[prodId] ?? 0) + qty;
            if (barcode.isNotEmpty)
              salesCount[barcode] = (salesCount[barcode] ?? 0) + qty;
          }
        }
      }
      _salesDataCache = salesCount;
      _lastCacheTime = DateTime.now();
    } catch (e) {
      debugPrint("🚨 Error: $e");
    } finally {
      if (mounted) setState(() => _isSorting = false);
    }
  }

  List<QueryDocumentSnapshot> _applyIntelligenceRules(
    List<QueryDocumentSnapshot> rawDocs,
  ) {
    List<QueryDocumentSnapshot> filtered = [];

    for (var doc in rawDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isBlocked'] == true) continue;
      filtered.add(doc);
    }

    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      final barcodeA = dataA['barcode']?.toString() ?? '';
      final barcodeB = dataB['barcode']?.toString() ?? '';

      int salesA = _salesDataCache[a.id] ?? _salesDataCache[barcodeA] ?? 0;
      int salesB = _salesDataCache[b.id] ?? _salesDataCache[barcodeB] ?? 0;

      int stA = dataA['physicalStock'] ?? dataA['stock'] ?? 0;
      int stB = dataB['physicalStock'] ?? dataB['stock'] ?? 0;

      // 🚀 CRASH FIX: Ab sorting bhi safe parser use karegi!
      DateTime? expA = _parseExpiryDate(dataA['expiryDate']);
      DateTime? expB = _parseExpiryDate(dataB['expiryDate']);

      if (_selectedSort == 'Trending') {
        int cmp = salesB.compareTo(salesA);
        if (cmp == 0) return stA.compareTo(stB);
        return cmp;
      }

      if (_selectedSort == 'ATL') {
        int cmp = salesA.compareTo(salesB);
        if (cmp == 0) return stB.compareTo(stA);
        return cmp;
      }

      if (_selectedSort == 'Stock') {
        int cmp = stA.compareTo(stB);
        if (cmp == 0) return salesB.compareTo(salesA);
        return cmp;
      }

      if (_selectedSort == 'Expiry') {
        if (expA == null && expB == null) return 0;
        if (expA == null) return 1;
        if (expB == null) return -1;
        return expA.compareTo(expB);
      }

      // 🚀 ADDED: Active offers ko priority dekar top par laao
      if (_selectedSort == 'Offers') {
        bool offerA = dataA['clearanceActive'] == true;
        bool offerB = dataB['clearanceActive'] == true;

        if (offerA && !offerB) return -1; // A upar aayega
        if (!offerA && offerB) return 1; // B upar aayega
        return 0; // Agar dono mein offer hai ya dono mein nahi hai, toh wahi position rakho
      }

      return 0;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tableHeaderBg = isDark
        ? const Color(0xFF131A13)
        : const Color(0xFFFFE0B2); // Amber 100

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textSecondary.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.memory, color: accentOrange, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "Quantum Promotion Engine 🌌",
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const InfoButton(
                    title: 'Quantum Promotion Engine',
                    en: 'Smart offer engine showing all products with 7-day sales data. Dead stock = low sales = apply offer for quick clearance. 9 offer types available: BOGO, Flat discount, Percentage, Bundle, Flash Sale and more. Raise PO directly for low-stock items.',
                    hi: 'Ye engine aapko batata hai konsa product chal raha hai aur konsa dead stock hai. 7 din ki sales dekho — agar kam hai to offer lagao jaldi clearance ke liye. 9 tarah ke offers hain. Stock khatam hone wala ho to seedha PO raise karo yahan se.',
                  ),
                ],
              ),
              if (_searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = "";
                    _currentPage = 0;
                  }),
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    "Clear Filter",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: textSecondary.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 0;
                    }),
                    decoration: InputDecoration(
                      hintText: "Search Product by Name or Barcode...",
                      hintStyle: TextStyle(
                        color: textSecondary.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(Icons.search, color: textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                flex: 1,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentOrange.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: cardDark,
                      value: _selectedSort,
                      icon: Icon(Icons.sort, color: accentOrange),
                      items: _sortOptions
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt['filter'],
                              child: Row(
                                children: [
                                  Icon(
                                    opt['icon'],
                                    size: 16,
                                    color: accentOrange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (String? val) async {
                        if (val != null) {
                          if (val == 'Trending' || val == 'ATL') {
                            await _analyzeRecentTransactions();
                          }
                          setState(() {
                            _selectedSort = val;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          _isSorting
              ? Padding(
                  padding: const EdgeInsets.all(50),
                  child: Center(
                    child: CircularProgressIndicator(color: accentOrange),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _engineStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(color: accentOrange),
                        ),
                      );
                    }
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final processedProducts = _applyIntelligenceRules(
                      snapshot.data!.docs,
                    );
                    if (processedProducts.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111811)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            "Radar is Clear! ✅",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }

                    final totalPages = (processedProducts.length / _pageSize)
                        .ceil();
                    if (_currentPage >= totalPages && totalPages > 0) {
                      _currentPage = totalPages - 1;
                    }

                    final startIndex = _currentPage * _pageSize;
                    final endIndex =
                        (startIndex + _pageSize > processedProducts.length)
                        ? processedProducts.length
                        : startIndex + _pageSize;
                    final pageProducts = processedProducts.sublist(
                      startIndex,
                      endIndex,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // 🚀 FIX: Prevent infinite width crash on shrink
                        double safeWidth = constraints.maxWidth;
                        if (safeWidth.isInfinite) {
                          safeWidth = MediaQuery.of(context).size.width - 48;
                        }
                        final double tableWidth = safeWidth < 1000
                            ? 1000
                            : safeWidth;

                        return Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          interactive: true,
                          thickness: 8,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF131A13)
                                          : const Color(
                                              0xFF9EC2B6,
                                            ), // 🚀 Requested Custom Header Color
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      border: Border.all(
                                        color: textSecondary.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            "Product/Service Info",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "Expiry Status",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "Offer Status",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            "Stock",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "Action",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: pageProducts.length,
                                    itemBuilder: (context, index) {
                                      final doc = pageProducts[index];
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final productId = doc.id;
                                      final name =
                                          data['name'] ?? 'Unknown Item';
                                      final stock =
                                          data['physicalStock'] ??
                                          data['stock'] ??
                                          0;
                                      final price =
                                          data['price'] ?? data['mrp'] ?? 0;
                                      final isClearanceActive =
                                          data['clearanceActive'] == true;

                                      int daysLeft = 999;

                                      // 🚀 CRASH FIX: Ab yahan Smart Parser use ho raha hai!
                                      DateTime? parsedExpiry = _parseExpiryDate(
                                        data['expiryDate'],
                                      );
                                      if (parsedExpiry != null) {
                                        daysLeft = parsedExpiry
                                            .difference(DateTime.now())
                                            .inDays;
                                      }

                                      bool isDead = daysLeft < 0;

                                      return Dismissible(
                                        key: Key(productId),
                                        direction: DismissDirection.startToEnd,
                                        confirmDismiss: (direction) async =>
                                            await _showBlockConfirmDialog(
                                              context,
                                              name,
                                            ),
                                        onDismissed: (direction) async {
                                          final adminData = ref
                                              .read(adminRoleProvider)
                                              .value;
                                          await StockService.blockBatchSafely(
                                            productId,
                                            adminData?['tenantId'] ?? 'SYSTEM',
                                            adminData?['email'] ?? 'Unknown',
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "✅ $name Blocked & Logged!",
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        },
                                        background: Container(
                                          color: Colors.redAccent,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(
                                            left: 20,
                                          ),
                                          child: Row(
                                            children: const [
                                              Icon(
                                                Icons.block,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                "BLOCK ITEM",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: index % 2 == 0
                                                ? bgDark
                                                : cardDark,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: textSecondary
                                                    .withOpacity(0.1),
                                              ),
                                              left: BorderSide(
                                                color: textSecondary
                                                    .withOpacity(0.1),
                                              ),
                                              right: BorderSide(
                                                color: textSecondary
                                                    .withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                    Text(
                                                      "7-Day Sales: ${_salesDataCache[productId] ?? _salesDataCache[data['barcode']?.toString()] ?? 0}",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: accentOrange,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      "Price: ₹$price",
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: accentGreen,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "👉 Swipe right to Block",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: textSecondary,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: _buildSolidBadge(
                                                    isDead
                                                        ? "DEAD STOCK"
                                                        : (daysLeft <= 7
                                                              ? "EXPIRES: T-$daysLeft"
                                                              : "SAFE"),
                                                    isDead
                                                        ? Icons.delete_forever
                                                        : (daysLeft <= 3
                                                              ? Icons
                                                                    .warning_amber
                                                              : (daysLeft <= 7
                                                                    ? Icons
                                                                          .timer
                                                                    : Icons
                                                                          .verified_user)),
                                                    isDead
                                                        ? [
                                                            Colors
                                                                .grey
                                                                .shade800,
                                                            Colors.black87,
                                                          ]
                                                        : (daysLeft <= 3
                                                              ? [
                                                                  Colors
                                                                      .redAccent,
                                                                  Colors
                                                                      .red
                                                                      .shade700,
                                                                ]
                                                              : (daysLeft <= 7
                                                                    ? [
                                                                        Colors
                                                                            .orangeAccent,
                                                                        Colors
                                                                            .orange
                                                                            .shade700,
                                                                      ]
                                                                    : [
                                                                        Colors
                                                                            .teal
                                                                            .shade400,
                                                                        Colors
                                                                            .teal
                                                                            .shade600,
                                                                      ])),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: isDead
                                                      ? _buildSolidBadge(
                                                          "NOT APPLICABLE",
                                                          Icons.block,
                                                          [
                                                            Colors
                                                                .grey
                                                                .shade400,
                                                            Colors
                                                                .grey
                                                                .shade500,
                                                          ],
                                                        )
                                                      : (isClearanceActive
                                                            ? Builder(
                                                                builder: (context) {
                                                                  final clearanceType =
                                                                      data['clearanceType']
                                                                          ?.toString() ??
                                                                      '';
                                                                  final double
                                                                  pPrice =
                                                                      double.tryParse(
                                                                        price
                                                                            .toString(),
                                                                      ) ??
                                                                      0;
                                                                  final double
                                                                  oPrice =
                                                                      double.tryParse(
                                                                        data['offerPrice']?.toString() ??
                                                                            '',
                                                                      ) ??
                                                                      0;

                                                                  String
                                                                  offerDisplayName =
                                                                      'OFFER ACTIVE';
                                                                  List<Color>
                                                                  offerGradient = [
                                                                    Colors
                                                                        .purple
                                                                        .shade400,
                                                                    Colors
                                                                        .purple
                                                                        .shade600,
                                                                  ];
                                                                  IconData
                                                                  offerIcon = Icons
                                                                      .local_offer;

                                                                  if (clearanceType ==
                                                                          'PERCENTAGE' ||
                                                                      clearanceType ==
                                                                          'TIERED_QTY') {
                                                                    int
                                                                    percent =
                                                                        (pPrice >
                                                                                0 &&
                                                                            oPrice >
                                                                                0)
                                                                        ? (((pPrice -
                                                                                          oPrice) /
                                                                                      pPrice) *
                                                                                  100)
                                                                              .round()
                                                                        : 0;
                                                                    offerDisplayName =
                                                                        percent >
                                                                            0
                                                                        ? '$percent% OFF'
                                                                        : 'PERCENT OFF';
                                                                    offerGradient = [
                                                                      const Color(
                                                                        0xFF2962FF,
                                                                      ),
                                                                      Colors
                                                                          .blue
                                                                          .shade700,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .percent_rounded;
                                                                  } else if (clearanceType ==
                                                                      'FLAT_AMOUNT') {
                                                                    int flat =
                                                                        (pPrice >
                                                                                0 &&
                                                                            oPrice >
                                                                                0)
                                                                        ? (pPrice -
                                                                                  oPrice)
                                                                              .round()
                                                                        : 0;
                                                                    offerDisplayName =
                                                                        flat > 0
                                                                        ? '₹$flat OFF'
                                                                        : 'FLAT OFF';
                                                                    offerGradient = [
                                                                      const Color(
                                                                        0xFF00C853,
                                                                      ),
                                                                      Colors
                                                                          .green
                                                                          .shade700,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .currency_rupee_rounded;
                                                                  } else if (clearanceType ==
                                                                      'BOGO') {
                                                                    offerDisplayName =
                                                                        'B1G1';
                                                                    offerGradient = [
                                                                      const Color(
                                                                        0xFFFF6D00,
                                                                      ),
                                                                      Colors
                                                                          .orange
                                                                          .shade700,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .shopping_bag_outlined;
                                                                  } else if (clearanceType ==
                                                                      'BUY_X_GET_Y') {
                                                                    offerDisplayName =
                                                                        'BXGY';
                                                                    offerGradient = [
                                                                      const Color(
                                                                        0xFFFF6D00,
                                                                      ),
                                                                      Colors
                                                                          .orange
                                                                          .shade700,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .shopping_bag_outlined;
                                                                  } else if (clearanceType ==
                                                                      'BUNDLE_PRICE') {
                                                                    final v1 =
                                                                        data['value1']
                                                                            ?.toInt() ??
                                                                        'X';
                                                                    final v2 =
                                                                        data['value2']
                                                                            ?.toInt() ??
                                                                        'Y';
                                                                    offerDisplayName =
                                                                        '$v1 for ₹$v2';
                                                                    offerGradient = [
                                                                      Colors
                                                                          .teal
                                                                          .shade400,
                                                                      Colors
                                                                          .teal
                                                                          .shade600,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .inventory_2;
                                                                  } else if (clearanceType ==
                                                                      'FLASH_SALE') {
                                                                    offerDisplayName =
                                                                        'FLASH';
                                                                    offerGradient = [
                                                                      Colors
                                                                          .redAccent,
                                                                      Colors
                                                                          .red
                                                                          .shade700,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .flash_on;
                                                                  } else if (clearanceType ==
                                                                          'CROSS_PRODUCT' ||
                                                                      clearanceType ==
                                                                          'BUY_X_GET_Y_CROSS') {
                                                                    offerDisplayName =
                                                                        'CROSS';
                                                                    offerGradient = [
                                                                      Colors
                                                                          .deepPurple
                                                                          .shade400,
                                                                      Colors
                                                                          .deepPurple
                                                                          .shade600,
                                                                    ];
                                                                    offerIcon =
                                                                        Icons
                                                                            .compare_arrows;
                                                                  }

                                                                  return Container(
                                                                    height: 34,
                                                                    width: 130,
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          left:
                                                                              8,
                                                                          right:
                                                                              4,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: offerGradient
                                                                          .first
                                                                          .withOpacity(
                                                                            0.1,
                                                                          ),
                                                                      border: Border.all(
                                                                        color: offerGradient
                                                                            .first
                                                                            .withOpacity(
                                                                              0.5,
                                                                            ),
                                                                        width:
                                                                            1,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            6,
                                                                          ),
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          offerIcon,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              offerGradient.first,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Expanded(
                                                                          child: FittedBox(
                                                                            fit:
                                                                                BoxFit.scaleDown,
                                                                            alignment:
                                                                                Alignment.centerLeft,
                                                                            child: Text(
                                                                              offerDisplayName,
                                                                              style: TextStyle(
                                                                                color: offerGradient.first,
                                                                                fontWeight: FontWeight.w900,
                                                                                fontSize: 11,
                                                                                letterSpacing: 0.5,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Tooltip(
                                                                          message:
                                                                              "REMOVE OFFER",
                                                                          child: InkWell(
                                                                            onTap: () async {
                                                                              bool?
                                                                              confirm =
                                                                                  await showDialog<
                                                                                    bool
                                                                                  >(
                                                                                    context: context,
                                                                                    builder:
                                                                                        (
                                                                                          ctx,
                                                                                        ) => AlertDialog(
                                                                                          backgroundColor: cardDark,
                                                                                          title: Text(
                                                                                            "Remove Offer?",
                                                                                            style: TextStyle(
                                                                                              color: textPrimary,
                                                                                              fontWeight: FontWeight.bold,
                                                                                            ),
                                                                                          ),
                                                                                          content: Text(
                                                                                            "Are you sure you want to deactivate this offer? Customer will no longer see this discount.",
                                                                                            style: TextStyle(
                                                                                              color: textSecondary,
                                                                                            ),
                                                                                          ),
                                                                                          actions: [
                                                                                            TextButton(
                                                                                              onPressed: () => Navigator.pop(
                                                                                                ctx,
                                                                                                false,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                "Cancel",
                                                                                                style: TextStyle(
                                                                                                  color: Colors.grey,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            ElevatedButton(
                                                                                              style: ElevatedButton.styleFrom(
                                                                                                backgroundColor: Colors.redAccent,
                                                                                              ),
                                                                                              onPressed: () => Navigator.pop(
                                                                                                ctx,
                                                                                                true,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                "Remove",
                                                                                                style: TextStyle(
                                                                                                  color: Colors.white,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                  );
                                                                              if (confirm ==
                                                                                  true) {
                                                                                await StockService.undoClearance(
                                                                                  productId,
                                                                                );
                                                                                if (context.mounted) {
                                                                                  ScaffoldMessenger.of(
                                                                                    context,
                                                                                  ).showSnackBar(
                                                                                    SnackBar(
                                                                                      content: const Text(
                                                                                        "✅ Offer Removed Successfully!",
                                                                                      ),
                                                                                      backgroundColor: accentOrange,
                                                                                    ),
                                                                                  );
                                                                                }
                                                                              }
                                                                            },
                                                                            child: Container(
                                                                              padding: const EdgeInsets.all(
                                                                                4,
                                                                              ),
                                                                              decoration: BoxDecoration(
                                                                                color: offerGradient.first.withOpacity(
                                                                                  0.2,
                                                                                ),
                                                                                borderRadius: BorderRadius.circular(
                                                                                  4,
                                                                                ),
                                                                              ),
                                                                              child: Icon(
                                                                                Icons.close_rounded,
                                                                                color: offerGradient.first,
                                                                                size: 14,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                },
                                                              )
                                                            : InkWell(
                                                                onTap: () =>
                                                                    _handleApplyOffer(
                                                                      context,
                                                                      productId,
                                                                      name,
                                                                      price,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                child: Container(
                                                                  height: 34,
                                                                  width: 130,
                                                                  decoration: BoxDecoration(
                                                                    color: accentOrange
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: accentOrange
                                                                          .withOpacity(
                                                                            0.5,
                                                                          ),
                                                                      width: 1,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Icon(
                                                                        Icons
                                                                            .sell,
                                                                        size:
                                                                            14,
                                                                        color:
                                                                            accentOrange,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            4,
                                                                      ),
                                                                      const FittedBox(
                                                                        fit: BoxFit
                                                                            .scaleDown,
                                                                        child: Text(
                                                                          "APPLY OFFER",
                                                                          style: TextStyle(
                                                                            color: Color(
                                                                              0xFFFF6D00,
                                                                            ),
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            letterSpacing:
                                                                                0.5,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              )),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  stock.toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                    color: stock <= 20
                                                        ? accentRed
                                                        : textPrimary,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: InkWell(
                                                    onTap: () => showDialog(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          CreatePODialog(
                                                            productId:
                                                                productId,
                                                            productName: name,
                                                            currentStock: stock,
                                                          ),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    child: Container(
                                                      height: 34,
                                                      width: 130,
                                                      decoration: BoxDecoration(
                                                        color: accentGreen
                                                            .withOpacity(0.1),
                                                        border: Border.all(
                                                          color: accentGreen
                                                              .withOpacity(0.5),
                                                          width: 1,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .add_shopping_cart,
                                                            size: 14,
                                                            color: accentGreen,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            child: Text(
                                                              "RAISE PO",
                                                              style: TextStyle(
                                                                color:
                                                                    accentGreen,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  if (totalPages > 1) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bgDark,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: textSecondary.withOpacity(0.1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Showing ${startIndex + 1} - $endIndex of ${processedProducts.length} Entries",
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.chevron_left,
                                                  color: accentOrange,
                                                ),
                                                onPressed: _currentPage > 0
                                                    ? () => setState(
                                                        () => _currentPage--,
                                                      )
                                                    : null,
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: accentOrange,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  "${_currentPage + 1} / $totalPages",
                                                  style: TextStyle(
                                                    color: bgDark,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.chevron_right,
                                                  color: accentOrange,
                                                ),
                                                onPressed:
                                                    _currentPage <
                                                        totalPages - 1
                                                    ? () => setState(
                                                        () => _currentPage++,
                                                      )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  // 💎 PREMIUM SAAS PILL BADGE (Matches Reference Image)
  Widget _buildSolidBadge(
    String text,
    IconData icon,
    List<Color> gradientColors,
  ) {
    Color primaryColor = gradientColors.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1), // 🚀 Safe tint (No Warning)
        borderRadius: BorderRadius.circular(20), // 🚀 Pill Shape (Gol)
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: primaryColor),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showBlockConfirmDialog(
    BuildContext context,
    String name,
  ) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              "Block Item?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Are you sure you want to block '$name'? Stock will become 0 and item will be removed from customer app immediately.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Block Item",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleApplyOffer(
    BuildContext context,
    String productId,
    String name,
    num originalPrice, // 🚀 4th argument (Ye error 1 fix karega)
  ) async {
    OfferPayload? createdOffer = await showDialog<OfferPayload>(
      context: context,
      builder: (ctx) =>
          OfferCreationDialog(productId: productId, productName: name),
    );
    if (createdOffer != null) {
      await StockService.applyAdvancedClearance(
        productId,
        createdOffer.type,
        createdOffer.data,
      );

      // 🚀 UNIVERSAL DISCOUNT ENGINE: Har offer ka 'Effective Unit Price' nikalega Node.js ke liye
      double calculatedOfferPrice = originalPrice.toDouble();

      // Extract universal values safely
      double v1 =
          double.tryParse(createdOffer.data['value1']?.toString() ?? '0') ?? 0;
      double v2 =
          double.tryParse(createdOffer.data['value2']?.toString() ?? '0') ?? 0;

      switch (createdOffer.type) {
        case 'PERCENTAGE':
        case 'FLASH_SALE':
        case 'TIERED_QTY':
          // Tiered mein v2 discount percentage hai, baakiyo mein v1
          double discountPercent = (createdOffer.type == 'TIERED_QTY')
              ? v2
              : v1;
          calculatedOfferPrice =
              originalPrice - (originalPrice * (discountPercent / 100));
          break;
        case 'FLAT_AMOUNT':
          calculatedOfferPrice = originalPrice - v1;
          break;
        case 'BOGO':
          // Buy 1 Get 1 = 50% effective off per unit
          calculatedOfferPrice = originalPrice / 2;
          break;
        case 'BUY_X_GET_Y':
          // Pay for X items, get (X + Y) items
          if (v1 > 0 && v2 > 0) {
            calculatedOfferPrice = (originalPrice * v1) / (v1 + v2);
          }
          break;
        case 'BUNDLE_PRICE':
          // Total Bundle Price (v2) divided by Total Qty (v1)
          if (v1 > 0) {
            calculatedOfferPrice = v2 / v1;
          }
          break;
        case 'CROSS_PRODUCT':
        case 'BUY_X_GET_Y_CROSS':
          // Cross product target item par apply hota hai, current item full price par hi bikega
          calculatedOfferPrice = originalPrice.toDouble();
          break;
      }

      // 🛡️ Safety check: Price zero se neeche na jaye
      if (calculatedOfferPrice < 0) calculatedOfferPrice = 0;

      // Database me 'offerPrice' push karo taaki Node.js exact discountBurn nikal sake
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'offerPrice': calculatedOfferPrice});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Offer Applied & Synced with Quantum Engine!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
} // 🚀 FIX: YE AAKHRI BRACKET MISSING THA (Ye error 2 fix karega)
