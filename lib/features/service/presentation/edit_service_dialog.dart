import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_master_provider.dart';

class EditServiceDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> serviceData;
  const EditServiceDialog({super.key, required this.serviceData});

  @override
  ConsumerState<EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends ConsumerState<EditServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _sacCtrl;

  late String _selectedGst;

  final List<String> _gstSlabs = [
    '0% GST',
    '5% GST',
    '12% GST',
    '18% GST',
    '28% GST',
  ];

  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentBlue = Color(0xFF2962FF);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF1A221A);

  @override
  void initState() {
    super.initState();
    // 🚀 Pre-fill data from existing service
    _codeCtrl = TextEditingController(
      text: widget.serviceData['barcode']?.toString() ?? '',
    );
    _nameCtrl = TextEditingController(
      text: widget.serviceData['name']?.toString() ?? '',
    );
    _priceCtrl = TextEditingController(
      text: widget.serviceData['price']?.toString() ?? '0',
    );
    _sacCtrl = TextEditingController(
      text: widget.serviceData['sac']?.toString() ?? '',
    );

    String gstVal = widget.serviceData['gst']?.toString() ?? '18% GST';
    if (!_gstSlabs.contains(gstVal)) gstVal = '18% GST'; // Fallback safely
    _selectedGst = gstVal;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sacCtrl.dispose();
    super.dispose();
  }

  void _updateService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updatedData = {
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        'sac': _sacCtrl.text.trim(),
        'gst': _selectedGst,
      };

      // 🚀 Call Update Provider (Uses the unchangeable barcode as Doc ID reference)
      await ref
          .read(serviceMasterProvider.notifier)
          .updateService(_codeCtrl.text.trim(), updatedData);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Service Updated!"),
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
        side: BorderSide(color: accentBlue.withOpacity(0.2), width: 1),
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
              // 🟦 HEADER
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
                        color: accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: accentBlue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Edit Service",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Update service details. Service Code cannot be changed.",
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
                      icon: const Icon(Icons.close, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ⬜ FORM BODY
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
                                label: "Service Code (LOCKED) 🔒",
                                controller: _codeCtrl,
                                icon: Icons.lock,
                                readOnly:
                                    true, // 🚀 Locked to prevent Firebase mapping bugs
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildTextField(
                                label: "Service Name",
                                controller: _nameCtrl,
                                icon: Icons.design_services,
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
                                  const Text(
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
                                              style: const TextStyle(
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
                                label: "SAC Code",
                                controller: _sacCtrl,
                                icon: Icons.account_balance,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 🟩 FOOTER
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
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateService,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 18),
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
                        "Update Service",
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
      style: const TextStyle(
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
      color: textSecondary.withOpacity(0.1),
    ),
  );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
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
            color: readOnly ? textSecondary : textPrimary,
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
            color: readOnly ? textSecondary : textPrimary,
          ),
          decoration: _inputStyle(icon: icon, isLocked: readOnly),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputStyle({required IconData icon, bool isLocked = false}) {
    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: isLocked ? textSecondary.withOpacity(0.5) : textSecondary,
        size: 20,
      ),
      filled: true,
      fillColor: isLocked ? bgDark : inputBg, // Darker bg if locked
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: isLocked
          ? null
          : const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: accentBlue, width: 1.5),
            ),
    );
  }
}
