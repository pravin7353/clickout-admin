import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- THEME CONSTANTS ---
const Color bgDark = Color(0xFF080B08);
const Color cardDark = Color(0xFF111811);
const Color accentGreen = Color(0xFF00C853);
const Color textPrimary = Color(0xFFF0F0F0);
const Color textSecondary = Color(0xFF888888);

class AssignStaffDialog extends StatefulWidget {
  final String?
  tenantId; // Agar Super Admin ne bulaya toh shayad tenantId enter karna pade
  final String? storeId; // Sirf Tenant Dashboard se aayega
  final String? branchCode; // Agar lock karna hai toh pass karo
  final String? fixedRole; // Agar pehle se 'MANAGER' fix karna hai

  const AssignStaffDialog({
    super.key,
    this.tenantId,
    this.storeId,
    this.branchCode,
    this.fixedRole,
  });

  @override
  State<AssignStaffDialog> createState() => _AssignStaffDialogState();
}

class _AssignStaffDialogState extends State<AssignStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _tenantIdCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  String? _selectedRole;
  bool _isLoading = false;

  final List<String> _availableRoles = [
    'MANAGER',
    'AUDITOR',
    'GUARD',
    'CASHIER',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tenantId != null) _tenantIdCtrl.text = widget.tenantId!;
    if (widget.branchCode != null) _branchCtrl.text = widget.branchCode!;
    if (widget.fixedRole != null) _selectedRole = widget.fixedRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _tenantIdCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final staffRef = db.collection('staff').doc();

      final roleToSave = widget.fixedRole ?? _selectedRole ?? 'STAFF';

      // 1. Create Staff Doc (Common for both screens)
      batch.set(staffRef, {
        'docId': staffRef.id,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': roleToSave,
        'tenantId': _tenantIdCtrl.text.trim(),
        'branchCode': _branchCtrl.text.trim().toUpperCase(),
        'storeId': widget.storeId ?? 'UNASSIGNED',
        'isActive': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Link to Store (Sirf tab chalega jab Tenant Dashboard se aayega aur Store ID hoga)
      if (widget.storeId != null && roleToSave == 'MANAGER') {
        batch.update(db.collection('stores').doc(widget.storeId), {
          'managerName': _nameCtrl.text.trim(),
          'managerPhone': _phoneCtrl.text.trim(),
          'managerId': staffRef.id,
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$roleToSave Assigned Successfully!"),
            backgroundColor: accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary),
      filled: true,
      fillColor: bgDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentGreen),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentGreen.withValues(alpha: 0.2)),
      ),
      title: Row(
        children: [
          const Icon(Icons.person_add_alt_1, color: accentGreen),
          const SizedBox(width: 10),
          Text(
            widget.fixedRole != null
                ? "Assign ${widget.fixedRole}"
                : "Onboard New Staff",
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tenant ID (Sirf tab dikhega jab Super Admin directly staff add kar raha ho)
                if (widget.tenantId == null) ...[
                  TextFormField(
                    controller: _tenantIdCtrl,
                    style: const TextStyle(color: textPrimary),
                    decoration: _inputDeco("Tenant ID *"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                ],

                // Role Dropdown (Sirf tab dikhega jab role fix na ho)
                if (widget.fixedRole == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    dropdownColor: cardDark,
                    style: const TextStyle(color: textPrimary),
                    decoration: _inputDeco("Assign Role *"),
                    items: _availableRoles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRole = v),
                    validator: (v) => v == null ? "Select a role" : null,
                  ),
                  const SizedBox(height: 15),
                ],

                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: textPrimary),
                  decoration: _inputDeco("Full Name *"),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneCtrl,
                  style: const TextStyle(color: textPrimary),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDeco(
                    "Phone Number *",
                  ).copyWith(counterText: ""),
                  validator: (v) =>
                      v!.length != 10 ? "10 digits required" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco("Email ID (For Login) *"),
                  validator: (v) => !v!.contains('@') ? "Invalid email" : null,
                ),
                const SizedBox(height: 15),

                // Branch Code (Agar locked hai toh readonly dikhega)
                TextFormField(
                  controller: _branchCtrl,
                  readOnly: widget.branchCode != null,
                  style: TextStyle(
                    color: widget.branchCode != null
                        ? textSecondary
                        : textPrimary,
                  ),
                  decoration: _inputDeco(
                    widget.branchCode != null
                        ? "Assigned Branch (Locked)"
                        : "Branch Code (e.g., MUM_01) *",
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentGreen,
            foregroundColor: bgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: bgDark,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "CREATE ACCESS",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
