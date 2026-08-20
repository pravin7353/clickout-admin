import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../features/onboarding/widgets/simulations_coach_overlay.dart';

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

  bool _sameAsNamePhone = true;
  bool _sameAsLocation = true;
  bool _sameAsLicenses = true;
  bool _useTenantBank = true;
  Map<String, dynamic>? _tenantData;
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

  bool _isFetchingLocation = false;
  bool _isLocationVerified = false;
  bool _isFetchingBank = false;
  bool _isBankVerified = false;

  Future<void> _fetchTenantData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenantId)
          .get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _tenantData = doc.data();
            _applyInheritance();
          });
        }
      }
    } finally {
      // no-op: _isFetchingTenant was write-only and has been removed
    }
  }

  void _applyInheritance() {
    if (_tenantData == null) return;

    if (_sameAsNamePhone) {
      _storeNameCtrl.text =
          _tenantData!['companyName']?.toString() ?? widget.companyName;
      final phone = _tenantData!['contact']?['phone']?.toString();
      if (phone != null && phone.isNotEmpty) _phoneControllers[0].text = phone;
    } else {
      _storeNameCtrl.clear();
      _phoneControllers[0].clear();
    }

    if (_sameAsLocation) {
      final loc = _tenantData!['location'] as Map<String, dynamic>? ?? {};
      _addressCtrl.text = loc['address']?.toString() ?? '';
      _cityCtrl.text = loc['city']?.toString() ?? '';
      _pincodeCtrl.text = loc['pincode']?.toString() ?? '';
      String inheritedState = loc['state']?.toString() ?? '';
      _selectedState = _states.contains(inheritedState) ? inheritedState : null;
      if (_pincodeCtrl.text.length == 6) _isLocationVerified = true;
    } else {
      _addressCtrl.clear();
      _cityCtrl.clear();
      _pincodeCtrl.clear();
      _selectedState = null;
    }

    if (_sameAsLicenses) {
      _dynamicLicenses.clear();
      final licenses = _tenantData!['licenses'] as List?;
      if (licenses != null && licenses.isNotEmpty) {
        for (var lic in licenses) {
          _dynamicLicenses.add({
            'type': lic['type'].toString(),
            'number': lic['number'].toString(),
          });
        }
      }
    } else {
      _dynamicLicenses.clear();
    }

    if (_useTenantBank) {
      final bank = _tenantData!['bankDetails'] as Map<String, dynamic>? ?? {};
      _accNameCtrl.text = bank['accountName']?.toString() ?? '';
      _fullAccountNumber = bank['accountNo']?.toString() ?? '';
      _accNoCtrl.text = _fullAccountNumber;
      _ifscCtrl.text = bank['ifsc']?.toString() ?? '';
      _bankNameCtrl.text = bank['bankName']?.toString() ?? '';
      _upiCtrl.text = bank['upi']?.toString() ?? '';
      if (_ifscCtrl.text.length == 11) _isBankVerified = true;
    } else {
      _accNameCtrl.clear();
      _accNoCtrl.clear();
      _fullAccountNumber = '';
      _ifscCtrl.clear();
      _bankNameCtrl.clear();
      _upiCtrl.clear();
    }
    setState(() {});
  }

  void _addLicenseRow() {
    setState(() {
      _dynamicLicenses.add({'type': 'GSTIN', 'number': ''});
    });
  }

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
            if (mounted) {
              setState(() {
                _cityCtrl.text = postOffice['District'] ?? postOffice['Block'];
                String fetchedState = postOffice['State'];
                _selectedState = _states.contains(fetchedState)
                    ? fetchedState
                    : null;
                _isLocationVerified = true;
                _isFetchingLocation = false;
                _autoGenerateBranchCode();
              });
            }
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
    } else {
      setState(() {
        _isLocationVerified = false;
        _isFetchingLocation = false;
      });
    }
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
          if (mounted) {
            setState(() {
              _bankNameCtrl.text = "${data['BANK']} (${data['BRANCH']})";
              _isBankVerified = true;
              _isFetchingBank = false;
              if (_accNameCtrl.text.isEmpty)
                _accNameCtrl.text = _storeNameCtrl.text.toUpperCase();
            });
          }
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
    } else {
      setState(() {
        _isBankVerified = false;
        _isFetchingBank = false;
        _bankNameCtrl.clear();
      });
    }
  }

  static const Color bgDark = Color(0xFF080B08);
  static const Color cardDark = Color(0xFF111811);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF1A221A);

  final _storeNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();

  // Manager Details Controllers
  final _managerEmailCtrl = TextEditingController();
  final _managerEmpIdCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();
  final _managerPhoneCtrl = TextEditingController();

  final List<TextEditingController> _phoneControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _landlineControllers = [
    TextEditingController(),
  ];
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String? _selectedState;

  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final FocusNode _accNoFocus = FocusNode();
  String _fullAccountNumber = '';

  final _kStoreName = GlobalKey();
  final _kBranchCode = GlobalKey();
  final _kPhone = GlobalKey();
  final _kAddress = GlobalKey();
  final _kCity = GlobalKey();
  final _kState = GlobalKey();
  final _kPincode = GlobalKey();
  final _kAccName = GlobalKey();
  final _kAccNo = GlobalKey();
  final _kIfsc = GlobalKey();
  final _kUpi = GlobalKey();

  bool _isBranchCodeManuallyEdited = false;
  bool _isBranchChecking = false;
  String? _branchError;

  Future<void> _checkBranchCode(String code) async {
    if (code.trim().length < 3) {
      setState(() => _branchError = null);
      return;
    }
    setState(() {
      _isBranchChecking = true;
      _branchError = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('tenantId', isEqualTo: widget.tenantId)
          .where('branchCode', isEqualTo: code.trim().toUpperCase())
          .get();
      if (mounted)
        setState(() {
          _isBranchChecking = false;
          _branchError = snap.docs.isNotEmpty
              ? 'Branch Code already exists!'
              : null;
        });
    } catch (e) {
      if (mounted) setState(() => _isBranchChecking = false);
    }
  }

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
    _fetchTenantData();
    _storeNameCtrl.addListener(_autoGenerateBranchCode);
    _cityCtrl.addListener(_autoGenerateBranchCode);

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
    _managerEmailCtrl.dispose();
    _managerEmpIdCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    for (var ctrl in _phoneControllers) {
      ctrl.dispose();
    }
    for (var ctrl in _landlineControllers) {
      ctrl.dispose();
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

  void _autoGenerateBranchCode() {
    if (_isBranchCodeManuallyEdited) return;
    String prefix = _storeNameCtrl.text.replaceAll(' ', '').toUpperCase();
    if (prefix.isEmpty)
      prefix = widget.companyName.replaceAll(' ', '').toUpperCase();
    prefix = prefix.length >= 3 ? prefix.substring(0, 3) : prefix;

    String city = _cityCtrl.text.replaceAll(' ', '').toUpperCase();
    city = city.length >= 3 ? city.substring(0, 3) : city;

    if (city.isNotEmpty && prefix.isNotEmpty) {
      _branchCodeCtrl.text = "${prefix}_${city}_001";
      _checkBranchCode(_branchCodeCtrl.text);
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

  Future<void> _submit() async {
    if (_storeNameCtrl.text.trim().length < 3) return _scrollTo(_kStoreName);
    if (_branchCodeCtrl.text.trim().isEmpty) return _scrollTo(_kBranchCode);

    setState(() => _isLoading = true);
    final branchCode = _branchCodeCtrl.text.trim().toUpperCase();
    final managerEmail = _managerEmailCtrl.text.trim().toLowerCase();
    final db = FirebaseFirestore.instance;

    final duplicateCheck = await db
        .collection('stores')
        .where('tenantId', isEqualTo: widget.tenantId)
        .where('branchCode', isEqualTo: branchCode)
        .get();

    if (duplicateCheck.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: Branch Code '$branchCode' already exists in this tenant!",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      _scrollTo(_kBranchCode);
      return;
    }

    final existingManager = await db
        .collection('staff')
        .where('email', isEqualTo: managerEmail)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (existingManager.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: This email is already assigned to an active operational account.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_phoneControllers.first.text.trim().length != 10)
      return _scrollTo(_kPhone);
    if (_addressCtrl.text.trim().isEmpty) return _scrollTo(_kAddress);
    if (_cityCtrl.text.trim().isEmpty) return _scrollTo(_kCity);
    if (_selectedState == null) return _scrollTo(_kState);
    if (_pincodeCtrl.text.trim().length != 6) return _scrollTo(_kPincode);

    if (!_useTenantBank) {
      if (_accNameCtrl.text.trim().isEmpty) return _scrollTo(_kAccName);
      if (_fullAccountNumber.length < 9) return _scrollTo(_kAccNo);
      if (!RegExp(
        r'^[A-Z]{4}0[A-Z0-9]{6}$',
      ).hasMatch(_ifscCtrl.text.trim().toUpperCase()))
        return _scrollTo(_kIfsc);
      if (_upiCtrl.text.trim().isNotEmpty && !_upiCtrl.text.contains('@'))
        return _scrollTo(_kUpi);
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final batch = db.batch();
      final storeRef = db.collection('stores').doc();
      final staffRef = db.collection('staff').doc();
      final adminEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin';

      batch.set(staffRef, {
        'docId': staffRef.id,
        'email': _managerEmailCtrl.text.trim().toLowerCase(),
        'name': _managerNameCtrl.text.trim(),
        'phone': _managerPhoneCtrl.text.trim(),
        'role': 'MANAGER',
        'tenantId': widget.tenantId,
        'storeId': storeRef.id,
        'branchCode': _branchCodeCtrl.text.trim().toUpperCase(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Map<String, dynamic> finalBankDetails = {};
      if (!_useTenantBank) {
        finalBankDetails = {
          'isCustom': true,
          'accountName': _accNameCtrl.text.trim(),
          'accountNo': _fullAccountNumber,
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'bankName': _bankNameCtrl.text.trim(),
          'upi': _upiCtrl.text.trim(),
        };
      } else {
        final tenantDoc = await db
            .collection('tenants')
            .doc(widget.tenantId)
            .get();
        final tenantBank = tenantDoc.data()?['bankDetails'] ?? {};
        finalBankDetails = {
          'isCustom': false,
          'accountName': tenantBank['accountName'] ?? '',
          'accountNo': tenantBank['accountNo'] ?? '',
          'ifsc': tenantBank['ifsc'] ?? '',
          'bankName': tenantBank['bankName'] ?? '',
          'upi': tenantBank['upi'] ?? '',
        };
      }

      batch.set(storeRef, {
        'storeId': storeRef.id,
        'tenantId': widget.tenantId,
        'storeName': _storeNameCtrl.text.trim(),
        'branchCode': _branchCodeCtrl.text.trim().toUpperCase(),
        'managerEmail': _managerEmailCtrl.text.trim().toLowerCase(),
        'managerEmpId': _managerEmpIdCtrl.text.trim(),
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
        'location': {
          'address': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _selectedState,
          'pincode': _pincodeCtrl.text.trim(),
        },
        'licenses': _dynamicLicenses,
        'bankDetails': finalBankDetails,
        'status': 'ACTIVE',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Store '${_storeNameCtrl.text.trim()}' created!"),
            backgroundColor: accentGreen,
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
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
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
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 15),
      child: Row(
        children: [
          Icon(icon, color: accentGreen, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: accentGreen,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            activeColor: accentGreen,
            side: const BorderSide(color: Colors.white54, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

    return SimulationCoachOverlay(
      message:
          "Let's drop your first Store node on the map. Click the button below to auto-fill dummy data for a quick test.",
      themeColor: accentGreen,
      actionLabel: "AUTO-FILL DUMMY DATA",
      onAction: () {
        setState(() {
          _sameAsNamePhone = false;
          _sameAsLocation = false;
          _sameAsLicenses = false;
          _useTenantBank = false;
          _storeNameCtrl.text = "ClickOut Prime Node";
          _branchCodeCtrl.text = "CLK_PRM_01";
          _managerEmailCtrl.text = "manager.prime@clickout.in";
          _managerNameCtrl.text = "John Doe";
          _managerEmpIdCtrl.text = "EMP-001";
          _managerPhoneCtrl.text = "9988776655";
          _phoneControllers[0].text = "9988776655";
          _isBranchCodeManuallyEdited = true;
        });
      },
      child: Dialog(
        backgroundColor: bgDark,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentGreen.withValues(alpha: 0.2)),
        ),
        child: Container(
          width: isMobile ? double.infinity : 850,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: accentGreen.withValues(alpha: 0.15)),
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
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.w900,
                        ),
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: accentGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: accentGreen,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Information entered here automatically orchestrates store deployments, invoicing, tax compliance architectures, and fallback settlement rules.",
                                style: TextStyle(
                                  color: accentGreen,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            "1. Basic Store Details",
                            Icons.storefront,
                          ),
                          _compactCheckbox(
                            "Same as Company",
                            _sameAsNamePhone,
                            (v) => setState(() {
                              _sameAsNamePhone = v!;
                              _applyInheritance();
                            }),
                          ),
                        ],
                      ),
                      _responsiveRow(
                        isMobile,
                        TextFormField(
                          key: _kStoreName,
                          controller: _storeNameCtrl,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDeco(
                            "Store / Branch Name *",
                            hint: "e.g. Jaiswar Flour Mill",
                          ),
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? "Min 3 chars"
                              : null,
                        ),
                        TextFormField(
                          key: _kBranchCode,
                          controller: _branchCodeCtrl,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDeco(
                            "Branch Code *",
                            hint: "e.g. JAI_MUM_001",
                            suffix: _isBranchChecking
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : (_branchError == null &&
                                          _branchCodeCtrl.text.length >= 3
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : null),
                          ).copyWith(errorText: _branchError),
                          onChanged: (v) {
                            _isBranchCodeManuallyEdited = true;
                            _checkBranchCode(v);
                          },
                          validator: (v) => v!.trim().isEmpty
                              ? "Required"
                              : (_branchError != null
                                    ? "Duplicate Code"
                                    : null),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _responsiveRow(
                        isMobile,
                        TextFormField(
                          key: _kPhone,
                          controller: _phoneControllers[0],
                          style: const TextStyle(color: textPrimary),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDeco(
                            "Primary Mobile *",
                            prefix: const Icon(
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
                          style: const TextStyle(color: textPrimary),
                          keyboardType: TextInputType.phone,
                          decoration: _inputDeco(
                            "Primary Landline (Optional)",
                            prefix: const Icon(
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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            "2. Location Context",
                            Icons.location_on,
                          ),
                          _compactCheckbox(
                            "Same as Company",
                            _sameAsLocation,
                            (v) => setState(() {
                              _sameAsLocation = v!;
                              _applyInheritance();
                            }),
                          ),
                        ],
                      ),
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: _kPincode,
                                  controller: _pincodeCtrl,
                                  style: const TextStyle(color: textPrimary),
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
                                            child: CircularProgressIndicator(
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
                                  validator: (v) => (v == null || v.length != 6)
                                      ? "6 digits required"
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: _kCity,
                                  controller: _cityCtrl,
                                  style: const TextStyle(color: textPrimary),
                                  decoration: _inputDeco("City *"),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? "Required" : null,
                                ),
                                const SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  key: _kState,
                                  isExpanded: true,
                                  value: _selectedState,
                                  dropdownColor: inputBg,
                                  style: const TextStyle(color: textPrimary),
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
                                    key: _kPincode,
                                    controller: _pincodeCtrl,
                                    style: const TextStyle(color: textPrimary),
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
                                              child: CircularProgressIndicator(
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
                                    key: _kCity,
                                    controller: _cityCtrl,
                                    style: const TextStyle(color: textPrimary),
                                    decoration: _inputDeco("City *"),
                                    validator: (v) =>
                                        v!.trim().isEmpty ? "Required" : null,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: _kState,
                                    isExpanded: true,
                                    value: _selectedState,
                                    dropdownColor: inputBg,
                                    style: const TextStyle(color: textPrimary),
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
                                ),
                              ],
                            ),
                      const SizedBox(height: 15),
                      TextFormField(
                        key: _kAddress,
                        controller: _addressCtrl,
                        style: const TextStyle(color: textPrimary),
                        decoration: _inputDeco("Complete Store Address *"),
                        validator: (v) => v!.trim().isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 25),

                      // 🚀 NEW SECTION: MANAGER DETAILS
                      _buildSectionTitle("3. Manager Details", Icons.badge),
                      _responsiveRow(
                        isMobile,
                        TextFormField(
                          controller: _managerNameCtrl,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDeco(
                            "Manager Full Name *",
                            hint: "e.g. Rahul Sharma",
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? "Required" : null,
                        ),
                        TextFormField(
                          controller: _managerEmpIdCtrl,
                          style: const TextStyle(color: textPrimary),
                          decoration: _inputDeco(
                            "Manager Employee ID *",
                            hint: "e.g. EMP-001",
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
                          style: const TextStyle(color: textPrimary),
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
                          style: const TextStyle(color: textPrimary),
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDeco(
                            "Manager Login Email *",
                            hint: "e.g. manager@store.com",
                            prefix: const Icon(
                              Icons.email_outlined,
                              size: 18,
                              color: textSecondary,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || !v.contains('@'))
                              return "Valid Email Required";
                            final adminEmail =
                                FirebaseAuth.instance.currentUser?.email;
                            if (v.trim().toLowerCase() ==
                                adminEmail?.toLowerCase()) {
                              return "Cannot use HQ Owner email for Store Manager";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildSectionTitle(
                                "4. Legal & Compliance",
                                Icons.gavel,
                              ),
                              const SizedBox(width: 15),
                              _compactCheckbox(
                                "Same as Company",
                                _sameAsLicenses,
                                (v) => setState(() {
                                  _sameAsLicenses = v!;
                                  _applyInheritance();
                                }),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _addLicenseRow,
                            icon: const Icon(
                              Icons.add,
                              color: accentGreen,
                              size: 16,
                            ),
                            label: const Text(
                              "Add",
                              style: TextStyle(color: accentGreen),
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
                              style: const TextStyle(color: textPrimary),
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
                              style: const TextStyle(color: textPrimary),
                              textCapitalization: TextCapitalization.characters,
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
                                if (v == null || v.isEmpty) return "Required";
                                if (!isValid)
                                  return config['errorMsg'] as String;
                                return null;
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            "5. Banking & Settlement Node",
                            Icons.account_balance,
                          ),
                          _compactCheckbox("Same as Company", _useTenantBank, (
                            v,
                          ) {
                            setState(() {
                              _useTenantBank = v!;
                              if (v) {
                                _applyInheritance();
                              } else {
                                _accNameCtrl.clear();
                                _accNoCtrl.clear();
                                _fullAccountNumber = '';
                                _ifscCtrl.clear();
                                _bankNameCtrl.clear();
                                _upiCtrl.clear();
                              }
                            });
                          }),
                        ],
                      ),

                      TextFormField(
                        controller: _accNameCtrl,
                        readOnly: _useTenantBank,
                        style: TextStyle(
                          color: _useTenantBank ? textSecondary : textPrimary,
                        ),
                        decoration: _inputDeco(
                          "Store Account Holder Name *",
                          isReadOnly: _useTenantBank,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _responsiveRow(
                        isMobile,
                        TextFormField(
                          key: _kIfsc,
                          controller: _ifscCtrl,
                          readOnly: _useTenantBank,
                          style: TextStyle(
                            color: _useTenantBank ? textSecondary : textPrimary,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 11,
                          onChanged: _useTenantBank ? null : _onIfscChanged,
                          decoration: _inputDeco(
                            "IFSC Code *",
                            isReadOnly: _useTenantBank,
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
                          style: const TextStyle(color: textSecondary),
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
                          focusNode: _useTenantBank ? null : _accNoFocus,
                          controller: _accNoCtrl,
                          readOnly: _useTenantBank,
                          style: TextStyle(
                            color: _useTenantBank ? textSecondary : textPrimary,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _inputDeco(
                            "Store Settlement Account *",
                            isReadOnly: _useTenantBank,
                          ),
                          onChanged: (v) {
                            if (_accNoFocus.hasFocus) _fullAccountNumber = v;
                          },
                        ),
                        TextFormField(
                          key: _kUpi,
                          controller: _upiCtrl,
                          readOnly: _useTenantBank,
                          style: TextStyle(
                            color: _useTenantBank ? textSecondary : textPrimary,
                          ),
                          decoration: _inputDeco(
                            "Settlement UPI ID (Optional)",
                            isReadOnly: _useTenantBank,
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
                    top: BorderSide(color: accentGreen.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
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
                        backgroundColor: accentGreen,
                        foregroundColor: bgDark,
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
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: bgDark,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "DEPLOY STORE",
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
      ),
    );
  }
}
