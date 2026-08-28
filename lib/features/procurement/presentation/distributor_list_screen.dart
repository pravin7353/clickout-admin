import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'add_distributor_dialog.dart'; // 🚀 Added Missing Import
import 'edit_distributor_dialog.dart';
import '../../coach/widgets/info_button.dart';
import '/core/theme/app_theme.dart'; // 🚀 Added Theme Support

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

  Future<void> _toggleStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('suppliers').doc(docId).update({
      'isActive': !currentStatus,
    });
  }

  Future<void> _deleteSupplier(String docId, String name, dynamic c) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: c.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Delete Supplier?",
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Are you sure you want to delete '$name'?",
              style: TextStyle(color: c.textSecondary),
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
                  backgroundColor: c.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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

    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Query query = FirebaseFirestore.instance.collection('suppliers').limit(300);

    if (role != 'SUPER_ADMIN' &&
        role != 'SUPER ADMIN' &&
        role != 'ADMIN' &&
        tenantId != null) {
      query = query.where('tenantId', isEqualTo: tenantId);
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎩 HEADER SECTION
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.cardBg,
                        border: Border.all(
                          color: c.textSecondary.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: c.textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hub, color: c.success, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Vendor Intelligence Directory",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const InfoButton(
                              title: 'Vendor Intelligence Directory',
                              en: 'Your complete supplier database — distributors, wholesalers, and service providers. Add contact details, GST, and payment terms. Linked to Purchase Orders for one-click reordering.',
                              hi: 'Aapke saare suppliers ka directory — distributors, wholesalers, service providers. Contact, GST, payment terms sab yahan save karo. PO raise karne ke liye directly linked hai.',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Track supply chains, contact info, and supplier metrics.",
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🚀 NEW: Button on Desktop
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => const AddDistributorDialog(),
                      ),
                      icon: const Icon(Icons.domain_add_outlined, size: 20),
                      label: const Text(
                        "Add Distributor",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // 🚀 NEW: Button on Mobile (Full Width for better UX)
              if (isMobile) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => const AddDistributorDialog(),
                    ),
                    icon: const Icon(Icons.domain_add_outlined, size: 20),
                    label: const Text(
                      "Add Distributor",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 🔍 SEARCH & FILTERS
              TextField(
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "Search by Supplier Name, Code, or Category...",
                  hintStyle: TextStyle(
                    color: c.textSecondary.withValues(alpha: 0.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFFF6D00),
                  ),
                  filled: true,
                  fillColor: c.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: c.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF6D00),
                      width: 2,
                    ),
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
                        child: CircularProgressIndicator(color: c.success),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "🚨 Error loading data: ${snapshot.error}",
                          style: TextStyle(color: c.danger),
                        ),
                      );
                    }

                    var docs = snapshot.data?.docs.toList() ?? [];

                    docs.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final timeA = dataA['createdAt'] as Timestamp?;
                      final timeB = dataB['createdAt'] as Timestamp?;
                      if (timeA == null || timeB == null) return 0;
                      return timeB.compareTo(timeA);
                    });

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
                            color: c.textSecondary,
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
                            color: c.cardBg,
                            borderRadius: BorderRadius.circular(
                              24,
                            ), // 🚀 Premium 24px Glass UI
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.05,
                                ),
                                blurRadius: 20,
                                spreadRadius: -5,
                              ),
                            ],
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
                                    c.scaffoldBg,
                                  ),
                                  dataRowMaxHeight: 70,
                                  dividerThickness: 0.5,
                                  horizontalMargin: 24,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        "Supplier Details",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Supplier Code",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Contact & Comm.",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Supply Category",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Status",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Actions",
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: docs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final bool isActive =
                                        data['isActive'] ?? true;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: const Color(
                                                  0xFFFF6D00,
                                                ).withValues(alpha: 0.1),
                                                child: Text(
                                                  (data['name'] ?? 'U')
                                                      .toString()[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF6D00),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                data['name'] ?? 'Unknown',
                                                style: TextStyle(
                                                  color: c.textPrimary,
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
                                              color: c.scaffoldBg,
                                              border: Border.all(
                                                color: c.textSecondary
                                                    .withValues(alpha: 0.3),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              data['supplierID'] ?? 'N/A',
                                              style: const TextStyle(
                                                color: Color(0xFFFF6D00),
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
                                                      color: c.textPrimary,
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
                                                      color: c.textSecondary,
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
                                              color: c.textPrimary,
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
                                                            ? c.success
                                                            : c.danger)
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color:
                                                      (isActive
                                                              ? c.success
                                                              : c.danger)
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
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
                                                        ? c.success
                                                        : c.danger,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    isActive
                                                        ? "ACTIVE"
                                                        : "INACTIVE",
                                                    style: TextStyle(
                                                      color: isActive
                                                          ? c.success
                                                          : c.danger,
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
                                                icon: const Icon(
                                                  Icons.edit_note,
                                                  color: Color(0xFFFF6D00),
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
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: c.danger,
                                                ),
                                                onPressed: () =>
                                                    _deleteSupplier(
                                                      doc.id,
                                                      data['name'] ?? 'Unknown',
                                                      c,
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
