import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/theme/app_theme.dart'; // 🚀 Premium Theme Imported
import 'create_po_dialog.dart';

class StockAlertWidget extends StatefulWidget {
  const StockAlertWidget({super.key});

  @override
  State<StockAlertWidget> createState() => _StockAlertWidgetState();
}

class _StockAlertWidgetState extends State<StockAlertWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  // 📄 PAGINATION STATE
  int _currentPage = 0;
  final int _pageSize = 5;

  Stream<QuerySnapshot> get _radarStream {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('physicalStock', isLessThanOrEqualTo: 20)
          .limit(50)
          .snapshots();
    }
    if (double.tryParse(query) != null) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: query)
          .limit(5)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('products')
        .where('searchKey', isGreaterThanOrEqualTo: query)
        .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(24), // 🚀 Premium 24px Radius
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.orange.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    "Shelf Radar 📉",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_searchQuery.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = "";
                      _currentPage = 0;
                    });
                  },
                  child: Text(
                    "Clear Search",
                    style: TextStyle(
                      color: c.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔍 SEARCH BAR
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _currentPage = 0;
              }),
              decoration: InputDecoration(
                hintText: "Search Product or Barcode...",
                hintStyle: TextStyle(
                  color: c.textSecondary.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: c.textSecondary,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: _radarStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(color: Colors.orange),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "No low-stock products found.",
                    style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              final allProducts = snapshot.data!.docs;

              // 🚀 REAL-TIME PAGINATION MATH
              final totalPages = (allProducts.length / _pageSize).ceil();
              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1;
              }

              final startIndex = _currentPage * _pageSize;
              final endIndex = (startIndex + _pageSize > allProducts.length)
                  ? allProducts.length
                  : startIndex + _pageSize;
              final pageProducts = allProducts.sublist(startIndex, endIndex);

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pageProducts.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: c.textSecondary.withValues(alpha: 0.1)),
                    itemBuilder: (context, index) {
                      final data =
                          pageProducts[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Unknown Item';
                      final physical = data['physicalStock'] ?? 0;
                      final docId = pageProducts[index].id;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: c.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          "Stock: $physical Units",
                          style: TextStyle(
                            color: physical <= 10 ? c.danger : c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.ctaBackground,
                            side: BorderSide(
                              color: c.ctaBackground.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => CreatePODialog(
                                productId: docId,
                                productName: name,
                                currentStock: physical,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text(
                            "Raise PO",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ⏭️ PAGINATION CONTROLS
                  if (totalPages > 1) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Alerts: ${allProducts.length}",
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.chevron_left,
                                color: c.textPrimary,
                              ),
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              "Page ${_currentPage + 1} of $totalPages",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.chevron_right,
                                color: c.textPrimary,
                              ),
                              onPressed: _currentPage < totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
