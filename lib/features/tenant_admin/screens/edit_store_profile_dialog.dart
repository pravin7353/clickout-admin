import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStoreProfileDialog extends StatefulWidget {
  final String? storeId;
  final String? branchCode;

  const EditStoreProfileDialog({super.key, this.storeId, this.branchCode});

  @override
  State<EditStoreProfileDialog> createState() => _EditStoreProfileDialogState();
}

class _EditStoreProfileDialogState extends State<EditStoreProfileDialog> {
  bool _isLoading = false;
  bool _isFetching = true;
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  String? _targetDocId;
  String _originalManagerEmail = '';

  // --- THEME COLORS (BLUE FOR EDIT) ---
  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentBlue = Color(0xFF378ADD);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF1A221A);

  // --- FIELD CONTROLLERS ---
  final _storeNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();

  final List<TextEditingController> _phoneControllers = [];
  final List<TextEditingController> _landlineControllers = [];

  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String? _selectedState;

  final List<Map<String, String>> _dynamicLicenses = [];
  final List<String> _licenseTypes = [
    'GSTIN',
    'FSSAI',
    'Drug License',
    'Liquor License',
    'Trade License',
    'Other',
  ];

  final _openTimeCtrl = TextEditingController();
  final _closeTimeCtrl = TextEditingController();
  final _countersCtrl = TextEditingController();

  final _mgrEmpIdCtrl = TextEditingController();
  final _mgrNameCtrl = TextEditingController();
  final _mgrPhoneCtrl = TextEditingController();
  final _mgrEmailCtrl = TextEditingController();

  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final FocusNode _accNoFocus = FocusNode();
  String _fullAccountNumber = '';

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
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStoreData();

    _accNoFocus.addListener(() {
      if (!_accNoFocus.hasFocus) {
        if (_fullAccountNumber.length >= 4) {
          _accNoCtrl.text =
              '•' * (_fullAccountNumber.length - 4) +
              _fullAccountNumber.substring(_fullAccountNumber.length - 4);
        }
      } else {
        _accNoCtrl.text = _fullAccountNumber;
      }
    });
  }

  Future<void> _fetchStoreData() async {
    try {
      _targetDocId = widget.storeId;

      if (_targetDocId == null && widget.branchCode != null) {
        final snap = await FirebaseFirestore.instance
            .collection('stores')
            .where('branchCode', isEqualTo: widget.branchCode)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) _targetDocId = snap.docs.first.id;
      }

      if (_targetDocId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(_targetDocId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          _storeNameCtrl.text = data['storeName'] ?? '';
          _branchCodeCtrl.text = data['branchCode'] ?? '';

          // Phones
          List phones = data['contactNumbers'] ?? [];
          if (phones.isEmpty) _phoneControllers.add(TextEditingController());
          for (var p in phones) {
            _phoneControllers.add(TextEditingController(text: p.toString()));
          }

          // Landlines
          List landlines = data['landlineNumbers'] ?? [];
          if (landlines.isEmpty) {
            _landlineControllers.add(TextEditingController());
          }
          for (var l in landlines) {
            _landlineControllers.add(TextEditingController(text: l.toString()));
          }

          // Location
          final loc = data['location'] ?? {};
          _addressCtrl.text = loc['address'] ?? '';
          _cityCtrl.text = loc['city'] ?? '';
          _pincodeCtrl.text = loc['pincode'] ?? '';
          if (_states.contains(loc['state'])) _selectedState = loc['state'];

          // Licenses
          List lics = data['licenses'] ?? [];
          for (var lic in lics) {
            _dynamicLicenses.add({
              'type': lic['type'].toString(),
              'number': lic['number'].toString(),
            });
          }

          // Operations
          final ops = data['operations'] ?? {};
          _openTimeCtrl.text = ops['openingTime'] ?? '09:00 AM';
          _closeTimeCtrl.text = ops['closingTime'] ?? '10:00 PM';
          _countersCtrl.text = (ops['billingCounters'] ?? 1).toString();

          // Manager
          _mgrNameCtrl.text = data['managerName'] ?? '';
          _mgrEmailCtrl.text = data['managerEmail'] ?? '';
          _originalManagerEmail = data['managerEmail'] ?? '';
          _mgrPhoneCtrl.text = data['managerPhone'] ?? '';
          _mgrEmpIdCtrl.text = data['managerEmpId'] ?? '';

          // Bank
          final bank = data['bankDetails'] ?? {};
          if (bank['isCustom'] == true) {
            _accNameCtrl.text = bank['accountName'] ?? '';
            _fullAccountNumber = bank['accountNo'] ?? '';
            _accNoCtrl.text = _fullAccountNumber;
            _ifscCtrl.text = bank['ifsc'] ?? '';
            _upiCtrl.text = bank['upi'] ?? '';
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    for (var c in _phoneControllers) {
      c.dispose();
    }
    for (var c in _landlineControllers) {
      c.dispose();
    }
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _countersCtrl.dispose();
    _mgrNameCtrl.dispose();
    _mgrEmailCtrl.dispose();
    _mgrPhoneCtrl.dispose();
    _mgrEmpIdCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _accNoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addPhoneField() {
    if (_phoneControllers.length < 3) {
      setState(() => _phoneControllers.add(TextEditingController()));
    }
  }

  void _removePhoneField(int index) {
    if (_phoneControllers.length > 1) {
      setState(() {
        _phoneControllers[index].dispose();
        _phoneControllers.removeAt(index);
      });
    }
  }

  void _addLandlineField() {
    if (_landlineControllers.length < 3) {
      setState(() => _landlineControllers.add(TextEditingController()));
    }
  }

  void _removeLandlineField(int index) {
    if (_landlineControllers.length > 1) {
      setState(() {
        _landlineControllers[index].dispose();
        _landlineControllers.removeAt(index);
      });
    }
  }

  void _addLicenseRow() =>
      setState(() => _dynamicLicenses.add({'type': 'GSTIN', 'number': ''}));

  Future<void> _selectTime(TextEditingController ctrl) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: accentBlue,
            onPrimary: bgDark,
            surface: cardDark,
            onSurface: textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => ctrl.text = picked.format(context));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _targetDocId == null) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final emailInput = _mgrEmailCtrl.text.trim().toLowerCase();

      // Check Email uniqueness if changed
      if (emailInput != _originalManagerEmail.toLowerCase()) {
        final staffCheck = await db
            .collection('staff')
            .where('email', isEqualTo: emailInput)
            .get();
        if (staffCheck.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🚨 Email already registered!"),
                backgroundColor: Colors.redAccent,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      bool hasBankDetails =
          _accNameCtrl.text.trim().isNotEmpty ||
          _fullAccountNumber.isNotEmpty ||
          _ifscCtrl.text.trim().isNotEmpty;
      Map<String, dynamic> finalBankDetails = {
        'isCustom': hasBankDetails,
        'accountName': _accNameCtrl.text.trim(),
        'accountNo': _fullAccountNumber,
        'ifsc': _ifscCtrl.text.trim().toUpperCase(),
        'upi': _upiCtrl.text.trim(),
      };

      final batch = db.batch();
      final storeRef = db.collection('stores').doc(_targetDocId);

      batch.update(storeRef, {
        'storeName': _storeNameCtrl.text.trim(),
        'contactNumbers': _phoneControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'landlineNumbers': _landlineControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'managerName': _mgrNameCtrl.text.trim(),
        'managerEmail': emailInput,
        'managerPhone': _mgrPhoneCtrl.text.trim(),
        'managerEmpId': _mgrEmpIdCtrl.text.trim().toUpperCase(),
        'location.address': _addressCtrl.text.trim(),
        'location.city': _cityCtrl.text.trim(),
        'location.state': _selectedState,
        'location.pincode': _pincodeCtrl.text.trim(),
        'licenses': _dynamicLicenses,
        'operations.openingTime': _openTimeCtrl.text.trim(),
        'operations.closingTime': _closeTimeCtrl.text.trim(),
        'operations.billingCounters':
            int.tryParse(_countersCtrl.text.trim()) ?? 1,
        'bankDetails': finalBankDetails,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Staff doc if exists
      if (_originalManagerEmail.isNotEmpty) {
        final staffQuery = await db
            .collection('staff')
            .where('email', isEqualTo: _originalManagerEmail)
            .where('role', isEqualTo: 'MANAGER')
            .limit(1)
            .get();
        if (staffQuery.docs.isNotEmpty) {
          batch.update(staffQuery.docs.first.reference, {
            'name': _mgrNameCtrl.text.trim(),
            'email': emailInput,
            'phone': _mgrPhoneCtrl.text.trim(),
            'empId': _mgrEmpIdCtrl.text.trim().toUpperCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Store Updated Successfully!"),
            backgroundColor: accentBlue,
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

  InputDecoration _inputDeco(String label, {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Row(
        children: [
          Icon(icon, color: accentBlue, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: accentBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveRow(bool isMobile, Widget child1, Widget child2) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child1, const SizedBox(height: 20), child2],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child1),
        const SizedBox(width: 20),
        Expanded(child: child2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Dialog(
      backgroundColor: bgDark,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentBlue.withOpacity(0.2)),
      ),
      child: Container(
        width: isMobile ? double.infinity : 800,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _isFetching
            ? const Center(child: CircularProgressIndicator(color: accentBlue))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: accentBlue.withOpacity(0.15)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Edit Store Details",
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(isMobile ? 20 : 30),
                        children: [
                          // --- SECTION 1 ---
                          _buildSectionTitle(
                            "1. Basic Store Details",
                            Icons.storefront,
                          ),
                          TextFormField(
                            controller: _storeNameCtrl,
                            style: const TextStyle(color: textPrimary),
                            decoration: _inputDeco("Store Name *"),
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? "Min 3 chars"
                                : null,
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 350),
                            child: TextFormField(
                              controller: _branchCodeCtrl,
                              readOnly: true, // 🚀 PROTECTED PRIMARY KEY
                              style: const TextStyle(color: textSecondary),
                              decoration: _inputDeco(
                                "Branch Code (System Protected)",
                                prefix: const Icon(
                                  Icons.lock,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ...List.generate(
                            _phoneControllers.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 350,
                                      ),
                                      child: TextFormField(
                                        controller: _phoneControllers[index],
                                        style: const TextStyle(
                                          color: textPrimary,
                                        ),
                                        keyboardType: TextInputType.phone,
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: _inputDeco(
                                          index == 0
                                              ? "Primary Contact *"
                                              : "Additional Contact ${index + 1}",
                                        ).copyWith(counterText: ""),
                                        validator: (v) =>
                                            (index == 0 &&
                                                (v == null || v.length != 10))
                                            ? "10 digits required"
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (index > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _removePhoneField(index),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_phoneControllers.length < 3)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addPhoneField,
                                icon: const Icon(
                                  Icons.add,
                                  color: accentBlue,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Add Contact",
                                  style: TextStyle(color: accentBlue),
                                ),
                              ),
                            ),
                          const SizedBox(height: 40),

                          // --- SECTION 2 ---
                          _buildSectionTitle("2. Location", Icons.location_on),
                          TextFormField(
                            controller: _addressCtrl,
                            style: const TextStyle(color: textPrimary),
                            decoration: _inputDeco("Complete Store Address *"),
                            validator: (v) =>
                                v!.trim().isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _cityCtrl,
                              style: const TextStyle(color: textPrimary),
                              decoration: _inputDeco("City *"),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                            TextFormField(
                              controller: _pincodeCtrl,
                              style: const TextStyle(color: textPrimary),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco(
                                "Pincode *",
                              ).copyWith(counterText: ""),
                              validator: (v) => (v == null || v.length != 6)
                                  ? "6 digits required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedState,
                            dropdownColor: inputBg,
                            style: const TextStyle(color: textPrimary),
                            decoration: _inputDeco("State *"),
                            items: _states
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedState = v),
                            validator: (v) => v == null ? "Select State" : null,
                          ),
                          const SizedBox(height: 40),

                          // --- SECTION 3 ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle(
                                "3. Legal & Compliance",
                                Icons.gavel,
                              ),
                              TextButton.icon(
                                onPressed: _addLicenseRow,
                                icon: const Icon(
                                  Icons.add,
                                  color: accentBlue,
                                  size: 16,
                                ),
                                label: const Text(
                                  "Add License",
                                  style: TextStyle(color: accentBlue),
                                ),
                              ),
                            ],
                          ),
                          ..._dynamicLicenses.asMap().entries.map((entry) {
                            int idx = entry.key;
                            Map<String, String> lic = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: _responsiveRow(
                                isMobile,
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      _licenseTypes.contains(lic['type'])
                                      ? lic['type']
                                      : 'Other',
                                  dropdownColor: inputBg,
                                  style: const TextStyle(color: textPrimary),
                                  decoration: _inputDeco("License Type"),
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
                                TextFormField(
                                  initialValue: lic['number'],
                                  style: const TextStyle(color: textPrimary),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: _inputDeco("License Number"),
                                  onChanged: (v) =>
                                      _dynamicLicenses[idx]['number'] = v
                                          .trim(),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 25),

                          // --- SECTION 4 ---
                          _buildSectionTitle(
                            "4. Operations",
                            Icons.access_time,
                          ),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _openTimeCtrl,
                              readOnly: true,
                              onTap: () => _selectTime(_openTimeCtrl),
                              style: const TextStyle(color: textPrimary),
                              decoration: _inputDeco(
                                "Opening Time *",
                                prefix: const Icon(
                                  Icons.timer,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                            TextFormField(
                              controller: _closeTimeCtrl,
                              readOnly: true,
                              onTap: () => _selectTime(_closeTimeCtrl),
                              style: const TextStyle(color: textPrimary),
                              decoration: _inputDeco(
                                "Closing Time *",
                                prefix: const Icon(
                                  Icons.timer,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 350),
                            child: TextFormField(
                              controller: _countersCtrl,
                              style: const TextStyle(color: textPrimary),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco("Billing Counters *"),
                              validator: (v) {
                                int val = int.tryParse(v ?? '') ?? 0;
                                return (val < 1 || val > 50) ? "1 to 50" : null;
                              },
                            ),
                          ),
                          const SizedBox(height: 40),

                          // --- SECTION 5 ---
                          _buildSectionTitle(
                            "5. Manager Assignment",
                            Icons.manage_accounts,
                          ),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _mgrNameCtrl,
                              style: const TextStyle(color: textPrimary),
                              decoration: _inputDeco(
                                "Manager Full Name *",
                                prefix: const Icon(
                                  Icons.person,
                                  color: textSecondary,
                                ),
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                            TextFormField(
                              controller: _mgrEmpIdCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: textPrimary),
                              decoration: _inputDeco(
                                "Manager EMP ID *",
                                prefix: const Icon(
                                  Icons.badge,
                                  color: textSecondary,
                                ),
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _mgrPhoneCtrl,
                              style: const TextStyle(color: textPrimary),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco(
                                "Manager Phone Number *",
                              ).copyWith(counterText: ""),
                              validator: (v) => (v == null || v.length != 10)
                                  ? "10 digits required"
                                  : null,
                            ),
                            TextFormField(
                              controller: _mgrEmailCtrl,
                              style: const TextStyle(color: textPrimary),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDeco("Manager Email *"),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? "Valid email required"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // --- SECTION 6 ---
                          _buildSectionTitle(
                            "6. Bank Details",
                            Icons.account_balance,
                          ),
                          TextFormField(
                            controller: _accNameCtrl,
                            style: const TextStyle(color: textPrimary),
                            decoration: _inputDeco("Account Holder Name"),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              focusNode: _accNoFocus,
                              controller: _accNoCtrl,
                              style: const TextStyle(color: textPrimary),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco("Account Number"),
                              onChanged: (v) {
                                if (_accNoFocus.hasFocus) {
                                  _fullAccountNumber = v;
                                }
                              },
                            ),
                            TextFormField(
                              controller: _ifscCtrl,
                              style: const TextStyle(color: textPrimary),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 11,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(11),
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9]'),
                                ),
                              ],
                              decoration: _inputDeco(
                                "IFSC Code",
                              ).copyWith(counterText: ""),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _upiCtrl,
                            style: const TextStyle(color: textPrimary),
                            decoration: _inputDeco("Settlement UPI ID"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: accentBlue.withOpacity(0.15)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "CANCEL",
                            style: TextStyle(color: textSecondary),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "UPDATE STORE",
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
