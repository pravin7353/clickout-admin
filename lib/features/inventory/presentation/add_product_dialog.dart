import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_master/product_master_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class AddProductDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingData;

  const AddProductDialog({super.key, this.existingData});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _unitCostCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _expiryCtrl;

  String _selectedGst = '0% GST';
  DateTime? _selectedDate;

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
  static const Color accentGreen = Color(0xFF00C853);
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    _barcodeCtrl = TextEditingController(text: data?['barcode'] ?? '');
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _priceCtrl = TextEditingController(text: data?['price']?.toString() ?? '');
    _unitCostCtrl = TextEditingController(
      text: data?['unitCost']?.toString() ?? '',
    ); // 🚀 NAYA
    _weightCtrl = TextEditingController(
      text: data?['weight']?.toString() ?? '',
    );
    _stockCtrl = TextEditingController(text: data?['stock']?.toString() ?? '');
    _expiryCtrl = TextEditingController(text: data?['expiryDate'] ?? '');

    if (data?['gst'] != null && _gstSlabs.contains(data!['gst'])) {
      _selectedGst = data['gst'];
    }
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCostCtrl.dispose();
    _weightCtrl.dispose();
    _stockCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              // 🚀 Removed const
              primary: accentGreen,
              onPrimary: bgDark,
              surface: cardDark,
              onSurface: textPrimary,
            ),
            dialogTheme: DialogThemeData(backgroundColor: bgDark),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _expiryCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final productData = {
        'barcode': _barcodeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'itemType':
            'PRODUCT', // 🚀 FIX: Iske bina naya product UI hide kar dega
        'searchKey': _nameCtrl.text
            .trim()
            .toLowerCase(), // 🚀 FIX: Search ke liye zaroori
        'price': _priceCtrl.text.trim(),
        'unitCost': _unitCostCtrl.text.trim(),
        'weight': _weightCtrl.text.trim(),
        'physicalStock': _stockCtrl.text.trim(),
        'gst': _selectedGst,
        'expiryDate': _selectedDate,
      };
      await ref.read(productMasterProvider.notifier).addNewProduct(productData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ New Master SKU Added!"),
            backgroundColor: accentGreen,
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
    final isEdit = widget.existingData != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 750,
        ), // 🛠️ FIX: Standardized width to match Edit SKU precisely
        child: Container(
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(24),
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
            children: [
              // 🟦 HEADER SECTION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit
                            ? Icons.edit_document
                            : Icons.qr_code_scanner_rounded,
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
                            isEdit ? "Edit Master SKU" : "Add New Master SKU",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEdit
                                ? "Update inventory specifications & pricing."
                                : "Register a new product into the enterprise inventory.",
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
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),

              // ⬜ FORM BODY SECTION (TALLER 2-COLUMN GRID)
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
                              label: "Barcode (Primary Key)",
                              controller: _barcodeCtrl,
                              icon: Icons.barcode_reader,
                              readOnly: isEdit,
                              hintText: "Scan or enter",
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              label: "Product Name",
                              controller: _nameCtrl,
                              icon: Icons.inventory_2_outlined,
                              hintText: "Example: Tata Salt 1kg",
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ROW 2: Pricing
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: "Selling Price (₹)",
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
                            child: _buildTextField(
                              label: "Unit Cost (₹) (APKA KHARIDI BHAV)",
                              controller: _unitCostCtrl,
                              icon: Icons.account_balance_wallet_outlined,
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ROW 3: Tax & Weight
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Included GST Slab",
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
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                  dropdownColor: cardDark,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: accentGreen,
                                  ),
                                  items: _gstSlabs.map((String slab) {
                                    return DropdownMenuItem(
                                      value: slab,
                                      child: Text(
                                        slab,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedGst = val!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              label: "Weight / Volume",
                              controller: _weightCtrl,
                              icon: Icons.scale_rounded,
                              hintText: "500g / 1L",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ROW 4: Inventory & Expiry
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: "Physical Stock",
                              controller: _stockCtrl,
                              icon: Icons.layers_outlined,
                              hintText: "Units",
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
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
                                  "Expiry Date",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _expiryCtrl,
                                  readOnly: true,
                                  onTap: () => _pickDate(context),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration:
                                      _inputStyle(
                                        icon: Icons.calendar_month_outlined,
                                        hintText: "Optional",
                                        readOnly: true,
                                      ).copyWith(
                                        suffixIcon: Icon(
                                          Icons.arrow_drop_down,
                                          color: textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                ),
                              ],
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
                  color: cardDark,
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
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.black, // Premium contrast
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
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit
                                      ? "Update Master SKU"
                                      : "Register Master SKU",
                                  style: const TextStyle(
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
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: readOnly ? textSecondary : textPrimary,
          ),
          decoration: _inputStyle(
            icon: icon,
            hintText: hintText,
            readOnly: readOnly,
          ),
          validator: validator,
        ),
      ],
    );
  }

  // 🛠️ PREMIUM SPACIOUS INPUT STYLE
  InputDecoration _inputStyle({
    required IconData icon,
    String? hintText,
    bool readOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.black26,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: readOnly
          ? (isDark ? Colors.white10 : Colors.grey.shade100)
          : (isDark
                ? cardDark
                : Colors.white), // 🚀 FIX: Solid white in light theme
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ), // 🛠️ NORMAL PADDING
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
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: children
                .map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: w,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (w) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: w == children.last ? 0 : 20,
                    ),
                    child: w,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
