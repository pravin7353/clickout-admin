import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/utils/hierarchy_filter.dart'; // 🚀 CRITICAL FOR ISOLATION
import 'providers/po_engine_service.dart';
import 'presentation/widgets/po_export_dialog.dart';
import 'presentation/widgets/expiry_dashboard.dart';
import 'presentation/add_distributor_dialog.dart';
import 'presentation/distributor_list_screen.dart';
import 'presentation/widgets/quantum_metrics_widget.dart';
import '../coach/widgets/info_button.dart';
import '../../../core/theme/app_theme.dart';

class POApprovalScreen extends ConsumerStatefulWidget {
  const POApprovalScreen({super.key});

  @override
  ConsumerState<POApprovalScreen> createState() => _POApprovalScreenState();
}

class _POApprovalScreenState extends ConsumerState<POApprovalScreen> {
  // 🚀 DISABLED AI TAB: Default tab is now 'Pending Approvals' (Tab 1)
  int _selectedTab = 1;
  bool _isUploadingCsv = false;

  // 🚀 NEW: Standard Pagination Setup
  int _poCurrentPage = 0;
  final int _poPageSize = 5;
  final ScrollController _poScrollController = ScrollController();

  // 🚀 ANTI-FLICKER CACHE: Stores last valid docs to survive empty cache snapshots
  List<QueryDocumentSnapshot>? _cachedValidDocs;

  @override
  void dispose() {
    _poScrollController.dispose();
    super.dispose();
  }

  // 🚀 CACHE ENGINE: Prevents infinite Firestore reads for Suppliers
  final Map<String, String> _supplierCache = {};

  Future<String> _getSupplierName(String? supplierId) async {
    if (supplierId == null || supplierId.isEmpty) return 'Unknown';
    if (_supplierCache.containsKey(supplierId)) {
      return _supplierCache[supplierId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierId)
          .get();
      // Asli naam lo, agar missing hai toh ID fallback karo
      final name = doc.exists
          ? (doc.data()?['name'] ?? supplierId)
          : supplierId;
      _supplierCache[supplierId] = name;
      return name;
    } catch (e) {
      return supplierId;
    }
  }

  // 🚀 THE BULLETPROOF STREAM (Exactly like Expiry Dashboard)
  Stream<QuerySnapshot> get _engineStream {
    final adminData = ref.watch(adminRoleProvider).value;
    if (adminData == null) return const Stream.empty();

    // 🔒 100% STRICT ISOLATION via HierarchyFilter
    Query baseQuery;
    if (_selectedTab == 0) {
      baseQuery = HierarchyFilter.apply(
        FirebaseFirestore.instance.collection('ai_po_suggestions'),
        adminData,
      );
    } else {
      baseQuery = HierarchyFilter.apply(
        FirebaseFirestore.instance.collection('purchase_orders'),
        adminData,
      );
    }

    // 🚀 We fetch snapshots WITHOUT orderBy to prevent Firebase Index Loading loops!
    return baseQuery.snapshots(includeMetadataChanges: true);
  }

