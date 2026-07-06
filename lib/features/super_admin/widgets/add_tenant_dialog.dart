import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class AddTenantDialog extends ConsumerStatefulWidget {
  const AddTenantDialog({super.key});

  @override
  ConsumerState<AddTenantDialog> createState() => _AddTenantDialogState();
}

class _AddTenantDialogState extends ConsumerState<AddTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _companyCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  String _selectedPlan = 'PRO';

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(tenantMasterProvider.notifier)
          .onboardNewTenant(
            companyName: _companyCtrl.text,
            plan: _selectedPlan,
            adminName: _adminNameCtrl.text,
            adminPhone: _adminPhoneCtrl.text,
            adminEmail: _adminEmailCtrl.text,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚀 ${_companyCtrl.text} Successfully Onboarded!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Onboard New Client 🏢",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Create a new tenant workspace and master admin account.",
                  style: TextStyle(color: Colors.grey),
                ),
                const Divider(height: 30),

                // Company Details
                TextFormField(
                  controller: _companyCtrl,
                  decoration: const InputDecoration(
                    labelText: "Company Name (e.g. Reliance Fresh)",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPlan,
                  decoration: const InputDecoration(
                    labelText: "Subscription Plan",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'BASIC',
                      child: Text("Basic (Max 5 Stores)"),
                    ),
                    DropdownMenuItem(
                      value: 'PRO',
                      child: Text("Pro (Max 50 Stores)"),
                    ),
                    DropdownMenuItem(
                      value: 'ENTERPRISE',
                      child: Text("Enterprise (1000+ Stores)"),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedPlan = val!),
                ),
                const SizedBox(height: 25),

                // First Admin Details
                const Text(
                  "First Admin Account (TENANT_ADMIN)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _adminNameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Admin Full Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _adminPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Admin Phone (+91)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) =>
                      v!.length != 10 ? "Enter 10 digit phone" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _adminEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Admin Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (v) =>
                      RegExp(
                        r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : "Enter valid email",
                ),
                const SizedBox(height: 25),

                // Actions
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.ctaBackground,
                      foregroundColor: context.colors.ctaText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "CREATE TENANT & ADMIN",
                            style: TextStyle(
                              color: context.colors.ctaText,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
