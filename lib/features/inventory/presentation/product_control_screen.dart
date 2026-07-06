import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';

import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/utils/hierarchy_filter.dart';

import 'add_product_dialog.dart';
import 'edit_product_dialog.dart';
import '../providers/product_master/product_master_provider.dart';
import 'package:clickout_admin/features/procurement/services/stock_service.dart';
import '../../coach/widgets/info_button.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class ProductControlScreen extends ConsumerStatefulWidget {
  const ProductControlScreen({super.key});

  @override
  ConsumerState<ProductControlScreen> createState() =>
      _ProductControlScreenState();
}

class _ProductControlScreenState extends ConsumerState<ProductControlScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController =
      ScrollController(); // 🚀 SCROLL FIX
  bool _isUploadingCsv = false;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

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

    // 🚀 SAAS ISOLATION: The Wall is Active Here!
    Query q =
        HierarchyFilter.apply(
          FirebaseFirestore.instance.collection('products'),
          adminData,
        ).where(
          'itemType',
          isEqualTo: 'PRODUCT',
        ); // 🚀 BUG FIX: Matched exact DB schema

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
      if (mounted) {
        final err = e.toString();
        final isIndex =
            err.contains('FAILED_PRECONDITION') || err.contains('index');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndex
                  ? "🚨 INDEX BUILDING: Bhai Firebase index banne me 10-15 min lagte hain! Firebase console me status 'Enabled' hone tak wait karo."
                  : "🚨 DB ERROR: $err",
            ),
            backgroundColor: const Color(0xFFFE8181),
            duration: const Duration(seconds: 8),
          ),
        );
      }
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

  // 🚀 CSV UPLOAD LOGIC (Calling Cloud Function with SaaS Context)
  Widget _csvRuleRow(String field, String wrong, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              field,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Text(
            wrong,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            right,
            style: const TextStyle(color: Color(0xFF00C853), fontSize: 12),
          ),
        ],
      ),
    );
  }

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

      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String branchCode = adminData?['branchCode'] ?? 'HQ';
      final String adminName = adminData?['name'] ?? 'Unknown Manager';
      final String adminEmail = adminData?['email'] ?? 'Unknown Email';

      // 🚨 FIELD VALIDATOR — Rejects units/symbols in numeric fields
      String? _validateNumericField(
        String value,
        String fieldName,
        int rowNum,
      ) {
        final cleaned = value.trim();
        if (cleaned.isEmpty) return null;
        // Reject if contains letters, %, ₹, or any non-numeric chars except dot
        if (RegExp(r'[a-zA-Z%₹\s]').hasMatch(cleaned)) {
          throw "🚨 Row $rowNum: '$fieldName' = '$cleaned' — INVALID FORMAT.\n\n"
              "❌ Wrong: ${fieldName == 'weight'
                  ? '250ml or 250gm'
                  : fieldName == 'gst'
                  ? '18%'
                  : '₹100'}\n"
              "✅ Correct: ${fieldName == 'weight'
                  ? '250'
                  : fieldName == 'gst'
                  ? '18'
                  : '100'}\n\n"
              "⚠️ Units/symbols in numeric fields WILL CRASH THE SYSTEM.\nFix CSV and re-upload.";
        }
        return null;
      }

      List<Map<String, dynamic>> productList = [];
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> row = line.split(',');
        if (row.isEmpty || row[0].trim().isEmpty) continue;

        // 🛡️ Validate numeric fields — reject units/symbols
        _validateNumericField(row.length > 2 ? row[2].trim() : '', 'price', i);
        _validateNumericField(
          row.length > 3 ? row[3].trim() : '',
          'unit cost',
          i,
        );
        _validateNumericField(row.length > 5 ? row[5].trim() : '', 'gst', i);
        _validateNumericField(row.length > 7 ? row[7].trim() : '', 'weight', i);

        // 🚀 SMART DATE NORMALIZATION (Fixes the MM/YYYY vs DD/MM/YYYY issue)
        String rawDate = row.length > 6 ? row[6].trim() : '';
        String parsedDate = rawDate.isNotEmpty
            ? rawDate.replaceAll('-', '/')
            : '';

        // 🚀 SENDING THE RICH PAYLOAD TO BACKEND
        productList.add({
          'barcode': row[0].trim(),
          'name': row.length > 1 ? row[1].trim() : 'Unknown Item',
          'itemType':
              'PRODUCT', // 🚀 FIX: Database me type update karega tabhi UI me dikhega
          'searchKey': row.length > 1
              ? row[1].trim().toLowerCase()
              : '', // 🚀 FIX: Search chalne ke liye zaroori
          'price': row.length > 2 ? double.tryParse(row[2].trim()) ?? 0 : 0,
          'weight': row.length > 3 ? row[3].trim() : '0',
          'physicalStock': row.length > 4
              ? int.tryParse(row[4].trim()) ?? 0
              : 0,
          'openingStock': row.length > 4 ? int.tryParse(row[4].trim()) ?? 0 : 0,
          'gst': row.length > 5 ? row[5].trim() : '0',
          'expiryDate': parsedDate.isNotEmpty
              ? parsedDate
              : null, // Store as String cleanly
          'tenantId': tenantId,
          'branchCode': branchCode,
          'addedBy': adminName,
          'addedByEmail': adminEmail,
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
            content: Text(
              "✅ ${response.data['message'] ?? 'Imported Successfully!'}",
            ),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
        _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 Error: $e"),
            backgroundColor: const Color(0xFFFE8181),
          ),
        );
      }
    } finally {
      setState(() => _isUploadingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminRoleProvider, (previous, next) {
      if (previous?.value == null && next.value != null) {
        _fetchInitialData();
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 768;

    // 🎨 DYNAMIC PREMIUM THEME (Emerald Aurora Light + Premium Dark)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgDark = context.colors.scaffoldBg;
    final Color cardDark = context.colors.cardBg;
    final Color accentGreen = isDark
        ? const Color(0xFF00C853)
        : const Color(0xFF0B6B60);
    final Color accentRed = const Color(0xFFFE8181);
    final Color textPrimary = context.colors.textPrimary;
    final Color textSecondary = context.colors.textSecondary;
    final Color inputBg = context.colors.scaffoldBg;
    final Color tableHeaderBg = context.colors.cardBg;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = (startIndex + _rowsPerPage > _docs.length)
        ? _docs.length
        : startIndex + _rowsPerPage;
    List<DocumentSnapshot> currentPageDocs = _docs.isEmpty
        ? []
        : _docs.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: bgDark,
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
                    Row(
                      children: [
                        Text(
                          "Product Master Roster 📦",
                          style: TextStyle(
                            fontSize: isMobile ? 24 : 28,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const InfoButton(
                          title: 'Product Master Roster',
                          en: 'Central inventory control — add, edit, delete products. Each product has barcode, stock, price, GST, and offer eligibility. Linked directly to billing and procurement.',
                          hi: 'Yahan se saare products manage karo — add karo, edit karo, delete karo. Barcode, stock, price, GST sab yahan set hota hai. Ye directly billing aur procurement se linked hai.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Enterprise SKU & Inventory Management",
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 15,
                  runSpacing: 10,
                  children: [
                    // 🚀 NAYA: TEMPLATE BUTTON
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        side: BorderSide(color: textSecondary.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: inputBg,
                            title: Text(
                              "CSV Format Template",
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Column Order:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'barcode, name, price, unit_cost, gst, physical_stock, expiry_date, weight',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Example row:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '8901542001234, Mango Juice, 100, 70, 18, 50, 12/2027, 250',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFF00C853),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    '⚠️ Weight: 250 ✅  250ml ❌\n⚠️ Price: 100 ✅  ₹100 ❌\n⚠️ GST: 18 ✅  18% ❌',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy, size: 14),
                                label: const Text('Copy Template'),
                                onPressed: () {
                                  Clipboard.setData(
                                    const ClipboardData(
                                      text:
                                          'barcode,name,price,unit_cost,gst,physical_stock,expiry_date,weight\n8901542001234,Mango Juice,100,70,18,50,12/2027,250',
                                    ),
                                  );
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Template copied to clipboard',
                                      ),
                                      backgroundColor: Color(0xFF00C853),
                                    ),
                                  );
                                },
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Got it"),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text(
                        "View Template",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inputBg,
                        foregroundColor: textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: textSecondary.withOpacity(0.2),
                          ),
                        ),
                      ),
                      onPressed: _isUploadingCsv
                          ? null
                          : () async {
                              // Show warning dialog before upload
                              await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: isDark
                                      ? const Color(0xFF111811)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: const [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.amber,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'CSV Format Rules',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Numeric fields must be NUMBERS ONLY:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _csvRuleRow('Weight', '250ml ❌', '250 ✅'),
                                      _csvRuleRow('Price', '₹100 ❌', '100 ✅'),
                                      _csvRuleRow('GST', '18% ❌', '18 ✅'),
                                      _csvRuleRow('Unit Cost', '₹70 ❌', '70 ✅'),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          '⚠️ Units or symbols in numeric fields will CRASH the system and corrupt your inventory.',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'CSV Column Order:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'barcode, name, price, unit_cost, gst, physical_stock, expiry_date(MM/YYYY), weight',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Example row:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '8901542001234, Mango Juice, 100, 70, 18, 50, 12/2027, 250',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: Color(0xFF00C853),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.copy, size: 14),
                                      label: const Text('Copy Template'),
                                      onPressed: () {
                                        Clipboard.setData(
                                          const ClipboardData(
                                            text:
                                                'barcode,name,price,unit_cost,gst,physical_stock,expiry_date,weight\n8901542001234,Mango Juice,100,70,18,50,12/2027,250',
                                          ),
                                        );
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✅ Template copied to clipboard',
                                            ),
                                            backgroundColor: Color(0xFF00C853),
                                          ),
                                        );
                                      },
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentGreen,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _processCsvImport();
                                      },
                                      child: const Text(
                                        'Understood, Upload CSV',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                      icon: _isUploadingCsv
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentGreen,
                              ),
                            )
                          : Icon(
                              Icons.file_upload_outlined,
                              size: 18,
                              color: accentGreen,
                            ),
                      label: Text(
                        _isUploadingCsv ? "Uploading..." : "Import CSV",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: isDark
                            ? const Color(0xFF080B08)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => const AddProductDialog(),
                      ).then((_) => _fetchInitialData()),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        "Add Product",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: isMobile ? double.infinity : 350,
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: textSecondary.withOpacity(0.15)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textPrimary),
                    onSubmitted: (val) {
                      _searchQuery = val;
                      _fetchInitialData();
                    },
                    decoration: InputDecoration(
                      hintText: "Scan Barcode or Search Name...",
                      hintStyle: TextStyle(
                        color: textSecondary.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(Icons.search, color: textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 18,
                                color: accentRed,
                              ),
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
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: textSecondary.withOpacity(0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: cardDark,
                      value: _sortOption,
                      icon: Icon(Icons.sort, color: accentGreen),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
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
              ],
            ),
            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading && _docs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(60),
                      child: Center(
                        child: CircularProgressIndicator(color: accentGreen),
                      ),
                    )
                  else if (currentPageDocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: accentRed.withOpacity(0.3),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              "Empty Shelf",
                              style: TextStyle(
                                color: accentRed,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "No products found matching criteria.",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: textSecondary.withOpacity(0.15),
                          ),
                          child: DataTable(
                            headingRowHeight: 56,
                            dataRowMaxHeight: 80,
                            dataRowMinHeight: 60,
                            columnSpacing: 25,
                            headingRowColor: WidgetStateProperty.all(
                              tableHeaderBg,
                            ),
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? textSecondary
                                  : const Color(0xFF004D40),
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                            columns: const [
                              DataColumn(label: Text("BARCODE")),
                              DataColumn(label: Text("PRODUCT NAME")),
                              DataColumn(label: Text("MRP / PRICE")),
                              DataColumn(label: Text("PHYSICAL STOCK")),
                              DataColumn(label: Text("STATUS")),
                              DataColumn(label: Text("ACTIONS")),
                            ],
                            rows: currentPageDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final int stock = data['physicalStock'] ?? 0;
                              bool isLowStock = stock <= 10;
                              final bool isBlocked = data['isBlocked'] ?? false;

                              final String displayBarcode =
                                  (data['barcode'] ?? doc.id)
                                      .toString()
                                      .split('_')
                                      .last;

                              // 🚀 SAFEGUARD DATA FOR EDIT DIALOG
                              var safeData = Map<String, dynamic>.from(data);
                              safeData['expiryDate'] = data['expiryDate']
                                  ?.toString();

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered))
                                    return inputBg;
                                  return Colors.transparent;
                                }),
                                cells: [
                                  DataCell(
                                    Text(
                                      displayBarcode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        data['name'] ?? 'N/A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      "₹${data['price'] ?? 0}",
                                      style: TextStyle(
                                        color: accentGreen,
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
                                            ? accentRed.withOpacity(0.1)
                                            : accentGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isLowStock
                                              ? accentRed.withOpacity(0.3)
                                              : accentGreen.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isLowStock)
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: accentRed,
                                              size: 14,
                                            ),
                                          if (isLowStock)
                                            const SizedBox(width: 4),
                                          Text(
                                            "$stock Units",
                                            style: TextStyle(
                                              color: isLowStock
                                                  ? accentRed
                                                  : accentGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
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
                                        color: isBlocked
                                            ? accentRed.withValues(alpha: 0.1)
                                            : accentGreen.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isBlocked
                                              ? accentRed.withValues(alpha: 0.3)
                                              : accentGreen.withValues(
                                                  alpha: 0.3,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        isBlocked ? "BLOCKED 💀" : "ACTIVE",
                                        style: TextStyle(
                                          color: isBlocked
                                              ? accentRed
                                              : accentGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize:
                                          MainAxisSize.min, // 🚀 RENDERFLEX FIX
                                      children: [
                                        if (isBlocked) // 🚀 SAAS RULE: Blocked item gets Restore Button
                                          IconButton(
                                            icon: const Icon(
                                              Icons.settings_backup_restore,
                                              color: Color(0xFFD4580A),
                                            ),
                                            tooltip: "Unblock & Restore Stock",
                                            onPressed: () => _showRestoreDialog(
                                              context,
                                              doc.id,
                                              data['name'] ?? 'Unknown Item',
                                            ),
                                          )
                                        else
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit_note,
                                              color: accentGreen,
                                            ),
                                            tooltip: "Edit Product",
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (ctx) =>
                                                  EditProductDialog(
                                                    productData: safeData,
                                                    docId: displayBarcode,
                                                  ),
                                            ).then((_) => _fetchInitialData()),
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: accentRed,
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
                          ), // End of DataTable
                        ), // End of Theme
                      ), // End of SingleChildScrollView 🚀
                    ), // End of Scrollbar 🚀

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentGreen,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: textPrimary),
                          onPressed: _currentPage > 0 ? _prevPage : null,
                          disabledColor: textSecondary.withOpacity(0.3),
                        ),
                        Text(
                          "Page ${_currentPage + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: textPrimary),
                          onPressed:
                              _hasMore ||
                                  ((_currentPage + 1) * _rowsPerPage <
                                      _docs.length)
                              ? _fetchNextPage
                              : null,
                          disabledColor: textSecondary.withOpacity(0.3),
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

  void _showRestoreDialog(BuildContext context, String fullDocId, String name) {
    final TextEditingController qtyCtrl = TextEditingController();
    bool isRestoring = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFD4580A), width: 1.5),
            ),
            backgroundColor: Theme.of(context).cardColor,
            elevation: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
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
                            color: const Color(
                              0xFFD4580A,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.settings_backup_restore,
                            color: Color(0xFFD4580A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Restore Blocked Item",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Unblock '$name' by adding new physical stock.",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "New Physical Stock",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter units",
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.add_box,
                          color: Color(0xFFD4580A),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1A221A)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(
                            color: Color(0xFFD4580A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isRestoring
                              ? null
                              : () => Navigator.pop(ctx),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4580A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: isRestoring
                              ? null
                              : () async {
                                  final int qty =
                                      int.tryParse(qtyCtrl.text.trim()) ?? 0;
                                  if (qty <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Enter a valid quantity!",
                                        ),
                                        backgroundColor: Color(0xFFFE8181),
                                      ),
                                    );
                                    return;
                                  }

                                  setState(() => isRestoring = true);
                                  try {
                                    await StockService.undoBlockBatch(
                                      fullDocId,
                                      qty,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("✅ $name Unblocked!"),
                                          backgroundColor: const Color(
                                            0xFF00C853,
                                          ),
                                        ),
                                      );
                                      _fetchInitialData();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      setState(() => isRestoring = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text("Error: $e"),
                                          backgroundColor: const Color(
                                            0xFFFE8181,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isRestoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: const Text(
                            "Restore Access",
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String barcode,
    String name,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFE8181), width: 1),
        ),
        title: Text(
          "Delete Product? 🗑️",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Delete '$name' (Barcode: $barcode)?",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE8181),
              foregroundColor: Colors.white,
            ),
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
                      backgroundColor: const Color(0xFFFE8181),
                    ),
                  );
                  _fetchInitialData();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: const Color(0xFFFE8181),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Yes, Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
