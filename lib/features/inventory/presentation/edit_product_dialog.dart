import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../inventory/providers/product_master/product_master_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class EditProductDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> productData;
  final String docId;

  const EditProductDialog({
    super.key,
    required this.productData,
    required this.docId,
  });

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _stockCtrl;
  late String _gst;
  DateTime? _selectedExpiry;

  // 🎨 STRICT DARK THEME CONSTANTS
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  static const Color accentGreen = Color(0xFF00C853);
  static const Color accentRed = Color(0xFFFE8181);
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => context.colors.scaffoldBg;

  @override
  void initState() {
    super.initState();

    _barcodeCtrl = TextEditingController(
      text: widget.productData['barcode'] ?? widget.docId,
    );
    _nameCtrl = TextEditingController(
      text:
          widget.productData['name'] ??
          widget.productData['product_name'] ??
          '',
    );
    _priceCtrl = TextEditingController(
      text: widget.productData['price']?.toString() ?? '0',
    );
    _weightCtrl = TextEditingController(
      text:
          widget.productData['weight']?.toString() ??
          widget.productData['weight_volume']?.toString() ??
          '',
    );
    _stockCtrl = TextEditingController(
      text:
          widget.productData['physicalStock']?.toString() ??
          widget.productData['physical_stock']?.toString() ??
          widget.productData['stock']?.toString() ??
          '0',
    );

    _gst =
        (widget.productData['gst'] ??
                widget.productData['gst_slab'] ??
                '0% GST')
            .toString();
    if (!_gst.contains('%')) _gst = '$_gst% GST';

    var rawExpiry =
        widget.productData['expiryDate'] ?? widget.productData['expiry_date'];
    if (rawExpiry != null) {
      if (rawExpiry is Timestamp) {
        _selectedExpiry = rawExpiry.toDate();
      } else if (rawExpiry is String && rawExpiry.isNotEmpty) {
        try {
          _selectedExpiry = DateFormat('dd MMM yyyy').parse(rawExpiry);
        } catch (e) {
          _selectedExpiry = DateTime.tryParse(rawExpiry);
        }
      }
    }
  }

  void _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedData = {
      'name': _nameCtrl.text.trim(),
      'price': _priceCtrl.text.trim(),
      'weight': _weightCtrl.text.trim(),
      'physicalStock': _stockCtrl.text.trim(),
      'gst': _gst,
      'expiryDate': _selectedExpiry,
    };

    try {
      await ref
          .read(productMasterProvider.notifier)
          .updateProduct(_barcodeCtrl.text, updatedData);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Master SKU Updated!"),
            backgroundColor: accentGreen,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(productMasterProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    int currentStock = int.tryParse(_stockCtrl.text) ?? 0;
    bool isLowStock = currentStock <= 10;
    bool isExpired =
        _selectedExpiry != null && _selectedExpiry!.isBefore(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentGreen.withOpacity(0.2), width: 1),
      ),
      backgroundColor: bgDark,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 750,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.all(24),
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
                  const Icon(Icons.edit_square, color: accentGreen, size: 28),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Enterprise SKU Editor",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          "Modifying: ${_barcodeCtrl.text}",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentRed.withOpacity(0.3)),
                      ),
                      child: const Text(
                        "Low Stock",
                        style: TextStyle(
                          color: accentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_selectedExpiry != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? accentRed.withOpacity(0.1)
                            : accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isExpired
                              ? accentRed.withOpacity(0.3)
                              : accentGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        isExpired ? "EXPIRED" : "Fresh",
                        style: TextStyle(
                          color: isExpired ? accentRed : accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 📦 BODY
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel("PRODUCT IDENTITY"),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildInputField(
                            label: "Product Name",
                            controller: _nameCtrl,
                            icon: Icons.inventory_2_outlined,
                            isRequired: true,
                            width: 400,
                          ),
                          _buildInputField(
                            label: "Weight/Volume",
                            controller: _weightCtrl,
                            icon: Icons.scale,
                            width: 200,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: textSecondary.withOpacity(0.1)),
                      ),

                      _buildSectionLabel("PRICING & TAX"),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildInputField(
                            label: "Selling Price (₹)",
                            controller: _priceCtrl,
                            icon: Icons.currency_rupee,
                            isNumber: true,
                            isRequired: true,
                            width: 200,
                          ),
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              initialValue: _gstSlabs.contains(_gst)
                                  ? _gst
                                  : '0% GST',
                              decoration: _inputDecoration(
                                "Included GST",
                                Icons.receipt_long,
                              ),
                              dropdownColor: cardDark,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: accentGreen,
                              ),
                              items: _gstSlabs
                                  .map(
                                    (val) => DropdownMenuItem(
                                      value: val,
                                      child: Text(
                                        val,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) => setState(() => _gst = val!),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Divider(color: textSecondary.withOpacity(0.1)),
                      ),

                      _buildSectionLabel("INVENTORY & LIFECYCLE"),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildInputField(
                            label: "Physical Stock",
                            controller: _stockCtrl,
                            icon: Icons.layers_outlined,
                            isNumber: true,
                            isRequired: true,
                            width: 200,
                          ),
                          SizedBox(
                            width: 250,
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _selectedExpiry ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.dark(
                                          primary: accentGreen,
                                          onPrimary: bgDark,
                                          surface: cardDark,
                                          onSurface: textPrimary,
                                        ),
                                        dialogTheme: DialogThemeData(
                                          backgroundColor: bgDark,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setState(() => _selectedExpiry = date);
                                }
                              },
                              child: InputDecorator(
                                decoration:
                                    _inputDecoration(
                                      "Expiry Date",
                                      Icons.calendar_month,
                                    ).copyWith(
                                      helperText:
                                          "Leave blank if non-perishable",
                                    ),
                                child: Text(
                                  _selectedExpiry != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_selectedExpiry!)
                                      : "Select Date",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedExpiry == null
                                        ? textSecondary
                                        : textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🦶 FOOTER
            Container(
              padding: const EdgeInsets.all(24),
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
                    onPressed: isProcessing
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: bgDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isProcessing ? null : _submitEdit,
                    icon: isProcessing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: bgDark,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.update, size: 18),
                    label: const Text(
                      "UPDATE CHANGES",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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

  final List<String> _gstSlabs = [
    '0% GST',
    '5% GST',
    '12% GST',
    '18% GST',
    '28% GST',
  ];

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isNumber = false,
    bool isRequired = false,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
        decoration: _inputDecoration(label, icon),
        validator: isRequired
            ? (value) => value == null || value.isEmpty ? "Required" : null
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: textSecondary.withOpacity(0.8),
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
