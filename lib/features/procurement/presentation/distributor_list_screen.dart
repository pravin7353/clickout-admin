import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'edit_distributor_dialog.dart';

class DistributorListScreen extends ConsumerStatefulWidget {
  const DistributorListScreen({super.key});

  @override
  ConsumerState<DistributorListScreen> createState() =>
      _DistributorListScreenState();
}

class _DistributorListScreenState extends ConsumerState<DistributorListScreen> {
  String _searchQuery = '';
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // 🎨 DYNAMIC LIGHT/DARK THEME
  Color get bgDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF080B08)
      : const Color(0xFFF4F5F7);
  Color get cardDark => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF111811)
      : const Color(0xFFFFFFFF);
  Color get accentGreen => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF00C853)
      : const Color(0xFF2E7D32);
  Color get accentOrange => const Color(0xFFFF6D00);
  Color get textPrimary =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get textSecondary =>
      Theme.of(context).textTheme.labelLarge?.color ?? Colors.grey;

  Future<void> _toggleStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('suppliers').doc(docId).update({
      'isActive': !currentStatus,
    });
  }

  Future<void> _deleteSupplier(String docId, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardDark,
            title: Text(
              "Delete Supplier?",
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Are you sure you want to delete '$name'?",
              style: TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminData = ref.watch(adminRoleProvider).value;
    final tenantId = adminData?['tenantId'];
    final role = (adminData?['role'] ?? '').toString().toUpperCase();

    // 🚀 SAAS INJECTION: Tenant Data Isolation
    Query query = FirebaseFirestore.instance.collection(
      'suppliers',
    ); // 🚀 FIX: Removed orderBy here
    if (role != 'SUPER_ADMIN' &&
        role != 'SUPER ADMIN' &&
        role != 'ADMIN' &&
        tenantId != null) {
      query = query.where('tenantId', isEqualTo: tenantId);
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎩 HEADER SECTION
              Row(
                children: [
                  // 🔙 BACK BUTTON
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardDark,
                        border: Border.all(
                          color: textSecondary.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        // 🚀 REMOVED CONST
                        Icons.arrow_back,
                        color: textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 🌟 MAIN ICON
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.hub,
                      color: accentGreen,
                      size: 28,
                    ), // 🚀 REMOVED CONST
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // 🚀 REMOVED CONST
                          "Vendor Intelligence Directory",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Track supply chains, contact info, and supplier metrics.",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔍 SEARCH & FILTERS
              TextField(
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                style: TextStyle(
                  // 🚀 REMOVED CONST
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "Search by Supplier Name, Code, or Category...",
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: accentOrange,
                  ), // 🚀 REMOVED CONST
                  filled: true,
                  fillColor: cardDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: textSecondary.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accentOrange,
                      width: 2,
                    ), // 🚀 REMOVED CONST
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 📊 DATA TABLE (Responsive)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: query.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        // 🚀 REMOVED CONST
                        child: CircularProgressIndicator(color: accentGreen),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "🚨 Error loading data: ${snapshot.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    var docs = snapshot.data?.docs.toList() ?? [];

                    // 🚀 FIX: Sort Locally in Dart to bypass Firestore Index Error
                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final timeA = dataA['createdAt'] as Timestamp?;
                      final timeB = dataB['createdAt'] as Timestamp?;
                      if (timeA == null || timeB == null) return 0;
                      return timeB.compareTo(
                        timeA,
                      ); // Descending (Newest first)
                    });

                    // Client-Side Search Filter
                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final code = (data['supplierID'] ?? '')
                            .toString()
                            .toLowerCase();
                        final cat = (data['categories'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery) ||
                            code.contains(_searchQuery) ||
                            cat.contains(_searchQuery);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No distributors found.",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        double safeWidth = constraints.maxWidth;
                        if (safeWidth.isInfinite)
                          safeWidth = MediaQuery.of(context).size.width - 48;
                        final double tableWidth = safeWidth < 1000
                            ? 1000
                            : safeWidth;

                        return Container(
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: textSecondary.withOpacity(0.1),
                            ),
                          ),
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            thickness: 8,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: SizedBox(
                                width: tableWidth,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    bgDark,
                                  ),
                                  dataRowMaxHeight: 70,
                                  dividerThickness: 0.5,
                                  horizontalMargin: 24,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        "Supplier Details",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Supplier Code",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Contact & Comm.",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Supply Category",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Status",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Actions",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: docs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final bool isActive =
                                        data['isActive'] ??
                                        true; // Default True
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: accentOrange
                                                    .withOpacity(0.1),
                                                child: Text(
                                                  (data['name'] ?? 'U')
                                                      .toString()[0]
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: accentOrange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                data['name'] ?? 'Unknown',
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: bgDark,
                                              border: Border.all(
                                                color: textSecondary
                                                    .withOpacity(0.3),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              data['supplierID'] ?? 'N/A',
                                              style: TextStyle(
                                                color: accentOrange,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.email,
                                                    size: 12,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    data['email'] ?? 'No Email',
                                                    style: TextStyle(
                                                      color: textPrimary,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone,
                                                    size: 12,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    data['phone'] ?? 'No Phone',
                                                    style: TextStyle(
                                                      color: textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            data['categories'] ?? 'General',
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          InkWell(
                                            onTap: () =>
                                                _toggleStatus(doc.id, isActive),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    (isActive
                                                            ? accentGreen
                                                            : Colors.redAccent)
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color:
                                                      (isActive
                                                              ? accentGreen
                                                              : Colors
                                                                    .redAccent)
                                                          .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isActive
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    size: 14,
                                                    color: isActive
                                                        ? accentGreen
                                                        : Colors.redAccent,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    isActive
                                                        ? "ACTIVE"
                                                        : "INACTIVE",
                                                    style: TextStyle(
                                                      color: isActive
                                                          ? accentGreen
                                                          : Colors.redAccent,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit_note,
                                                  color: accentOrange,
                                                ),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (ctx) =>
                                                      EditDistributorDialog(
                                                        docId: doc.id,
                                                        supplierData: data,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                                onPressed: () =>
                                                    _deleteSupplier(
                                                      doc.id,
                                                      data['name'] ?? 'Unknown',
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
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
