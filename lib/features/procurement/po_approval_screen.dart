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

class POApprovalScreen extends ConsumerStatefulWidget {
  const POApprovalScreen({super.key});

  @override
  ConsumerState<POApprovalScreen> createState() => _POApprovalScreenState();
}

class _POApprovalScreenState extends ConsumerState<POApprovalScreen> {
  // 🚀 DISABLED AI TAB: Default tab is now 'Pending Approvals' (Tab 1)
  int _selectedTab = 1;
  bool _isUploadingCsv = false;
  int _limit = 15; // 🚀 Universal Pagination Limit

  // 🚀 ANTI-FLICKER CACHE: Stores last valid docs to survive empty cache snapshots
  List<QueryDocumentSnapshot>? _cachedValidDocs;

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
    final isEngineRunning = ref.watch(poEngineProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;
    final adminData = ref.watch(adminRoleProvider).value;
    final realStoreId =
        adminData?['branchCode'] ?? adminData?['storeId'] ?? "HQ";

    const Color bgDark = Color(0xFF080B08);
    const Color cardDark = Color(0xFF111811);
    const Color accentGreen = Color(0xFF00C853);
    const Color accentOrange = Color(0xFFD4580A);
    const Color textPrimary = Color(0xFFF0F0F0);
    const Color textSecondary = Color(0xFF888888);

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
                          color: accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business_center,
                          color: accentOrange,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Procurement & Supply Chain",
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
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
                            color: textSecondary.withOpacity(0.2),
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
                            : const Icon(
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
                            color: textSecondary.withOpacity(0.2),
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
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2B3674),
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
                      // 🚀 DISABLED: Auto PO Engine Button Hidden completely
                      /*
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [accentGreen, Color(0xFF00963E)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: accentGreen.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isEngineRunning
                              ? null
                              : () async {
                                  try {
                                    int count = await ref
                                        .read(poEngineProvider.notifier)
                                        .generateDraftPOs();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            count > 0
                                                ? "✅ $count POs Auto-Generated!"
                                                : "👍 Stock is healthy.",
                                          ),
                                          backgroundColor: count > 0
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      );
                                      setState(() {
                                        _selectedTab = 1;
                                        _limit = 15;
                                      }); // Switch to Pending Tab
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Error: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: isEngineRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          label: Text(
                            isEngineRunning
                                ? "GENERATING..."
                                : "RUN AUTO-PO ENGINE",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      */
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
              const Divider(),
              const SizedBox(height: 20),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 🚀 DISABLED: AI Suggestions Tab Hidden completely
                    /*
                    _buildTabButton(
                      0,
                      "🤖 AI Suggestions",
                      Icons.psychology,
                      Colors.purple,
                    ),
                    const SizedBox(width: 16),
                    */
                    _buildTabButton(
                      1,
                      "Pending Approvals",
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    _buildTabButton(
                      2,
                      "PO History",
                      Icons.history,
                      Colors.green,
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
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: accentOrange),
                      ),
                    );
                  }

                  // 🧠 ANTI-FLICKER LOGIC: Ignore empty local cache if we already had data
                  if (snapshot.hasData) {
                    final isCacheEmpty =
                        snapshot.data!.docs.isEmpty &&
                        snapshot.data!.metadata.isFromCache;
                    if (!isCacheEmpty) {
                      _cachedValidDocs =
                          snapshot.data!.docs; // Update cache with real data
                    }
                  }

                  final rawDocs = _cachedValidDocs ?? snapshot.data?.docs ?? [];

                  // Agar abhi tak connect ho raha hai aur data nahi aaya, toh loading dikhao (Empty flash rokne ke liye)
                  if (rawDocs.isEmpty &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: accentOrange),
                      ),
                    );
                  }

                  // 🧠 IN-MEMORY FILTERING & SORTING (Safe from Firebase Errors)
                  List<QueryDocumentSnapshot> docs = [];

                  for (var doc in rawDocs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (_selectedTab == 1) {
                      final status = data['status'] ?? 'DRAFT';
                      // 🚀 FIX: Auto PO generates 'PENDING', Run Button generates 'DRAFT', AI generates 'PENDING_APPROVAL'
                      if ([
                        'DRAFT',
                        'PENDING',
                        'PENDING_APPROVAL',
                      ].contains(status)) {
                        docs.add(doc);
                      }
                    } else if (_selectedTab == 2) {
                      final status = data['status'] ?? '';
                      if ([
                        'APPROVED',
                        'REJECTED',
                        'DELIVERED',
                      ].contains(status)) {
                        docs.add(doc);
                      }
                    } else {
                      // Tab 0: AI Suggestions
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

                  // Pagination Logic
                  bool hasMoreData = docs.length > _limit;
                  if (docs.length > _limit) {
                    docs = docs.sublist(0, _limit);
                  }

                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: textSecondary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedTab == 0
                                ? Icons.check_circle
                                : (_selectedTab == 1
                                      ? Icons.inventory_2_outlined
                                      : Icons.history),
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedTab == 0
                                ? "AI has no suggestions today. Stock is optimized! ✨"
                                : (_selectedTab == 1
                                      ? "No Pending POs!"
                                      : "No approved orders yet."),
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

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length + (hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 🚀 LOAD MORE BUTTON
                      if (index == docs.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardDark,
                                foregroundColor: accentOrange,
                                side: BorderSide(
                                  color: accentOrange.withOpacity(0.5),
                                ),
                              ),
                              onPressed: () => setState(() => _limit += 15),
                              icon: const Icon(Icons.keyboard_arrow_down),
                              label: const Text("Load More Records"),
                            ),
                          ),
                        );
                      }

                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      // ==========================================
                      // 🤖 TAB 0: AI SUGGESTIONS UI
                      // ==========================================
                      if (_selectedTab == 0) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(
                              color: Colors.purple.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          color: cardDark,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          color: Colors.purple,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "AI Restock Alert",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 🚀 FIX: FutureBuilder with Caching for AI Suggestions
                                    FutureBuilder<String>(
                                      future: _getSupplierName(
                                        data['supplierId'],
                                      ),
                                      builder: (context, supSnap) {
                                        return Text(
                                          supSnap.data ?? 'Loading...',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                Divider(color: textSecondary.withOpacity(0.1)),
                                Text(
                                  data['productName'] ?? 'Unknown Item',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Reason: ${data['reason'] ?? 'Stock is low'}",
                                  style: const TextStyle(
                                    color: textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 15,
                                  runSpacing: 10,
                                  children: [
                                    // 🚀 FIX: Default fallback to 10 if backend sends null
                                    Text(
                                      "Suggested Qty: ${data['recommendedQty'] ?? 10} Units",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: accentOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        TextButton(
                                          onPressed: () => ref
                                              .read(poEngineProvider.notifier)
                                              .rejectAiSuggestion(
                                                data['suggestionId'] ?? doc.id,
                                              ),
                                          child: const Text(
                                            "Dismiss",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.purple,
                                          ),
                                          onPressed: () async {
                                            await ref
                                                .read(poEngineProvider.notifier)
                                                .approveAIPo(
                                                  data,
                                                  data['recommendedQty'] ?? 0,
                                                  realStoreId,
                                                );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    "✅ AI PO Approved & Email Sent!",
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.flash_on,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "APPROVE & SEND",
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
                              ],
                            ),
                          ),
                        );
                      }

                      // ==========================================
                      // 📦 TAB 1 & 2: PURCHASE ORDERS UI
                      // ==========================================
                      final items = data['items'] as List<dynamic>? ?? [];
                      DateTime date =
                          (data['createdAt'] ??
                                  data['approvedAt'] as Timestamp?)
                              ?.toDate() ??
                          DateTime.now();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: const Color(0xFF888888).withOpacity(0.1),
                          ),
                        ),
                        elevation: 0,
                        color: cardDark,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🚀 FIX: Restored the Correct PO Header with FutureBuilder for Real Supplier Names!
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.domain,
                                        color: _selectedTab == 1
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 10),
                                      FutureBuilder<String>(
                                        future: _getSupplierName(
                                          data['supplierId'],
                                        ),
                                        builder: (context, supSnap) {
                                          return Text(
                                            "Supplier: ${supSnap.data ?? 'Loading...'}",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('dd MMM, hh:mm a').format(date),
                                    style: const TextStyle(
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(
                                height: 30,
                                color: textSecondary.withOpacity(0.1),
                              ),
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "• ${item['name']}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bgDark,
                                          border: Border.all(
                                            color: accentOrange.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "Req: ${item['orderQty']} units",
                                          style: const TextStyle(
                                            color: accentOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 15,
                                runSpacing: 10,
                                children: _selectedTab == 1
                                    ? [
                                        TextButton.icon(
                                          onPressed: () => FirebaseFirestore
                                              .instance
                                              .collection('purchase_orders')
                                              .doc(doc.id)
                                              .delete(),
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          label: const Text(
                                            "Discard",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
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
                                                      .collection('suppliers')
                                                      .doc(supplierId)
                                                      .get();
                                              final supplierInfo =
                                                  supplierSnap.data() ?? {};

                                              if (context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
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
                                                    senderName: senderName,
                                                    onMarkAsRead: () async {
                                                      await ref
                                                          .read(
                                                            poEngineProvider
                                                                .notifier,
                                                          )
                                                          .approvePO(doc.id);
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
                                                  content: Text("🚨 Error: $e"),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            "APPROVE & SEND PO",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ]
                                    : [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.verified,
                                                color: Colors.green,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Approved by ${data['approvedBy'] ?? 'Admin'}",
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                              ),
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
        _limit = 15;
        _cachedValidDocs =
            null; // 🚀 FIX: Flush cache on tab switch to stop Ghost Data Leak!
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withOpacity(0.1)
              : const Color(0xFF111811),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? themeColor
                : const Color(0xFF888888).withOpacity(0.2),
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
