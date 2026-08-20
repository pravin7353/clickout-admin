import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

// IMPORTANT: Adjust import paths based on your actual file structure
import '../../auth/auth_provider.dart';

class TenantOnboardingScreen extends ConsumerStatefulWidget {
  const TenantOnboardingScreen({super.key});

  @override
  ConsumerState<TenantOnboardingScreen> createState() =>
      _TenantOnboardingScreenState();
}

class _TenantOnboardingScreenState
    extends ConsumerState<TenantOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetching = true;

  // Controllers
  final _companyNameCtrl = TextEditingController();
  final _hoAddressCtrl = TextEditingController();
  final _hoCityCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // Dynamic GSTIN Controllers
  final List<TextEditingController> _gstinControllers = [
    TextEditingController(),
  ];

  // Dropdowns
  String? _selectedState;
  String? _selectedIndustry;

  final List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Jammu & Kashmir',
    'Chandigarh',
    'Other',
  ];

  final List<String> _industries = [
    'Supermarket',
    'Department Store',
    'Electronics',
    'Pharmacy',
    'Fashion',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // Microtask to safely read provider in initState
    Future.microtask(() async {
      final adminData = ref.read(adminRoleProvider).value;
      final tenantId = adminData?['tenantId'];

      if (tenantId != null && tenantId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (mounted) {
              setState(() {
                _companyNameCtrl.text = data['companyName'] ?? '';
                _isFetching = false;
              });
            }
          }
        } catch (e) {
          debugPrint("Error fetching tenant profile: $e");
          if (mounted) setState(() => _isFetching = false);
        }
      } else {
        if (mounted) setState(() => _isFetching = false);
      }
    });
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _hoAddressCtrl.dispose();
    _hoCityCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    for (var ctrl in _gstinControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addGstinField() {
    if (_gstinControllers.length < 5) {
      setState(() {
        _gstinControllers.add(TextEditingController());
      });
    }
  }

  void _removeGstinField(int index) {
    if (_gstinControllers.length > 1) {
      setState(() {
        _gstinControllers[index].dispose();
        _gstinControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final adminData = ref.read(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];

      if (tenantId == null || tenantId.isEmpty) {
        throw "Tenant ID not found. Please re-login.";
      }

      // Collect valid GSTINs
      final List<String> validGstins = _gstinControllers
          .map((c) => c.text.trim().toUpperCase())
          .where((text) => text.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('tenants').doc(tenantId).set({
        'isOnboardingComplete': true,
        'companyName': _companyNameCtrl.text.trim(),
        'hoAddress': _hoAddressCtrl.text.trim(),
        'hoCity': _hoCityCtrl.text.trim(),
        'hoState': _selectedState,
        'gstins': validGstins,
        'primaryContact': {
          'name': _contactNameCtrl.text.trim(),
          'phone': _contactPhoneCtrl.text.trim(),
        },
        'industryType': _selectedIndustry,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        // Form submitted, router will automatically redirect or we can push manually
        context.go('/tenant-dashboard/$tenantId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Setup Failed: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Premium Input Style connected to app_theme
  InputDecoration _premiumInputStyle(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(
        color: context.colors.textSecondary.withValues(alpha: 0.5),
      ),
      prefixIcon: Icon(icon, color: context.colors.textSecondary),
      filled: true,
      fillColor: context.colors.scaffoldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.success, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.danger, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2B3674)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 700, // Constrained width for web form
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B3674),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Welcome to ClickOut!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Let's complete your tenant profile to activate your dashboard.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BODY
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "COMPANY DETAILS",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _companyNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _premiumInputStyle(
                            "Company Display Name *",
                            Icons.business,
                          ),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        DropdownButtonFormField<String>(
                          initialValue: _selectedIndustry,
                          decoration: _premiumInputStyle(
                            "Industry Type *",
                            Icons.category_outlined,
                          ),
                          items: _industries
                              .map(
                                (ind) => DropdownMenuItem(
                                  value: ind,
                                  child: Text(ind),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedIndustry = val),
                          validator: (v) => v == null ? "Required" : null,
                        ),
                        const SizedBox(height: 30),

                        const Text(
                          "HEAD OFFICE LOCATION",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _hoAddressCtrl,
                          decoration: _premiumInputStyle(
                            "Complete Address *",
                            Icons.location_on_outlined,
                          ),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _hoCityCtrl,
                                decoration: _premiumInputStyle(
                                  "City *",
                                  Icons.location_city,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedState,
                                decoration: _premiumInputStyle(
                                  "State *",
                                  Icons.map_outlined,
                                ),
                                items: _indianStates
                                    .map(
                                      (st) => DropdownMenuItem(
                                        value: st,
                                        child: Text(st),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedState = val),
                                validator: (v) => v == null ? "Required" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        const Text(
                          "TAX & COMPLIANCE",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 15),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _gstinControllers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _gstinControllers[index],
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      maxLength: 15,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9]'),
                                        ),
                                      ],
                                      decoration: _premiumInputStyle(
                                        index == 0
                                            ? "Primary GSTIN *"
                                            : "Additional GSTIN ${index + 1}",
                                        Icons.receipt_long,
                                      ).copyWith(counterText: ""),
                                      validator: (v) {
                                        if (index == 0 &&
                                            (v == null || v.isEmpty)) {
                                          return "Primary GSTIN is required";
                                        }
                                        if (v != null &&
                                            v.isNotEmpty &&
                                            v.length != 15) {
                                          return "GSTIN must be 15 characters";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  if (index > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _removeGstinField(index),
                                    )
                                  else
                                    const SizedBox(
                                      width: 48,
                                    ), // Placeholder for alignment
                                ],
                              ),
                            );
                          },
                        ),

                        if (_gstinControllers.length < 5)
                          TextButton.icon(
                            onPressed: _addGstinField,
                            icon: const Icon(
                              Icons.add,
                              color: Color(0xFF2B3674),
                            ),
                            label: const Text(
                              "Add Another GSTIN",
                              style: TextStyle(
                                color: Color(0xFF2B3674),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 30),

                        const Text(
                          "PRIMARY CONTACT",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _contactNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: _premiumInputStyle(
                                  "Contact Name *",
                                  Icons.person_outline,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: TextFormField(
                                controller: _contactPhoneCtrl,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _premiumInputStyle(
                                  "Phone Number *",
                                  Icons.phone_outlined,
                                ).copyWith(counterText: ""),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Required";
                                  if (v.length != 10) {
                                    return "Must be 10 digits";
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // SUBMIT BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF10B981,
                              ), // Premium Green
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _submitSetup,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "COMPLETE SETUP & GO TO DASHBOARD",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
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
        ),
      ),
    );
  }
}
