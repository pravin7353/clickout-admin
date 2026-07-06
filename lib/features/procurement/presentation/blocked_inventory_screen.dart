import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class BlockedInventoryScreen extends ConsumerWidget {
  const BlockedInventoryScreen({super.key});

  // 🎨 STRICT DARK THEME CONSTANTS
  static const Color accentGreen = Color(0xFF00C853);
  static const Color accentRed = Color(0xFFFE8181);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgDark = context.colors.scaffoldBg;
    final cardDark = context.colors.cardBg;
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;

    final adminData = ref.watch(adminRoleProvider).value;
    final tenantId = adminData?['tenantId'];
    final role = (adminData?['role'] ?? '').toString().toUpperCase();

    if (role == 'MANAGER') {
      return Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: Text(
            "Access Denied. HQ Report Only.",
            style: TextStyle(
              color: accentRed,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
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
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Cross-Branch Expiry and Damage Tracking.",
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: textSecondary.withOpacity(0.1)),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ledger')
                      .where('tenantId', isEqualTo: tenantId)
                      .where('reason', isEqualTo: 'EXPIRED_BATCH_BLOCKED')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: accentRed),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No shrinkage reported. Good job!",
                          style: TextStyle(
                            color: accentGreen,
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
                            color: accentRed.withOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: accentRed.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "TOTAL UNITS LOST (ALL STORES)",
                                style: TextStyle(
                                  color: accentRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                "$totalLoss Units",
                                style: const TextStyle(
                                  color: accentRed,
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
                                  context.colors.cardBg,
                                ),
                                headingTextStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
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
                                            color: textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['productId'] ?? 'N/A',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: accentGreen,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['productName'] ?? 'N/A',
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          "- ${data['quantityRemoved'] ?? 0}",
                                          style: const TextStyle(
                                            color: accentRed,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          data['blockedBy'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: textSecondary,
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
