import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 NAYA IMPORT: RIVERPOD
import '../providers/product_master/product_master_provider.dart'; // 🚀 NAYA IMPORT: PROVIDER

// 🚀 CHANGED TO ConsumerStatefulWidget
class AddProductDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingData;

  const AddProductDialog({super.key, this.existingData});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

// 🚀 CHANGED TO ConsumerState
class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
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

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    _barcodeCtrl = TextEditingController(text: data?['barcode'] ?? '');
    _nameCtrl = TextEditingController(text: data?['name'] ?? '');
    _priceCtrl = TextEditingController(text: data?['price']?.toString() ?? '');
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2B3674),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
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

  // 🚀 REWIRED TO USE PROVIDER AND STRICT SCHEMA
  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final productData = {
        'barcode': _barcodeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'weight': _weightCtrl.text.trim(),
        'physicalStock': _stockCtrl.text.trim(),
        'gst': _selectedGst,
        'expiryDate':
            _selectedDate, // Send DateTime, Provider will convert to Timestamp
      };

      // Call the newly fixed Provider!
      await ref.read(productMasterProvider.notifier).addNewProduct(productData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("New Master SKU Added!"),
            backgroundColor: Colors.green,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
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
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B3674).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit
                            ? Icons.edit_document
                            : Icons.qr_code_scanner_rounded,
                        color: const Color(0xFF2B3674),
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
                            style: const TextStyle(
                              color: Color(0xFF1E1E2D),
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
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
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
                        // --- 📦 SECTION 1: PRODUCT IDENTITY ---
                        _buildSectionTitle("PRODUCT IDENTITY"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Barcode (Primary Key)",
                              controller: _barcodeCtrl,
                              icon: Icons.barcode_reader,
                              readOnly: isEdit,
                              hintText: "Scan or enter barcode",
                              helperText:
                                  "Scan barcode or manually enter product code.",
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
                              helperText:
                                  "Enter the full recognizable product name.",
                              validator: (v) => v!.isEmpty
                                  ? 'Product name is required'
                                  : null,
                            ),
                          ],
                        ),

                        _buildDivider(),

                        // --- 💰 SECTION 2: PRICING ---
                        _buildSectionTitle("PRICING"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Selling Price",
                              controller: _priceCtrl,
                              icon: Icons.currency_rupee,
                              hintText: "0.00",
                              helperText:
                                  "Final selling price inclusive of taxes.",
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
                                  return 'Price must be greater than 0';
                                }
                                return null;
                              },
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Included GST Slab",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E1E2D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGst,
                                  decoration: _inputStyle(
                                    icon: Icons.receipt_long_outlined,
                                    helperText:
                                        "Select applicable tax bracket.",
                                  ),
                                  dropdownColor: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  items: _gstSlabs.map((String slab) {
                                    return DropdownMenuItem(
                                      value: slab,
                                      child: Text(
                                        slab,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedGst = val!),
                                ),
                              ],
                            ),
                          ],
                        ),

                        _buildDivider(),

                        // --- 🏢 SECTION 3: INVENTORY ---
                        _buildSectionTitle("INVENTORY"),
                        _ResponsiveRow(
                          children: [
                            _buildTextField(
                              label: "Physical Stock",
                              controller: _stockCtrl,
                              icon: Icons.layers_outlined,
                              hintText: "Enter number of units",
                              helperText:
                                  "Number of items currently available in inventory.",
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
                              helperText: "Optional measurement for logistics.",
                            ),
                          ],
                        ),

                        _buildDivider(),

                        // --- ⏳ SECTION 4: LIFECYCLE ---
                        _buildSectionTitle("LIFECYCLE"),
                        _ResponsiveRow(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Expiry Date",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E1E2D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _expiryCtrl,
                                  readOnly: true,
                                  onTap: () => _pickDate(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  decoration:
                                      _inputStyle(
                                        icon: Icons.calendar_month_outlined,
                                        hintText: "Select Date",
                                        helperText:
                                            "Leave empty for non-perishable items.",
                                      ).copyWith(
                                        suffixIcon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.grey,
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

              // 🟩 FOOTER SECTION (Action Bar)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B3674),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
                          : Text(
                              isEdit ? "Update Product" : "Save Product",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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

  // --- HELPER WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    String? helperText,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1E2D),
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
            color: readOnly ? Colors.grey.shade600 : Colors.black87,
          ),
          decoration: _inputStyle(
            icon: icon,
            hintText: hintText,
            helperText: helperText,
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
    String? helperText,
    bool readOnly = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      helperStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontWeight: FontWeight.normal,
      ),
      prefixIcon: Icon(
        icon,
        color: readOnly ? Colors.grey.shade400 : Colors.grey.shade600,
        size: 20,
      ),
      filled: true,
      fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2B3674), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
    );
  }
}

// 📱 RESPONSIVE ROW HELPER
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
