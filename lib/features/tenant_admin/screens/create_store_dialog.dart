import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateStoreDialog extends StatefulWidget {
  final String tenantId;
  final String companyName;

  const CreateStoreDialog({
    super.key,
    required this.tenantId,
    required this.companyName,
  });

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // --- THEME COLORS ---
  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF1A221A);

  // --- FIELD CONTROLLERS ---
  // Section 1
  final _storeNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _landlineCtrl = TextEditingController();
  // 🚀 DYNAMIC LISTS FOR MULTIPLE NUMBERS
  final List<TextEditingController> _phoneControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _landlineControllers = [
    TextEditingController(),
  ];

  // Section 2
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String? _selectedState;

  // Section 3
  final _gstinCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();

  // Section 4
  final _openTimeCtrl = TextEditingController(text: '09:00 AM');
  final _closeTimeCtrl = TextEditingController(text: '10:00 PM');
  final _countersCtrl = TextEditingController(text: '1');

  // Section 5 (Manager - Currently Disabled for Schema Consistency)
  /*
  final _mgrEmpIdCtrl = TextEditingController();
  final _mgrNameCtrl = TextEditingController();
  final _mgrPhoneCtrl = TextEditingController();
  final _mgrEmailCtrl = TextEditingController();
  */

  // Section 6 (Optional Bank Details)
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final FocusNode _accNoFocus = FocusNode();
  String _fullAccountNumber = '';

  // --- SCROLL KEYS FOR VALIDATION ---
  final _kStoreName = GlobalKey();
  final _kBranchCode = GlobalKey();
  final _kPhone = GlobalKey();
  final _kAddress = GlobalKey();
  final _kCity = GlobalKey();
  final _kState = GlobalKey();
  final _kPincode = GlobalKey();
  final _kGst = GlobalKey();
  final _kCounters = GlobalKey();

  /*
  final _kMgrEmpId = GlobalKey();
  final _kMgrName = GlobalKey();
  final _kMgrPhone = GlobalKey();
  final _kMgrEmail = GlobalKey();
  */

  final _kAccName = GlobalKey();
  final _kAccNo = GlobalKey();
  final _kIfsc = GlobalKey();
  final _kUpi = GlobalKey();

  bool _isBranchCodeManuallyEdited = false;

  final List<String> _states = [
    'Andaman & Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra & Nagar Haveli and Daman & Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu & Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
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
    _cityCtrl.addListener(_autoGenerateBranchCode);

    // Bank Account Masking Logic
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

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _landlineCtrl.dispose();
    for (var ctrl in _phoneControllers) {
      ctrl.dispose();
    }
    for (var ctrl in _landlineControllers) {
      ctrl.dispose();
    }
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstinCtrl.dispose();
    _fssaiCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _countersCtrl.dispose();

    /*
    _mgrEmpIdCtrl.dispose();
    _mgrNameCtrl.dispose();
    _mgrPhoneCtrl.dispose();
    _mgrEmailCtrl.dispose();
    */

    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _accNoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🚀 ADD / REMOVE LOGIC FOR DYNAMIC FIELDS
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

  void _autoGenerateBranchCode() {
    if (_isBranchCodeManuallyEdited) return;
    String prefix = widget.companyName.replaceAll(' ', '').toUpperCase();
    prefix = prefix.length >= 3 ? prefix.substring(0, 3) : prefix;

    String city = _cityCtrl.text.replaceAll(' ', '').toUpperCase();
    city = city.length >= 3 ? city.substring(0, 3) : city;

    if (city.isNotEmpty) {
      _branchCodeCtrl.text = "${prefix}_${city}_001";
    }
  }

  void _scrollTo(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
    );
    _formKey.currentState!.validate();
  }

  Future<void> _selectTime(TextEditingController ctrl) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accentGreen,
              onPrimary: bgDark,
              surface: cardDark,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => ctrl.text = picked.format(context));
    }
  }

  Future<void> _submit() async {
    // --- MANUAL VALIDATION & AUTO-SCROLL ---
    if (_storeNameCtrl.text.trim().length < 3) return _scrollTo(_kStoreName);
    if (_branchCodeCtrl.text.trim().isEmpty) return _scrollTo(_kBranchCode);
    if (_phoneControllers.first.text.trim().length != 10) {
      return _scrollTo(_kPhone);
    }
    if (_addressCtrl.text.trim().isEmpty) return _scrollTo(_kAddress);
    if (_cityCtrl.text.trim().isEmpty) return _scrollTo(_kCity);
    if (_selectedState == null) return _scrollTo(_kState);
    if (_pincodeCtrl.text.trim().length != 6) return _scrollTo(_kPincode);

    final gst = _gstinCtrl.text.trim().toUpperCase();
    if (gst.isNotEmpty &&
        !RegExp(
          r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$',
        ).hasMatch(gst)) {
      return _scrollTo(_kGst);
    }

    int counters = int.tryParse(_countersCtrl.text.trim()) ?? 0;
    if (counters < 1 || counters > 50) return _scrollTo(_kCounters);

    // Partial Fill Validation for Bank Details
    bool hasBankDetails =
        _accNameCtrl.text.trim().isNotEmpty ||
        _fullAccountNumber.isNotEmpty ||
        _ifscCtrl.text.trim().isNotEmpty ||
        _upiCtrl.text.trim().isNotEmpty;

    if (hasBankDetails) {
      if (_accNameCtrl.text.trim().isEmpty) return _scrollTo(_kAccName);
      if (_fullAccountNumber.length < 9 || _fullAccountNumber.length > 18) {
        return _scrollTo(_kAccNo);
      }
      if (!RegExp(
        r'^[A-Z]{4}0[A-Z0-9]{6}$',
      ).hasMatch(_ifscCtrl.text.trim().toUpperCase())) {
        return _scrollTo(_kIfsc);
      }
      if (_upiCtrl.text.trim().isNotEmpty && !_upiCtrl.text.contains('@')) {
        return _scrollTo(_kUpi);
      }
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final storeRef = db.collection('stores').doc();
      final adminEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin';

      // 🚀 1. FETCH TENANT BANK DETAILS FOR FALLBACK
      Map<String, dynamic> finalBankDetails = {};

      if (hasBankDetails) {
        finalBankDetails = {
          'isCustom': true,
          'accountName': _accNameCtrl.text.trim(),
          'accountNo': _fullAccountNumber,
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'upi': _upiCtrl.text.trim(),
        };
      } else {
        // Agar Bank details nahi daali, toh Tenant ka default fetch karo
        final tenantDoc = await db
            .collection('tenants')
            .doc(widget.tenantId)
            .get();
        final tenantData = tenantDoc.data() ?? {};
        final tenantBank = tenantData['bankDetails'] ?? {};

        finalBankDetails = {
          'isCustom': false,
          'accountName': tenantBank['accountName'] ?? '',
          'accountNo': tenantBank['accountNo'] ?? '',
          'ifsc': tenantBank['ifsc'] ?? '',
          'upi': tenantBank['upi'] ?? '',
        };
      }

      // 🚀 2. WRITE STORE (With Missing ID Fix)
      batch.set(storeRef, {
        'storeId': storeRef.id, // 👈 GAYAB THA (FIXED)
        'tenantId': widget.tenantId, // 👈 GAYAB THA (FIXED)
        'storeName': _storeNameCtrl.text.trim(),
        'branchCode': _branchCodeCtrl.text.trim().toUpperCase(),
        'contactNumbers': _phoneControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'landlineNumbers': _landlineControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'location': {
          'address': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _selectedState,
          'pincode': _pincodeCtrl.text.trim(),
        },
        'legal': {
          'gstin': _gstinCtrl.text.trim().toUpperCase(),
          'fssai': _fssaiCtrl.text.trim().toUpperCase(),
        },
        'operations': {
          'openingTime': _openTimeCtrl.text.trim(),
          'closingTime': _closeTimeCtrl.text.trim(),
          'billingCounters': counters,
        },
        'bankDetails': finalBankDetails, // 👈 TENANT FALLBACK APPLIED
        'status': 'ACTIVE',
        'isActive': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Write Audit Log
      final auditRef = db.collection('admin_audit_logs').doc();
      batch.set(auditRef, {
        'action': 'STORE_CREATED',
        'tenantId': widget.tenantId,
        'storeName': _storeNameCtrl.text.trim(),
        'branchCode': _branchCodeCtrl.text.trim().toUpperCase(),
        'actor': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Close Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Store '${_storeNameCtrl.text.trim()}' created successfully!",
            ),
            backgroundColor: accentGreen,
            behavior: SnackBarBehavior.floating,
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
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Row(
        children: [
          Icon(icon, color: accentGreen, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: accentGreen,
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
        side: BorderSide(color: accentGreen.withValues(alpha: 0.2)),
      ),
      child: Container(
        width: isMobile ? double.infinity : 800,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accentGreen.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Onboard New Store",
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // BODY
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
                      key: _kStoreName,
                      controller: _storeNameCtrl,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco(
                        "Store Name *",
                        hint: "e.g. Jaiswar Flour Mill - Wadala",
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? "Min 3 chars"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    // 🚀 CHOTA FIELD (MAX WIDTH 350)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: TextFormField(
                        key: _kBranchCode,
                        controller: _branchCodeCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _inputDeco(
                          "Branch Code *",
                          hint: "e.g. JAI_MUM_001",
                        ),
                        onChanged: (_) => _isBranchCodeManuallyEdited = true,
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🚀 DYNAMIC MOBILE NUMBERS
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
                                ), // 🚀 CHOTA FIELD
                                child: TextFormField(
                                  key: index == 0 ? _kPhone : null,
                                  controller: _phoneControllers[index],
                                  style: const TextStyle(color: textPrimary),
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputDeco(
                                    index == 0
                                        ? "Primary Contact Number *"
                                        : "Additional Contact ${index + 1}",
                                  ).copyWith(counterText: ""),
                                  validator: (v) {
                                    if (index == 0 &&
                                        (v == null || v.length != 10)) {
                                      return "10 digits required";
                                    }
                                    if (index > 0 &&
                                        v!.isNotEmpty &&
                                        v.length != 10) {
                                      return "Must be 10 digits";
                                    }
                                    return null;
                                  },
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
                            color: accentGreen,
                            size: 18,
                          ),
                          label: const Text(
                            "Add Another Contact",
                            style: TextStyle(
                              color: accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // 🚀 DYNAMIC LANDLINE NUMBERS WITH REGEX
                    ...List.generate(
                      _landlineControllers.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 350,
                                ), // 🚀 CHOTA FIELD
                                child: TextFormField(
                                  controller: _landlineControllers[index],
                                  style: const TextStyle(color: textPrimary),
                                  keyboardType: TextInputType.phone,
                                  decoration: _inputDeco(
                                    index == 0
                                        ? "Primary Landline (Optional)"
                                        : "Additional Landline ${index + 1}",
                                    hint: "e.g. 022-12345678",
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    if (!RegExp(
                                      r'^[0]?[0-9]{2,4}[-\s]?[0-9]{6,8}$',
                                    ).hasMatch(v.trim())) {
                                      return "Invalid format (e.g. 022-12345678)";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            if (index > 0)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removeLandlineField(index),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_landlineControllers.length < 3)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addLandlineField,
                          icon: const Icon(
                            Icons.add,
                            color: accentGreen,
                            size: 18,
                          ),
                          label: const Text(
                            "Add Another Landline",
                            style: TextStyle(
                              color: accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 40),

                    // --- SECTION 2 ---
                    _buildSectionTitle("2. Location", Icons.location_on),
                    TextFormField(
                      key: _kAddress,
                      controller: _addressCtrl,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco("Complete Store Address *"),
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    _responsiveRow(
                      isMobile,
                      TextFormField(
                        key: _kCity,
                        controller: _cityCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _inputDeco("City *"),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      TextFormField(
                        key: _kPincode,
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
                      key: _kState,
                      initialValue: _selectedState,
                      dropdownColor: inputBg,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco("State *"),
                      items: _states
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedState = v),
                      validator: (v) => v == null ? "Select State" : null,
                    ),
                    const SizedBox(height: 40),

                    // --- SECTION 3 ---
                    _buildSectionTitle("3. Legal & Compliance", Icons.gavel),
                    _responsiveRow(
                      isMobile,
                      TextFormField(
                        key: _kGst,
                        controller: _gstinCtrl,
                        style: const TextStyle(color: textPrimary),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                        decoration: _inputDeco(
                          "Store GSTIN (Optional)",
                        ).copyWith(counterText: ""),
                        validator: (v) =>
                            (v != null &&
                                v.isNotEmpty &&
                                !RegExp(
                                  r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$',
                                ).hasMatch(v.toUpperCase()))
                            ? "Invalid GST"
                            : null,
                      ),
                      TextFormField(
                        controller: _fssaiCtrl,
                        style: const TextStyle(color: textPrimary),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 14,
                        decoration: _inputDeco(
                          "FSSAI License (Optional)",
                        ).copyWith(counterText: ""),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- SECTION 4 ---
                    _buildSectionTitle("4. Operations", Icons.access_time),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                              const SizedBox(height: 20),
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
                              const SizedBox(height: 20),
                              TextFormField(
                                key: _kCounters,
                                controller: _countersCtrl,
                                style: const TextStyle(color: textPrimary),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDeco("Billing Counters *"),
                                validator: (v) {
                                  int val = int.tryParse(v ?? '') ?? 0;
                                  return (val < 1 || val > 50)
                                      ? "1 to 50"
                                      : null;
                                },
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
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
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: TextFormField(
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
                              const SizedBox(width: 20),
                              Expanded(
                                child: TextFormField(
                                  key: _kCounters,
                                  controller: _countersCtrl,
                                  style: const TextStyle(color: textPrimary),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _inputDeco("Billing Counters *"),
                                  validator: (v) {
                                    int val = int.tryParse(v ?? '') ?? 0;
                                    return (val < 1 || val > 50)
                                        ? "1 to 50"
                                        : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 40),

                    /* FUTURE UPDATE: UNCOMMENT WHEN MANAGER SYSTEM IS REINTEGRATED INTO STORE CREATION
                    // --- SECTION 5 ---
                    _buildSectionTitle(
                      "5. Manager Assignment",
                      Icons.manage_accounts,
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Manager will receive a secure Magic Link on their email to login via ClickOut Manager App.",
                              style: TextStyle(
                                color: Colors.blueAccent.shade100,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      key: _kMgrName,
                      controller: _mgrNameCtrl,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco("Manager Full Name *"),
                      validator: (v) => v!.trim().isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    // 噫 MANAGER EMP ID & NAME ROW
                    _responsiveRow(
                      isMobile,
                      TextFormField(
                        key: _kMgrEmpId,
                        controller: _mgrEmpIdCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: textPrimary),
                        decoration: _inputDeco(
                          "Manager EMP ID *",
                          hint: "e.g. EMP-001",
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9-]'),
                          ),
                        ],
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      TextFormField(
                        key: _kMgrName,
                        controller: _mgrNameCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _inputDeco("Manager Full Name *"),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 噫 MANAGER PHONE & EMAIL ROW
                    _responsiveRow(
                      isMobile,
                      TextFormField(
                        key: _kMgrPhone,
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
                        key: _kMgrEmail,
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
                    */

                    // --- SECTION 6 (Bank Fallback) ---
                    _buildSectionTitle(
                      "5. Bank Details (Optional)", // Changed from 6 to 5 due to comment out
                      Icons.account_balance,
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "If not filled, this store will use the company's default bank account for settlements.",
                              style: TextStyle(
                                color: Colors.amber.shade200,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      key: _kAccName,
                      controller: _accNameCtrl,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco("Account Holder Name"),
                    ),
                    const SizedBox(height: 20),
                    _responsiveRow(
                      isMobile,
                      TextFormField(
                        key: _kAccNo,
                        focusNode: _accNoFocus,
                        controller: _accNoCtrl,
                        style: const TextStyle(color: textPrimary),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDeco("Account Number"),
                        onChanged: (v) {
                          if (_accNoFocus.hasFocus) _fullAccountNumber = v;
                        },
                      ),
                      TextFormField(
                        key: _kIfsc,
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
                      key: _kUpi,
                      controller: _upiCtrl,
                      style: const TextStyle(color: textPrimary),
                      decoration: _inputDeco("Settlement UPI ID (Optional)"),
                    ),
                  ],
                ),
              ),
            ),
            // FOOTER (SUBMIT)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: accentGreen.withValues(alpha: 0.15)),
                ),
              ),
              child: isMobile
                  // 📱 MOBILE BUTTONS (STACKED) 📱
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGreen,
                              foregroundColor: bgDark,
                              padding: const EdgeInsets.symmetric(vertical: 20),
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
                                      color: bgDark,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "CREATE STORE",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  // 💻 DESKTOP BUTTONS (ROW) 💻
                  : Row(
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
                            backgroundColor: accentGreen,
                            foregroundColor: bgDark,
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
                                    color: bgDark,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "CREATE STORE",
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
