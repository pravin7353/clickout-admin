import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/tenant_dashboard_provider.dart';
import '../../auth/auth_provider.dart';
import 'create_store_dialog.dart';
import 'edit_tenant_profile_dialog.dart';

// --- THEME CONSTANTS (STRICT) ---
const Color bgDark = Color(0xFF080B08);
const Color cardDark = Color(0xFF111811);
const Color accentGreen = Color(0xFF00C853);
const Color textPrimary = Color(0xFFF0F0F0);
const Color textSecondary = Color(0xFF888888);
final Color borderColor = accentGreen.withOpacity(0.15);

class TenantDashboardScreen extends ConsumerWidget {
  final String tenantId;

  const TenantDashboardScreen({super.key, required this.tenantId});

  // 🛡️ SECURITY ACTION DIALOG FOR TENANT ADMINS
  void _showStoreActionDialog({
    required BuildContext context,
    required String title,
    required String actionKeyword,
    required String storeName,
    required Color actionColor,
    required VoidCallback onConfirm,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
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
              style: const TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgDark,
                hintText: actionKeyword,
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
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
            child: const Text("CANCEL", style: TextStyle(color: textSecondary)),
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

    // 🔐 Role Check
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

    return Scaffold(
      backgroundColor: bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20.0 : 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // SECTION A: COMPANY HEADER
            // ==========================================
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
                              child: const Icon(
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
                                        style: const TextStyle(
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
                                        child: const Text(
                                          "PRO PLAN",
                                          style: TextStyle(
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
                                    style: const TextStyle(
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
                                // 🚀 REROUTED TO POPUP DIALOG
                                onPressed: () => showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => EditTenantProfileDialog(
                                    tenantId: tenantId,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.edit_note,
                                  color: textPrimary,
                                  size: 18,
                                ),
                                label: const Flexible(
                                  child: Text(
                                    "Edit Profile",
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12,
                                    ),
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
                                  icon: const Icon(
                                    Icons.add_business,
                                    color: bgDark,
                                    size: 18,
                                  ),
                                  label: const Flexible(
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
                          child: const Icon(
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
                                      style: const TextStyle(
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
                                style: const TextStyle(
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
                          // 🚀 DESKTOP POPUP FIX
                          onPressed: () => showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) =>
                                EditTenantProfileDialog(tenantId: tenantId),
                          ),
                          icon: const Icon(Icons.edit_note, color: textPrimary),
                          label: const Text(
                            "Edit Profile",
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
                            icon: const Icon(Icons.add_business, color: bgDark),
                            label: const Text(
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

            // ==========================================
            // SECTION B: KPI CARDS
            // ==========================================
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
                        title: "Total Stores",
                        value: storesState.value?.length.toString() ?? "0",
                        icon: Icons.storefront,
                        color: Colors.blueAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        title: "Total Staff",
                        value: staffCountState.value?.toString() ?? "0",
                        icon: Icons.people_alt_outlined,
                        color: Colors.indigoAccent,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        title: "Active Today",
                        value: "0",
                        icon: Icons.local_activity_outlined,
                        color: accentGreen,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildKPICard(
                        title: "Pending Alerts",
                        value: "0",
                        icon: Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),

            // ==========================================
            // SECTION C: STORE LIST TABLE
            // ==========================================
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
                        const Text(
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
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40.0),
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
                                const Text(
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
                            columns: const [
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

                              // 🚀 FUTURE UPDATE: HIDDEN MANAGER COLUMNS
                              // DataColumn(label: Text("Manager", style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary))),
                              // DataColumn(label: Text("Assign Manager", style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary))),
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
                              // 🚀 FUTURE UPDATE: UNCOMMENT WHEN MANAGER SYSTEM IS READY
                              /*
                              final hasManager =
                                  store['managerName'] != null &&
                                  store['managerName'].toString().isNotEmpty;
                              */

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      store['storeName'] ?? 'Unnamed Store',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      store['branchCode'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: textSecondary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      store['location']?['city'] ?? 'N/A',
                                      style: const TextStyle(
                                        color: textPrimary,
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

                                  /* FUTURE UPDATE: UNCOMMENT WHEN MANAGER SYSTEM IS READY// 1. 🛡️ MANAGER COLUMN (Only Tenant Admin can remove)
                                  DataCell(
                                    hasManager
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                store['managerName'],
                                                style: const TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (!isSuperAdmin) // Tenant Admin only
                                                InkWell(
                                                  onTap: () async {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('stores')
                                                        .doc(store['id'])
                                                        .update({
                                                          'managerName':
                                                              FieldValue.delete(),
                                                          'managerPhone':
                                                              FieldValue.delete(),
                                                          'managerId':
                                                              FieldValue.delete(),
                                                        });
                                                  },
                                                  child: const Text(
                                                    "Remove Manager",
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 11,
                                                      decoration: TextDecoration
                                                          .underline,
                                                      decorationColor:
                                                          Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : const Text(
                                            "Unassigned",
                                            style: TextStyle(
                                              color: Colors.amber,
                                            ),
                                          ),
                                  ),

                                  // 2. 🛡️ ASSIGN MANAGER COLUMN (Only Tenant Admin can assign)
                                  DataCell(
                                    !isSuperAdmin
                                        ? TextButton.icon(
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  AssignManagerDialog(
                                                    tenantId: tenantId,
                                                    storeId: store['id'],
                                                    branchCode:
                                                        store['branchCode'],
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.person_add_alt_1,
                                              color: accentGreen,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              "+ Assign",
                                              style: TextStyle(
                                                color: accentGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            "View Only",
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                  ),
                                  */

                                  // 3. STORE ACTIONS COLUMN
                                  DataCell(
                                    _buildResponsiveStoreActions(
                                      context: context,
                                      width: width,
                                      isSuperAdmin: isSuperAdmin,
                                      store: store,
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

  // =========================================================
  // ⚡ RESPONSIVE ACTION COLUMN ENGINE (ICON ONLY)
  // =========================================================
  Widget _buildResponsiveStoreActions({
    required BuildContext context,
    required double width,
    required bool isSuperAdmin,
    required Map<String, dynamic> store,
  }) {
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width <= 1024;
    final String storeId = store['id'];
    final bool isActive = store['status'] == 'ACTIVE';

    // 🚀 ROUTING: Operations Dashboard
    void enterStore() => context.go('/dashboard');

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

    void promptDelete() {
      _showStoreActionDialog(
        context: context,
        title: "Delete Store?",
        actionKeyword: "DELETE",
        storeName: store['storeName'] ?? 'Store',
        actionColor: Colors.redAccent,
        onConfirm: () async {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .update({
                'isDeleted': true,
                'deletedAt': FieldValue.serverTimestamp(),
              });
        },
      );
    }

    // 📱 MOBILE: POPUP MENU
    if (isMobile) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: textSecondary),
        color: cardDark,
        onSelected: (val) {
          if (val == 'enter') enterStore();
          if (val == 'suspend') promptSuspend();
          if (val == 'delete') promptDelete();
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'enter',
            child: Row(
              children: [
                Icon(Icons.login, color: accentGreen, size: 18),
                SizedBox(width: 8),
                Text('Enter Store', style: TextStyle(color: textPrimary)),
              ],
            ),
          ),
          if (!isSuperAdmin) // 🛡️ ONLY TENANT ADMIN CAN SEE
            PopupMenuItem(
              value: 'suspend',
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.amber,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    isActive ? 'Suspend Store' : 'Activate Store',
                    style: const TextStyle(color: textPrimary),
                  ),
                ],
              ),
            ),
          if (!isSuperAdmin) // 🛡️ ONLY TENANT ADMIN CAN SEE
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Delete Store',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // 💻 TABLET / DESKTOP: ICONS WITH TOOLTIPS
    final List<Widget> actions = [
      Tooltip(
        message: "Enter Store",
        child: IconButton(
          icon: const Icon(Icons.login, color: accentGreen, size: 20),
          onPressed: enterStore,
          splashRadius: 20,
        ),
      ),
      if (!isSuperAdmin) // 🛡️ ONLY TENANT ADMIN
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
      if (!isSuperAdmin) // 🛡️ ONLY TENANT ADMIN
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
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
                  style: const TextStyle(
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
                  style: const TextStyle(
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

// =========================================================
// 🧑‍💼 ASSIGN MANAGER DIALOG
// =========================================================
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

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final staffRef = db.collection('staff').doc();

      // 1. Create Staff Doc
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

      // 2. Link to Store
      batch.update(db.collection('stores').doc(widget.storeId), {
        'managerName': _nameCtrl.text.trim(),
        'managerPhone': _phoneCtrl.text.trim(),
        'managerId': staffRef.id,
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Manager Assigned Successfully!"),
            backgroundColor: accentGreen,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardDark,
      title: const Text(
        "Assign Store Manager",
        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Manager Name",
                filled: true,
                fillColor: bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _phoneCtrl,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Phone Number",
                filled: true,
                fillColor: bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) => v!.length != 10 ? "10 digits required" : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _emailCtrl,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: "Email ID (For Login)",
                filled: true,
                fillColor: bgDark,
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
          child: const Text("CANCEL", style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentGreen,
            foregroundColor: bgDark,
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: bgDark),
                )
              : const Text("ASSIGN"),
        ),
      ],
    );
  }
}
