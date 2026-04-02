import 'package:flutter/material.dart';
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

  // --- ENTERPRISE DROPDOWNS & SELECTORS ---
  String? _selectedVolume;
  String? _selectedState;

  // 1. Goods vs Services (Primary Sector)
  bool _dealsInGoods = true;
  bool _dealsInServices = false;

  // 2. Multi-Select Industry (LinkedIn Style)
  final TextEditingController _industrySearchCtrl = TextEditingController();
  final List<String> _selectedIndustries = [];
  final List<String> _commonIndustries = [
    'Super Mart',
    'Department Store',
    'Electronics',
    'Pharmacy',
    'Fashion Retail',
    'F&B',
    'IT Services',
    'Consulting',
    'Other',
  ];
  List<String> _filteredIndustries = [];

  // 3. Dynamic Licenses
  final List<Map<String, String>> _dynamicLicenses = [];
  final List<String> _licenseTypes = [
    'GSTIN',
    'FSSAI',
    'Drug License',
    'Liquor License',
    'Trade License',
    'Other',
  ];

  // Helper to add industry tag
  void _addIndustry(String industry) {
    if (industry.trim().isEmpty) return;
    final cleanName = industry.trim();
    if (!_selectedIndustries.contains(cleanName)) {
      setState(() {
        _selectedIndustries.add(cleanName);
        _industrySearchCtrl.clear();
        _filteredIndustries = List.from(_commonIndustries);
      });
    }
  }

  // Helper to add empty license row
  void _addLicenseRow() {
    setState(() {
      _dynamicLicenses.add({'type': 'GSTIN', 'number': ''});
    });
  }

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
    _filteredIndustries = List.from(_commonIndustries);
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

        // 🚀 LOAD: Goods/Services
        if (data['goods_or_services'] != null) {
          final List<dynamic> gs = data['goods_or_services'];
          _dealsInGoods = gs.contains('Goods');
          _dealsInServices = gs.contains('Services');
        }

        // 🚀 LOAD: Industries (LinkedIn Style)
        if (data['industries'] != null) {
          _selectedIndustries.clear();
          for (var ind in data['industries']) {
            _selectedIndustries.add(ind.toString());
          }
        } else if (data['businessType'] != null &&
            data['businessType'].toString().isNotEmpty) {
          // Fallback for old data
          _selectedIndustries.add(data['businessType'].toString());
        }

        final location = data['location'] as Map<String, dynamic>? ?? {};
        _addressCtrl.text = location['address'] ?? '';
        _cityCtrl.text = location['city'] ?? '';
        _pincodeCtrl.text = location['pincode'] ?? '';
        _selectedState = _states.contains(location['state'])
            ? location['state']
            : null;

        final kyc = data['kyc'] as Map<String, dynamic>? ?? {};
        _panCtrl.text = kyc['pan'] ?? '';

        // 🚀 LOAD: Dynamic Licenses
        if (data['licenses'] != null) {
          _dynamicLicenses.clear();
          for (var lic in data['licenses']) {
            _dynamicLicenses.add({
              'type': lic['type']?.toString() ?? 'Other',
              'number': lic['number']?.toString() ?? '',
            });
          }
        } else if ((kyc['gstin'] ?? '').toString().isNotEmpty) {
          // Fallback: Migrate old GST to new dynamic license array
          _dynamicLicenses.add({'type': 'GSTIN', 'number': kyc['gstin']});
        }

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

            // 🚀 ENTERPRISE SAVING LOGIC
            'goods_or_services': [
              _dealsInGoods ? 'Goods' : null,
              _dealsInServices ? 'Services' : null,
            ].whereType<String>().toList(),
            'industries': _selectedIndustries,
            'licenses': _dynamicLicenses,

            'establishedYear': int.tryParse(_estYearCtrl.text.trim()) ?? 0,
            'contact.phone': _phoneCtrl.text.trim(),
            'contact.email': _emailCtrl.text.trim(),
            'location.address': _addressCtrl.text.trim(),
            'location.city': _cityCtrl.text.trim(),
            'location.pincode': _pincodeCtrl.text.trim(),
            'location.state': _selectedState,
            'kyc.pan': _panCtrl.text.trim().toUpperCase(),
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
                      // 🚀 ENTERPRISE UI 1: Goods/Services Toggle
                      const Text(
                        "Primary Sector *",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                "Goods / Products",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              value: _dealsInGoods,
                              activeColor: const Color(0xFF00C853),
                              checkColor: Colors.black,
                              side: const BorderSide(color: Colors.grey),
                              onChanged: (val) =>
                                  setState(() => _dealsInGoods = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                "Services",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              value: _dealsInServices,
                              activeColor: const Color(0xFF00C853),
                              checkColor: Colors.black,
                              side: const BorderSide(color: Colors.grey),
                              onChanged: (val) => setState(
                                () => _dealsInServices = val ?? false,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // 🚀 ENTERPRISE UI 2: LinkedIn Style Industry Multi-Select
                      TextFormField(
                        controller: _industrySearchCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _deco("Search & Add Industry *").copyWith(
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Color(0xFF00C853),
                            ),
                            onPressed: () =>
                                _addIndustry(_industrySearchCtrl.text),
                          ),
                        ),
                        onFieldSubmitted: (v) => _addIndustry(v),
                        onChanged: (val) {
                          setState(() {
                            _filteredIndustries = _commonIndustries
                                .where(
                                  (i) => i.toLowerCase().contains(
                                    val.toLowerCase(),
                                  ),
                                )
                                .toList();
                          });
                        },
                      ),
                      if (_industrySearchCtrl.text.isNotEmpty &&
                          _filteredIndustries.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            color: const Color(0xFF080B08),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredIndustries.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(
                                  _filteredIndustries[index],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: const Icon(
                                  Icons.add,
                                  color: Color(0xFF00C853),
                                  size: 16,
                                ),
                                onTap: () =>
                                    _addIndustry(_filteredIndustries[index]),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedIndustries
                            .map(
                              (industry) => Chip(
                                label: Text(
                                  industry,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: const Color(
                                  0xFF00C853,
                                ).withOpacity(0.2),
                                deleteIconColor: Colors.white70,
                                onDeleted: () => setState(
                                  () => _selectedIndustries.remove(industry),
                                ),
                                side: BorderSide(
                                  color: const Color(
                                    0xFF00C853,
                                  ).withOpacity(0.5),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 15),

                      // ESTABLISHMENT YEAR (Moved here)
                      TextFormField(
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
                      TextFormField(
                        controller: _panCtrl,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10,
                        decoration: _deco(
                          "PAN Number *",
                        ).copyWith(counterText: ""),
                        validator: (v) =>
                            !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(v!)
                            ? "Invalid PAN"
                            : null,
                      ),
                      const SizedBox(height: 25),

                      // 🚀 ENTERPRISE UI 3: Dynamic Licenses
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Licenses & Compliance",
                            style: TextStyle(
                              color: Color(0xFF00C853),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addLicenseRow,
                            icon: const Icon(
                              Icons.add,
                              color: Color(0xFF00C853),
                              size: 16,
                            ),
                            label: const Text(
                              "Add License",
                              style: TextStyle(color: Color(0xFF00C853)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._dynamicLicenses.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Map<String, String> lic = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue:
                                      _licenseTypes.contains(lic['type'])
                                      ? lic['type']
                                      : 'Other',
                                  dropdownColor: const Color(0xFF080B08),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _deco("Type"),
                                  items: _licenseTypes
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _dynamicLicenses[idx]['type'] = v!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: lic['number'],
                                  style: const TextStyle(color: Colors.white),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: _deco("License Number"),
                                  onChanged: (v) =>
                                      _dynamicLicenses[idx]['number'] = v
                                          .trim(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => setState(
                                  () => _dynamicLicenses.removeAt(idx),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

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
