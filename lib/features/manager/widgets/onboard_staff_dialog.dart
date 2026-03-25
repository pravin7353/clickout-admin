import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 SAAS INJECTION

import '../services/employee_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION
import '../../tenant_admin/providers/org_provider.dart'; // 🚀 NEW: DYNAMIC ROLES ENGINE

class OnboardStaffDialog extends ConsumerStatefulWidget {
  const OnboardStaffDialog({super.key});

  @override
  ConsumerState<OnboardStaffDialog> createState() => _OnboardStaffDialogState();
}

class _OnboardStaffDialogState extends ConsumerState<OnboardStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  CustomRole? _selectedRole; // 🚀 Now holds the full dynamic role object
  final _empIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  bool _isLoading = false;

  void _submitForm() async {
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
      // 🚀 SAAS INJECTION: Fetch Tenant ID safely
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

      await EmployeeService.createEmployee(
        empId: _empIdCtrl.text.trim(),
        role: _selectedRole!.roleName, // 👈 Passing the dynamic Role Name
        tagPrefix: _selectedRole!.tagPrefix, // 👈 Passing the Security Tag
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
        branchCode: _branchCtrl.text,
        tenantId: tenantId,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Staff account created! Welcome Email sent."),
            backgroundColor: Colors.green,
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

  InputDecoration _enterpriseInputStyle(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF2B3674), width: 2),
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
    final orgState = ref.watch(orgStructureProvider); // 📡 Fetching Live Tree

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.all(isMobile ? 0 : 20),
      alignment: isMobile ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: isMobile ? double.infinity : 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isMobile
              ? const BorderRadius.vertical(top: Radius.circular(20))
              : BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    color: Color(0xFF2B3674),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Onboard New Staff",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3674),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🚀 THE NEW DYNAMIC DROPDOWN
                      orgState.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text(
                          "Error: $err",
                          style: const TextStyle(color: Colors.red),
                        ),
                        data: (roles) {
                          if (roles.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber),
                              ),
                              child: const Text(
                                "⚠️ No Custom Roles found. Please create roles in 'Org Structure' first.",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          // Sort by hierarchy level
                          final sortedRoles = [...roles];
                          sortedRoles.sort(
                            (a, b) => a.level.compareTo(b.level),
                          );

                          return DropdownButtonFormField<CustomRole>(
                            initialValue: _selectedRole,
                            decoration: _enterpriseInputStyle(
                              "System Designation *",
                            ),
                            dropdownColor: Colors.white,
                            hint: const Text("Select Custom Role ▼"),
                            items: sortedRoles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      "${r.roleName} (Level ${r.level})",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedRole = val),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _empIdCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _enterpriseInputStyle(
                          "Employee ID *",
                          hint: "e.g. EMP-001",
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
                        decoration: _enterpriseInputStyle(
                          "Full Name *",
                          hint: "e.g. John Doe",
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
                        decoration: _enterpriseInputStyle(
                          "Phone Number (Login Credential) *",
                        ).copyWith(prefixText: "+91  "),
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
                        decoration: _enterpriseInputStyle(
                          "Official Email Address (Optional)",
                        ),
                        validator: (v) {
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
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _branchCtrl,
                        decoration: _enterpriseInputStyle(
                          "Branch Assignment Code *",
                          hint: "e.g. MUM01",
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? "Branch code is required"
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

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
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B3674),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Create Access",
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
  }
}
