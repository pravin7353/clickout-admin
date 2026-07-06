import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentGreen.withOpacity(0.2), width: 1),
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

              // ⬜ FORM BODY SECTION
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("PRODUCT IDENTITY"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Barcode (Primary Key)",
                              controller: _barcodeCtrl,
                              icon: Icons.barcode_reader,
                              readOnly: isEdit,
                              hintText: "Scan or enter barcode",
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) => v!.isEmpty
                                  ? 'Barcode is strictly required'
                                  : null,
                            ),
                            _buildTextField(
                              label: "Product Name",
                              controller: _nameCtrl,
                              icon: Icons.inventory_2_outlined,
                              hintText: "Example: Tata Salt 1kg",
                              validator: (v) => v!.isEmpty
                                  ? 'Product name is required'
                                  : null,
                            ),
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("PRICING"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Selling Price (Bikri Bhav)",
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
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Price is required';
                                }
                                if (double.tryParse(v) == null ||
                                    double.parse(v) <= 0) {
                                  return 'Price must be > 0';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              label: "Unit Cost (Kharidi Bhav)",
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
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Cost is required';
                                }
                                if (double.tryParse(v) == null ||
                                    double.parse(v) <= 0) {
                                  return 'Cost must be > 0';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _ResponsiveRow(
                          children: [
                            Column(
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
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedGst = val!),
                                ),
                              ],
                            ),
                            const SizedBox(), // Empty container to keep GST slab aligned left
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("INVENTORY"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Physical Stock",
                              controller: _stockCtrl,
                              icon: Icons.layers_outlined,
                              hintText: "Enter number of units",
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Stock is required';
                                }
                                if (int.tryParse(v) == null ||
                                    int.parse(v) < 0) {
                                  return 'Stock cannot be negative';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              label: "Weight / Volume",
                              controller: _weightCtrl,
                              icon: Icons.scale_rounded,
                              hintText: "500g / 1kg / 1L",
                            ),
                          ],
                        ),
                        _buildDivider(),

                        _buildSectionTitle("LIFECYCLE"),
                        _ResponsiveRow(
                          children: [
                            Column(
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
                                  ),
                                  decoration:
                                      _inputStyle(
                                        icon: Icons.calendar_month_outlined,
                                        hintText: "Select Date (Optional)",
                                      ).copyWith(
                                        suffixIcon: Icon(
                                          Icons.arrow_drop_down,
                                          color: textSecondary,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(),
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
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProduct,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: bgDark,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: bgDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      label: Text(
                        isEdit ? "Update Product" : "Save Product",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(
        height: 1,
        thickness: 1,
        color: textSecondary.withOpacity(0.1),
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

  InputDecoration _inputStyle({
    required IconData icon,
    String? hintText,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: textSecondary.withOpacity(0.5),
        fontWeight: FontWeight.normal,
      ),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: readOnly ? bgDark : inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: accentGreen, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
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
