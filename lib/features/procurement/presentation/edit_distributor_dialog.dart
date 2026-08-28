import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '/core/theme/app_theme.dart'; // 🚀 Added Theme Support

class EditDistributorDialog extends ConsumerStatefulWidget {
  final String docId;
  final Map<String, dynamic> supplierData;

  const EditDistributorDialog({
    super.key,
    required this.docId,
    required this.supplierData,
  });

  @override
  ConsumerState<EditDistributorDialog> createState() =>
      _EditDistributorDialogState();
}

class _EditDistributorDialogState extends ConsumerState<EditDistributorDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _idCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _categoryCtrl;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(
      text: widget.supplierData['supplierID'] ?? '',
    );
    _nameCtrl = TextEditingController(text: widget.supplierData['name'] ?? '');
    _emailCtrl = TextEditingController(
      text: widget.supplierData['email'] ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.supplierData['phone'] ?? '',
    );
    _categoryCtrl = TextEditingController(
      text: widget.supplierData['categories'] ?? '',
    );
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _updateDistributor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final adminData = ref.read(adminRoleProvider).value;
      final adminEmail = adminData?['email'] ?? 'Unknown Admin';

      final updateData = {
        'supplierID': _idCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'categories': _categoryCtrl.text.trim(),
        'updatedBy': adminEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.docId)
          .update(updateData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Distributor Updated Successfully!"),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update: $e"),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            color: c.scaffoldBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFFFF6D00).withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🟦 HEADER SECTION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: Color(0xFFFF6D00),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Distributor Profile",
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Update supplier details, contact info, or category mappings.",
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: c.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),

              // ⬜ FORM BODY SECTION
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("COMPANY IDENTITY", c),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            _buildTextField(
                              label: "Distributor / Supplier Name",
                              controller: _nameCtrl,
                              icon: Icons.business,
                              width: 350,
                              c: c,
                              isDark: isDark,
                              validator: (v) =>
                                  v!.isEmpty ? 'Name is required' : null,
                            ),
                            _buildTextField(
                              label: "Supplier Code",
                              controller: _idCtrl,
                              icon: Icons.badge,
                              width: 200,
                              c: c,
                              isDark: isDark,
                            ),
                          ],
                        ),
                        _buildDivider(c),

                        _buildSectionTitle("CONTACT & COMMUNICATION", c),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            _buildTextField(
                              label: "Email Address",
                              controller: _emailCtrl,
                              icon: Icons.email_outlined,
                              width: 280,
                              keyboardType: TextInputType.emailAddress,
                              c: c,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty || !v.contains('@')
                                  ? 'Valid email required'
                                  : null,
                            ),
                            _buildTextField(
                              label: "Phone / WhatsApp",
                              controller: _phoneCtrl,
                              icon: Icons.phone_android,
                              width: 280,
                              keyboardType: TextInputType.phone,
                              c: c,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty
                                  ? 'Phone number is required'
                                  : null,
                            ),
                          ],
                        ),
                        _buildDivider(c),

                        _buildSectionTitle("SUPPLY CATEGORIES", c),
                        _buildTextField(
                          label: "Categories Handled",
                          controller: _categoryCtrl,
                          icon: Icons.category_outlined,
                          width: double.infinity,
                          c: c,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 🟩 FOOTER SECTION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: c.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateDistributor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isLoading ? "Updating..." : "Update Details",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, dynamic c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: c.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDivider(dynamic c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: c.textSecondary.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required double width,
    required dynamic c,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: c.textSecondary, size: 20),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFFFF6D00), width: 1.5),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Colors.redAccent),
              ),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
