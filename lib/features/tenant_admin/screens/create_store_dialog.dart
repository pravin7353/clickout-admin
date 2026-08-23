import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/onboarding/widgets/simulations_coach_overlay.dart';

/// A single bank account entry. A store can have more than one settlement
/// account (e.g. a supermarket commonly keeps a separate current account for
/// vendor payments vs. a primary settlement account).
class _BankAccount {
  String label;
  final TextEditingController accNameCtrl = TextEditingController();
  final TextEditingController accNoCtrl = TextEditingController();
  final TextEditingController ifscCtrl = TextEditingController();
  final TextEditingController bankNameCtrl = TextEditingController();
  final TextEditingController upiCtrl = TextEditingController();
  final FocusNode accNoFocus = FocusNode();
  String fullAccountNumber = '';
  bool isFetching = false;
  bool isVerified = false;

  _BankAccount({this.label = 'Primary Settlement'});

  void dispose() {
    accNameCtrl.dispose();
    accNoCtrl.dispose();
    ifscCtrl.dispose();
    bankNameCtrl.dispose();
    upiCtrl.dispose();
    accNoFocus.dispose();
  }

  Map<String, dynamic> toMap() => {
    'label': label,
    'accountName': accNameCtrl.text.trim(),
    'accountNo': fullAccountNumber,
    'ifsc': ifscCtrl.text.trim().toUpperCase(),
    'bankName': bankNameCtrl.text.trim(),
    'upi': upiCtrl.text.trim(),
  };
}

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

  // ---- Wizard state ----
  int _currentStep = 0;
  final List<String> _stepTitles = [
    'Store & Manager',
    'Location',
    'Licenses',
    'Banking',
  ];
  final List<IconData> _stepIcons = [
    Icons.storefront,
    Icons.location_on_outlined,
    Icons.gavel,
    Icons.account_balance,
  ];
  final _step0Key = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  bool _sameAsNamePhone = true;
  bool _sameAsLocation = true;
  bool _sameAsLicenses = true;
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

  // ---- Banking (multi-account) ----
  final List<_BankAccount> _bankAccounts = [];
  bool _bankSkipped = false;
  final List<String> _bankLabels = [
    'Primary Settlement',
    'Vendor Payments',
    'Other',
  ];

  Future<void> _fetchTenantData() async {
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
  }

  bool get _tenantHasGst {
    final gstins = _tenantData?['gstins'] as List?;
    return gstins != null && gstins.isNotEmpty;
  }

  void _applyInheritance() {
    if (_tenantData == null) return;

    if (_sameAsNamePhone) {
      _storeNameCtrl.text =
          _tenantData!['companyName']?.toString() ?? widget.companyName;
      final phone = _tenantData!['primaryContact']?['phone']?.toString();
      if (phone != null && phone.isNotEmpty) _phoneControllers[0].text = phone;
    } else {
      _storeNameCtrl.clear();
      _phoneControllers[0].clear();
    }

    if (_sameAsLocation) {
      _addressCtrl.text = _tenantData!['hoAddress']?.toString() ?? '';
      _cityCtrl.text = _tenantData!['hoCity']?.toString() ?? '';
      String inheritedState = _tenantData!['hoState']?.toString() ?? '';
      _selectedState = _states.contains(inheritedState) ? inheritedState : null;
    } else {
      _addressCtrl.clear();
      _cityCtrl.clear();
      _pincodeCtrl.clear();
      _selectedState = null;
    }

    if (_sameAsLicenses) {
      _dynamicLicenses.clear();
      final gstins = _tenantData!['gstins'] as List?;
      if (gstins != null && gstins.isNotEmpty) {
        _dynamicLicenses.add({
          'type': 'GSTIN',
          'number': gstins.first.toString(),
        });
      }
    } else {
      _dynamicLicenses.clear();
    }
    setState(() {});
  }

  void _addLicenseRow() {
    setState(() {
      _dynamicLicenses.add({'type': 'GSTIN', 'number': ''});
    });
  }

  void _addBankAccount() {
    setState(() {
      final usedLabels = _bankAccounts.map((b) => b.label).toSet();
      final nextLabel = _bankLabels.firstWhere(
        (l) => !usedLabels.contains(l),
        orElse: () => 'Other',
      );
      _bankAccounts.add(_BankAccount(label: nextLabel));
    });
  }

  void _removeBankAccount(int idx) {
    setState(() {
      _bankAccounts[idx].dispose();
      _bankAccounts.removeAt(idx);
    });
  }

  /// Per-license-type demo format so a first-time admin knows exactly what
  /// to type instead of guessing and bouncing off validation errors.
  Map<String, dynamic> _getLicenseConfig(String type) {
    switch (type) {
      case 'GSTIN':
        return {
          'label': 'GST Number *',
          'hint': 'e.g. 27ABCDE1234F1Z5',
          'maxLength': 15,
          'formatters': [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          'regex': r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{3}$',
          'errorMsg': 'Invalid 15-digit GST format',
        };
      case 'FSSAI':
        return {
          'label': 'FSSAI License No. *',
          'hint': 'e.g. 12345678901234',
          'maxLength': 14,
          'formatters': [FilteringTextInputFormatter.digitsOnly],
          'regex': r'^[0-9]{14}$',
          'errorMsg': 'FSSAI must be 14 digits',
        };
      case 'Drug License':
        return {
          'label': 'Drug License No. *',
          'hint': 'e.g. MH-MUM-12345',
          'maxLength': 20,
          'formatters': <TextInputFormatter>[],
          'regex': r'^[A-Z0-9\-\/]{5,20}$',
          'errorMsg': 'e.g. MH-MUM-12345',
        };
      case 'Liquor License':
        return {
          'label': 'Liquor License No. *',
          'hint': 'e.g. LIQ/2024/00123',
          'maxLength': 20,
          'formatters': <TextInputFormatter>[],
          'regex': r'^[A-Z0-9\-\/]{5,20}$',
          'errorMsg': 'e.g. LIQ/2024/00123',
        };
      case 'Trade License':
        return {
          'label': 'Trade License No. *',
          'hint': 'e.g. TL/WD12/0456/24',
          'maxLength': 25,
          'formatters': <TextInputFormatter>[],
          'regex': r'^[A-Z0-9\-\/]{5,25}$',
          'errorMsg': 'e.g. TL/WD12/0456/24',
        };
      case 'Fire NOC':
        return {
          'label': 'Fire NOC No. *',
          'hint': 'e.g. FIRE/NOC/2024/789',
          'maxLength': 25,
          'formatters': <TextInputFormatter>[],
          'regex': r'^[A-Z0-9\-\/]{5,25}$',
          'errorMsg': 'e.g. FIRE/NOC/2024/789',
        };
      default:
        return {
          'label': 'Registration Code *',
          'hint': 'Enter code',
          'maxLength': 30,
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
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _isLocationVerified = false;
        });
      }
    } else {
      setState(() {
        _isLocationVerified = false;
        _isFetchingLocation = false;
      });
    }
  }

  Future<void> _onIfscChanged(_BankAccount acct, String val) async {
    if (val.length == 11) {
      setState(() {
        acct.isFetching = true;
        acct.isVerified = false;
      });
      try {
        final response = await http
            .get(Uri.parse('https://ifsc.razorpay.com/${val.toUpperCase()}'))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              acct.bankNameCtrl.text = "${data['BANK']} (${data['BRANCH']})";
              acct.isVerified = true;
              acct.isFetching = false;
              if (acct.accNameCtrl.text.isEmpty) {
                acct.accNameCtrl.text = _storeNameCtrl.text.toUpperCase();
              }
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("IFSC API Fallback: $e");
      }
      if (mounted) {
        setState(() {
          acct.isFetching = false;
          acct.isVerified = false;
          acct.bankNameCtrl.clear();
        });
      }
    } else {
      setState(() {
        acct.isVerified = false;
        acct.isFetching = false;
        acct.bankNameCtrl.clear();
      });
    }
  }

  final _storeNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();

  final _managerEmailCtrl = TextEditingController();
  final _managerEmpIdCtrl = TextEditingController();
  final _managerNameCtrl = TextEditingController();
  final _managerPhoneCtrl = TextEditingController();

  final List<TextEditingController> _phoneControllers = [
    TextEditingController(),
  ];
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String? _selectedState;

  final _kStoreName = GlobalKey();
  final _kBranchCode = GlobalKey();

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
      if (mounted) {
        setState(() {
          _isBranchChecking = false;
          _branchError = snap.docs.isNotEmpty
              ? 'Branch Code already exists!'
              : null;
        });
      }
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
    // Start with one bank account by default - keeps the common case (single
    // account) a one-tap flow while still allowing more to be added.
    _bankAccounts.add(_BankAccount(label: 'Primary Settlement'));
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
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    for (var acct in _bankAccounts) {
      acct.dispose();
    }
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

  // ---- Step navigation ----
  bool _validateStep0() {
    if (_storeNameCtrl.text.trim().length < 3) return false;
    if (_branchCodeCtrl.text.trim().isEmpty || _branchError != null)
      return false;
    if (!_step0Key.currentState!.validate()) return false;
    final adminEmail = FirebaseAuth.instance.currentUser?.email;
    if (_managerEmailCtrl.text.trim().toLowerCase() ==
        adminEmail?.toLowerCase()) {
      return false;
    }
    return true;
  }

  bool _validateStep1() => _step1Key.currentState!.validate();

  bool _validateStep2() {
    if (!_step2Key.currentState!.validate()) return false;
    for (final lic in _dynamicLicenses) {
      final config = _getLicenseConfig(lic['type'] ?? 'Other');
      final val = (lic['number'] ?? '').toUpperCase();
      if (!RegExp(config['regex'] as String).hasMatch(val)) return false;
    }
    return true;
  }

  void _goNext() {
    bool ok = true;
    if (_currentStep == 0) ok = _validateStep0();
    if (_currentStep == 1) ok = _validateStep1();
    if (_currentStep == 2) ok = _validateStep2();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted fields before continuing.'),
        ),
      );
      return;
    }
    if (_currentStep < _stepTitles.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
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
      setState(() => _currentStep = 0);
      return;
    }

    // 🛡️ SECURITY FIX: Added 'tenantId' filter.
    // Firestore rules block cross-tenant reads. Bina is filter ke query
    // poore DB me search karne ki koshish karti hai aur 403 fail ho jati hai.
    final existingManager = await db
        .collection('staff')
        .where('tenantId', isEqualTo: widget.tenantId)
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
      setState(() => _currentStep = 0);
      return;
    }

    // Banking is optional at creation time - validate only what's filled in.
    if (!_bankSkipped) {
      for (final acct in _bankAccounts) {
        final hasAnyInput =
            acct.accNameCtrl.text.trim().isNotEmpty ||
            acct.fullAccountNumber.isNotEmpty ||
            acct.ifscCtrl.text.trim().isNotEmpty;
        if (!hasAnyInput) continue;
        if (acct.accNameCtrl.text.trim().isEmpty ||
            acct.fullAccountNumber.length < 9 ||
            !RegExp(
              r'^[A-Z]{4}0[A-Z0-9]{6}$',
            ).hasMatch(acct.ifscCtrl.text.trim().toUpperCase())) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Please complete the bank account fully, or use 'Add Later'.",
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _currentStep = 3);
          return;
        }
      }
    }

    try {
      final batch = db.batch();
      final storeRef = db.collection('stores').doc();
      final staffRef = db.collection('staff').doc();

      // 🧹 CLEANUP FIX: Removed unused 'adminEmail' variable warning.
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

      final bankAccountsPayload = _bankSkipped
          ? []
          : _bankAccounts
                .where(
                  (a) =>
                      a.fullAccountNumber.isNotEmpty &&
                      a.ifscCtrl.text.trim().isNotEmpty,
                )
                .map((a) => a.toMap())
                .toList();

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
        'location': {
          'address': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _selectedState,
          'pincode': _pincodeCtrl.text.trim(),
        },
        'licenses': _dynamicLicenses,
        'bankAccounts': bankAccountsPayload,
        // Surfaced on the store dashboard as a persistent reminder banner
        // until at least one bank account is added - store creation itself
        // is never blocked on this.
        'bankDetailsPending': bankAccountsPayload.isEmpty,
        'status': 'ACTIVE',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🛡️ SECURITY FIX: Removed client-side write to 'admin_audit_logs'.
      // Firestore rules strictly block frontend writes to audit collections to prevent tampering.
      // Store and Staff creation will now commit successfully.
      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Store '${_storeNameCtrl.text.trim()}' created!"),
            backgroundColor: context.colors.success,
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

  InputDecoration _inputDeco(
    String label, {
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    final c = context.colors;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: c.scaffoldBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.ctaBackground, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.danger, width: 1),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.ctaBackground, size: 20),
          const SizedBox(width: 10),
          Flexible(
            // 🛠️ UI FIX: Prevents text overflow on small windows
            child: Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
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
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            activeColor: c.ctaBackground,
            side: BorderSide(color: c.textSecondary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

  Widget _infoBanner(
    String text, {
    IconData icon = Icons.info_outline,
    Color? color,
  }) {
    final c = context.colors;
    final tone = color ?? c.ctaBackground;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: tone, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step header (progress) ----
  Widget _buildStepHeader(bool isMobile) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 30,
        vertical: 16,
      ),
      child: Row(
        children: List.generate(_stepTitles.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          final circleColor = isDone || isActive ? c.ctaBackground : c.border;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: circleColor,
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Icon(
                          _stepIcons[i],
                          size: 14,
                          color: isActive ? Colors.white : c.textSecondary,
                        ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _stepTitles[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive ? c.textPrimary : c.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (i != _stepTitles.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? c.ctaBackground : c.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ---- Step 0: Store & Manager ----
  Widget _buildStep0(bool isMobile) {
    final c = context.colors;
    return Form(
      key: _step0Key,
      child: ListView(
        padding: EdgeInsets.all(isMobile ? 16 : 30),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionTitle(
                  "Basic Store Details",
                  Icons.storefront,
                ),
              ),
              _compactCheckbox("Same as Company", _sameAsNamePhone, (v) {
                setState(() {
                  _sameAsNamePhone = v!;
                  _applyInheritance();
                });
              }),
            ],
          ),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kStoreName,
              controller: _storeNameCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: _inputDeco(
                "Store / Branch Name *",
                hint: "e.g. Jaiswar Flour Mill",
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? "Min 3 chars" : null,
            ),
            TextFormField(
              key: _kBranchCode,
              controller: _branchCodeCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: _inputDeco(
                "Branch Code *",
                hint: "e.g. JAI_MUM_001",
                suffix: _isBranchChecking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (_branchError == null && _branchCodeCtrl.text.length >= 3
                          ? Icon(Icons.check_circle, color: c.success)
                          : null),
              ).copyWith(errorText: _branchError),
              onChanged: (v) {
                _isBranchCodeManuallyEdited = true;
                _checkBranchCode(v);
              },
              validator: (v) => v!.trim().isEmpty
                  ? "Required"
                  : (_branchError != null ? "Duplicate Code" : null),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneControllers[0],
            style: TextStyle(color: c.textPrimary),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco(
              "Primary Mobile *",
              prefix: Icon(
                Icons.phone_android,
                size: 18,
                color: c.textSecondary,
              ),
            ).copyWith(counterText: ""),
            validator: (v) =>
                (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                ? "Invalid Mobile"
                : null,
          ),
          const SizedBox(height: 30),
          _buildSectionTitle("Manager Details", Icons.badge),
          _infoBanner(
            "The manager account is created immediately with login access. If you're managing this store yourself, "
            "just enter your own details below (a different email than your HQ owner login).",
          ),
          _responsiveRow(
            isMobile,
            TextFormField(
              controller: _managerNameCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: _inputDeco(
                "Manager Full Name *",
                hint: "e.g. Rahul Sharma",
              ),
              validator: (v) => v!.trim().isEmpty ? "Required" : null,
            ),
            TextFormField(
              controller: _managerEmpIdCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: _inputDeco(
                "Manager Employee ID *",
                hint: "e.g. EMP-001",
              ),
              validator: (v) => v!.trim().isEmpty ? "Required" : null,
            ),
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              controller: _managerPhoneCtrl,
              style: TextStyle(color: c.textPrimary),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDeco(
                "Manager Phone *",
              ).copyWith(counterText: ""),
              validator: (v) =>
                  (v == null || !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                  ? "Invalid Mobile"
                  : null,
            ),
            TextFormField(
              controller: _managerEmailCtrl,
              style: TextStyle(color: c.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco(
                "Manager Login Email *",
                hint: "e.g. manager@store.com",
                prefix: Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: c.textSecondary,
                ),
              ),
              validator: (v) {
                if (v == null || !v.contains('@'))
                  return "Valid Email Required";
                final adminEmail = FirebaseAuth.instance.currentUser?.email;
                if (v.trim().toLowerCase() == adminEmail?.toLowerCase()) {
                  return "Cannot use HQ Owner email for Store Manager";
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Step 1: Location ----
  Widget _buildStep1(bool isMobile) {
    final c = context.colors;
    return Form(
      key: _step1Key,
      child: ListView(
        padding: EdgeInsets.all(isMobile ? 16 : 30),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionTitle(
                  "Store Location",
                  Icons.location_on_outlined,
                ),
              ),
              _compactCheckbox("Same as Company", _sameAsLocation, (v) {
                setState(() {
                  _sameAsLocation = v!;
                  _applyInheritance();
                });
              }),
            ],
          ),
          _responsiveRow(
            isMobile,
            TextFormField(
              controller: _pincodeCtrl,
              style: TextStyle(color: c.textPrimary),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onPincodeChanged,
              decoration: _inputDeco(
                "Pincode *",
                prefix: Icon(
                  Icons.pin_drop_outlined,
                  size: 18,
                  color: c.textSecondary,
                ),
                suffix: _isFetchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (_isLocationVerified
                          ? Icon(Icons.check_circle, color: c.success)
                          : null),
              ).copyWith(counterText: ""),
              validator: (v) => (v == null || v.trim().length != 6)
                  ? "6-digit Pincode"
                  : null,
            ),
            TextFormField(
              controller: _cityCtrl,
              style: TextStyle(color: c.textPrimary),
              decoration: _inputDeco("City *", hint: "Auto-fills from Pincode"),
              validator: (v) => v!.trim().isEmpty ? "Required" : null,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedState,
            style: TextStyle(color: c.textPrimary),
            dropdownColor: c.cardBg,
            decoration: _inputDeco(
              "State *",
              prefix: Icon(
                Icons.map_outlined,
                size: 18,
                color: c.textSecondary,
              ),
            ),
            items: _states
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedState = v),
            validator: (v) => v == null ? "Required" : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _addressCtrl,
            style: TextStyle(color: c.textPrimary),
            decoration: _inputDeco("Complete Store Address *"),
            validator: (v) => v!.trim().isEmpty ? "Required" : null,
          ),
        ],
      ),
    );
  }

  // ---- Step 2: Licenses ----
  Widget _buildStep2(bool isMobile) {
    final c = context.colors;
    return Form(
      key: _step2Key,
      child: ListView(
        padding: EdgeInsets.all(isMobile ? 16 : 30),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  // 🛠️ UI FIX: Replaced nested Row with Wrap to prevent crash
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 15,
                  children: [
                    _buildSectionTitle("Legal & Compliance", Icons.gavel),
                    _compactCheckbox("Same as Company", _sameAsLicenses, (v) {
                      setState(() {
                        _sameAsLicenses = v!;
                        _applyInheritance();
                      });
                    }),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _addLicenseRow,
                icon: Icon(Icons.add, color: c.ctaBackground, size: 16),
                label: Text(
                  "Add License",
                  style: TextStyle(color: c.ctaBackground),
                ),
              ),
            ],
          ),
          if (_dynamicLicenses.isEmpty)
            _infoBanner(
              "No licenses added yet - this is optional and you can add them anytime later from the store settings.",
              icon: Icons.info_outline,
              color: c.textSecondary,
            ),
          ..._dynamicLicenses.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, String> lic = entry.value;
            final config = _getLicenseConfig(lic['type'] ?? 'Other');
            final val = lic['number'] ?? '';
            final isValid = RegExp(
              config['regex'] as String,
            ).hasMatch(val.toUpperCase());

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _responsiveRow(
                    isMobile,
                    DropdownButtonFormField<String>(
                      initialValue: _licenseTypes.contains(lic['type'])
                          ? lic['type']
                          : 'Other',
                      dropdownColor: c.cardBg,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _inputDeco("Compliance Type"),
                      items: _licenseTypes
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _dynamicLicenses[idx]['type'] = v!;
                        _dynamicLicenses[idx]['number'] = '';
                      }),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey("${idx}_${lic['type']}"),
                            initialValue: val,
                            style: TextStyle(color: c.textPrimary),
                            textCapitalization: TextCapitalization.characters,
                            maxLength: config['maxLength'],
                            inputFormatters: config['formatters'],
                            decoration: _inputDeco(
                              config['label'] as String,
                              hint: config['hint'] as String,
                              suffix: val.isNotEmpty
                                  ? Icon(
                                      isValid
                                          ? Icons.check_circle
                                          : Icons.error_outline,
                                      color: isValid ? c.success : c.danger,
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
                              if (!isValid) return config['errorMsg'] as String;
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: c.textSecondary,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _dynamicLicenses.removeAt(idx)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---- Step 3: Banking (multi-account, skippable) ----
  Widget _buildStep3(bool isMobile) {
    final c = context.colors;
    return ListView(
      padding: EdgeInsets.all(isMobile ? 16 : 30),
      children: [
        _buildSectionTitle("Banking & Settlement", Icons.account_balance),
        if (_tenantHasGst)
          _infoBanner(
            "Make sure this account is linked with your GST for seamless reconciliation.",
            icon: Icons.verified_outlined,
          ),
        if (_bankSkipped)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: c.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Banking skipped. The store will deploy, but settlements can't run until at least one account is added later from Store Settings.",
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _bankSkipped = false),
                  child: Text(
                    "Add now",
                    style: TextStyle(
                      color: c.ctaBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ..._bankAccounts.asMap().entries.map((entry) {
            final idx = entry.key;
            final acct = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _bankLabels.contains(acct.label)
                              ? acct.label
                              : 'Other',
                          dropdownColor: c.cardBg,
                          style: TextStyle(color: c.textPrimary),
                          decoration: _inputDeco("Account Purpose"),
                          items: _bankLabels
                              .map(
                                (l) =>
                                    DropdownMenuItem(value: l, child: Text(l)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => acct.label = v!),
                        ),
                      ),
                      if (_bankAccounts.length > 1)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: c.danger),
                          onPressed: () => _removeBankAccount(idx),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: acct.accNameCtrl,
                    style: TextStyle(color: c.textPrimary),
                    decoration: _inputDeco("Account Holder Name"),
                  ),
                  const SizedBox(height: 16),
                  _responsiveRow(
                    isMobile,
                    TextFormField(
                      controller: acct.ifscCtrl,
                      style: TextStyle(color: c.textPrimary),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 11,
                      onChanged: (v) => _onIfscChanged(acct, v),
                      decoration: _inputDeco(
                        "IFSC Code",
                        suffix: acct.isFetching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : (acct.isVerified
                                  ? Icon(Icons.check_circle, color: c.success)
                                  : null),
                      ).copyWith(counterText: ""),
                    ),
                    TextFormField(
                      controller: acct.bankNameCtrl,
                      readOnly: true,
                      style: TextStyle(color: c.textSecondary),
                      decoration: _inputDeco("Resolved Branch Name"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _responsiveRow(
                    isMobile,
                    TextFormField(
                      controller: acct.accNoCtrl,
                      focusNode: acct.accNoFocus,
                      style: TextStyle(color: c.textPrimary),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDeco("Settlement Account Number"),
                      onChanged: (v) => acct.fullAccountNumber = v,
                    ),
                    TextFormField(
                      controller: acct.upiCtrl,
                      style: TextStyle(color: c.textPrimary),
                      decoration: _inputDeco("Settlement UPI ID (Optional)"),
                    ),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addBankAccount,
                icon: Icon(Icons.add, color: c.ctaBackground, size: 18),
                label: Text(
                  "Add Another Account",
                  style: TextStyle(
                    color: c.ctaBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _bankSkipped = true),
                child: Text(
                  "Add Later, skip for now",
                  style: TextStyle(
                    color: c.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final c = context.colors;

    return SimulationCoachOverlay(
      message:
          "Let's drop your first Store node on the map. Click the button below to auto-fill dummy data for a quick test.",
      themeColor: c.ctaBackground,
      actionLabel: "AUTO-FILL DUMMY DATA",
      onAction: () {
        setState(() {
          _sameAsNamePhone = false;
          _sameAsLocation = false;
          _sameAsLicenses = false;
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
        backgroundColor: c.cardBg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
        child: Container(
          width: isMobile ? double.infinity : 850,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "Onboard New Store",
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: isMobile ? 20 : 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: c.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: _buildStepHeader(isMobile),
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep0(isMobile),
                    _buildStep1(isMobile),
                    _buildStep2(isMobile),
                    _buildStep3(isMobile),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentStep == 0
                        ? TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "CANCEL",
                              style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _goBack,
                            icon: Icon(
                              Icons.arrow_back,
                              size: 16,
                              color: c.textSecondary,
                            ),
                            label: Text(
                              "Back",
                              style: TextStyle(
                                color: c.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    _currentStep < _stepTitles.length - 1
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.ctaBackground,
                              foregroundColor: c.ctaText,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _goNext,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text(
                              "NEXT",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.ctaBackground,
                              foregroundColor: c.ctaText,
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
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: c.ctaText,
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
