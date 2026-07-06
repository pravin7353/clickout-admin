import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/org_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class EditRoleDialog extends ConsumerStatefulWidget {
  final CustomRole role;
  const EditRoleDialog({super.key, required this.role});

  @override
  ConsumerState<EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends ConsumerState<EditRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _roleNameCtrl;
  late TextEditingController _tagPrefixCtrl;
  late TextEditingController _levelCtrl;
  String? _selectedReportsTo;

  @override
  void initState() {
    super.initState();
    _roleNameCtrl = TextEditingController(text: widget.role.roleName);
    _tagPrefixCtrl = TextEditingController(text: widget.role.tagPrefix);
    _levelCtrl = TextEditingController(text: widget.role.level.toString());
    _selectedReportsTo = widget.role.reportsTo;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(orgStructureProvider.notifier)
          .updateCustomRole(
            roleId: widget.role.id,
            roleName: _roleNameCtrl.text.trim(),
            reportsToId: _selectedReportsTo,
            level: int.parse(_levelCtrl.text.trim()),
            tagPrefix: _tagPrefixCtrl.text.replaceAll(' ', '_').toUpperCase(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Role Updated Successfully!"),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _premiumInputStyle(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: context.colors.textSecondary),
      labelStyle: TextStyle(color: context.colors.textSecondary, fontSize: 14),
      filled: true,
      fillColor: context.colors.scaffoldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.success, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(orgStructureProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B3674).withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 PREMIUM HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3674).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF2B3674),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Edit Designation",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B3674),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Update role details and hierarchy logic.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 💡 INFO BANNER
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Modifying a role updates it for all employees assigned to this designation.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextFormField(
                        controller: _roleNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _premiumInputStyle(
                          "Role Name *",
                          Icons.work_outline,
                        ),
                        validator: (v) => v!.isEmpty ? "Required field" : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _tagPrefixCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration:
                            _premiumInputStyle(
                              "Security Tag Prefix *",
                              Icons.security_rounded,
                            ).copyWith(
                              helperText:
                                  "Used internally to grant database access.",
                            ),
                        validator: (v) => v!.isEmpty ? "Required field" : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _levelCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _premiumInputStyle(
                                "Rank Level",
                                Icons.format_list_numbered,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: orgState.when(
                              data: (roles) {
                                final availableRoles = roles
                                    .where((r) => r.id != widget.role.id)
                                    .toList(); // Prevent reporting to self
                                return DropdownButtonFormField<String>(
                                  initialValue: _selectedReportsTo,
                                  decoration: _premiumInputStyle(
                                    "Reports To",
                                    Icons.arrow_upward_rounded,
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        "No One (Highest Authority)",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ),
                                    ...availableRoles.map(
                                      (r) => DropdownMenuItem(
                                        value: r.id,
                                        child: Text(
                                          "${r.roleName} (Level ${r.level})",
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _selectedReportsTo = val),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (_, __) =>
                                  const Text("Error loading roles"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B3674),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "UPDATE ROLE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
