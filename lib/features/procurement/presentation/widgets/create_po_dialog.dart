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
    final isMobile = MediaQuery.of(context).size.width < 600;

    // 🎨 THEME CONSTANTS
    const Color bgDark = Color(0xFF080B08);
    const Color cardDark = Color(0xFF111811);
    const Color accentOrange = Color(0xFFD4580A);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: accentOrange,
          width: 1.5,
        ), // 🚀 ORANGE BORDER
      ),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 600,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111811), // cardDark
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFD4580A).withOpacity(0.2),
                  ), // 🚀 ORANGE BORDER
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3674).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Color(0xFF2B3674),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Generate Purchase Order",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E1E2D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Target SKU: ${widget.productName}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Shelf Stock: ${widget.currentStock}",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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

                      // 🔍 SMART AUTOCOMPLETE DROPDOWN
                      _isLoadingSuppliers
                          ? const Center(child: CircularProgressIndicator())
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
                                            textEditingValue.text.toLowerCase(),
                                          );
                                    });
                                  },
                              onSelected: (selection) {
                                // 🚀 FIX: Actual ID jayega DB mein, Name nahi!
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
                                      ),
                                      decoration: _inputStyle(
                                        icon: Icons.domain,
                                        hintText: "Search Supplier Name...",
                                        helperText:
                                            "Type to search from database.",
                                      ),
                                      validator: (val) =>
                                          val == null || val.isEmpty
                                          ? "Please select a supplier"
                                          : null,
                                      onChanged: (val) => _selectedSupplier =
                                          val, // Fallback if manually typed
                                    );
                                  },
                            ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Divider(),
                      ),

                      _buildSectionTitle("ORDER SPECIFICATIONS"),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: TextFormField(
                              controller: _qtyCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputStyle(
                                icon: Icons.production_quantity_limits,
                                hintText: "Enter Quantity",
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : 220,
                            child: TextFormField(
                              controller: _branchCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputStyle(
                                icon: Icons.store,
                                hintText: "Branch Code",
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _deliveryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 60),
                            ),
                          );
                          if (date != null) {
                            setState(() => _deliveryDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputStyle(
                            icon: Icons.calendar_month,
                            helperText: "When should the supplier deliver?",
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(_deliveryDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🦶 FOOTER (Actions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF080B08), // bgDark
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF888888).withOpacity(0.1),
                  ),
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
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4580A), // 🚀 ORANGE
                      foregroundColor: const Color(0xFF080B08),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
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
                                  backgroundColor: Colors.red,
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
                                      "✅ PO Raised! Kindly check 'PENDING APPROVALS' to approve and send to supplier.",
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: Colors.red,
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
                        : const Icon(Icons.send_rounded, size: 20),
                    label: const Text(
                      "Generate PO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  InputDecoration _inputStyle({
    required IconData icon,
    String? hintText,
    String? helperText,
  }) {
    const Color inputBg = Color(0xFF1A221A);
    const Color accentOrange = Color(0xFFD4580A);
    const Color textSecondary = Color(0xFF888888);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      helperText: helperText,
      helperStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: textSecondary),
      filled: true,
      fillColor: inputBg, // 🚀 Dark Input
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
        borderSide: const BorderSide(
          color: accentOrange,
          width: 2,
        ), // 🚀 ORANGE FOCUS
      ),
    );
  }
}
