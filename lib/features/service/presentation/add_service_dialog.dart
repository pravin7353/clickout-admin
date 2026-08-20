import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_master_provider.dart'; // 🚀 NAYA SERVICE PROVIDER
import 'package:clickout_admin/core/theme/app_theme.dart';

class AddServiceDialog extends ConsumerStatefulWidget {
  const AddServiceDialog({super.key});

  @override
  ConsumerState<AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends ConsumerState<AddServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _sacCtrl; // 🚀 SAC CODE FOR SERVICES

  String _selectedGst = '18% GST'; // Services pe default usually 18% lagta hai

  final List<String> _gstSlabs = [
    '0% GST',
    '5% GST',
    '12% GST',
    '18% GST',
    '28% GST',
  ];

  // 🎨 STRICT DARK THEME CONSTANTS
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  static const Color accentBlue = Color(0xFF2962FF); // 🚀 Service Blue Theme
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _sacCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sacCtrl.dispose();
    super.dispose();
  }

  void _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final serviceData = {
        'barcode': _codeCtrl.text.trim(), // Treated as Service ID
        'name': _nameCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'sac': _sacCtrl.text.trim(),
        'gst': _selectedGst,
        'itemType': 'SERVICE', // 🚀 THE SAAS LABEL
        'unitCost': 0, // No Kharidi Bhav for Services
        'physicalStock': 0, // No stock
        'weight': '',
        'expiryDate': null,
      };

      // 🚀 Naye service engine ko data bheja
      await ref.read(serviceMasterProvider.notifier).addNewService(serviceData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ New Service Added!"),
            backgroundColor: accentBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $e"),
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
        side: BorderSide(color: accentBlue.withValues(alpha: 0.2), width: 1),
      ),
      backgroundColor: bgDark,
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
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
                        color: accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.room_service,
                        color: accentBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add New Service",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Register a non-physical service (e.g., Hair Spa, Polishing).",
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
                      icon: Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
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
                        _buildSectionTitle("SERVICE IDENTITY"),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: "Service Code (ID)",
                                controller: _codeCtrl,
                                icon: Icons.tag,
                                hintText: "e.g., VHSSPA002",
                                inputFormatters: [
                                  // 🚀 FIX: Only allow letters & numbers (No spaces, no hyphens, no +)
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]'),
                                  ),
                                  // 🚀 FIX: Auto-convert to UPPERCASE while typing
                                  TextInputFormatter.withFunction(
                                    (oldValue, newValue) => TextEditingValue(
                                      text: newValue.text.toUpperCase(),
                                      selection: newValue.selection,
                                    ),
                                  ),
                                ],
                                validator: (v) =>
                                    v!.isEmpty ? 'Code required' : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildTextField(
                                label: "Service Name",
                                controller: _nameCtrl,
                                icon: Icons.design_services,
                                hintText: "Example: L'Oreal Hair Spa",
                                validator: (v) =>
                                    v!.isEmpty ? 'Name required' : null,
                              ),
                            ),
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("PRICING & COMPLIANCE"),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: "Service Charge (₹)",
                                controller: _priceCtrl,
                                icon: Icons.sell_outlined,
                                hintText: "0.00",
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Charge required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Applicable GST",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedGst,
                                    decoration: _inputStyle(
                                      icon: Icons.receipt_long,
                                    ),
                                    dropdownColor: cardDark,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: accentBlue,
                                    ),
                                    items: _gstSlabs
                                        .map(
                                          (String slab) => DropdownMenuItem(
                                            value: slab,
                                            child: Text(
                                              slab,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedGst = val!),
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
                              child: _buildTextField(
                                label: "SAC Code (For Services)",
                                controller: _sacCtrl,
                                icon: Icons.account_balance,
                                hintText: "e.g., 9983",
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Expanded(
                              child: SizedBox(),
                            ), // Placeholder to keep UI aligned
                          ],
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
                      onPressed: _isLoading ? null : _saveService,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label: const Text(
                        "Save Service",
                        style: TextStyle(
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

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: textSecondary,
        letterSpacing: 1.5,
      ),
    ),
  );
  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Divider(
      height: 1,
      thickness: 1,
      color: textSecondary.withValues(alpha: 0.1),
    ),
  );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
          decoration: _inputStyle(icon: icon, hintText: hintText),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputStyle({required IconData icon, String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: accentBlue, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
