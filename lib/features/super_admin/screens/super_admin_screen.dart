import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

final saasTenantsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return FirebaseFirestore.instance
          .collection('tenants')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => {'docId': doc.id, ...doc.data()})
                .toList();
          });
    });

class SuperAdminScreen extends ConsumerWidget {
  const SuperAdminScreen({super.key});

  static const Color accentGreen = Color(0xFF00C853);

  Future<void> _updateTenantStatus(
    BuildContext context,
    Map<String, dynamic> t,
    bool newStatus,
  ) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin';
    final action = newStatus ? 'TENANT_REACTIVATED' : 'TENANT_SUSPENDED';

    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(t['tenantId'])
        .update({
          'isActive': newStatus,
          newStatus ? 'reactivatedAt' : 'suspendedAt':
              FieldValue.serverTimestamp(),
          newStatus ? 'reactivatedBy' : 'suspendedBy': email,
        });

    await FirebaseFirestore.instance.collection('admin_audit_logs').add({
      'action': action,
      'tenantId': t['tenantId'],
      'companyName': t['companyName'],
      'actor': email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? "Tenant Reactivated" : "Tenant Suspended"),
          backgroundColor: newStatus ? Colors.green : Colors.amber,
        ),
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    Map<String, dynamic> t,
    Color cardDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
  ) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        title: const Text(
          "Permanently Delete?",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Type DELETE to permanently remove ${t['companyName']}. This cannot be undone.",
              style: TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ctrl,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: "DELETE",
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.5),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (ctrl.text.trim() == "DELETE") {
                Navigator.pop(ctx);
                final email =
                    FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin';

                await FirebaseFirestore.instance
                    .collection('tenants')
                    .doc(t['tenantId'])
                    .update({
                      'isDeleted': true,
                      'deletedAt': FieldValue.serverTimestamp(),
                      'deletedBy': email,
                      'isActive': false,
                    });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Tenant Deleted permanently"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text("CONFIRM DELETE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsState = ref.watch(saasTenantsProvider);
    final isMobile =
        MediaQuery.of(context).size.width < 1100; // Increased breakpoint

    // 🎨 THEME DYNAMIC COLORS (Fixes Light Mode Bug)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgDark = theme.scaffoldBackgroundColor;
    final cardDark = theme.cardColor;
    final textPrimary =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final textSecondary = theme.textTheme.labelLarge?.color ?? Colors.grey;
    final dividerColor = theme.dividerColor;
    final inputBg = isDark ? const Color(0xFF1A221A) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgDark,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20.0 : 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚀 WRAP LAGAYA HEADER MEIN BHI TAAKI CHOTE SCREEN PE NAHI PHATE
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 20,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Global Network Overview 🌍",
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "SaaS Command Center - Monitor all active tenants & operations",
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (isMobile) const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: isDark
                          ? const Color(0xFF0A0F0A)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => context.go('/register-client'),
                    icon: const Icon(Icons.domain_add, size: 20),
                    label: const Text(
                      "ONBOARD NEW CLIENT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              tenantsState.maybeWhen(
                data: (tenants) {
                  int totalBranches = 0;
                  for (var t in tenants) {
                    totalBranches += (t['totalBranches'] as num?)?.toInt() ?? 0;
                  }

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKPICard(
                          "Total Brands Onboarded",
                          tenants.length.toString(),
                          Icons.business,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                        ),
                        const SizedBox(height: 15),
                        _buildKPICard(
                          "Total Active Branches",
                          totalBranches.toString(),
                          Icons.storefront,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                        ),
                        const SizedBox(height: 15),
                        _buildKPICard(
                          "Platform Health",
                          "100%",
                          Icons.monitor_heart,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                          isGreen: true,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          "Total Brands Onboarded",
                          tenants.length.toString(),
                          Icons.business,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildKPICard(
                          "Total Active Branches",
                          totalBranches.toString(),
                          Icons.storefront,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildKPICard(
                          "Platform Health",
                          "100%",
                          Icons.monitor_heart,
                          cardDark,
                          textPrimary,
                          textSecondary,
                          dividerColor,
                          inputBg,
                          isGreen: true,
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: accentGreen),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Text(
                "Registered Tenants Directory",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 15),

              SizedBox(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dividerColor),
                  ),
                  child: tenantsState.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: accentGreen),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        "Error: $err",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (tenants) {
                      if (tenants.isEmpty) {
                        return _buildEmptyState(
                          context,
                          textPrimary,
                          textSecondary,
                        );
                      }
                      return Column(
                        children: [
                          if (!isMobile)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: dividerColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _headerCell(
                                    "TENANT ID / COMPANY",
                                    textSecondary,
                                    flex: 3,
                                  ),
                                  _headerCell(
                                    "BUSINESS TYPE",
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _headerCell(
                                    "BRANCHES",
                                    textSecondary,
                                    flex: 1,
                                  ),
                                  _headerCell("STATUS", textSecondary, flex: 1),
                                  _headerCell("JOINED", textSecondary, flex: 1),
                                  _headerCell(
                                    "ACTIONS",
                                    textSecondary,
                                    flex: 4,
                                    align: Alignment.centerRight,
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: tenants.length,
                              separatorBuilder: (_, __) => Divider(
                                color: isMobile
                                    ? Colors.transparent
                                    : dividerColor,
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final t = tenants[index];
                                final isActive = t['isActive'] == true;
                                final createdAt = t['createdAt'] as Timestamp?;
                                final dateStr = createdAt != null
                                    ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(createdAt.toDate())
                                    : 'N/A';

                                if (isMobile) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: dividerColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t['companyName'] ?? 'Unknown',
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? accentGreen.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isActive
                                                    ? "ACTIVE"
                                                    : "SUSPENDED",
                                                style: TextStyle(
                                                  color: isActive
                                                      ? accentGreen
                                                      : Colors.redAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t['tenantId'] ?? '',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              t['businessType'] ?? 'Retail',
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              "${t['totalBranches'] ?? 0} Stores",
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: accentGreen
                                                    .withValues(alpha: 0.1),
                                                foregroundColor: accentGreen,
                                                elevation: 0,
                                              ),
                                              onPressed: () => context.go(
                                                '/tenant-dashboard/${t['tenantId']}',
                                              ),
                                              child: const Text(
                                                "PORTAL",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isActive
                                                    ? Colors.amber.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.green.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                foregroundColor: isActive
                                                    ? Colors.amber
                                                    : Colors.green,
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                if (isActive) {
                                                  _updateTenantStatus(
                                                    context,
                                                    t,
                                                    false,
                                                  );
                                                } else {
                                                  _updateTenantStatus(
                                                    context,
                                                    t,
                                                    true,
                                                  );
                                                }
                                              },
                                              child: Text(
                                                isActive
                                                    ? "SUSPEND"
                                                    : "REACTIVATE",
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors
                                                    .redAccent
                                                    .withValues(alpha: 0.1),
                                                foregroundColor:
                                                    Colors.redAccent,
                                                elevation: 0,
                                              ),
                                              onPressed: () =>
                                                  _showDeleteDialog(
                                                    context,
                                                    t,
                                                    cardDark,
                                                    textPrimary,
                                                    textSecondary,
                                                    inputBg,
                                                  ),
                                              child: const Text(
                                                "DELETE",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['companyName'] ?? 'Unknown',
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              t['tenantId'] ?? '',
                                              style: TextStyle(
                                                color: textSecondary,
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          t['businessType'] ?? 'Retail',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: inputBg,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            "${t['totalBranches'] ?? 0} Stores",
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Row(
                                          children: [
                                            Icon(
                                              isActive
                                                  ? Icons.circle
                                                  : Icons.cancel,
                                              color: isActive
                                                  ? accentGreen
                                                  : Colors.redAccent,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isActive ? "ACTIVE" : "SUSPENDED",
                                              style: TextStyle(
                                                color: isActive
                                                    ? accentGreen
                                                    : Colors.redAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),

                                      // 🚀 FIX: WRAP LAGAYA HAI ROW KI JAGAH, KABHI NAHI PHATEGA
                                      Expanded(
                                        flex: 4,
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: accentGreen
                                                    .withValues(alpha: 0.1),
                                                foregroundColor: accentGreen,
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                context.go(
                                                  '/tenant-dashboard/${t['tenantId']}',
                                                );
                                              },
                                              child: const Text(
                                                "ENTER PORTAL",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isActive
                                                    ? Colors.amber.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.green.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                foregroundColor: isActive
                                                    ? Colors.amber
                                                    : Colors.green,
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                if (isActive) {
                                                  _updateTenantStatus(
                                                    context,
                                                    t,
                                                    false,
                                                  );
                                                } else {
                                                  _updateTenantStatus(
                                                    context,
                                                    t,
                                                    true,
                                                  );
                                                }
                                              },
                                              child: Text(
                                                isActive
                                                    ? "SUSPEND"
                                                    : "REACTIVATE",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors
                                                    .redAccent
                                                    .withValues(alpha: 0.1),
                                                foregroundColor:
                                                    Colors.redAccent,
                                                elevation: 0,
                                              ),
                                              onPressed: () =>
                                                  _showDeleteDialog(
                                                    context,
                                                    t,
                                                    cardDark,
                                                    textPrimary,
                                                    textSecondary,
                                                    inputBg,
                                                  ),
                                              child: const Text(
                                                "DELETE",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color cardDark,
    Color textPrimary,
    Color textSecondary,
    Color dividerColor,
    Color inputBg, {
    bool isGreen = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGreen ? accentGreen.withValues(alpha: 0.1) : inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isGreen ? accentGreen : textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isGreen ? accentGreen : textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String title,
    Color textSecondary, {
    required int flex,
    Alignment align = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: align,
        child: Text(
          title,
          style: TextStyle(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radar,
            size: 80,
            color: textSecondary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            "No clients onboarded yet.",
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Click the button above to register your first SaaS client.",
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
