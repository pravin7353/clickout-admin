import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // 🚀 Neon Theme
import '../providers/org_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class AddRoleDialog extends ConsumerStatefulWidget {
  const AddRoleDialog({super.key});

  @override
  ConsumerState<AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends ConsumerState<AddRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _roleNameCtrl = TextEditingController();
  final _tagPrefixCtrl = TextEditingController();
  final _levelCtrl = TextEditingController(text: '2'); // Default
  String? _selectedReportsTo;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(orgStructureProvider.notifier)
          .addCustomRole(
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
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 10),
                Text(
                  "Role '${_roleNameCtrl.text}' Created Successfully!",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00FF88), // 🚀 Neon Green
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 Error: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎨 DYNAMIC THEME INPUT STYLE
  InputDecoration _premiumInputStyle(
    BuildContext context,
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: context.colors.textSecondary.withValues(alpha: 0.5),
      ),
      prefixIcon: Icon(icon, color: context.colors.success.withValues(alpha: 0.7)),
      labelStyle: TextStyle(color: context.colors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: context.colors.scaffoldBg, // 🚀 Connected to Theme
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.success, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.danger, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(orgStructureProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: theme.cardColor, // 🚀 Dark Card BG
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_tree_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Define Organization Role",
                          style: GoogleFonts.syne(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Create a new designation rank.",
                          style: GoogleFonts.dmSans(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
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

            // 📝 FORM BODY
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 💡 INFO BANNER
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hub_outlined,
                              color: theme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Enterprise Hierarchy: Define roles and their reporting hierarchy. Higher levels hold broader system access.",
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextFormField(
                        controller: _roleNameCtrl,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        textCapitalization: TextCapitalization.words,
                        decoration: _premiumInputStyle(
                          context,
                          "Role Name *",
                          Icons.work_outline,
                          hint: "e.g., Regional Manager, Store Head",
                        ),
                        validator: (v) => v!.isEmpty ? "Required field" : null,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _tagPrefixCtrl,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration:
                            _premiumInputStyle(
                              context,
                              "Security Tag Prefix *",
                              Icons.security_rounded,
                              hint: "e.g., REGION, STORE",
                            ).copyWith(
                              helperText:
                                  "Used internally to grant database access.",
                              helperStyle: const TextStyle(color: Colors.grey),
                            ),
                        validator: (v) => v!.isEmpty ? "Required field" : null,
                      ),
                      const SizedBox(height: 20),

                      isMobile
                          ? Column(
                              // 📱 MOBILE VIEW: Upar-Neeche
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _levelCtrl,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration:
                                      _premiumInputStyle(
                                        context,
                                        "Rank Level",
                                        Icons.format_list_numbered,
                                      ).copyWith(
                                        helperText: "1 is Top Head",
                                        helperStyle: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                  validator: (v) =>
                                      v!.isEmpty ? "Required" : null,
                                ),
                                const SizedBox(height: 20),
                                orgState.when(
                                  data: (roles) {
                                    final availableRoles =
                                        roles; // In edit_role, use: roles.where((r) => r.id != widget.role.id).toList();
                                    return DropdownButtonFormField<String>(
                                      initialValue: _selectedReportsTo,
                                      decoration: _premiumInputStyle(
                                        context,
                                        "Reports To",
                                        Icons.arrow_upward_rounded,
                                      ),
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                      ),
                                      dropdownColor: theme.cardColor,
                                      isExpanded:
                                          true, // 👈 Fixes Dropdown Text Overflow
                                      borderRadius: BorderRadius.circular(12),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                            "No One (Highest Authority)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        ...availableRoles.map(
                                          (r) => DropdownMenuItem(
                                            value: r.id,
                                            child: Text(
                                              "${r.roleName} (Level ${r.level})",
                                              style: TextStyle(
                                                color: theme
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) => setState(
                                        () => _selectedReportsTo = val,
                                      ),
                                    );
                                  },
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, __) => const Text(
                                    "Failed to load roles",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              // 💻 DESKTOP VIEW: Aaju-Baaju
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _levelCtrl,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration:
                                        _premiumInputStyle(
                                          context,
                                          "Rank Level",
                                          Icons.format_list_numbered,
                                        ).copyWith(
                                          helperText: "1 is Top Head",
                                          helperStyle: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                    validator: (v) =>
                                        v!.isEmpty ? "Required" : null,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: orgState.when(
                                    data: (roles) {
                                      final availableRoles =
                                          roles; // In edit_role, use: roles.where((r) => r.id != widget.role.id).toList();
                                      return DropdownButtonFormField<String>(
                                        initialValue: _selectedReportsTo,
                                        decoration: _premiumInputStyle(
                                          context,
                                          "Reports To",
                                          Icons.arrow_upward_rounded,
                                        ),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                        dropdownColor: theme.cardColor,
                                        isExpanded:
                                            true, // 👈 Fixes Dropdown Text Overflow
                                        borderRadius: BorderRadius.circular(12),
                                        items: [
                                          DropdownMenuItem(
                                            value: null,
                                            child: Text(
                                              "No One (Highest Authority)",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ),
                                          ...availableRoles.map(
                                            (r) => DropdownMenuItem(
                                              value: r.id,
                                              child: Text(
                                                "${r.roleName} (Level ${r.level})",
                                                style: TextStyle(
                                                  color: theme
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) => setState(
                                          () => _selectedReportsTo = val,
                                        ),
                                      );
                                    },
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => const Text(
                                      "Failed to load roles",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 30),

                      // 🚀 SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "CREATE ROLE",
                                  style: GoogleFonts.dmSans(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
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
