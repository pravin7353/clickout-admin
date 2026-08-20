import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

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

  // 🎨 DYNAMIC LIGHT/DARK THEME
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  Color get accentGreen => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF00C853)
      : const Color(0xFF2E7D32);
  Color get accentOrange => const Color(0xFFFF6D00);
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

  @override
  void initState() {
    super.initState();
    // 🚀 Pre-fill existing data instantly
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
        'updatedBy': adminEmail, // 🚀 Audit Trail
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
            // 🚀 REMOVED CONST
            content: const Text("✅ Distributor Updated Successfully!"),
            backgroundColor: accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentOrange.withValues(alpha: 0.2), width: 1),
      ),
      backgroundColor: bgDark,
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(16),
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
                  color: bgDark,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: textSecondary.withValues(alpha: 0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        // 🚀 REMOVED CONST
                        Icons.edit_document,
                        color: accentOrange,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // 🚀 REMOVED CONST
                            "Edit Distributor Profile",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Update supplier details, contact info, or category mappings.",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: textSecondary,
                      ), // 🚀 REMOVED CONST
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),

              // ⬜ FORM BODY SECTION
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("COMPANY IDENTITY"),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            _buildTextField(
                              label: "Distributor / Supplier Name",
                              controller: _nameCtrl,
                              icon: Icons.business,
                              width: 350,
                              validator: (v) =>
                                  v!.isEmpty ? 'Name is required' : null,
                            ),
                            _buildTextField(
                              label: "Supplier Code",
                              controller: _idCtrl,
                              icon: Icons.badge,
                              width: 200,
                            ),
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("CONTACT & COMMUNICATION"),
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
                              validator: (v) => v!.isEmpty
                                  ? 'Phone number is required'
                                  : null,
                            ),
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("SUPPLY CATEGORIES"),
                        _buildTextField(
                          label: "Categories Handled",
                          controller: _categoryCtrl,
                          icon: Icons.category_outlined,
                          width: double.infinity,
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
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: textSecondary.withValues(alpha: 0.1)),
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
                        // 🚀 REMOVED CONST
                        "Cancel",
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateDistributor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentOrange,
                        foregroundColor: bgDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? SizedBox(
                              // 🚀 REMOVED CONST
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: bgDark,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          // 🚀 REMOVED CONST
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: textSecondary.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required double width,
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
              // 🚀 REMOVED CONST
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              // 🚀 REMOVED CONST
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: textSecondary, size: 20),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                // 🚀 REMOVED CONST
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: accentOrange, width: 2),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
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
