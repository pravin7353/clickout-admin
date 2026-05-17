import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/po_engine_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION

class CreatePODialog extends ConsumerStatefulWidget {
  final String productId;
  final String productName;
  final int currentStock;

  const CreatePODialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.currentStock,
  });

  @override
  ConsumerState<CreatePODialog> createState() => _CreatePODialogState();
}

class _CreatePODialogState extends ConsumerState<CreatePODialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: "100");
  final _branchCtrl =
      TextEditingController(); // 🚀 FIX: Removed hardcoded MUM01

  String _selectedSupplier = "";
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 3));

  // 🚀 LIVE SUPPLIER FETCHING STATE
  List<Map<String, dynamic>> _suppliersList = [];
  bool _isLoadingSuppliers = true;

  @override
  void initState() {
    super.initState();

    // 🚀 FIX: Automatically set the exact branch code of the logged-in user!
    final adminData = ref.read(adminRoleProvider).value;
    final branchCode =
        adminData?['branchCode'] ?? adminData?['storeId'] ?? "HQ";
    _branchCtrl.text = branchCode;

    _fetchSuppliers();
  }

  // 📡 Fetch Suppliers from Database
  // 📡 Fetch Suppliers from Database (🚀 SAAS INJECTED)
  Future<void> _fetchSuppliers() async {
    try {
      // 🚀 SAAS CONTEXT
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];
      final role = (ref.read(adminRoleProvider).value?['role'] ?? '')
          .toString()
          .toLowerCase();

      Query query = FirebaseFirestore.instance.collection('suppliers');

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }

      final snap = await query.get();
      setState(() {
        _suppliersList = snap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['id'] = d.id;
          return data;
        }).toList();

        if (_suppliersList.isNotEmpty) {
          _selectedSupplier = _suppliersList.first['id'];
        }
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      debugPrint("Error fetching suppliers: $e");
      if (mounted) setState(() => _isLoadingSuppliers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(poEngineProvider);

    // 🎨 THEME CONSTANTS (Standard Premium Dark)
    const Color bgDark = Color(0xFF080B08);
    const Color accentGreen = Color(0xFF00C853);
    const Color textPrimary = Color(0xFFF0F0F0);
    const Color textSecondary = Color(0xFF888888);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: textSecondary.withOpacity(0.2), width: 1),
      ),
      backgroundColor: bgDark,
      elevation: 24,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: bgDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎩 HEADER
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
                        Icons.local_shipping,
                        color: accentGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Generate Purchase Order",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Target SKU: ${widget.productName}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Shelf Stock: ${widget.currentStock}",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 📦 BODY
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("SUPPLIER DETAILS"),

                        const Text(
                          "Select Supplier",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _isLoadingSuppliers
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: accentGreen,
                                ),
                              )
                            : Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (option) =>
                                    option['name'] ?? 'Unknown',
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return _suppliersList;
                                      }
                                      return _suppliersList.where((option) {
                                        return option['name']
                                            .toString()
                                            .toLowerCase()
                                            .contains(
                                              textEditingValue.text
                                                  .toLowerCase(),
                                            );
                                      });
                                    },
                                onSelected: (selection) {
                                  _selectedSupplier = selection['id'];
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      textEditingController,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      return TextFormField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        decoration: _inputStyle(
                                          icon: Icons.domain,
                                          hintText: "Search Supplier Name...",
                                        ),
                                        validator: (val) =>
                                            val == null || val.isEmpty
                                            ? "Please select a supplier"
                                            : null,
                                        onChanged: (val) =>
                                            _selectedSupplier = val,
                                      );
                                    },
                              ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Divider(
                            color: textSecondary.withOpacity(0.1),
                            height: 1,
                            thickness: 1,
                          ),
                        ),

                        _buildSectionTitle("ORDER SPECIFICATIONS"),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Order Quantity",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _qtyCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                    decoration: _inputStyle(
                                      icon: Icons.production_quantity_limits,
                                      hintText: "Enter Quantity",
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Branch Code",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _branchCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                    decoration: _inputStyle(
                                      icon: Icons.store,
                                      hintText: "Branch Code",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Delivery Date",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _deliveryDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 60),
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: accentGreen,
                                          onPrimary: Colors.white,
                                          surface: Color(0xFF111811),
                                          onSurface: textPrimary,
                                        ),
                                        dialogBackgroundColor: bgDark,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setState(() => _deliveryDate = date);
                                }
                              },
                              child: InputDecorator(
                                decoration: _inputStyle(
                                  icon: Icons.calendar_month,
                                ),
                                child: Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_deliveryDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
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
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              if (_selectedSupplier.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Select a valid supplier!"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              try {
                                await ref
                                    .read(poEngineProvider.notifier)
                                    .createManualPO(
                                      productId: widget.productId,
                                      productName: widget.productName,
                                      supplierId: _selectedSupplier,
                                      orderQty: int.parse(_qtyCtrl.text),
                                      deliveryDate: _deliveryDate,
                                      branchCode: _branchCtrl.text,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "✅ PO Raised! Check PENDING APPROVALS.",
                                      ),
                                      backgroundColor: accentGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error: $e"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text(
                        "Generate PO",
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF888888),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  InputDecoration _inputStyle({required IconData icon, String? hintText}) {
    const Color inputBg = Color(0xFF1A221A);
    const Color accentGreen = Color(0xFF00C853);
    const Color textSecondary = Color(0xFF888888);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentGreen, width: 1.5),
      ),
    );
  }
}
