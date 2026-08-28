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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    final bool isGstZero = _selectedGst == '0% GST';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
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
                    ? accentBlue.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🟦 PREMIUM HEADER SECTION
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
                              color: c.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Register a non-physical service (e.g., Hair Spa, Polishing).",
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

              // ⬜ COMPACT NO-SCROLL FORM BODY
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ROW 1: Identity
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: "Service Code (ID)",
                              controller: _codeCtrl,
                              icon: Icons.tag,
                              hintText: "e.g., VHSSPA002",
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9]'),
                                ),
                                TextInputFormatter.withFunction(
                                  (oldValue, newValue) => TextEditingValue(
                                    text: newValue.text.toUpperCase(),
                                    selection: newValue.selection,
                                  ),
                                ),
                              ],
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              label: "Service Name",
                              controller: _nameCtrl,
                              icon: Icons.design_services,
                              hintText: "Example: L'Oreal Hair Spa",
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ROW 2: Pricing & Compliance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "GST (if applicable)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGst,
                                  decoration: _inputStyle(
                                    icon: Icons.receipt_long,
                                  ),
                                  dropdownColor: c.cardBg,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: accentBlue,
                                  ),
                                  items: _gstSlabs.map((String slab) {
                                    return DropdownMenuItem(
                                      value: slab,
                                      child: Text(
                                        slab,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: c.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedGst = val!;
                                      if (_selectedGst == '0% GST') {
                                        _sacCtrl.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              label: "SAC Code (For Service)",
                              controller: _sacCtrl,
                              icon: Icons.account_balance,
                              hintText: isGstZero
                                  ? "N/A for 0% GST"
                                  : "e.g., 9983",
                              keyboardType: TextInputType.number,
                              readOnly: isGstZero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 🟩 PREMIUM FOOTER
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                      ),
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
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveService,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
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
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Save Configuration",
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
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: readOnly ? c.textSecondary : c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: readOnly ? c.textSecondary : c.textPrimary,
            fontSize: 14,
          ),
          decoration: _inputStyle(
            icon: icon,
            hintText: hintText,
            isLocked: readOnly,
          ),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputStyle({
    required IconData icon,
    String? hintText,
    bool isLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.black26,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: isLocked
          ? (isDark ? Colors.white10 : Colors.grey.shade100)
          : (isDark
                ? c.cardBg
                : Colors.white), // 🚀 FIX: Solid white in light theme
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      focusedBorder: isLocked
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade300,
              ),
            )
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accentBlue),
            ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
