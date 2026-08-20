import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          // 🚀 COST FIX: Low-stock alert list pehle bina limit ke tha.
          .limit(50)
          .snapshots();
    }
    if (double.tryParse(query) != null) {
      return FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: query)
          // 🚀 COST FIX: barcode ideally unique hai, safety limit lagaya.
          .limit(5)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('products')
        .where('searchKey', isGreaterThanOrEqualTo: query)
        .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20) // Limit search results initially
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.orange.withValues(alpha: 0.05), blurRadius: 10),
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
                  Icon(Icons.inventory_2, color: Colors.orange),
                  SizedBox(width: 10),
                  Text(
                    "Shelf Radar 📉",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3674),
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
                  child: const Text("Clear Search"),
                ),
            ],
          ),
          const SizedBox(height: 15),

          // 🔍 SEARCH BAR
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _currentPage = 0;
              }),
              decoration: const InputDecoration(
                hintText: "Search Product or Barcode...",
                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: _radarStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No products found.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              final allProducts = snapshot.data!.docs;

              // 🚀 REAL-TIME PAGINATION MATH
              final totalPages = (allProducts.length / _pageSize).ceil();
              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1; // Safety check
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
                    separatorBuilder: (context, index) => const Divider(),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Stock: $physical Units",
                          style: TextStyle(
                            color: physical <= 10 ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            side: const BorderSide(color: Colors.blueAccent),
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Alerts: ${allProducts.length}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              "Page ${_currentPage + 1} of $totalPages",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
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
