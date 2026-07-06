import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/tenant_dashboard_provider.dart';
import '../../auth/auth_provider.dart';
import 'create_store_dialog.dart';
import 'edit_tenant_profile_dialog.dart';
import 'edit_store_profile_dialog.dart';
import '../../../core/store/providers/store_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

final growthConfigProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, tenantId) async {
      final snap = await FirebaseFirestore.instance
          .collection('growth_configs')
          .where('tenantId', isEqualTo: tenantId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty ? snap.docs.first.data() : null;
    });

class TenantDashboardScreen extends ConsumerWidget {
  final String tenantId;

  const TenantDashboardScreen({super.key, required this.tenantId});

  void _showStoreActionDialog({
    required BuildContext context,
    required String title,
    required String actionKeyword,
    required String storeName,
    required Color actionColor,
    required VoidCallback onConfirm,
  }) {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = context.colors.cardBg;
    final inputBg = context.colors.scaffoldBg;
    final textCol = context.colors.textPrimary;
    final textMuted = context.colors.textSecondary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          title,
          style: TextStyle(color: actionColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Type $actionKeyword to confirm this action for $storeName.",
              style: TextStyle(color: textCol),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ctrl,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                hintText: actionKeyword,
                hintStyle: TextStyle(color: textMuted.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL", style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (ctrl.text.trim() == actionKeyword) {
                Navigator.pop(ctx);
                onConfirm();
              }
            },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(tenantProfileProvider(tenantId));
    final storesState = ref.watch(tenantStoresProvider(tenantId));
    final staffCountState = ref.watch(tenantStaffCountProvider(tenantId));
    final activeTodayState = ref.watch(tenantActiveTodayProvider(tenantId));
    final pendingAlertsState = ref.watch(tenantPendingAlertsProvider(tenantId));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgDark = context.colors.scaffoldBg;
    final cardDark = context.colors.cardBg;
    final textPrimary = context.colors.textPrimary;
    final textSecondary = context.colors.textSecondary;
    final accentGreen = context.colors.success;
    final borderColor = context.colors.border;

    final adminData = ref.watch(adminRoleProvider).value;
    final role = (adminData?['role'] ?? '').toString().toUpperCase();
    final isSuperAdmin = role == 'SUPER_ADMIN';

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    final rawTenantId = profileState.value?['tenantId'] ?? tenantId;
    final displayId = rawTenantId.length > 12
        ? '${rawTenantId.substring(0, 12)}...'
        : rawTenantId;
    final companyName = profileState.value?['companyName'] ?? "Loading...";

    if (!profileState.isLoading && profileState.value == null) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: Colors.redAccent,
                size: 60,
              ),
              const SizedBox(height: 24),
              const Text(
                "Data Integrity Failure: Tenant missing.",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout),
                label: const Text(
                  "FORCE LOGOUT",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20.0 : 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final tenantData = profileState.value ?? {};
                final location =
                    tenantData['location'] as Map<String, dynamic>? ?? {};
                final kyc = tenantData['kyc'] as Map<String, dynamic>? ?? {};

                bool isProfileIncomplete =
                    (location['address']?.toString().isEmpty ?? true) ||
                    (kyc['pan']?.toString().isEmpty ?? true);
                final storesList = storesState.value ?? [];
                final activeStoresCount = storesList
                    .where((s) => s['isDeleted'] != true)
                    .length;
                bool isNoStores = activeStoresCount == 0;

                final configState = ref.watch(growthConfigProvider(tenantId));
                bool hasNoConfig =
                    configState.value == null && !configState.isLoading;

                if (isProfileIncomplete) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) =>
                            EditTenantProfileDialog(tenantId: tenantId),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "ACTION REQUIRED: Your Company Profile is incomplete. Click here to setup your business details.",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else if (isNoStores) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => CreateStoreDialog(
                          tenantId: tenantId,
                          companyName: tenantData['companyName'] ?? 'Unknown',
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "PROFILE COMPLETE: Next, click here to add your first Store/Branch.",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blueAccent,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else if (hasNoConfig) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.pending_actions,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "PENDING CONFIG: Store Managers need to setup their Growth AI Profiles from their respective dashboards.",
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            Builder(
              builder: (context) {
                final configState = ref.watch(growthConfigProvider(tenantId));
                if (configState.value != null && !configState.isLoading) {
                  final catName =
                      configState.value!['businessType'] ?? "Unknown";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.rocket_launch,
                            color: accentGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Growth Engine Active",
                                style: TextStyle(
                                  color: accentGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Category: $catName • Custom AI Logic Applied",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            foregroundColor: bgDark,
                          ),
                          onPressed: () => context.go('/growth'),
                          child: const Text(
                            "View Radar",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Icon(
                                Icons.business_rounded,
                                color: accentGreen,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        companyName,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          (profileState
                                                      .value?['subscriptionPlan'] ??
                                                  'trial')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "ID: $displayId",
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => EditTenantProfileDialog(
                                    tenantId: tenantId,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.edit_note,
                                  color: textPrimary,
                                  size: 18,
                                ),
                                label: const Flexible(
                                  child: Text(
                                    "Company Profile",
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: borderColor),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            if (!isSuperAdmin) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openStoreDialog(
                                    context,
                                    tenantId,
                                    companyName,
                                  ),
                                  icon: Icon(
                                    Icons.add_business,
                                    color: bgDark,
                                    size: 18,
                                  ),
                                  label: Flexible(
                                    child: Text(
                                      "Add Store",
                                      style: TextStyle(
                                        color: bgDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentGreen,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            color: accentGreen,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      companyName,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.amber.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      "PRO PLAN",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tenant ID: $rawTenantId",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                EditTenantProfileDialog(tenantId: tenantId),
                          ),
                          icon: Icon(Icons.edit_note, color: textPrimary),
                          label: Text(
                            "Company Profile",
                            style: TextStyle(color: textPrimary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (!isSuperAdmin) ...[
                          const SizedBox(width: 15),
                          ElevatedButton.icon(
                            onPressed: () => _openStoreDialog(
                              context,
                              tenantId,
                              companyName,
                            ),
                            icon: Icon(Icons.add_business, color: bgDark),
                            label: Text(
                              "Add Store",
                              style: TextStyle(
                                color: bgDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 30),

            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final isMob = w < 600;
                final isTab = w >= 600 && w < 1024;
                final itemWidth = (isMob || isTab)
                    ? (w - 15) / 2
                    : (w - 45) / 4;

                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        context: context,
                        title: "Total Stores",
                        value: storesState.value?.length.toString() ?? "0",
                        icon: Icons.storefront,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        context: context,
                        title: "Total Staff",
                        value: staffCountState.value?.toString() ?? "0",
                        icon: Icons.people_alt_outlined,
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        context: context,
                        title: "Active Today",
                        value: activeTodayState.value?.toString() ?? "0",
                        icon: Icons.local_activity_outlined,
                        color: accentGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        context: context,
                        title: "Pending Alerts",
                        value: pendingAlertsState.value?.toString() ?? "0",
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Store Locations",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Icon(Icons.more_horiz, color: textSecondary),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),

                  storesState.when(
                    loading: () => Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: CircularProgressIndicator(color: accentGreen),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Error loading stores: $err",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (stores) {
                      final activeStores = stores
                          .where((s) => s['isDeleted'] != true)
                          .toList();
                      if (activeStores.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 60,
                                  color: textSecondary.withOpacity(0.3),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  "No stores yet.",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Click 'Add Store' to begin mapping your branches.",
                                  style: TextStyle(
                                    color: textSecondary.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: width > 1000 ? 1000 : width,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFF1A221A),
                            ),
                            dataRowMaxHeight: 80,
                            dataRowMinHeight: 70,
                            columns: [
                              DataColumn(
                                label: Text(
                                  "Store Name",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Branch Code",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "City",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Status",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "Store Actions",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            rows: activeStores.map((store) {
                              final isActive =
                                  store['status'] == 'ACTIVE' &&
                                  store['isActive'] == true;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      store['storeName'] ?? 'Unnamed Store',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      store['branchCode'] ?? 'N/A',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      store['location']?['city'] ?? 'N/A',
                                      style: TextStyle(color: textPrimary),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? accentGreen.withOpacity(0.1)
                                            : Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isActive
                                              ? accentGreen.withOpacity(0.3)
                                              : Colors.redAccent.withOpacity(
                                                  0.3,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        isActive
                                            ? "ACTIVE"
                                            : (store['status'] ?? "INACTIVE"),
                                        style: TextStyle(
                                          color: isActive
                                              ? accentGreen
                                              : Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildResponsiveStoreActions(
                                      context: context,
                                      width: width,
                                      isSuperAdmin: isSuperAdmin,
                                      store: store,
                                      ref: ref,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStoreActions({
    required BuildContext context,
    required double width,
    required bool isSuperAdmin,
    required Map<String, dynamic> store,
    required WidgetRef ref,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardDark = isDark ? const Color(0xFF111811) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF111111);
    final textSecondary = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF6B7280);
    final accentGreen = Theme.of(context).primaryColor;

    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width <= 1024;
    final String storeId = store['id'];
    final bool isActive = store['status'] == 'ACTIVE';

    // 🚀 FIX: Ab yahan 'ref' accessible hoga aur hum state set karenge
    void enterStore() {
      ref
          .read(activeStoreProvider.notifier)
          .setStore(
            tenantId: store['tenantId'] ?? '',
            branchCode: store['branchCode'] ?? '',
            storeName: store['storeName'] ?? 'Store',
            managerEmail: store['managerEmail'] ?? '',
            managerEmpId: store['managerEmpId'] ?? '',
            managerName: store['managerName'] ?? '',
            managerPhone: store['managerPhone'] ?? '',
          );
      context.go('/dashboard');
    }

    void promptSuspend() {
      final keyword = isActive ? 'SUSPEND' : 'REACTIVATE';
      final actionColor = isActive ? Colors.amber : Colors.green;
      _showStoreActionDialog(
        context: context,
        title: isActive ? "Suspend Store?" : "Reactivate Store?",
        actionKeyword: keyword,
        storeName: store['storeName'] ?? 'Store',
        actionColor: actionColor,
        onConfirm: () async {
          final newStatus = isActive ? 'SUSPENDED' : 'ACTIVE';
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .update({'status': newStatus, 'isActive': !isActive});
        },
      );
    }

    Future<void> _deleteStoreCascade(String storeId) async {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 🚀 1. PURE CASCADE DELETE: Hard delete records across all operational collections
      final collectionsToCascade = [
        'staff',
        'products',
        'carts',
        'idt_deposits',
        'logs',
        'audit_logs',
        'notifications',
        'invoices',
        'analytics',
        'customer_sessions',
        'orders',
        'store_metrics',
      ];

      for (String collectionName in collectionsToCascade) {
        final querySnap = await db
            .collection(collectionName)
            .where('storeId', isEqualTo: storeId)
            .get();
        for (var doc in querySnap.docs) {
          batch.delete(doc.reference); // 🔥 PERMANENT WIPE (NO FLAGS)
        }
      }

      // 🚀 2. PURE CASCADE DELETE: Delete the store document LAST
      final storeRef = db.collection('stores').doc(storeId);
      batch.delete(storeRef); // 🔥 WIPE STORE FROM FIRESTORE

      await batch.commit();
    }

    void promptDelete() {
      _showStoreActionDialog(
        context: context,
        title: "Delete Store?",
        actionKeyword: "DELETE",
        storeName: store['storeName'] ?? 'Store',
        actionColor: Colors.redAccent,
        onConfirm: () async {
          await _deleteStoreCascade(storeId);
        },
      );
    }

    if (isMobile) {
      return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: textSecondary),
        color: cardDark,
        onSelected: (val) {
          if (val == 'enter') enterStore();
          if (val == 'suspend') promptSuspend();
          if (val == 'delete') promptDelete();
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'enter',
            child: Row(
              children: [
                Icon(Icons.login, color: accentGreen, size: 18),
                const SizedBox(width: 8),
                Text('Enter Store', style: TextStyle(color: textPrimary)),
              ],
            ),
          ),
          if (!isSuperAdmin)
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Store',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ],
              ),
            ),
          if (!isSuperAdmin)
            PopupMenuItem(
              value: 'suspend',
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Suspend Store' : 'Activate Store',
                    style: TextStyle(color: textPrimary),
                  ),
                ],
              ),
            ),
          if (!isSuperAdmin)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Delete Store',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final List<Widget> actions = [
      Tooltip(
        message: "Enter Store",
        child: IconButton(
          icon: Icon(Icons.login, color: Colors.white, size: 20),
          onPressed: enterStore,
          splashRadius: 20,
        ),
      ),
      if (!isSuperAdmin)
        Tooltip(
          message: "Edit Store",
          child: IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.blueAccent,
              size: 20,
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => EditStoreProfileDialog(
                storeId: storeId,
                branchCode: store['branchCode'],
              ),
            ),
            splashRadius: 20,
          ),
        ),
      if (!isSuperAdmin)
        Tooltip(
          message: isActive ? "Suspend Store" : "Reactivate Store",
          child: IconButton(
            icon: Icon(
              isActive ? Icons.pause_circle : Icons.play_circle,
              color: Colors.amber,
              size: 20,
            ),
            onPressed: promptSuspend,
            splashRadius: 20,
          ),
        ),
      if (!isSuperAdmin)
        Tooltip(
          message: "Delete Store",
          child: IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: promptDelete,
            splashRadius: 20,
          ),
        ),
    ];

    if (isTablet) {
      return Wrap(spacing: 4, runSpacing: 4, children: actions);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }

  void _openStoreDialog(
    BuildContext context,
    String tenantId,
    String companyName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CreateStoreDialog(tenantId: tenantId, companyName: companyName),
    );
  }

  Widget _buildKPICard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardDark = isDark ? const Color(0xFF111811) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF111111);
    final textSecondary = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF6B7280);
    final borderColor = isDark
        ? Theme.of(context).primaryColor.withOpacity(0.15)
        : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AssignManagerDialog extends StatefulWidget {
  final String tenantId;
  final String storeId;
  final String branchCode;

  const AssignManagerDialog({
    super.key,
    required this.tenantId,
    required this.storeId,
    required this.branchCode,
  });

  @override
  State<AssignManagerDialog> createState() => _AssignManagerDialogState();
}

class _AssignManagerDialogState extends State<AssignManagerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF111811) : Colors.white;
    final inputBg = isDark ? const Color(0xFF080B08) : const Color(0xFFF3F4F6);
    final textCol = isDark ? const Color(0xFFF0F0F0) : const Color(0xFF111111);
    final textMuted = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF6B7280);
    final brandColor = Theme.of(context).primaryColor;

    void _submit() async {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _isLoading = true);

      try {
        final db = FirebaseFirestore.instance;
        final batch = db.batch();
        final staffRef = db.collection('staff').doc();

        batch.set(staffRef, {
          'docId': staffRef.id,
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'role': 'MANAGER',
          'tenantId': widget.tenantId,
          'storeId': widget.storeId,
          'branchCode': widget.branchCode,
          'isActive': true,
          'isDeleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        batch.update(db.collection('stores').doc(widget.storeId), {
          'managerName': _nameCtrl.text.trim(),
          'managerPhone': _phoneCtrl.text.trim(),
          'managerId': staffRef.id,
        });

        await batch.commit();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Manager Assigned Successfully!"),
              backgroundColor: brandColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    return AlertDialog(
      backgroundColor: dialogBg,
      title: Text(
        "Assign Store Manager",
        style: TextStyle(color: textCol, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                labelText: "Manager Name",
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _phoneCtrl,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                labelText: "Phone Number",
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) => v!.length != 10 ? "10 digits required" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _emailCtrl,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                labelText: "Email ID (For Login)",
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) => v!.contains('@') ? null : "Invalid email",
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("CANCEL", style: TextStyle(color: textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: isDark ? const Color(0xFF080B08) : Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: isDark ? const Color(0xFF080B08) : Colors.white,
                  ),
                )
              : const Text("ASSIGN"),
        ),
      ],
    );
  }
}
