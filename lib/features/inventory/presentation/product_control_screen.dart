import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION

import 'add_product_dialog.dart';
import 'edit_product_dialog.dart';
import '../providers/product_master/product_master_provider.dart';

class ProductControlScreen extends ConsumerStatefulWidget {
  const ProductControlScreen({super.key});

  @override
  ConsumerState<ProductControlScreen> createState() =>
      _ProductControlScreenState();
}

class _ProductControlScreenState extends ConsumerState<ProductControlScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isUploadingCsv = false;

  // 🚀 PAGINATION & FILTER STATE
  List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _rowsPerPage = 20;

  String _searchQuery = "";
  String _sortOption = 'NEWEST';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // 🧠 SMART FIRESTORE QUERY BUILDER (🚀 SAAS INJECTED)
  Query _buildQuery() {
    final adminData = ref.read(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String role = (adminData?['role'] ?? '').toString().toLowerCase();

    Query q = FirebaseFirestore.instance.collection('products');

    // 🚀 SAAS ISOLATION
    if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
      q = q.where('tenantId', isEqualTo: tenantId);
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      if (double.tryParse(query) != null) {
        q = q
            .where('barcode', isGreaterThanOrEqualTo: query)
            .where('barcode', isLessThanOrEqualTo: '$query\uf8ff')
            .orderBy('barcode');
      } else {
        q = q
            .where('searchKey', isGreaterThanOrEqualTo: query)
            .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff')
            .orderBy('searchKey');
      }
    } else {
      if (_sortOption == 'STOCK_DESC') {
        q = q.orderBy('physicalStock', descending: true);
      } else if (_sortOption == 'STOCK_ASC') {
        q = q.orderBy('physicalStock', descending: false);
      } else {
        q = q.orderBy('createdAt', descending: true);
      }
    }

    return q.limit(_rowsPerPage);
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _buildQuery().get();
      _docs = snap.docs;
      _hasMore = snap.docs.length == _rowsPerPage;
      _currentPage = 0;
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore || _isLoading || _docs.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _buildQuery().startAfterDocument(_docs.last).get();
      _docs.addAll(snap.docs);
      _hasMore = snap.docs.length == _rowsPerPage;
      _currentPage++;
    } catch (e) {
      debugPrint("Pagination Error: $e");
    }
    setState(() => _isLoading = false);
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  // 🚀 CSV UPLOAD LOGIC (🚀 SAAS INJECTED)
  Future<void> _processCsvImport() async {
    setState(() => _isUploadingCsv = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => _isUploadingCsv = false);
        return;
      }

      final bytes = result.files.single.bytes!;
      final csvString = utf8.decode(bytes);
      List<String> lines = csvString.split('\n');

      if (lines.isEmpty || lines.length <= 1) {
        throw "🚨 CSV is empty or missing data rows!";
      }

      // 🚀 SAAS INJECTION
      final String? tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      List<Map<String, dynamic>> productList = [];
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> row = line.split(',');
        if (row.isEmpty || row[0].trim().isEmpty) continue;

        productList.add({
          'barcode': row[0].trim(),
          'name': row.length > 1 ? row[1].trim() : 'Unknown Item',
          'price': row.length > 2 ? double.tryParse(row[2].trim()) ?? 0 : 0,
          'weight': row.length > 3 ? row[3].trim() : '0',
          'stock': row.length > 4 ? int.tryParse(row[4].trim()) ?? 0 : 0,
          'gst': row.length > 5 ? row[5].trim() : '0',
          'expiryDate': row.length > 6 && row[6].trim().isNotEmpty
              ? row[6].trim()
              : null,
          'tenantId': tenantId, // 🚀 SAAS INJECTION
        });
      }

      if (productList.isEmpty) throw "🚨 No valid data found in CSV!";

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'bulkImportProducts',
      );
      final response = await callable.call({'products': productList});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${response.data['message']}"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color themeNavy = Color(0xFF2B3674);
    final isMobile = MediaQuery.of(context).size.width < 768;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = (startIndex + _rowsPerPage > _docs.length)
        ? _docs.length
        : startIndex + _rowsPerPage;
    List<DocumentSnapshot> currentPageDocs = _docs.isEmpty
        ? []
        : _docs.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Product Master Roster 📦",
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: themeNavy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Enterprise SKU & Inventory Management",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 15,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: themeNavy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onPressed: _isUploadingCsv ? null : _processCsvImport,
                      icon: _isUploadingCsv
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(
                        _isUploadingCsv ? "Uploading..." : "Import CSV",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeNavy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => const AddProductDialog(),
                      ).then((_) => _fetchInitialData()),
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "Add Product",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: isMobile ? double.infinity : 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) {
                      _searchQuery = val;
                      _fetchInitialData();
                    },
                    decoration: InputDecoration(
                      hintText: "Scan Barcode or Search Name...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _fetchInitialData();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortOption,
                      icon: const Icon(Icons.sort, color: themeNavy),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeNavy,
                        fontSize: 13,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'NEWEST',
                          child: Text("Sort: Newest First"),
                        ),
                        DropdownMenuItem(
                          value: 'STOCK_DESC',
                          child: Text("Sort: Highest Stock"),
                        ),
                        DropdownMenuItem(
                          value: 'STOCK_ASC',
                          child: Text("Sort: Lowest Stock (Alerts)"),
                        ),
                      ],
                      onChanged: _searchQuery.isNotEmpty
                          ? null
                          : (val) {
                              setState(() => _sortOption = val!);
                              _fetchInitialData();
                            },
                    ),
                  ),
                ),

                if (_searchQuery.isEmpty)
                  const Text(
                    "💡 Hint: Searching disables custom sorting.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading && _docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (currentPageDocs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(
                        child: Text(
                          "No products found matching criteria.",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade50,
                        ),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B3674),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        columnSpacing: 40,
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 60,
                        columns: const [
                          DataColumn(label: Text("BARCODE")),
                          DataColumn(label: Text("PRODUCT NAME")),
                          DataColumn(label: Text("MRP / PRICE")),
                          DataColumn(label: Text("PHYSICAL STOCK")),
                          DataColumn(label: Text("ACTIONS")),
                        ],
                        rows: currentPageDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final int stock = data['physicalStock'] ?? 0;
                          bool isLowStock = stock <= 10;

                          // SaaS Extracted Barcode (Visual clean up)
                          final String displayBarcode =
                              (data['barcode'] ?? doc.id)
                                  .toString()
                                  .split('_')
                                  .last;

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered)) {
                                return Colors.blue.withOpacity(0.04);
                              }
                              return Colors.white;
                            }),
                            cells: [
                              DataCell(
                                Text(
                                  displayBarcode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: themeNavy,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  data['name'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "₹${data['price'] ?? 0}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLowStock)
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red,
                                          size: 14,
                                        ),
                                      if (isLowStock) const SizedBox(width: 4),
                                      Text(
                                        "$stock Units",
                                        style: TextStyle(
                                          color: isLowStock
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_note,
                                        color: Colors.blueAccent,
                                      ),
                                      tooltip: "Edit Product Details",
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (ctx) => EditProductDialog(
                                          productData: data,
                                          docId:
                                              displayBarcode, // Clean barcode pass
                                        ),
                                      ).then((_) => _fetchInitialData()),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: "Delete Product",
                                      onPressed: () => _confirmDelete(
                                        context,
                                        ref,
                                        displayBarcode,
                                        data['name'] ?? 'Unknown Item',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          tooltip: "Previous Page",
                          onPressed: _currentPage > 0 ? _prevPage : null,
                        ),
                        Text(
                          "Page ${_currentPage + 1}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeNavy,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          tooltip: "Next Page",
                          onPressed:
                              _hasMore ||
                                  ((_currentPage + 1) * _rowsPerPage <
                                      _docs.length)
                              ? _fetchNextPage
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String barcode,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product? 🗑️"),
        content: Text(
          "Are you sure you want to permanently delete '$name' (Barcode: $barcode)?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(productMasterProvider.notifier)
                    .deleteProduct(barcode, name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("🗑️ $name deleted!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _fetchInitialData();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Yes, Delete",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
