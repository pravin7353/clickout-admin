import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 FIX: IMPORT ADDED

import 'widgets/onboard_staff_dialog.dart';
import 'services/employee_service.dart';
import 'providers/manager_provider.dart';
import '../../core/providers/access_control_provider.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

class ManagerScreen extends ConsumerStatefulWidget {
  const ManagerScreen({super.key});

  @override
  ConsumerState<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends ConsumerState<ManagerScreen> {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // 🎨 DYNAMIC THEME INPUT STYLE
  InputDecoration _premiumInputStyle(
    BuildContext context,
    String label, {
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.textTheme.labelLarge?.color,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1A221A) : Colors.grey.shade50,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: theme.iconTheme.color?.withOpacity(0.5))
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? theme.dividerColor : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  void _showEditStaffDialog(Map<String, dynamic> staffData) {
    final formKey = GlobalKey<FormState>();

    String selectedRole = staffData['role'] ?? 'CASHIER';
    String selectedBranch =
        staffData['branchCode'] ?? 'ALL'; // 🚀 TEXT CTRL KI JAGAH VARIABLE
    final phoneCtrl = TextEditingController(text: staffData['phone'] ?? '');

    final String empName = staffData['name'] ?? 'Unknown Staff';
    final String empId = staffData['empId'] ?? 'N/A';

    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: theme.cardColor,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A221A)
                            : Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.manage_accounts,
                            color: theme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Edit Personnel",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              Text(
                                "$empName ($empId)",
                                style: TextStyle(
                                  color: theme.textTheme.labelLarge?.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: theme.dividerColor),
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Changing security role will immediately alter app permissions.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.orange.shade200
                                            : Colors.orange.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 🚀 STATIC ROLES LIST
                            DropdownButtonFormField<String>(
                              initialValue:
                                  [
                                    'MANAGER',
                                    'CASHIER',
                                    'GUARD',
                                    'ALL',
                                  ].contains(selectedRole.toUpperCase())
                                  ? selectedRole.toUpperCase()
                                  : 'CASHIER',
                              decoration: _premiumInputStyle(
                                context,
                                "Security Role (Designation)",
                                prefixIcon: Icons.shield_outlined,
                              ),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              dropdownColor: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              items: ['MANAGER', 'CASHIER', 'GUARD']
                                  .map(
                                    (role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => selectedRole = val!),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: phoneCtrl,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              decoration: _premiumInputStyle(
                                context,
                                "Phone Number",
                                prefixIcon: Icons.phone_outlined,
                              ).copyWith(prefixText: "+91 "),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (v) => v!.length != 10
                                  ? "Strictly 10 digits required"
                                  : null,
                            ),
                            const SizedBox(height: 20),

                            // 🚀 DYNAMIC BRANCH SELECTION (StreamBuilder)
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('stores')
                                  .where(
                                    'tenantId',
                                    isEqualTo: staffData['tenantId'],
                                  )
                                  .where('isDeleted', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                List<DropdownMenuItem<String>> branchItems = [
                                  DropdownMenuItem(
                                    value: "ALL",
                                    child: Text(
                                      "ALL BRANCHES (HQ)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ];

                                for (var doc in snapshot.data!.docs) {
                                  final storeData =
                                      doc.data() as Map<String, dynamic>;
                                  final bCode = storeData['branchCode'] ?? '';
                                  final sName =
                                      storeData['storeName'] ?? 'Store';
                                  if (bCode.isNotEmpty) {
                                    branchItems.add(
                                      DropdownMenuItem(
                                        value: bCode,
                                        child: Text(
                                          "$bCode - $sName",
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }

                                // 🛡️ Legacy branch fallback
                                bool branchExists = branchItems.any(
                                  (item) => item.value == selectedBranch,
                                );
                                if (!branchExists &&
                                    selectedBranch.isNotEmpty) {
                                  branchItems.add(
                                    DropdownMenuItem(
                                      value: selectedBranch,
                                      child: Text(
                                        "$selectedBranch (Legacy)",
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return DropdownButtonFormField<String>(
                                  initialValue: selectedBranch.isEmpty
                                      ? "ALL"
                                      : selectedBranch,
                                  dropdownColor: theme.cardColor,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  decoration: _premiumInputStyle(
                                    context,
                                    "Branch Assignment Code",
                                    prefixIcon:
                                        Icons.store_mall_directory_outlined,
                                  ),
                                  items: branchItems,
                                  onChanged: (val) =>
                                      setState(() => selectedBranch = val!),
                                  validator: (v) => v == null
                                      ? "Please select a branch"
                                      : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() => isLoading = true);
                                    try {
                                      // 🚀 FETCH CURRENT ADMIN DETAILS FOR AUDIT
                                      final currentAdmin = ref
                                          .read(adminRoleProvider)
                                          .value;
                                      final editorName =
                                          currentAdmin?['name'] ??
                                          'Unknown Admin';
                                      final editorEmail =
                                          currentAdmin?['email'] ??
                                          'Unknown Email';

                                      await EmployeeService.updateEmployee(
                                        uid: staffData['docId'],
                                        collectionName:
                                            staffData['collectionName'] ??
                                            'staff',
                                        role: selectedRole,
                                        phone: phoneCtrl.text.trim(),
                                        branchCode: selectedBranch,
                                        tenantId: staffData['tenantId'],
                                        editedBy:
                                            editorName, // 🚀 NEW: Passed to service
                                        editedByEmail:
                                            editorEmail, // 🚀 NEW: Passed to service
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ref
                                            .read(managerProvider.notifier)
                                            .fetchInitial();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Staff Updated & Access Synced!",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => isLoading = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Update Changes",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoleBadge(String role, bool isActive) {
    if (!isActive) return _styledChip("LOCKED", Colors.red);
    switch (role) {
      case 'MANAGER':
        return _styledChip("MANAGER", Colors.purple);
      case 'GUARD':
        return _styledChip("GUARD", Colors.orange.shade800);
      case 'CASHIER':
        return _styledChip("CASHIER", Colors.blueAccent);
      default:
        return _styledChip(role, Colors.grey);
    }
  }

  Widget _styledChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showCsvDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BulkImportDialog(
        onComplete: () => ref.read(managerProvider.notifier).fetchInitial(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final managerState = ref.watch(managerProvider);
    final managerNotifier = ref.read(managerProvider.notifier);

    // 🚀 ROLE AND HAKI CHECK (Strict Trimmed Match)
    final adminData = ref.watch(adminRoleProvider).value;
    final rawRole = (adminData?['role'] ?? '').toString().toUpperCase().trim();
    final isManager = rawRole == 'MANAGER';
    final canEdit = ref.watch(canEditProvider);

    final showActions = isManager || canEdit;

    // Theme adaptions
    final theme = Theme.of(context);
    final tableBg = theme.cardColor;
    final textP = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 15,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Command Roster 👥",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textP,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Total Active Enterprise Staff: ${managerState.totalStaffCount}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (showActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(
                        Icons.file_upload_outlined,
                        color: theme.primaryColor,
                      ),
                      label: Text(
                        "Import CSV",
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        side: BorderSide(color: theme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showCsvDialog,
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Add Personnel",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final success = await showDialog(
                          context: context,
                          builder: (ctx) => const OnboardStaffDialog(),
                        );
                        if (success == true) {
                          ref.read(managerProvider.notifier).fetchInitial();
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 32),

          // 🎛️ FILTER BAR
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Filter by Category: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                DropdownButton<String>(
                  value: managerState.currentFilters.role,
                  underline: const SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: theme.primaryColor,
                    fontSize: 12,
                  ),
                  dropdownColor: theme.cardColor,
                  items: ['ALL', 'CASHIER', 'GUARD', 'MANAGER']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => managerNotifier.updateFilter(role: val),
                ),
              ],
            ),
          ),

          // 📜 PAGINATED DATA TABLE
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: tableBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: theme.dividerColor),
              ),
              child: managerState.indexErrorMsg.isNotEmpty
                  ? Center(
                      child: Text(
                        managerState.indexErrorMsg,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : (managerState.isLoading && managerState.records.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : managerState.records.isEmpty
                  ? const Center(
                      child: Text(
                        "No personnel found. The roster is empty.",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  thickness: 8,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth > 1050
                                            ? constraints.maxWidth
                                            : 1050,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: DataTable(
                                          headingRowHeight: 56,
                                          dataRowMaxHeight: 65,
                                          dataRowMinHeight: 65,
                                          headingRowColor:
                                              WidgetStateProperty.all(
                                                theme.brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF1A221A)
                                                    : Colors.grey.shade50,
                                              ),
                                          headingTextStyle: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: textP,
                                            fontSize: 12,
                                            letterSpacing: 1.0,
                                          ),
                                          dividerThickness: 0.5,
                                          columns: [
                                            if (!isManager)
                                              const DataColumn(
                                                label: Text("TENANT ID"),
                                              ), // 🚀 MANAGER KE LIYE STRICTLY HIDE
                                            const DataColumn(
                                              label: Text("EMP ID"),
                                            ),
                                            const DataColumn(
                                              label: Text("PERSONNEL NAME"),
                                            ),
                                            const DataColumn(
                                              label: Text("ASSIGNED ROLE"),
                                            ),
                                            const DataColumn(
                                              label: Text("BRANCH"),
                                            ),
                                            const DataColumn(
                                              label: Text("CONTACT"),
                                            ),
                                            const DataColumn(
                                              label: Text("SECURITY"),
                                            ),
                                            const DataColumn(
                                              label: Text("ACTIONS"),
                                            ),
                                          ],
                                          rows: managerState.records.asMap().entries.map((
                                            entry,
                                          ) {
                                            int idx = entry.key;
                                            Map<String, dynamic> data =
                                                entry.value;
                                            final bool isActive =
                                                data['isActive'] ?? true;

                                            return DataRow(
                                              color:
                                                  WidgetStateProperty.resolveWith<
                                                    Color?
                                                  >((Set<WidgetState> states) {
                                                    if (states.contains(
                                                      WidgetState.hovered,
                                                    )) {
                                                      return Colors.blue
                                                          .withOpacity(0.04);
                                                    }
                                                    if (idx % 2 == 0) {
                                                      return Colors.grey
                                                          .withOpacity(0.02);
                                                    }
                                                    return tableBg;
                                                  }),
                                              cells: [
                                                if (!isManager) // 🚀 MANAGER KE LIYE STRICTLY HIDE
                                                  DataCell(
                                                    Text(
                                                      data['tenantId'] ?? 'N/A',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                DataCell(
                                                  Text(
                                                    data['empId'] ?? 'N/A',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                      color: textP,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    data['name'] ?? 'N/A',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                      color: textP,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  _buildRoleBadge(
                                                    data['role'] ?? '',
                                                    isActive,
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    data['branchCode'] ?? 'N/A',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    data['phone'] ?? 'N/A',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: isActive
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        isActive
                                                            ? "Active"
                                                            : "Locked",
                                                        style: TextStyle(
                                                          color: isActive
                                                              ? Colors.green
                                                              : Colors.red,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(
                                                  // 🛡️ HAKI UPGRADE: Manager ab doosre MANAGER ko bhi touch nahi kar sakta!
                                                  (showActions &&
                                                          !(isManager &&
                                                              [
                                                                'SUPER_ADMIN',
                                                                'TENANT_ADMIN',
                                                                'OWNER',
                                                                'MANAGER',
                                                              ].contains(
                                                                (data['role'] ??
                                                                        '')
                                                                    .toString()
                                                                    .toUpperCase(),
                                                              )))
                                                      ? PopupMenuButton<String>(
                                                          icon: const Icon(
                                                            Icons.more_horiz,
                                                            color: Colors.grey,
                                                          ),
                                                          color:
                                                              theme.cardColor,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          onSelected: (value) async {
                                                            if (value ==
                                                                'edit') {
                                                              _showEditStaffDialog(
                                                                data,
                                                              );
                                                            } else if (value ==
                                                                'toggle') {
                                                              await EmployeeService.toggleEmployeeStatus(
                                                                data['docId'],
                                                                isActive,
                                                                data['collectionName'],
                                                              );
                                                              managerNotifier
                                                                  .fetchInitial();
                                                            } else if (value ==
                                                                'delete') {
                                                              await EmployeeService.softDeleteEmployee(
                                                                data['docId'],
                                                                data['collectionName'],
                                                              );
                                                              managerNotifier
                                                                  .fetchInitial();
                                                            }
                                                          },
                                                          itemBuilder: (context) => [
                                                            PopupMenuItem(
                                                              value: 'edit',
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .edit_outlined,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .blueAccent,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Text(
                                                                    "Edit Profile",
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .textTheme
                                                                          .bodyLarge
                                                                          ?.color,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'toggle',
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    isActive
                                                                        ? Icons
                                                                              .lock_outline
                                                                        : Icons
                                                                              .lock_open_outlined,
                                                                    size: 20,
                                                                    color:
                                                                        isActive
                                                                        ? Colors
                                                                              .orange
                                                                        : Colors
                                                                              .green,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Text(
                                                                    isActive
                                                                        ? "Revoke Access"
                                                                        : "Restore Access",
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .textTheme
                                                                          .bodyLarge
                                                                          ?.color,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const PopupMenuDivider(),
                                                            const PopupMenuItem(
                                                              value: 'delete',
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .delete_outline,
                                                                    size: 20,
                                                                    color: Colors
                                                                        .redAccent,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Text(
                                                                    "Remove Staff",
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .redAccent,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : const Tooltip(
                                                          message:
                                                              'Access Restricted',
                                                          child: Icon(
                                                            Icons.lock_outline,
                                                            color: Colors.grey,
                                                            size: 20,
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
                                );
                              },
                            ),
                          ),
                        ),
                        if (managerState.hasMore)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              border: Border(
                                top: BorderSide(color: theme.dividerColor),
                              ),
                            ),
                            child: Center(
                              child: managerState.isLoading
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton.icon(
                                      icon: Icon(
                                        Icons.download_rounded,
                                        color: theme.primaryColor,
                                      ),
                                      label: Text(
                                        "Load More Staff",
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                      onPressed: () =>
                                          managerNotifier.fetchMore(),
                                    ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// BulkImportDialog code can remain exactly as before, just ensure text colors use Theme if needed.
class BulkImportDialog extends ConsumerStatefulWidget {
  // 🚀 FIX: Added Consumer
  final VoidCallback onComplete;
  const BulkImportDialog({super.key, required this.onComplete});
  @override
  ConsumerState<BulkImportDialog> createState() => _BulkImportDialogState(); // 🚀 FIX: Added ConsumerState
}

class _BulkImportDialogState extends ConsumerState<BulkImportDialog> {
  // 🚀 FIX: Added ConsumerState
  final TextEditingController _csvController = TextEditingController();
  bool _isProcessing = false;
  int _totalRows = 0, _currentRow = 0, _successCount = 0, _failCount = 0;
  final List<String> _errorLogs = [];
  Future<void> _processCsv() async {
    final text = _csvController.text.trim();
    if (text.isEmpty) return;
    List<String> lines = text.split('\n');
    if (lines.length < 2) {
      setState(() => _errorLogs.add("Error: Minimum 1 data row required."));
      return;
    }
    setState(() {
      _isProcessing = true;
      _totalRows = lines.length - 1;
      _currentRow = 0;
      _successCount = 0;
      _failCount = 0;
      _errorLogs.clear();
    });
    for (int i = 1; i < lines.length; i++) {
      if (!mounted) break;
      setState(() => _currentRow = i);
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      List<String> columns = line.split(',');
      if (columns.length < 6) {
        _failCount++;
        _errorLogs.add(
          "Row $i: Missing columns. Expected 6, got ${columns.length}",
        );
        continue;
      }
      // 🚀 SAAS INJECTION: Loop ke bahar ek baar data fetch kar lo
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String creatorName = adminData?['name'] ?? 'Super Admin';
      final String creatorEmail = adminData?['email'] ?? 'Unknown Email';

      try {
        await EmployeeService.createEmployee(
          empId: columns[0].trim(),
          name: columns[1].trim(),
          email: columns[2].trim(),
          phone: columns[3].trim(),
          role: columns[4].trim(),
          branchCode: columns[5].trim(),
          tagPrefix: columns[4]
              .trim(), // 🚀 Role name ko hi tagPrefix bana diya
          tenantId: tenantId,
          addedBy: creatorName,
          addedByEmail: creatorEmail,
        );
        _successCount++;
      } catch (e) {
        _failCount++;
        _errorLogs.add("Row $i (${columns[0]}): ${e.toString()}");
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.cardColor,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, color: theme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  "Bulk Onboarding Engine",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Format: empId, name, email, phone, role, branchCode",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (!_isProcessing && _totalRows == 0) ...[
              TextField(
                controller: _csvController,
                maxLines: 10,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF1A221A)
                      : Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                    ),
                    onPressed: _processCsv,
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text(
                      "Start Batch Process",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                "Processing: $_currentRow / $_totalRows",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _totalRows > 0 ? (_currentRow / _totalRows) : 0,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard("Successful", _successCount, Colors.green),
                  _buildStatCard("Failed", _failCount, Colors.red),
                ],
              ),
              if (_errorLogs.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  height: 150,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: ListView.builder(
                    itemCount: _errorLogs.length,
                    itemBuilder: (ctx, i) => Text(
                      "⚠️ ${_errorLogs[i]}",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ),
              if (!_isProcessing)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onComplete();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
