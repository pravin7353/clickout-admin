import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 FIX: IMPORT ADDED

import '../services/employee_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/error_state.dart';

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
  Future<QuerySnapshot>? _storesFuture; // 🛠️ FIX: Cache for stores

  // 🎨 STRICT DARK THEME CONSTANTS
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  static const Color accentGreen = Color(0xFF00C853);
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.black26,
        fontSize: 13,
      ),
      filled: true,
      fillColor: cardDark, // 🛠️ FIX: Premium thick background style
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey, size: 18)
          : null,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentGreen),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final adminData = ref.watch(adminRoleProvider).value;

    // 🛠️ FIX: Initialize Future once to prevent dropdown flickering on setState
    _storesFuture ??= FirebaseFirestore.instance
        .collection('stores')
        .where('tenantId', isEqualTo: adminData?['tenantId'])
        .where('isDeleted', isEqualTo: false)
        .limit(200)
        .get();
    final String autoFetchedBranch =
        adminData?['branchCode']?.toString().toUpperCase() ?? 'HQ';
    final role = (adminData?['role'] ?? '').toString().toUpperCase();
    final isTenantAdmin = role == 'TENANT_ADMIN' || role == 'SUPER_ADMIN';
    final isManager = role == 'MANAGER';

    // 🚀 STATIC ROLES LIST
    final List<String> availableRoles = ['MANAGER', 'CASHIER', 'GUARD'];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(isMobile ? 15 : 20),
      alignment: Alignment.center,
      child: Container(
        width: isMobile ? double.infinity : 550,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(24), // 🛠️ FIX: Premium curves
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? accentGreen.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🌟 PREMIUM HEADER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: accentGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Onboard Personnel",
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Grant access and assign branch roles",
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
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
                      FutureBuilder<QuerySnapshot>(
                        future: _storesFuture, // 🛠️ FIX: Used cached future
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
                                  color: accentGreen.withValues(alpha: 0.3),
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
                                        Text(
                                          // 🚀 Removed const
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
                                  color: accentGreen.withValues(alpha: 0.3),
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
                                    style: TextStyle(
                                      // 🚀 Removed const
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );

                          // 🏢 Agar Tenant Admin hai, toh unke saare stores ka Dropdown dikhao
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ErrorState(
                                message: "Failed to load branches.",
                                onRetry: () => setState(() {
                                  _storesFuture = FirebaseFirestore.instance
                                      .collection('stores')
                                      .where(
                                        'tenantId',
                                        isEqualTo: adminData?['tenantId'],
                                      )
                                      .where('isDeleted', isEqualTo: false)
                                      .limit(200)
                                      .get();
                                }),
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: SkeletonBox(
                                height: 56,
                              ), // 🚀 MATCHES INPUT HEIGHT
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
                                    style: TextStyle(
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
                              // 🛠️ FIX: Removed ValueKey to fix the locking bug!
                              value: _selectedBranch,
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
                        // 🛠️ FIX: Removed ValueKey to fix the locking bug!
                        value: _selectedRole,
                        dropdownColor: cardDark,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: accentGreen,
                        ),
                        decoration: _darkInputStyle(
                          "System Designation *",
                          prefixIcon: Icons.shield_outlined,
                        ),
                        hint: Text(
                          // 🚀 Removed const
                          "Select Role ▼",
                          style: TextStyle(color: textSecondary),
                        ),
                        items: availableRoles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    // 🚀 Removed const
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
                        style: TextStyle(
                          // 🚀 Removed const
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
                        style: TextStyle(
                          color: textPrimary,
                        ), // 🚀 Removed const
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
                        style: TextStyle(
                          color: textPrimary,
                        ), // 🚀 Removed const
                        decoration:
                            _darkInputStyle(
                              "Phone (Login Credential) *",
                              prefixIcon: Icons.phone_android_outlined,
                            ).copyWith(
                              prefixText: "+91  ",
                              prefixStyle: TextStyle(
                                color: textPrimary,
                              ), // 🚀 Removed const
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
                        style: TextStyle(
                          color: textPrimary,
                        ), // 🚀 Removed const
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
            // 🚀 PREMIUM FOOTER ACTIONS
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor:
                          Colors.black, // 🛠️ Premium dark text on green
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _submitForm(autoFetchedBranch),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.rocket_launch, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Create Access",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
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