  Future<void> _processSupplierCsvImport() async {
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
      if (lines.length <= 1) throw "🚨 CSV is empty or missing data rows!";

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;
      for (int i = 1; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;
        List<String> row = line.split(',');
        if (row.isEmpty || row.length < 2 || row[1].trim().isEmpty) continue;

        final docRef = FirebaseFirestore.instance.collection('suppliers').doc();
        batch.set(docRef, {
          'supplierID': row[0].trim(),
          'name': row[1].trim(),
          'email': row.length > 2 ? row[2].trim() : '',
          'phone': row.length > 3 ? row[3].trim() : '',
          'categories': row.length > 4 ? row[4].trim() : '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $count Distributors Imported Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
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
    // 🚀 Watch kept (without storing) so this screen still rebuilds when the
    // PO engine status changes, even though the value itself isn't read here.
    ref.watch(poEngineProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;
    final adminData = ref.watch(adminRoleProvider).value;
    final realStoreId =
        adminData?['branchCode'] ?? adminData?['storeId'] ?? "HQ";

    // 🎨 DYNAMIC LIGHT/DARK THEME
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgDark = context.colors.scaffoldBg;
    final Color cardDark = context.colors.cardBg;
    final Color accentGreen = isDark
        ? const Color(0xFF00C853)
        : const Color(0xFF2E7D32);
    final Color accentOrange = const Color(0xFFFF6D00); // 🚀 Sunset Amber
    final Color textPrimary = context.colors.textPrimary;
    final Color textSecondary = context.colors.textSecondary;
    final Color tableHeaderBg = context.colors.cardBg;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.business_center,
                          color: accentOrange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Procurement & Supply Chain",
                                style: TextStyle(
                                  fontSize: isMobile ? 22 : 28,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const InfoButton(
                                title: 'Procurement & Supply Chain',
                                en: 'Complete vendor and inventory management hub. Add distributors, run promotions on slow-moving stock, raise purchase orders, and track blocked inventory — all from one place.',
                                hi: 'Yahan se vendor manage karo, slow stock pe offer lagao, purchase order raise karo aur blocked inventory track karo. Sab ek jagah.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Smart Sourcing & Global Vendor Intelligence",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardDark,
                          foregroundColor: textPrimary,
                          elevation: 0,
                          side: BorderSide(
                            color: textSecondary.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isUploadingCsv
                            ? null
                            : _processSupplierCsvImport,
                        icon: _isUploadingCsv
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.cloud_upload_outlined,
                                size: 20,
                                color: accentOrange,
                              ),
                        label: Text(
                          _isUploadingCsv ? "Uploading..." : "Import CSV",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cardDark,
                          foregroundColor: textPrimary,
                          elevation: 0,
                          side: BorderSide(
                            color: textSecondary.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => const AddDistributorDialog(),
                        ),
                        icon: const Icon(Icons.domain_add_outlined, size: 20),
                        label: const Text(
                          "Add Distributor",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF2B3674),
                          foregroundColor: isDark
                              ? const Color(0xFF2B3674)
                              : Colors.white,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DistributorListScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.hub_outlined, size: 20),
                        label: const Text(
                          "Vendor Directory",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              QuantumMetricsWidget(storeId: realStoreId),
              const SizedBox(
                width: double.infinity,
                child: ExpiryAlertDashboard(),
              ),
              const SizedBox(height: 40),
              Divider(color: textSecondary.withValues(alpha: 0.2)),
              const SizedBox(height: 20),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(
                      1,
                      "Pending Approvals",
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    const InfoButton(
                      title: 'Pending Approvals',
                      en: 'Purchase orders created but not yet sent or confirmed by vendor. Review and approve before dispatching to distributor.',
                      hi: 'Ye wo POs hain jo banaye hain par vendor ko abhi bheje nahi. Review karo aur approve karo tabhi distributor tak jayega.',
                    ),
                    const SizedBox(width: 12),
                    _buildTabButton(
                      2,
                      "PO History",
                      Icons.history,
                      Colors.green,
                    ),
                    const SizedBox(width: 4),
                    const InfoButton(
                      title: 'PO History',
                      en: 'All previously raised purchase orders with status — sent, received, or cancelled. Use this to track vendor delivery performance.',
                      hi: 'Pehle raise kiye gaye saare purchase orders yahan dikhenge — sent, received ya cancelled. Vendor ki delivery track karne ke liye use karo.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 🚀 THE ULTIMATE STREAM BUILDER
              StreamBuilder<QuerySnapshot>(
                stream: _engineStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: accentOrange),
                      ),
                    );
                  }

                  if (snapshot.hasData) {
                    final isCacheEmpty =
                        snapshot.data!.docs.isEmpty &&
                        snapshot.data!.metadata.isFromCache;
                    if (!isCacheEmpty) _cachedValidDocs = snapshot.data!.docs;
                  }

                  final rawDocs = _cachedValidDocs ?? snapshot.data?.docs ?? [];

                  if (rawDocs.isEmpty &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: accentOrange),
                      ),
                    );
                  }

                  // 🧠 IN-MEMORY FILTERING
                  List<QueryDocumentSnapshot> docs = [];
                  for (var doc in rawDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (_selectedTab == 1) {
                      final status = data['status'] ?? 'DRAFT';
                      if ([
                        'DRAFT',
                        'PENDING',
                        'PENDING_APPROVAL',
                      ].contains(status))
                        docs.add(doc);
                    } else if (_selectedTab == 2) {
                      final status = data['status'] ?? '';
                      if ([
                        'APPROVED',
                        'REJECTED',
                        'DELIVERED',
                      ].contains(status))
                        docs.add(doc);
                    } else {
                      docs.add(doc);
                    }
                  }

                  // Safe Sort by Latest Date
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime =
                        (aData['createdAt'] ??
                                aData['approvedAt'] ??
                                aData['updatedAt'])
                            as Timestamp?;
                    final bTime =
                        (bData['createdAt'] ??
                                bData['approvedAt'] ??
                                bData['updatedAt'])
                            as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  // 🚀 NEW PAGINATION ENGINE (5 Items limit, No Load More)
                  final totalPages = (docs.length / _poPageSize).ceil();
                  if (_poCurrentPage >= totalPages && totalPages > 0) {
                    _poCurrentPage = totalPages - 1;
                  }

                  final startIndex = _poCurrentPage * _poPageSize;
                  final endIndex = (startIndex + _poPageSize > docs.length)
                      ? docs.length
                      : startIndex + _poPageSize;
                  final pageDocs = docs.isEmpty
                      ? []
                      : docs.sublist(startIndex, endIndex);

                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedTab == 1
                                ? Icons.inventory_2_outlined
                                : Icons.history,
                            size: 60,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedTab == 1
                                ? "No Pending POs!"
                                : "No approved orders yet.",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ==========================================
                  // 📦 TABLE UI (Tab 1 & 2)
                  // ==========================================
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      double safeWidth = constraints.maxWidth;
                      if (safeWidth.isInfinite)
                        safeWidth = MediaQuery.of(context).size.width - 48;
                      final double tableWidth = safeWidth < 1000
                          ? 1000
                          : safeWidth;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: textSecondary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Scrollbar(
                              controller: _poScrollController,
                              thumbVisibility: true,
                              thickness: 8,
                              child: SingleChildScrollView(
                                controller: _poScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: tableWidth,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      tableHeaderBg,
                                    ),
                                    dataRowMaxHeight:
                                        double.infinity, // Allows items to wrap
                                    dataRowMinHeight: 70,
                                    dividerThickness: 0.5,
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          "Date & Time",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Supplier Details",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Order Items & Qty",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Actions / Status",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: pageDocs.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final items =
                                          data['items'] as List<dynamic>? ?? [];
                                      DateTime date =
                                          (data['createdAt'] ??
                                                  data['approvedAt']
                                                      as Timestamp?)
                                              ?.toDate() ??
                                          DateTime.now();

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy\nhh:mm a',
                                              ).format(date),
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            FutureBuilder<String>(
                                              future: _getSupplierName(
                                                data['supplierId'],
                                              ),
                                              builder: (context, supSnap) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.domain,
                                                      color: _selectedTab == 1
                                                          ? Colors.orange
                                                          : Colors.green,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      supSnap.data ??
                                                          'Loading...',
                                                      style: TextStyle(
                                                        color: accentOrange,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: items
                                                    .map(
                                                      (item) => Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 4,
                                                            ),
                                                        child: Text(
                                                          "• ${item['name']} (Req: ${item['orderQty']} units)",
                                                          style: TextStyle(
                                                            color: textPrimary,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            _selectedTab == 1
                                                ? Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                        tooltip: "Discard PO",
                                                        onPressed: () =>
                                                            FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                  'purchase_orders',
                                                                )
                                                                .doc(doc.id)
                                                                .delete(),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              accentGreen,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 12,
                                                              ),
                                                        ),
                                                        icon: const Icon(
                                                          Icons.send,
                                                          size: 14,
                                                        ),
                                                        label: const Text(
                                                          "APPROVE & SEND",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        onPressed: () async {
                                                          try {
                                                            final supplierId =
                                                                data['supplierId'];
                                                            String senderName =
                                                                adminData?['name'] ??
                                                                'Store Manager';
                                                            final supplierSnap =
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'suppliers',
                                                                    )
                                                                    .doc(
                                                                      supplierId,
                                                                    )
                                                                    .get();
                                                            final supplierInfo =
                                                                supplierSnap
                                                                    .data() ??
                                                                {};

                                                            if (context
                                                                .mounted) {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    false,
                                                                builder: (ctx) => PoExportDialog(
                                                                  poId: doc.id,
                                                                  supplierName:
                                                                      supplierInfo['name'] ??
                                                                      'Unknown Supplier',
                                                                  supplierEmail:
                                                                      supplierInfo['email'] ??
                                                                      '',
                                                                  supplierPhone:
                                                                      supplierInfo['phone'] ??
                                                                      '',
                                                                  items: items,
                                                                  senderName:
                                                                      senderName,
                                                                  onMarkAsRead: () async {
                                                                    await ref
                                                                        .read(
                                                                          poEngineProvider
                                                                              .notifier,
                                                                        )
                                                                        .approvePO(
                                                                          doc.id,
                                                                        );
                                                                    if (mounted) {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            "✅ PO Moved to History!",
                                                                          ),
                                                                          backgroundColor:
                                                                              Colors.green,
                                                                        ),
                                                                      );
                                                                    }
                                                                  },
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "🚨 Error: $e",
                                                                ),
                                                                backgroundColor:
                                                                    Colors
                                                                        .redAccent,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  )
                                                : Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: accentGreen
                                                          .withValues(alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: accentGreen
                                                            .withValues(alpha: 0.3),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.verified,
                                                          color: accentGreen,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          "Approved by ${data['approvedBy'] ?? 'Admin'}",
                                                          style: TextStyle(
                                                            color: accentGreen,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 🚀 PAGINATION FOOTER
                          const SizedBox(height: 16),
                          if (totalPages > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: textSecondary.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Showing ${startIndex + 1} - $endIndex of ${docs.length} Entries",
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.chevron_left,
                                          color: accentOrange,
                                        ),
                                        onPressed: _poCurrentPage > 0
                                            ? () => setState(
                                                () => _poCurrentPage--,
                                              )
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentOrange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "${_poCurrentPage + 1} / $totalPages",
                                          style: TextStyle(
                                            color: accentOrange,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.chevron_right,
                                          color: accentOrange,
                                        ),
                                        onPressed:
                                            _poCurrentPage < totalPages - 1
                                            ? () => setState(
                                                () => _poCurrentPage++,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(
    int index,
    String title,
    IconData icon,
    Color activeColor,
  ) {
    bool isSelected = _selectedTab == index;
    Color themeColor = isSelected
        ? const Color(0xFFD4580A)
        : const Color(0xFF888888);
    return InkWell(
      onTap: () => setState(() {
        _selectedTab = index;
        _poCurrentPage = 0; // 🚀 FIX: Reset pagination to page 1
        _cachedValidDocs =
            null; // 🚀 FIX: Flush cache on tab switch to stop Ghost Data Leak!
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: 0.1)
              : const Color(0xFF111811),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? themeColor
                : const Color(0xFF888888).withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
