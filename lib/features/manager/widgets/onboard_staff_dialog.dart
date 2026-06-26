import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 FIX: IMPORT ADDED

import '../services/employee_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

class OnboardStaffDialog extends ConsumerStatefulWidget {
  const OnboardStaffDialog({super.key});

  @override
  ConsumerState<OnboardStaffDialog> createState() => _OnboardStaffDialogState();
}

class _OnboardStaffDialogState extends ConsumerState<OnboardStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedRole;
  String? _selectedBranch; // 🚀 NAYA: Dynamic Branch Dropdown variable
  final _empIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isLoading = false;

  // 🎨 STRICT DARK THEME CONSTANTS
  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF1A221A);

  void _submitForm(String defaultBranchCode) async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠ Kindly select the role for the employee"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adminData = ref.read(adminRoleProvider).value;
      final tenantId = adminData?['tenantId'];
      final creatorName = adminData?['name'] ?? 'Super Admin';
      final creatorEmail = adminData?['email'] ?? 'Unknown Email';

      await EmployeeService.createEmployee(
        empId: _empIdCtrl.text.trim(),
        role: _selectedRole!,
        tagPrefix: _selectedRole!,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
        branchCode: _selectedBranch ?? defaultBranchCode,
        tenantId: tenantId,
        addedBy: creatorName,
        addedByEmail: creatorEmail,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Staff account created! Welcome Email sent."),
            backgroundColor: accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _darkInputStyle(
    String label, {
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: 13),
      filled: true,
      fillColor: inputBg,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: textSecondary, size: 18)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: accentGreen, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final adminData = ref.watch(adminRoleProvider).value;
    final String autoFetchedBranch =
        adminData?['branchCode']?.toString().toUpperCase() ?? 'HQ';
    final role = (adminData?['role'] ?? '').toString().toUpperCase();
    final isTenantAdmin = role == 'TENANT_ADMIN' || role == 'SUPER_ADMIN';
    final isManager = role == 'MANAGER';

    // 🚀 STATIC ROLES LIST
    final List<String> availableRoles = ['MANAGER', 'CASHIER', 'GUARD'];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentGreen.withOpacity(0.2), width: 1),
      ),
      backgroundColor: bgDark,
      insetPadding: EdgeInsets.all(isMobile ? 15 : 20),
      alignment: Alignment.center,
      child: Container(
        width: isMobile ? double.infinity : 550,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    color: accentGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Onboard Personnel",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: textSecondary.withOpacity(0.1),
            ),

            // --- FORM CONTENT ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🚀 DYNAMIC BRANCH SELECTION OR STATIC WALL
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('stores')
                            .where(
                              'tenantId',
                              isEqualTo: adminData?['tenantId'],
                            )
                            .where('isDeleted', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          // 🛡️ Agar Manager hai, toh purana non-editable Wall chip dikhao
                          if (!isTenantAdmin) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: accentGreen.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: accentGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Deploying to Branch",
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          autoFetchedBranch,
                                          style: const TextStyle(
                                            color: accentGreen,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // 🔒 Manager = apni branch pe locked
                          if (isManager)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentGreen.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: accentGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Branch: $autoFetchedBranch (Locked)",
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );

                          // 🏢 Agar Tenant Admin hai, toh unke saare stores ka Dropdown dikhao
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: accentGreen,
                              ),
                            );
                          }

                          List<DropdownMenuItem<String>> branchItems = [
                            const DropdownMenuItem(
                              value: "ALL",
                              child: Text(
                                "ALL BRANCHES (HQ)",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: accentGreen,
                                ),
                              ),
                            ),
                          ];

                          for (var doc in snapshot.data!.docs) {
                            final storeData =
                                doc.data() as Map<String, dynamic>;
                            final bCode = storeData['branchCode'] ?? '';
                            final sName = storeData['storeName'] ?? 'Store';
                            if (bCode.isNotEmpty) {
                              branchItems.add(
                                DropdownMenuItem(
                                  value: bCode,
                                  child: Text(
                                    "$bCode - $sName",
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBranch,
                              dropdownColor: cardDark,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: accentGreen,
                              ),
                              decoration: _darkInputStyle(
                                "Assign to Branch *",
                                prefixIcon: Icons.storefront,
                              ),
                              items: branchItems,
                              onChanged: (val) =>
                                  setState(() => _selectedBranch = val),
                              validator: (v) =>
                                  v == null ? "Please select a branch" : null,
                            ),
                          );
                        },
                      ),

                      // 🚀 STATIC DROPDOWN (Replaced Org Engine)
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        dropdownColor: cardDark,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: accentGreen,
                        ),
                        decoration: _darkInputStyle(
                          "System Designation *",
                          prefixIcon: Icons.shield_outlined,
                        ),
                        hint: const Text(
                          "Select Role ▼",
                          style: TextStyle(color: textSecondary),
                        ),
                        items: availableRoles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedRole = val;
                        }),
                        validator: (v) => v == null ? "Required" : null,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _empIdCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: _darkInputStyle(
                          "Employee ID *",
                          hint: "e.g. EMP-001",
                          prefixIcon: Icons.badge_outlined,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9-]'),
                          ),
                        ],
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? "Employee ID is required"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _darkInputStyle(
                          "Full Name *",
                          hint: "e.g. John Doe",
                          prefixIcon: Icons.person_outline,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return "Minimum 3 characters required";
                          }
                          if (v.trim().split(' ').length < 2) {
                            return "Please enter full name (First & Last)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _phoneCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration:
                            _darkInputStyle(
                              "Phone (Login Credential) *",
                              prefixIcon: Icons.phone_android_outlined,
                            ).copyWith(
                              prefixText: "+91  ",
                              prefixStyle: const TextStyle(color: textPrimary),
                            ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) => (v == null || v.length != 10)
                            ? "Strictly 10 digit mobile number required"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _emailCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _darkInputStyle(
                          _selectedRole == 'MANAGER'
                              ? "Official Email Address *"
                              : "Official Email Address (Optional)",
                          prefixIcon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (_selectedRole == 'MANAGER' &&
                              (v == null || v.trim().isEmpty)) {
                            return "Email is mandatory for Manager role";
                          }
                          if (v != null &&
                              v.isNotEmpty &&
                              !RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(v)) {
                            return "Invalid email format";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: textSecondary.withOpacity(0.1),
            ),

            // --- FOOTER BUTTONS ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: bgDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _submitForm(autoFetchedBranch),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: bgDark,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.rocket_launch, size: 18),
                    label: Text(
                      _isLoading ? "Processing..." : "Create Access",
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
