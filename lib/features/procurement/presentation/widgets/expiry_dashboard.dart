import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stock_service.dart';
import 'offer_creation_dialog.dart';
import 'create_po_dialog.dart';

class ExpiryAlertDashboard extends StatefulWidget {
  const ExpiryAlertDashboard({super.key});

  @override
  State<ExpiryAlertDashboard> createState() => _ExpiryAlertDashboardState();
}

class _ExpiryAlertDashboardState extends State<ExpiryAlertDashboard> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  int _currentPage = 0;
  final int _pageSize = 10;
  String _selectedSort = 'Trending';
  bool _isSorting = false;

  Map<String, int> _salesDataCache = {};
  DateTime? _lastCacheTime;

  final List<Map<String, dynamic>> _sortOptions = [
    {
      'name': 'Trending',
      'icon': Icons.local_fire_department,
      'filter': 'Trending',
    },
    {'name': 'Expiry', 'icon': Icons.hourglass_bottom, 'filter': 'Expiry'},
    {'name': 'Stock', 'icon': Icons.inventory, 'filter': 'Stock'},
    {'name': 'ATL', 'icon': Icons.trending_down, 'filter': 'ATL'},
  ];

  @override
  void initState() {
    super.initState();
    _analyzeRecentTransactions();
  }

  Stream<QuerySnapshot> get _engineStream {
    final query = _searchQuery.trim().toLowerCase();
    var baseQuery = FirebaseFirestore.instance.collection('products');

    if (query.isNotEmpty) {
      if (double.tryParse(query) != null) {
        return baseQuery.where('barcode', isEqualTo: query).snapshots();
      }
      return baseQuery
          .where('searchKey', isGreaterThanOrEqualTo: query)
          .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .snapshots();
    }
    return baseQuery.snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeRecentTransactions() async {
    if (_lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!).inMinutes < 5) {
      return;
    }

    setState(() => _isSorting = true);
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
          )
          .get();

      Map<String, int> salesCount = {};
      for (var doc in ordersSnap.docs) {
        final data = doc.data();
        if (data['paymentStatus'] == 'PAID' ||
            data['paymentStatus'] == 'SUCCESS') {
          final items = data['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            String prodId = item['productId'] ?? '';
            int qty = item['quantity'] ?? item['orderQty'] ?? 1;
            if (prodId.isNotEmpty) {
              salesCount[prodId] = (salesCount[prodId] ?? 0) + qty;
            }
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

      int salesA = _salesDataCache[a.id] ?? 0;
      int salesB = _salesDataCache[b.id] ?? 0;

      int stA = dataA['physicalStock'] ?? dataA['stock'] ?? 0;
      int stB = dataB['physicalStock'] ?? dataB['stock'] ?? 0;

      Timestamp? expA = dataA['expiryDate'] as Timestamp?;
      Timestamp? expB = dataB['expiryDate'] as Timestamp?;

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

      return 0;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.memory, color: Color(0xFF2B3674), size: 28),
                  SizedBox(width: 12),
                  Text(
                    "Quantum Promotion Engine 🌌",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B3674),
                    ),
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
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 0;
                    }),
                    decoration: const InputDecoration(
                      hintText: "Search Product by Name or Barcode...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSort,
                      icon: const Icon(Icons.sort, color: Colors.blue),
                      items: _sortOptions
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt['filter'],
                              child: Row(
                                children: [
                                  Icon(
                                    opt['icon'],
                                    size: 16,
                                    color: const Color(0xFF2B3674),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF2B3674),
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
              ? const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _engineStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(),
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
                          color: Colors.grey.shade50,
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
                        final double tableWidth = constraints.maxWidth < 1000
                            ? 1000
                            : constraints.maxWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
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
                                    color: Colors.grey.shade100,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          "Product Info",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2B3674),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "Expiry Status",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2B3674),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "Offer Status",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2B3674),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          "Stock",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2B3674),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "Action",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2B3674),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: pageProducts.length,
                                  itemBuilder: (context, index) {
                                    final doc = pageProducts[index];
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final productId = doc.id;
                                    final name = data['name'] ?? 'Unknown Item';
                                    final stock =
                                        data['physicalStock'] ??
                                        data['stock'] ??
                                        0;
                                    final price =
                                        data['price'] ?? data['mrp'] ?? 0;
                                    final isClearanceActive =
                                        data['clearanceActive'] == true;

                                    int daysLeft = 999;
                                    if (data['expiryDate'] != null) {
                                      daysLeft =
                                          (data['expiryDate'] as Timestamp)
                                              .toDate()
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
                                        await StockService.blockBatchSafely(
                                          productId,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("✅ $name Blocked!"),
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
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                            left: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                            right: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // 1. PRODUCT INFO
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    "7-Day Sales: ${_salesDataCache[productId] ?? 0}",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.blueAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Price: ₹$price",
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    "👉 Swipe right to Block",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 2. EXPIRY STATUS (Unified Solid Button Theme)
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
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
                                                                  ? Icons.timer
                                                                  : Icons
                                                                        .verified_user)),
                                                  isDead
                                                      ? [
                                                          Colors.grey.shade800,
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

                                            // 3. OFFER STATUS (Unified Solid Button Theme)
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: isDead
                                                    ? _buildSolidBadge(
                                                        "NOT APPLICABLE",
                                                        Icons.block,
                                                        [
                                                          Colors.grey.shade400,
                                                          Colors.grey.shade500,
                                                        ],
                                                      )
                                                    : (isClearanceActive
                                                          ? Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _buildSolidBadge(
                                                                  (data['clearanceTag'] ??
                                                                          'OFFER ACTIVE')
                                                                      .toString()
                                                                      .toUpperCase(),
                                                                  Icons
                                                                      .local_offer,
                                                                  [
                                                                    Colors
                                                                        .purple
                                                                        .shade400,
                                                                    Colors
                                                                        .purple
                                                                        .shade600,
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                InkWell(
                                                                  onTap: () =>
                                                                      StockService.undoClearance(
                                                                        productId,
                                                                      ),
                                                                  child: const Padding(
                                                                    padding:
                                                                        EdgeInsets.only(
                                                                          left:
                                                                              4.0,
                                                                        ),
                                                                    child: Text(
                                                                      "Remove Offer",
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .red,
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        decoration:
                                                                            TextDecoration.underline,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          : Container(
                                                              height: 38,
                                                              width:
                                                                  140, // 🚀 Fixed width like badges
                                                              decoration: BoxDecoration(
                                                                gradient: const LinearGradient(
                                                                  colors: [
                                                                    Color(
                                                                      0xFF10B981,
                                                                    ),
                                                                    Color(
                                                                      0xFF059669,
                                                                    ),
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color:
                                                                        const Color(
                                                                          0xFF059669,
                                                                        ).withValues(
                                                                          alpha:
                                                                              0.3,
                                                                        ),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          4,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: ElevatedButton.icon(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .transparent,
                                                                  shadowColor:
                                                                      Colors
                                                                          .transparent,
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            5,
                                                                      ),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ),
                                                                onPressed: () =>
                                                                    _handleApplyOffer(
                                                                      context,
                                                                      productId,
                                                                      name,
                                                                    ),
                                                                icon: const Icon(
                                                                  Icons.sell,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                label: const FittedBox(
                                                                  fit: BoxFit
                                                                      .scaleDown,
                                                                  child: Text(
                                                                    "APPLY OFFER",
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      letterSpacing:
                                                                          0.5,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            )),
                                              ),
                                            ),

                                            // 4. STOCK
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                stock.toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  color: stock <= 20
                                                      ? Colors.red
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),

                                            // 5. ACTION (RAISE PO - Matched Width)
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  height: 38,
                                                  width:
                                                      140, // 🚀 Fixed width like badges
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF3B82F6),
                                                            Color(0xFF2563EB),
                                                          ],
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.blue
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      shadowColor:
                                                          Colors.transparent,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: () => showDialog(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          CreatePODialog(
                                                            productId:
                                                                productId,
                                                            productName: name,
                                                            currentStock: stock,
                                                          ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons.add_shopping_cart,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                    label: const FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        "RAISE PO",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
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

                                // PAGINATION
                                if (totalPages > 1) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Showing ${startIndex + 1} - $endIndex of ${processedProducts.length} Entries",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_left,
                                                color: Color(0xFF2B3674),
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
                                                color: const Color(0xFF2B3674),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "${_currentPage + 1} / $totalPages",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chevron_right,
                                                color: Color(0xFF2B3674),
                                              ),
                                              onPressed:
                                                  _currentPage < totalPages - 1
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
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  // 🚀 THE NEW UNIFIED SOLID BADGE (MATCHES BUTTONS PERFECTLY)
  Widget _buildSolidBadge(
    String text,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      height: 38,
      width: 140, // Perfect identical alignment down the table
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Offer Applied!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
