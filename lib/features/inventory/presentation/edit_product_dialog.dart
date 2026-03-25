import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../inventory/providers/product_master/product_master_provider.dart';

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

  @override
  void initState() {
    super.initState();

    // 🧠 SMART PARSING TO PREVENT CRASHES
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
    if (!_gst.contains('%')) _gst = '$_gst% GST'; // Normalize legacy data

    // 🛡️ THE CRASH SAVIOR: Handle both String and Timestamp gracefully
    var rawExpiry =
        widget.productData['expiryDate'] ?? widget.productData['expiry_date'];
    if (rawExpiry != null) {
      if (rawExpiry is Timestamp) {
        _selectedExpiry = rawExpiry.toDate();
      } else if (rawExpiry is String && rawExpiry.isNotEmpty) {
        try {
          _selectedExpiry = DateFormat('dd MMM yyyy').parse(rawExpiry);
        } catch (e) {
          _selectedExpiry = DateTime.tryParse(rawExpiry); // Fallback
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
      'expiryDate':
          _selectedExpiry, // The provider will convert this to Timestamp
    };

    try {
      await ref
          .read(productMasterProvider.notifier)
          .updateProduct(_barcodeCtrl.text, updatedData);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Master SKU Updated Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 750,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_square,
                    color: Color(0xFF2B3674),
                    size: 28,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Enterprise SKU Editor",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E1E2D),
                          ),
                        ),
                        Text(
                          "Modifying: ${_barcodeCtrl.text}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Health Badges
                  if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Low Stock",
                        style: TextStyle(
                          color: Colors.deepOrange,
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
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpired ? "EXPIRED" : "Fresh",
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.green,
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
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
                              items: _gstSlabs
                                  .map(
                                    (val) => DropdownMenuItem(
                                      value: val,
                                      child: Text(
                                        val,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
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
                                        ? Colors.grey
                                        : Colors.black,
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
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isProcessing
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B3674),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isProcessing ? null : _submitEdit,
                    child: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "SAVE CHANGES",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
          color: Colors.grey.shade500,
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
        style: const TextStyle(fontWeight: FontWeight.w600),
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
      labelStyle: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2B3674), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}
