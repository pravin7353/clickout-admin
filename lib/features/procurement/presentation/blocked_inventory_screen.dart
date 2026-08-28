import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '/core/theme/app_theme.dart'; // 🚀 Added Theme Support

class BlockedInventoryScreen extends ConsumerWidget {
  const BlockedInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final adminData = ref.watch(adminRoleProvider).value;
    final tenantId = adminData?['tenantId'];
    final role = (adminData?['role'] ?? '').toString().toUpperCase();

    if (role == 'MANAGER') {
      return Scaffold(
        backgroundColor: c.scaffoldBg,
        body: Center(
          child: Text(
            "Access Denied. HQ Report Only.",
            style: TextStyle(
              color: c.danger,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Shrinkage & Blocked Audit 🛑",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Cross-Branch Expiry and Damage Tracking.",
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(24), // 🚀 Premium 24px
                  border: Border.all(
                    color: c.textSecondary.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? c.danger.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ledger')
                      .where('tenantId', isEqualTo: tenantId)
                      .where('reason', isEqualTo: 'EXPIRED_BATCH_BLOCKED')
                      .orderBy('createdAt', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: c.danger),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No shrinkage reported. Good job!",
                          style: TextStyle(
                            color: c.success,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    int totalLoss = 0;
                    for (var doc in snapshot.data!.docs) {
                      totalLoss += (doc['quantityRemoved'] as int?) ?? 0;
                    }

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.danger.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: c.danger.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "TOTAL UNITS LOST (ALL STORES)",
                                style: TextStyle(
                                  color: c.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                "$totalLoss Units",
                                style: TextStyle(
                                  color: c.danger,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  c.cardBg,
                                ),
                                headingTextStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                                columns: const [
                                  DataColumn(label: Text("DATE / TIME")),
                                  DataColumn(label: Text("PRODUCT ID")),
                                  DataColumn(label: Text("PRODUCT NAME")),
                                  DataColumn(label: Text("UNITS BLOCKED")),
                                  DataColumn(
                                    label: Text("AUTHORIZED BY (AUDIT)"),
                                  ),
                                ],
                                rows: snapshot.data!.docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final date = data['createdAt'] != null
                                      ? DateFormat('dd MMM, hh:mm a').format(
                                          (data['createdAt'] as Timestamp)
                                              .toDate(),
                                        )
                                      : 'N/A';
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          date,
                                          style: TextStyle(
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['productId'] ?? 'N/A',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: c.success,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['productName'] ?? 'N/A',
                                          style: TextStyle(
                                            color: c.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          "- ${data['quantityRemoved'] ?? 0}",
                                          style: TextStyle(
                                            color: c.danger,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['blockedBy'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: c.textSecondary,
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
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
