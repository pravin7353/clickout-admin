import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/store/providers/store_provider.dart';

import 'presentation/add_service_dialog.dart';
import 'presentation/edit_service_dialog.dart';
import 'providers/service_master_provider.dart';

class ServiceControlScreen extends ConsumerStatefulWidget {
  const ServiceControlScreen({super.key});

  @override
  ConsumerState<ServiceControlScreen> createState() =>
      _ServiceControlScreenState();
}

class _ServiceControlScreenState extends ConsumerState<ServiceControlScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  // 🚀 FIX: Set limit to 10 items per page
  final int _rowsPerPage = 10;
  String _searchQuery = "";

  final ScrollController _horizontalScrollController =
      ScrollController(); // 🚀 SCROLL FIX

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Query _buildQuery() {
    final adminData = ref.read(adminRoleProvider).value;
    final activeStore = ref.read(activeStoreProvider);

    final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
    final String? branchCode =
        activeStore?.branchCode ?? adminData?['branchCode'];
    final String role = (adminData?['role'] ?? '')
        .toString()
        .toUpperCase(); // 🚀 FETCH ROLE

    Query q = FirebaseFirestore.instance
        .collection('products')
        .where('itemType', isEqualTo: 'SERVICE'); // 🚀 ONLY FETCH SERVICES

    // 🛡️ LEVEL 1 ISOLATION (Super Admin Bypass)
    if (role != 'SUPER_ADMIN' && tenantId != null && tenantId.isNotEmpty) {
      q = q.where('tenantId', isEqualTo: tenantId);
    }

    // 🛡️ LEVEL 2 ISOLATION (Store Verification)
    if (role != 'SUPER_ADMIN' &&
        branchCode != null &&
        branchCode.isNotEmpty &&
        branchCode != 'HQ' &&
        branchCode != 'ALL') {
      q = q.where('branchCode', isEqualTo: branchCode);
    }

    // 🚀 NO ORDER_BY = NO INDEX ERRORS
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      q = q
          .where('searchKey', isGreaterThanOrEqualTo: query)
          .where('searchKey', isLessThanOrEqualTo: '$query\uf8ff');
    }

    return q.limit(_rowsPerPage);
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _buildQuery().get();
      if (mounted) {
        setState(() {
          _docs = snap.docs;
          _hasMore = snap.docs.length == _rowsPerPage;
          _currentPage = 0;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNextPage() async {
    if (!_hasMore || _isLoading || _docs.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _buildQuery().startAfterDocument(_docs.last).get();
      if (snap.docs.isNotEmpty) {
        _docs.addAll(snap.docs);
        _currentPage++;
      }
      _hasMore = snap.docs.length == _rowsPerPage;
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  void _confirmDelete(String barcode, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor, // 🚀 FIX: Dynamic Theme
        title: const Text(
          "Delete Service? ✂️",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Remove '$name' from catalog?",
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(serviceMasterProvider.notifier)
                  .deleteService(barcode);
              _fetchInitialData();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 DYNAMIC PREMIUM THEME (Sapphire Ocean Light + Premium Dark)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgDark = theme.scaffoldBackgroundColor;
    final Color cardDark = theme.cardColor;
    final Color accentBlue = isDark
        ? const Color(0xFF2962FF)
        : const Color(0xFF1565C0);
    final Color textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color textSecondary =
        theme.textTheme.labelLarge?.color ?? Colors.grey;
    final Color inputBg = isDark
        ? const Color(0xFF1A221A)
        : const Color(0xFFF4F5F7);
    final Color tableHeaderBg = isDark
        ? const Color(0xFF1A221A)
        : const Color(0xFFE3F2FD);

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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            // 🚀 FIX: Used Wrap to prevent layout break on small screens
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🚀 CONST HATAYA
                    Text(
                      "Service Master Roster ✂️",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Enterprise Service & Labor Management",
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
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
                    builder: (ctx) => const AddServiceDialog(),
                  ).then((_) => _fetchInitialData()),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    "Add Service",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- SEARCH BAR ---
            Container(
              // 🚀 FIX: Prevent search bar from forcing a rigid width
              constraints: const BoxConstraints(maxWidth: 350),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: textSecondary.withOpacity(0.15)),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary), // 🚀 const hataya
                onSubmitted: (val) {
                  _searchQuery = val;
                  _fetchInitialData();
                },
                decoration: InputDecoration(
                  hintText: "Search Service Name...",
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: textSecondary,
                  ), // 🚀 const hataya
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.redAccent,
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
            const SizedBox(height: 25),

            // --- TABLE ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: textSecondary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoading && _docs.isEmpty)
                    Padding(
                      // 🚀 const hataya
                      padding: const EdgeInsets.all(60),
                      child: Center(
                        child: CircularProgressIndicator(color: accentBlue),
                      ),
                    )
                  else if (currentPageDocs.isEmpty)
                    Padding(
                      // 🚀 const hataya
                      padding: const EdgeInsets.all(60),
                      child: Center(
                        child: Text(
                          "No services found.",
                          style: TextStyle(color: textSecondary),
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
                            columnSpacing: 35,
                            headingRowColor: WidgetStateProperty.all(
                              tableHeaderBg,
                            ),
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? textSecondary
                                  : const Color(
                                      0xFF0D47A1,
                                    ), // 💎 Deep Blue Header
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                            columns: const [
                              DataColumn(label: Text("SERVICE CODE")),
                              DataColumn(label: Text("SERVICE NAME")),
                              DataColumn(label: Text("CHARGE")),
                              DataColumn(label: Text("SAC CODE")),
                              DataColumn(label: Text("STATUS")),
                              DataColumn(label: Text("ACTIONS")),
                            ],
                            rows: currentPageDocs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final displayBarcode = (data['barcode'] ?? doc.id)
                                  .toString()
                                  .split('_')
                                  .last;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      displayBarcode,
                                      style: TextStyle(
                                        // 🚀 const hataya
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 200, // 🚀 NAME WRAP FIX
                                      child: Text(
                                        data['name'] ?? 'N/A',
                                        style: TextStyle(
                                          // 🚀 const hataya
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
                                        // 🚀 const hataya
                                        color: accentBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      data['sac'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.grey,
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
                                        color: accentBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        // 🚀 const hataya
                                        "ACTIVE",
                                        style: TextStyle(
                                          color: accentBlue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize
                                          .min, // 🚀 ACTIONS OVERFLOW FIX
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            // 🚀 const hataya
                                            Icons.edit_note,
                                            color: accentBlue,
                                          ),
                                          onPressed: () {
                                            // 🚀 FIX: Open Edit Service Dialog with pre-filled data!
                                            showDialog(
                                              context: context,
                                              builder: (ctx) =>
                                                  EditServiceDialog(
                                                    serviceData: data,
                                                  ),
                                            ).then(
                                              (_) => _fetchInitialData(),
                                            ); // Refresh table after edit
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () => _confirmDelete(
                                            displayBarcode,
                                            data['name'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ), // End DataTable
                        ), // End Theme 🚀
                      ), // End SingleChildScrollView 🚀
                    ), // End Scrollbar 🚀
                  // --- PAGINATION FOOTER ---
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      // 🚀 const hataya
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
                            // 🚀 const hataya
                            padding: const EdgeInsets.only(right: 15),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: accentBlue,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            // 🚀 const hataya
                            Icons.chevron_left,
                            color: textPrimary,
                          ),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        Text(
                          "Page ${_currentPage + 1}",
                          style: TextStyle(
                            // 🚀 const hataya
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            // 🚀 const hataya
                            Icons.chevron_right,
                            color: textPrimary,
                          ),
                          // 🚀 FIX: Properly switch between local cache and Firebase fetch
                          onPressed:
                              ((_currentPage + 1) * _rowsPerPage < _docs.length)
                              ? () =>
                                    setState(
                                      () => _currentPage++,
                                    ) // Go to next cached page
                              : (_hasMore
                                    ? _fetchNextPage
                                    : null), // Fetch from DB
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
}
