import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

class DistributorListScreen extends ConsumerStatefulWidget {
  const DistributorListScreen({super.key});

  @override
  ConsumerState<DistributorListScreen> createState() =>
      _DistributorListScreenState();
}

class _DistributorListScreenState extends ConsumerState<DistributorListScreen> {
  String _searchQuery = '';

  // 🎨 STRICT DARK THEME CONSTANTS
  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color accentOrange = Color(0xFFD4580A);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);

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
                      child: const Icon(
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
                    child: const Icon(Icons.hub, color: accentGreen, size: 28),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: "Search by Supplier Name, Code, or Category...",
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: accentOrange),
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
                    borderSide: const BorderSide(color: accentOrange, width: 2),
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
                      return const Center(
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

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: textSecondary.withOpacity(0.1),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(bgDark),
                            dataRowMaxHeight: 70,
                            dividerThickness: 0.5,
                            horizontalMargin: 24,
                            columns: const [
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
                                  "Demand Metric",
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            rows: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
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
                                            style: const TextStyle(
                                              color: accentOrange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          data['name'] ?? 'Unknown',
                                          style: const TextStyle(
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
                                          color: textSecondary.withOpacity(0.3),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        data['supplierID'] ?? 'N/A',
                                        style: const TextStyle(
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
                                              color: textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              data['email'] ?? 'No Email',
                                              style: const TextStyle(
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
                                              color: textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              data['phone'] ?? 'No Phone',
                                              style: const TextStyle(
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
                                      style: const TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    // 🚀 Placeholder for Advanced Metrics (Can be wired to PO count later)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.trending_up,
                                          color: accentGreen,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Active",
                                          style: TextStyle(
                                            color: accentGreen.withOpacity(0.8),
                                            fontWeight: FontWeight.bold,
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
