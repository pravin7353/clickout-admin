import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/po_engine_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '/core/theme/app_theme.dart'; // 🚀 Added Theme Support
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/error_state.dart';

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
  final _branchCtrl = TextEditingController();

  String _selectedSupplier = "";
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 3));

  List<Map<String, dynamic>> _suppliersList = [];
  bool _isLoadingSuppliers = true;
  bool _hasErrorSuppliers = false;

  @override
  void initState() {
    super.initState();
    final adminData = ref.read(adminRoleProvider).value;
    final branchCode =
        adminData?['branchCode'] ?? adminData?['storeId'] ?? "HQ";
    _branchCtrl.text = branchCode;
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    try {
      final tenantId = ref.read(adminRoleProvider).value?['tenantId'];
      final role = (ref.read(adminRoleProvider).value?['role'] ?? '')
          .toString()
          .toLowerCase();

      Query query = FirebaseFirestore.instance.collection('suppliers');

      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }

      final snap = await query.get();
      if (mounted) {
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
          _hasErrorSuppliers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuppliers = false;
          _hasErrorSuppliers = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(poEngineProvider);
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: c.scaffoldBg,
            borderRadius: BorderRadius.circular(24), // 🚀 Premium 24px
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? c.success.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
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
                        color: c.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_shipping,
                        color: c.success,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Generate Purchase Order",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Target SKU: ${widget.productName}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.textSecondary,
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
                        color: c.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Shelf Stock: ${widget.currentStock}",
                        style: TextStyle(
                          color: c.danger,
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
                        _buildSectionTitle("SUPPLIER DETAILS", c),
                        Text(
                          "Select Supplier",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _hasErrorSuppliers
                            ? ErrorState(
                                message: "Failed to load suppliers.",
                                onRetry: () {
                                  setState(() {
                                    _isLoadingSuppliers = true;
                                    _hasErrorSuppliers = false;
                                  });
                                  _fetchSuppliers();
                                },
                              )
                            : _isLoadingSuppliers
                            ? const SkeletonBox(
                                height: 56,
                              ) // 🚀 MATCHES INPUT HEIGHT
                            : Autocomplete<Map<String, dynamic>>(
                                displayStringForOption: (option) =>
                                    option['name'] ?? 'Unknown',
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty)
                                        return _suppliersList;
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
                                onSelected: (selection) =>
                                    _selectedSupplier = selection['id'],
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: c.textPrimary,
                                        ),
                                        decoration: _inputStyle(
                                          icon: Icons.domain,
                                          hintText: "Search Supplier Name...",
                                          context: context,
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
                            color: c.textSecondary.withValues(alpha: 0.1),
                            height: 1,
                            thickness: 1,
                          ),
                        ),

                        _buildSectionTitle("ORDER SPECIFICATIONS", c),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Order Quantity",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _qtyCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                    decoration: _inputStyle(
                                      icon: Icons.production_quantity_limits,
                                      hintText: "Enter Quantity",
                                      context: context,
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
                                  Text(
                                    "Branch Code",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _branchCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                    decoration: _inputStyle(
                                      icon: Icons.store,
                                      hintText: "Branch Code",
                                      context: context,
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
                            Text(
                              "Delivery Date",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
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
                                        colorScheme: isDark
                                            ? ColorScheme.dark(
                                                primary: c.success,
                                                onPrimary: Colors.white,
                                                surface: c.cardBg,
                                                onSurface: c.textPrimary,
                                              )
                                            : ColorScheme.light(
                                                primary: c.success,
                                                onPrimary: Colors.white,
                                                surface: c.cardBg,
                                                onSurface: c.textPrimary,
                                              ),
                                        dialogBackgroundColor: c.scaffoldBg,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null)
                                  setState(() => _deliveryDate = date);
                              },
                              child: InputDecorator(
                                decoration: _inputStyle(
                                  icon: Icons.calendar_month,
                                  context: context,
                                ),
                                child: Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_deliveryDate),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
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
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.pop(context),
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.success,
                        foregroundColor: Colors.black, // 🚀 Premium dark text
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              if (_selectedSupplier.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      "Select a valid supplier!",
                                    ),
                                    backgroundColor: c.danger,
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
                                    SnackBar(
                                      content: const Text(
                                        "✅ PO Raised! Check PENDING APPROVALS.",
                                      ),
                                      backgroundColor: c.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: c.danger,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        isProcessing ? "PROCESSING..." : "Generate PO",
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

  Widget _buildSectionTitle(String title, dynamic c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: c.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  InputDecoration _inputStyle({
    required IconData icon,
    String? hintText,
    required BuildContext context,
  }) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: c.textSecondary, size: 20),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.success, width: 1.5),
      ),
    );
  }
}
