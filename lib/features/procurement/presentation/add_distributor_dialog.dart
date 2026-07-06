import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 SAAS INJECTION
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION
import '../../../core/theme/app_theme.dart';

class AddDistributorDialog extends ConsumerStatefulWidget {
  const AddDistributorDialog({super.key});

  @override
  ConsumerState<AddDistributorDialog> createState() =>
      _AddDistributorDialogState();
}

class _AddDistributorDialogState extends ConsumerState<AddDistributorDialog> {
  // 🚀 FIX: Aapke Missing Controllers wapas aa gaye!
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _categoryCtrl = TextEditingController();

  // 🎨 STRICT DARK THEME CONSTANTS
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  static const Color accentGreen = Color(0xFF00C853);
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _saveDistributor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 🚀 SAAS INJECTION: Fetch Tenant Identity safely
      final adminData = ref.read(adminRoleProvider).value;
      final tenantId = adminData?['tenantId'];
      final adminEmail = adminData?['email'] ?? 'Unknown Admin';

      if (tenantId == null) {
        throw "Tenant Identity Missing! Cannot save distributor.";
      }

      final supplierData = {
        'supplierID': _idCtrl.text.trim().isEmpty
            ? 'AUTO_GEN'
            : _idCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'categories': _categoryCtrl.text.trim(),
        'tenantId': tenantId, // 🚀 FIX: SaaS Isolation Locked!
        'addedBy': adminEmail, // 🚀 FIX: Audit Trail Locked!
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore (Auto-ID generate hoga)
      await FirebaseFirestore.instance
          .collection('suppliers')
          .add(supplierData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ New Distributor Added Successfully!"),
            backgroundColor: accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save distributor: $e"),
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
        side: BorderSide(color: accentGreen.withOpacity(0.2), width: 1),
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
                    bottom: BorderSide(color: textSecondary.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.domain_add,
                        color: accentGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // 🚀 Removed const
                            "Add New Distributor",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Register a new supplier for automated POs and tracking.",
                            style: TextStyle(
                              color: textSecondary, // 🚀 Requires dynamic color
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
                      ), // 🚀 Removed const
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
                              hintText: "E.g., Amul Distributor Mumbai",
                              width: 350,
                              validator: (v) =>
                                  v!.isEmpty ? 'Name is required' : null,
                            ),
                            _buildTextField(
                              label: "Supplier Code (Optional)",
                              controller: _idCtrl,
                              icon: Icons.badge,
                              hintText: "E.g., SUP001",
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
                              hintText: "orders@supplier.com",
                              width: 280,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty || !v.contains('@')
                                  ? 'Valid email required for POs'
                                  : null,
                            ),
                            _buildTextField(
                              label: "Phone / WhatsApp",
                              controller: _phoneCtrl,
                              icon: Icons.phone_android,
                              hintText: "+91 9876543210",
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
                          hintText: "E.g., Dairy, Bakery, FMCG",
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
                    top: BorderSide(color: textSecondary.withOpacity(0.1)),
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
                        // 🚀 Removed const
                        "Cancel",
                        style: TextStyle(
                          color: textSecondary, // 🚀 Uses dynamic color
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveDistributor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
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
                              // 🚀 Removed const
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: bgDark, // 🚀 Uses dynamic color
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                        _isLoading ? "Saving..." : "Save Distributor",
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
          // 🚀 Removed const
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: textSecondary, // 🚀 Uses dynamic color
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
        color: textSecondary.withOpacity(0.1), // 🚀 Dynamic color
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required double width,
    String? hintText,
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
              // 🚀 Removed const
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary, // 🚀 Dynamic color
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              // 🚀 Removed const
              fontWeight: FontWeight.w600,
              color: textPrimary, // 🚀 Dynamic color
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: textSecondary.withOpacity(0.5),
                fontWeight: FontWeight.normal,
              ),
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: accentGreen, width: 2),
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
