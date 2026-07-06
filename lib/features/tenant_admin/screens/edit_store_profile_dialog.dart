import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

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

  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  Color get accentBlue => context.colors.success; // Ya ctaBackground
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => Theme.of(context).brightness == Brightness.dark
      ? Colors.white10
      : Colors.black12;

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
    'Fire NOC',
    'Other',
  ];

  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _kIfsc = GlobalKey();
  final _kAccNo = GlobalKey();
  final _kUpi = GlobalKey();
  final FocusNode _accNoFocus = FocusNode();
  String _fullAccountNumber = '';
  bool _useTenantBank = true;

  // Manager Details Controllers
  final _managerEmailCtrl = TextEditingController();
  final _managerEmpIdCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();
  final _managerPhoneCtrl = TextEditingController();

  bool _isAdmin = false;
  bool _isManagerView = true;

  bool _isFetchingLocation = false;
  bool _isLocationVerified = false;
  bool _isFetchingBank = false;
  bool _isBankVerified = false;

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

          _managerEmailCtrl.text = data['managerEmail'] ?? '';
          _managerEmpIdCtrl.text = data['managerEmpId'] ?? '';
          _managerNameCtrl.text = data['managerName'] ?? '';
          _managerPhoneCtrl.text = data['managerPhone'] ?? '';

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final staffSnap = await FirebaseFirestore.instance
                .collection('staff')
                .where('email', isEqualTo: currentUser.email)
                .limit(1)
                .get();
            if (staffSnap.docs.isNotEmpty) {
              final r =
                  staffSnap.docs.first
                      .data()['role']
                      ?.toString()
                      .toUpperCase() ??
                  '';
              _isAdmin =
                  (r == 'TENANT_ADMIN' ||
                  r == 'SUPER_ADMIN' ||
                  r == 'OWNER' ||
                  r == 'TENANT');
              _isManagerView = !_isAdmin;
            }
          }

          List phones = data['contactNumbers'] ?? [];
          if (phones.isEmpty) _phoneControllers.add(TextEditingController());
          for (var p in phones)
            _phoneControllers.add(TextEditingController(text: p.toString()));

          List landlines = data['landlineNumbers'] ?? [];
          if (landlines.isEmpty)
            _landlineControllers.add(TextEditingController());
          for (var l in landlines)
            _landlineControllers.add(TextEditingController(text: l.toString()));

          final loc = data['location'] ?? {};
          _addressCtrl.text = loc['address'] ?? '';
          _cityCtrl.text = loc['city'] ?? '';
          _pincodeCtrl.text = loc['pincode'] ?? '';
          if (_states.contains(loc['state'])) _selectedState = loc['state'];
          if (_pincodeCtrl.text.length == 6) _isLocationVerified = true;

          List lics = data['licenses'] ?? [];
          for (var lic in lics) {
            _dynamicLicenses.add({
              'type': lic['type'].toString(),
              'number': lic['number'].toString(),
            });
          }

          final bank = data['bankDetails'] ?? {};
          _useTenantBank = bank['isCustom'] != true;

          _accNameCtrl.text = bank['accountName']?.toString() ?? '';
          _fullAccountNumber = bank['accountNo']?.toString() ?? '';
          _accNoCtrl.text = _fullAccountNumber;
          _ifscCtrl.text = bank['ifsc']?.toString() ?? '';
          _upiCtrl.text = bank['upi']?.toString() ?? '';
          _bankNameCtrl.text = bank['bankName']?.toString() ?? '';
          if (_ifscCtrl.text.length == 11) _isBankVerified = true;
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
    _managerEmailCtrl.dispose();
    _managerEmpIdCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    for (var c in _phoneControllers) {
      c.dispose();
    }
    for (var c in _landlineControllers) {
      c.dispose();
    }
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLicenseRow() =>
      setState(() => _dynamicLicenses.add({'type': 'GSTIN', 'number': ''}));

  Map<String, dynamic> _getLicenseConfig(String type) {
    switch (type) {
      case 'GSTIN':
        return {
          'label': 'GST Number *',
          'hint': '27ABCDE1234F1Z5',
          'maxLength': 15,
          'keyboard': TextInputType.text,
          'formatters': [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          'regex': r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{3}$',
          'errorMsg': 'Invalid 15-digit GST format',
        };
      default:
        return {
          'label': 'Registration Code *',
          'hint': 'Enter code',
          'maxLength': 30,
          'keyboard': TextInputType.text,
          'formatters': <TextInputFormatter>[],
          'regex': r'^.{3,30}$',
          'errorMsg': 'Required',
        };
    }
  }

  Future<void> _onPincodeChanged(String val) async {
    if (val.length == 6) {
      setState(() {
        _isFetchingLocation = true;
        _isLocationVerified = false;
      });
      try {
        final response = await http
            .get(Uri.parse('https://api.postalpincode.in/pincode/$val'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data[0]['Status'] == 'Success') {
            final postOffice = data[0]['PostOffice'][0];
            if (mounted)
              setState(() {
                _cityCtrl.text = postOffice['District'] ?? postOffice['Block'];
                String fetchedState = postOffice['State'];
                _selectedState = _states.contains(fetchedState)
                    ? fetchedState
                    : null;
                _isLocationVerified = true;
                _isFetchingLocation = false;
              });
            return;
          }
        }
      } catch (e) {
        debugPrint("Pincode API Fallback: $e");
      }
      if (mounted)
        setState(() {
          _isFetchingLocation = false;
          _isLocationVerified = false;
          _cityCtrl.clear();
          _selectedState = null;
        });
    } else
      setState(() {
        _isLocationVerified = false;
        _isFetchingLocation = false;
      });
  }

  Future<void> _onIfscChanged(String val) async {
    if (val.length == 11) {
      setState(() {
        _isFetchingBank = true;
        _isBankVerified = false;
      });
      try {
        final response = await http
            .get(Uri.parse('https://ifsc.razorpay.com/${val.toUpperCase()}'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted)
            setState(() {
              _bankNameCtrl.text = "${data['BANK']} (${data['BRANCH']})";
              _isBankVerified = true;
              _isFetchingBank = false;
              if (_accNameCtrl.text.isEmpty)
                _accNameCtrl.text = _storeNameCtrl.text.toUpperCase();
            });
          return;
        }
      } catch (e) {
        debugPrint("IFSC API Fallback: $e");
      }
      if (mounted)
        setState(() {
          _isFetchingBank = false;
          _isBankVerified = false;
          _bankNameCtrl.clear();
        });
    } else
      setState(() {
        _isBankVerified = false;
        _isFetchingBank = false;
        _bankNameCtrl.clear();
      });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _targetDocId == null) return;

    if (!_useTenantBank) {
      if (_fullAccountNumber.length < 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Valid account number required")),
        );
        return;
      }
      if (!RegExp(
        r'^[A-Z]{4}0[A-Z0-9]{6}$',
      ).hasMatch(_ifscCtrl.text.trim().toUpperCase())) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Valid IFSC required")));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final storeRef = db.collection('stores').doc(_targetDocId);

      final updateData = {
        'storeName': _storeNameCtrl.text.trim(),
        'managerName': _managerNameCtrl.text.trim(),
        'managerPhone': _managerPhoneCtrl.text.trim(),
        'contactNumbers': _phoneControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'landlineNumbers': _landlineControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'location.address': _addressCtrl.text.trim(),
        'location.city': _cityCtrl.text.trim(),
        'location.state': _selectedState,
        'location.pincode': _pincodeCtrl.text.trim(),
        'licenses': _dynamicLicenses,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isAdmin) {
        updateData['managerEmail'] = _managerEmailCtrl.text
            .trim()
            .toLowerCase();
        updateData['managerEmpId'] = _managerEmpIdCtrl.text.trim();
      }

      if (!_useTenantBank && _isAdmin) {
        updateData['bankDetails.isCustom'] = true;
        updateData['bankDetails.accountName'] = _accNameCtrl.text.trim();
        updateData['bankDetails.accountNo'] = _fullAccountNumber;
        updateData['bankDetails.ifsc'] = _ifscCtrl.text.trim().toUpperCase();
        updateData['bankDetails.bankName'] = _bankNameCtrl.text.trim();
        updateData['bankDetails.upi'] = _upiCtrl.text.trim();
      } else if (_isAdmin) {
        updateData['bankDetails.isCustom'] = false;
      }

      await storeRef.update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Store Updated Successfully!"),
            backgroundColor: accentBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco(
    String label, {
    String? hint,
    Widget? prefix,
    Widget? suffix,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      labelStyle: TextStyle(color: textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      filled: true,
      fillColor: isReadOnly ? inputBg.withOpacity(0.55) : inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:  BorderSide(color: accentBlue, width: 1.5),
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
      padding: const EdgeInsets.only(bottom: 20, top: 15),
      child: Row(
        children: [
          Icon(icon, color: accentBlue, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: accentBlue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveRow(bool isMobile, Widget child1, Widget child2) {
    if (isMobile)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child1, const SizedBox(height: 20), child2],
      );
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
        width: isMobile ? double.infinity : 850,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _isFetching
            ? Center(child: CircularProgressIndicator(color: accentBlue))
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
                         Text(
                          "Update Operational Node",
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon:  Icon(Icons.close, color: textSecondary),
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentBlue.withOpacity(0.2),
                              ),
                            ),
                            child:  Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: accentBlue,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Updating profile will automatically re-sync store routing, invoicing models, and compliance architectures for this branch.",
                                    style: TextStyle(
                                      color: accentBlue,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildSectionTitle(
                            "1. Basic Store Details",
                            Icons.storefront,
                          ),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _storeNameCtrl,
                              style:  TextStyle(color: textPrimary),
                              decoration: _inputDeco(
                                "Store / Branch Name *",
                                hint: "e.g. Jaiswar Flour Mill",
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 3)
                                  ? "Min 3 chars"
                                  : null,
                            ),
                            TextFormField(
                              controller: _branchCodeCtrl,
                              readOnly: true,
                              style:  TextStyle(color: textSecondary),
                              decoration: _inputDeco(
                                "Branch Code (Protected)",
                                prefix:  Icon(
                                  Icons.lock,
                                  color: textSecondary,
                                  size: 16,
                                ),
                                isReadOnly: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _phoneControllers[0],
                              style:  TextStyle(color: textPrimary),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco(
                                "Primary Mobile *",
                                prefix:  Icon(
                                  Icons.phone_android,
                                  size: 18,
                                  color: textSecondary,
                                ),
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  (v == null ||
                                      !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                                  ? "Invalid Mobile"
                                  : null,
                            ),
                            TextFormField(
                              controller: _landlineControllers[0],
                              style:  TextStyle(color: textPrimary),
                              keyboardType: TextInputType.phone,
                              decoration: _inputDeco(
                                "Primary Landline (Optional)",
                                prefix:  Icon(
                                  Icons.phone,
                                  size: 18,
                                  color: textSecondary,
                                ),
                                hint: "e.g. 022-12345678",
                              ),
                              validator: (v) =>
                                  (v != null &&
                                      v.trim().isNotEmpty &&
                                      !RegExp(
                                        r'^[0-9]{3,4}[-\s]?[0-9]{6,8}$',
                                      ).hasMatch(v.trim()))
                                  ? "Invalid format"
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 25),

                          _buildSectionTitle(
                            "2. Location Context",
                            Icons.location_on,
                          ),
                          isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _pincodeCtrl,
                                      style: TextStyle(
                                        color: textPrimary,
                                      ),
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: _onPincodeChanged,
                                      decoration: _inputDeco(
                                        "Pincode *",
                                        suffix: _isFetchingLocation
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : (_isLocationVerified
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                    )
                                                  : null),
                                      ).copyWith(counterText: ""),
                                      validator: (v) =>
                                          (v == null || v.length != 6)
                                          ? "6 digits required"
                                          : null,
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _cityCtrl,
                                      style: TextStyle(
                                        color: textPrimary,
                                      ),
                                      decoration: _inputDeco("City *"),
                                      validator: (v) =>
                                          v!.trim().isEmpty ? "Required" : null,
                                    ),
                                    const SizedBox(height: 20),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _selectedState,
                                      dropdownColor: inputBg,
                                      style: TextStyle(
                                        color: textPrimary,
                                      ),
                                      decoration: _inputDeco("State *"),
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
                                      validator: (v) =>
                                          v == null ? "Required" : null,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _pincodeCtrl,
                                        style:  TextStyle(
                                          color: textPrimary,
                                        ),
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        onChanged: _onPincodeChanged,
                                        decoration: _inputDeco(
                                          "Pincode *",
                                          suffix: _isFetchingLocation
                                              ? const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : (_isLocationVerified
                                                    ? const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                      )
                                                    : null),
                                        ).copyWith(counterText: ""),
                                        validator: (v) =>
                                            (v == null || v.length != 6)
                                            ? "6 digits required"
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _cityCtrl,
                                        style:  TextStyle(
                                          color: textPrimary,
                                        ),
                                        decoration: _inputDeco("City *"),
                                        validator: (v) => v!.trim().isEmpty
                                            ? "Required"
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: _selectedState,
                                        dropdownColor: inputBg,
                                        style:  TextStyle(
                                          color: textPrimary,
                                        ),
                                        decoration: _inputDeco("State *"),
                                        items: _states
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(
                                                  e,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => _selectedState = v),
                                        validator: (v) =>
                                            v == null ? "Required" : null,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _addressCtrl,
                            style:  TextStyle(color: textPrimary),
                            decoration: _inputDeco("Complete Store Address *"),
                            validator: (v) =>
                                v!.trim().isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 25),

                          // 🚀 NEW SECTION: MANAGER DETAILS (RBAC Applied)
                          _buildSectionTitle("3. Manager Details", Icons.badge),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _managerNameCtrl,
                              style:  TextStyle(color: textPrimary),
                              decoration: _inputDeco("Manager Full Name *"),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                            TextFormField(
                              controller: _managerEmpIdCtrl,
                              readOnly: _isManagerView,
                              style: TextStyle(
                                color: _isManagerView
                                    ? textSecondary
                                    : textPrimary,
                              ),
                              decoration: _inputDeco(
                                "Manager Employee ID *",
                                isReadOnly: _isManagerView,
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              controller: _managerPhoneCtrl,
                              style:  TextStyle(color: textPrimary),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco(
                                "Manager Phone *",
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  (v == null ||
                                      !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                                  ? "Invalid Mobile"
                                  : null,
                            ),
                            TextFormField(
                              controller: _managerEmailCtrl,
                              readOnly: _isManagerView,
                              style: TextStyle(
                                color: _isManagerView
                                    ? textSecondary
                                    : textPrimary,
                              ),
                              decoration: _inputDeco(
                                "Manager Login Email *",
                                isReadOnly: _isManagerView,
                                prefix: Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                  color: textSecondary,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || !v.contains('@'))
                                  return "Valid Email Required";
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 25),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle(
                                "4. Legal & Compliance",
                                Icons.gavel,
                              ),
                              TextButton.icon(
                                onPressed: _addLicenseRow,
                                icon:  Icon(
                                  Icons.add,
                                  color: accentBlue,
                                  size: 16,
                                ),
                                label:  Text(
                                  "Add",
                                  style: TextStyle(color: accentBlue),
                                ),
                              ),
                            ],
                          ),
                          ..._dynamicLicenses.asMap().entries.map((entry) {
                            int idx = entry.key;
                            Map<String, String> lic = entry.value;
                            final config = _getLicenseConfig(
                              lic['type'] ?? 'Other',
                            );
                            final val = lic['number'] ?? '';
                            final isValid = RegExp(
                              config['regex'] as String,
                            ).hasMatch(val.toUpperCase());

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: _responsiveRow(
                                isMobile,
                                DropdownButtonFormField<String>(
                                  value: _licenseTypes.contains(lic['type'])
                                      ? lic['type']
                                      : 'Other',
                                  dropdownColor: inputBg,
                                  style:  TextStyle(color: textPrimary),
                                  decoration: _inputDeco("Compliance Type"),
                                  items: _licenseTypes
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _dynamicLicenses[idx]['type'] = v!;
                                    _dynamicLicenses[idx]['number'] = '';
                                  }),
                                ),
                                TextFormField(
                                  key: ValueKey("${idx}_${lic['type']}"),
                                  initialValue: val,
                                  style:  TextStyle(color: textPrimary),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: config['maxLength'],
                                  keyboardType: config['keyboard'],
                                  inputFormatters: config['formatters'],
                                  decoration: _inputDeco(
                                    config['label'] as String,
                                    hint: config['hint'] as String,
                                    suffix: val.isNotEmpty
                                        ? Icon(
                                            isValid
                                                ? Icons.check_circle
                                                : Icons.error_outline,
                                            color: isValid
                                                ? Colors.green
                                                : Colors.redAccent,
                                            size: 20,
                                          )
                                        : null,
                                  ).copyWith(counterText: ""),
                                  onChanged: (v) {
                                    _dynamicLicenses[idx]['number'] = v
                                        .trim()
                                        .toUpperCase();
                                    setState(() {});
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return "Required";
                                    if (!isValid)
                                      return config['errorMsg'] as String;
                                    return null;
                                  },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 25),

                          _buildSectionTitle(
                            "5. Banking & Settlement Node",
                            Icons.account_balance,
                          ),
                          if (_useTenantBank)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentBlue.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    color: accentBlue,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "This store inherits the master HQ settlement account. Bank details are read-only.",
                                      style: TextStyle(
                                        color: accentBlue,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextFormField(
                            controller: _accNameCtrl,
                            readOnly: _isManagerView,
                            style: TextStyle(
                              color: _isManagerView
                                  ? textSecondary
                                  : textPrimary,
                            ),
                            decoration: _inputDeco(
                              "Store Account Holder Name *",
                              isReadOnly: _isManagerView,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              key: _kIfsc,
                              controller: _ifscCtrl,
                              readOnly: _isManagerView,
                              style: TextStyle(
                                color: _isManagerView
                                    ? textSecondary
                                    : textPrimary,
                              ),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 11,
                              onChanged: _isManagerView ? null : _onIfscChanged,
                              decoration: _inputDeco(
                                "IFSC Code *",
                                isReadOnly: _isManagerView,
                                suffix: _isFetchingBank
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : (_isBankVerified
                                          ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                          : null),
                              ).copyWith(counterText: ""),
                            ),
                            TextFormField(
                              controller: _bankNameCtrl,
                              readOnly: true,
                              style:  TextStyle(color: textSecondary),
                              decoration: _inputDeco(
                                "Resolved Branch Name",
                                isReadOnly: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _responsiveRow(
                            isMobile,
                            TextFormField(
                              key: _kAccNo,
                              focusNode: _isManagerView ? null : _accNoFocus,
                              controller: _accNoCtrl,
                              readOnly: _isManagerView,
                              style: TextStyle(
                                color: _isManagerView
                                    ? textSecondary
                                    : textPrimary,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _inputDeco(
                                "Store Settlement Account *",
                                isReadOnly: _isManagerView,
                              ),
                              onChanged: (v) {
                                if (_accNoFocus.hasFocus)
                                  _fullAccountNumber = v;
                              },
                            ),
                            TextFormField(
                              key: _kUpi,
                              controller: _upiCtrl,
                              readOnly: _isManagerView,
                              style: TextStyle(
                                color: _isManagerView
                                    ? textSecondary
                                    : textPrimary,
                              ),
                              decoration: _inputDeco(
                                "Settlement UPI ID (Optional)",
                                isReadOnly: _isManagerView,
                              ),
                            ),
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
                          child:  Text(
                            "CANCEL",
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "UPDATE PLATFORM OS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
}
