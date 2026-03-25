import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTenantProfileDialog extends StatefulWidget {
  final String tenantId;
  const EditTenantProfileDialog({super.key, required this.tenantId});

  @override
  State<EditTenantProfileDialog> createState() =>
      _EditTenantProfileDialogState();
}

class _EditTenantProfileDialogState extends State<EditTenantProfileDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final _brandCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _estYearCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _openTimeCtrl = TextEditingController();
  final _closeTimeCtrl = TextEditingController();
  final _employeesCtrl = TextEditingController();

  // --- DROPDOWNS ---
  String? _selectedBizType;
  String? _selectedVolume;
  String? _selectedState;

  final List<String> _bizTypes = [
    'Super Mart',
    'Department Store',
    'Electronics',
    'Pharmacy',
    'Fashion Retail',
    'F&B',
    'Other',
  ];
  final List<String> _volumeOptions = [
    'Under 1,000',
    '1,000 – 5,000',
    '5,000 – 20,000',
    '20,000+',
  ];
  final List<String> _states = [
    'Andaman & Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu & Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenantId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _brandCtrl.text = data['companyName'] ?? '';
        _ownerCtrl.text = data['ownerName'] ?? '';

        final contact = data['contact'] as Map<String, dynamic>? ?? {};
        _phoneCtrl.text = contact['phone'] ?? '';
        _emailCtrl.text = contact['email'] ?? '';

        _estYearCtrl.text = data['establishedYear']?.toString() ?? '';
        _selectedBizType = _bizTypes.contains(data['businessType'])
            ? data['businessType']
            : null;

        final location = data['location'] as Map<String, dynamic>? ?? {};
        _addressCtrl.text = location['address'] ?? '';
        _cityCtrl.text = location['city'] ?? '';
        _pincodeCtrl.text = location['pincode'] ?? '';
        _selectedState = _states.contains(location['state'])
            ? location['state']
            : null;

        final kyc = data['kyc'] as Map<String, dynamic>? ?? {};
        _panCtrl.text = kyc['pan'] ?? '';
        _gstCtrl.text = kyc['gstin'] ?? '';

        final bank = data['bankDetails'] as Map<String, dynamic>? ?? {};
        _accNameCtrl.text = bank['accountName'] ?? '';
        _accNoCtrl.text = bank['accountNo'] ?? '';
        _ifscCtrl.text = bank['ifsc'] ?? '';
        _upiCtrl.text = bank['upi'] ?? '';

        final config = data['config'] as Map<String, dynamic>? ?? {};
        _openTimeCtrl.text = config['openTime'] ?? '';
        _closeTimeCtrl.text = config['closeTime'] ?? '';
        _employeesCtrl.text = config['expectedEmployees']?.toString() ?? '';
        _selectedVolume = _volumeOptions.contains(config['monthlyVolume'])
            ? config['monthlyVolume']
            : null;
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenantId)
          .update({
            'companyName': _brandCtrl.text.trim(),
            'ownerName': _ownerCtrl.text.trim(),
            'businessType': _selectedBizType,
            'establishedYear': int.tryParse(_estYearCtrl.text.trim()) ?? 0,
            'contact.phone': _phoneCtrl.text.trim(),
            'contact.email': _emailCtrl.text.trim(),
            'location.address': _addressCtrl.text.trim(),
            'location.city': _cityCtrl.text.trim(),
            'location.pincode': _pincodeCtrl.text.trim(),
            'location.state': _selectedState,
            'kyc.pan': _panCtrl.text.trim().toUpperCase(),
            'kyc.gstin': _gstCtrl.text.trim().toUpperCase(),
            'bankDetails.accountName': _accNameCtrl.text.trim(),
            'bankDetails.accountNo': _accNoCtrl.text.trim(),
            'bankDetails.ifsc': _ifscCtrl.text.trim().toUpperCase(),
            'bankDetails.upi': _upiCtrl.text.trim(),
            'config.openTime': _openTimeCtrl.text.trim(),
            'config.closeTime': _closeTimeCtrl.text.trim(),
            'config.expectedEmployees':
                int.tryParse(_employeesCtrl.text.trim()) ?? 0,
            'config.monthlyVolume': _selectedVolume,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Color(0xFF00C853),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI HELPERS ---
  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF080B08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF00C853), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    errorStyle: const TextStyle(color: Colors.redAccent),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 15),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00C853),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C853)),
      );
    }

    return Dialog(
      backgroundColor: const Color(0xFF111811),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withOpacity(0.2)),
      ),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Edit Company Profile",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("1. Basic Business Details"),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brandCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Store/Brand Name *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _ownerCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Owner Full Name *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: _deco(
                                "Mobile Number *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  v!.length != 10 ? "10 Digits required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Admin Email *"),
                              validator: (v) =>
                                  !v!.contains('@') ? "Invalid Email" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBizType,
                              dropdownColor: const Color(0xFF080B08),
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Business Type *"),
                              items: _bizTypes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedBizType = v),
                              validator: (v) => v == null ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _estYearCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              decoration: _deco(
                                "Establishment Year *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  v!.length != 4 ? "Invalid Year" : null,
                            ),
                          ),
                        ],
                      ),

                      _sectionTitle("2. Location & KYC"),
                      TextFormField(
                        controller: _addressCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _deco("Complete Address *"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("City *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: _deco(
                                "Pincode *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  v!.length != 6 ? "6 Digits required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedState,
                              dropdownColor: const Color(0xFF080B08),
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("State *"),
                              items: _states
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedState = v),
                              validator: (v) => v == null ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _panCtrl,
                              style: const TextStyle(color: Colors.white),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 10,
                              decoration: _deco(
                                "PAN Number *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  !RegExp(
                                    r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
                                  ).hasMatch(v!)
                                  ? "Invalid PAN"
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _gstCtrl,
                              style: const TextStyle(color: Colors.white),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 15,
                              decoration: _deco(
                                "GST Number (Optional)",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  (v != null &&
                                      v.isNotEmpty &&
                                      !RegExp(
                                        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$',
                                      ).hasMatch(v))
                                  ? "Invalid GST"
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      _sectionTitle("3. Bank Setup (Default Settlement)"),
                      TextFormField(
                        controller: _accNameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _deco("Account Holder Name *"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _accNoCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: _deco("Account Number *"),
                              validator: (v) =>
                                  v!.length < 9 ? "Invalid Account" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _ifscCtrl,
                              style: const TextStyle(color: Colors.white),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 11,
                              decoration: _deco(
                                "IFSC Code *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  !RegExp(
                                    r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                  ).hasMatch(v!)
                                  ? "Invalid IFSC"
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _upiCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _deco("Settlement UPI ID (Optional)"),
                        validator: (v) =>
                            (v != null && v.isNotEmpty && !v.contains('@'))
                            ? "Invalid UPI"
                            : null,
                      ),

                      _sectionTitle("4. Store Configuration"),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _openTimeCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Opening Time *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _closeTimeCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Closing Time *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _employeesCtrl,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: _deco("Total Employees *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedVolume,
                              dropdownColor: const Color(0xFF080B08),
                              style: const TextStyle(color: Colors.white),
                              decoration: _deco("Monthly Volume *"),
                              items: _volumeOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedVolume = v),
                              validator: (v) => v == null ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveData, // 🚀 DIRECT SAVE
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "SAVE CHANGES",
                            style: TextStyle(fontWeight: FontWeight.bold),
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
}
