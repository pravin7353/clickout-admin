// lib/features/tenant_admin/screens/client_registration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ClientRegistrationScreen extends ConsumerStatefulWidget {
  const ClientRegistrationScreen({super.key});

  @override
  ConsumerState<ClientRegistrationScreen> createState() =>
      _ClientRegistrationScreenState();
}

class _ClientRegistrationScreenState
    extends ConsumerState<ClientRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Scroll Controller & Form Keys
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey<FormState>> _formKeys = List.generate(
    5, // Fixed to 5 steps
    (_) => GlobalKey<FormState>(),
  );

  // Field Keys for Auto-Scrolling to First Error
  final _kStoreName = GlobalKey();
  final _kOwnerName = GlobalKey();
  final _kMobile = GlobalKey();
  final _kEmail = GlobalKey();
  final _kBizType = GlobalKey();
  final _kBranches = GlobalKey();
  final _kYear = GlobalKey();
  final _kAddress = GlobalKey();
  final _kCity = GlobalKey();
  final _kPincode = GlobalKey();
  final _kState = GlobalKey();
  final _kPan = GlobalKey();
  final _kGst = GlobalKey();
  final _kAccName = GlobalKey();
  final _kAccNo = GlobalKey();
  final _kConfAccNo = GlobalKey();
  final _kIfsc = GlobalKey();
  final _kUpi = GlobalKey();
  final _kOpenTime = GlobalKey();
  final _kCloseTime = GlobalKey();
  final _kEmpCount = GlobalKey();
  final _kVolume = GlobalKey();

  // 🎨 DYNAMIC THEME GETTERS (Linked to app_theme.dart)
  Color get bgDark => context.colors.scaffoldBg;
  Color get cardDark => context.colors.cardBg;
  Color get textPrimary => context.colors.textPrimary;
  Color get textSecondary => context.colors.textSecondary;
  Color get inputBg => Theme.of(context).brightness == Brightness.dark
      ? Colors.white10
      : Colors.black12;
  Color get accentGreen => context.colors.success;

  // --- STEP 1: Business Details ---
  final _storeNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _branchesCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  String? _businessType;
  final List<String> _bizTypes = [
    'Super Mart',
    'Department Store',
    'Electronics',
    'Pharmacy',
    'Fashion Retail',
    'F&B',
    'Other',
  ];

  // --- STEP 2: Location & KYC ---
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String? _selectedState;
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

  // --- STEP 3: Bank & Payment ---
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _confirmAccNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  final FocusNode _accNoFocus = FocusNode();
  final FocusNode _confirmAccNoFocus = FocusNode();
  String _fullAccountNumber = '';
  String _fullConfirmAccountNumber = '';

  // --- STEP 4: Store Config ---
  final _openTimeCtrl = TextEditingController(text: '09:00 AM');
  final _closeTimeCtrl = TextEditingController(text: '10:00 PM');
  final _empCountCtrl = TextEditingController();
  String? _monthlyVolume;
  final List<String> _volumeOptions = [
    'Under 1,000',
    '1,000 – 5,000',
    '5,000 – 20,000',
    '20,000+',
  ];

  // --- STEP 5: Legal ---
  bool _tcAccepted = false;
  bool _dataConsent = false;
  bool _settlementAgreed = false;

  @override
  void initState() {
    super.initState();
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

    _confirmAccNoFocus.addListener(() {
      if (!_confirmAccNoFocus.hasFocus) {
        if (_fullConfirmAccountNumber.length >= 4) {
          _confirmAccNoCtrl.text =
              '•' * (_fullConfirmAccountNumber.length - 4) +
              _fullConfirmAccountNumber.substring(
                _fullConfirmAccountNumber.length - 4,
              );
        }
      } else {
        _confirmAccNoCtrl.text = _fullConfirmAccountNumber;
      }
    });
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _branchesCtrl.dispose();
    _yearCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _confirmAccNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _openTimeCtrl.dispose();
    _closeTimeCtrl.dispose();
    _empCountCtrl.dispose();
    _scrollController.dispose();
    _accNoFocus.dispose();
    _confirmAccNoFocus.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardDark,
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: Text(message, style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  // 🚀 RESTORED: 100% COMPLETE FIREBASE LOGIC (NO CUTS)
  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;
      final adminEmail = _emailCtrl.text.trim();
      final phoneNo = _mobileCtrl.text.trim();

      final staffQuery = await db
          .collection('staff')
          .where('email', isEqualTo: adminEmail)
          .get();
      if (staffQuery.docs.isNotEmpty) {
        _showErrorDialog(
          "Duplicate Found",
          "This email is already registered.",
        );
        setState(() => _isLoading = false);
        return;
      }

      final tenantQuery = await db
          .collection('tenants')
          .where('contact.phone', isEqualTo: phoneNo)
          .get();
      if (tenantQuery.docs.isNotEmpty) {
        _showErrorDialog(
          "Duplicate Found",
          "A client with this phone number already exists.",
        );
        setState(() => _isLoading = false);
        return;
      }

      final String prefix = _storeNameCtrl.text
          .replaceAll(' ', '')
          .toUpperCase()
          .substring(0, 3);
      final String tenantId =
          "${prefix}_${DateTime.now().millisecondsSinceEpoch}";
      final batch = db.batch();

      final tenantRef = db.collection('tenants').doc(tenantId);

      // 🚀 ALIGNING INITIAL REGISTRATION WITH NEW EDIT PROFILE SCHEMA
      final List<Map<String, String>> initialLicenses = [
        {'type': 'PAN', 'number': _panCtrl.text.trim().toUpperCase()},
        if (_gstCtrl.text.trim().isNotEmpty)
          {'type': 'GSTIN', 'number': _gstCtrl.text.trim().toUpperCase()},
      ];

      batch.set(tenantRef, {
        'tenantId': tenantId,
        'companyName': _storeNameCtrl.text.trim(),
        'ownerName': _ownerNameCtrl.text.trim(),
        'establishedYear': int.parse(_yearCtrl.text.trim()),
        'industries': [_businessType], // 🚀 Converted to Array Schema
        'goods_or_services': [], // To be configured in Edit Profile
        'contact': {
          'email': adminEmail,
          'phone': phoneNo,
          'recoveryEmail': '',
          'recoveryPhone': '',
        },
        'location': {
          'address': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _selectedState,
          'pincode': _pincodeCtrl.text.trim(),
        },
        'licenses': initialLicenses, // 🚀 Replaces old KYC object
        'bankDetails': {
          'accountName': _accNameCtrl.text.trim(),
          'accountNo': _fullAccountNumber,
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'upi': _upiCtrl.text.trim(),
          'bankName': '', // Will be resolved if edited
          'isCustom': false, // Inheritance flag
        },
        // 🚀 Removed 'config' and 'totalBranches' to prevent schema pollution
        'legal': {
          'tcAccepted': _tcAccepted,
          'dataConsent': _dataConsent,
          'settlementAgreed': _settlementAgreed,
        },
        'isActive': true,
        'isOnboardingComplete': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final staffRef = db.collection('staff').doc();
      batch.set(staffRef, {
        'docId': staffRef.id,
        'tenantId': tenantId,
        'branchCode': 'ALL',
        'name': _ownerNameCtrl.text.trim(),
        'email': adminEmail,
        'phone': phoneNo,
        'role': 'TENANT_ADMIN',
        'isActive': true,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: cardDark,
            title: Icon(Icons.check_circle, color: accentGreen, size: 50),
            content: Text(
              "Client registered successfully!\nLogin credentials will be sent to $adminEmail",
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/');
                },
                child: Text(
                  "GO TO COMMAND CENTER",
                  style: TextStyle(color: accentGreen),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚀 RESTORED: 100% COMPLETE AUTO-SCROLL LOGIC
  void _scrollTo(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
    );
    _formKeys[_currentStep].currentState!.validate();
  }

  // 🚀 RESTORED: 100% COMPLETE VALIDATION LOGIC
  void _nextStep() {
    if (_currentStep == 0) {
      if (_storeNameCtrl.text.trim().length < 3) return _scrollTo(_kStoreName);
      if (_ownerNameCtrl.text.trim().isEmpty) return _scrollTo(_kOwnerName);
      if (_mobileCtrl.text.trim().length != 10) return _scrollTo(_kMobile);
      if (!_emailCtrl.text.contains('@') || !_emailCtrl.text.contains('.')) {
        return _scrollTo(_kEmail);
      }
      if (_businessType == null) return _scrollTo(_kBizType);
      final branches = int.tryParse(_branchesCtrl.text.trim()) ?? 0;
      if (branches < 1 || branches > 10000) return _scrollTo(_kBranches);
      final year = int.tryParse(_yearCtrl.text.trim()) ?? 0;
      if (year < 1800 || year > DateTime.now().year) return _scrollTo(_kYear);
    } else if (_currentStep == 1) {
      if (_addressCtrl.text.trim().isEmpty) return _scrollTo(_kAddress);
      if (_cityCtrl.text.trim().isEmpty) return _scrollTo(_kCity);
      if (_pincodeCtrl.text.trim().length != 6) return _scrollTo(_kPincode);
      if (_selectedState == null) return _scrollTo(_kState);
      if (!RegExp(
        r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
      ).hasMatch(_panCtrl.text.trim().toUpperCase())) {
        return _scrollTo(_kPan);
      }
      final gst = _gstCtrl.text.trim().toUpperCase();
      if (gst.isNotEmpty &&
          !RegExp(
            r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$',
          ).hasMatch(gst)) {
        return _scrollTo(_kGst);
      }
    } else if (_currentStep == 2) {
      if (_accNameCtrl.text.trim().isEmpty) return _scrollTo(_kAccName);
      if (_fullAccountNumber.length < 9 || _fullAccountNumber.length > 18) {
        return _scrollTo(_kAccNo);
      }
      if (_fullConfirmAccountNumber != _fullAccountNumber ||
          _fullConfirmAccountNumber.isEmpty) {
        return _scrollTo(_kConfAccNo);
      }
      if (!RegExp(
        r'^[A-Z]{4}0[A-Z0-9]{6}$',
      ).hasMatch(_ifscCtrl.text.trim().toUpperCase())) {
        return _scrollTo(_kIfsc);
      }
      if (_upiCtrl.text.trim().isNotEmpty && !_upiCtrl.text.contains('@')) {
        return _scrollTo(_kUpi);
      }
    } else if (_currentStep == 3) {
      if (_openTimeCtrl.text.trim().isEmpty) return _scrollTo(_kOpenTime);
      if (_closeTimeCtrl.text.trim().isEmpty) return _scrollTo(_kCloseTime);
      final emps = int.tryParse(_empCountCtrl.text.trim()) ?? 0;
      if (emps < 1) return _scrollTo(_kEmpCount);
      if (_monthlyVolume == null) return _scrollTo(_kVolume);
    }

    if (_currentStep < 4) {
      if (_formKeys[_currentStep].currentState!.validate()) {
        setState(() => _currentStep++);
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.ease,
        );
      }
    }
  }

  // --- STYLES & VALIDATORS ---
  InputDecoration _customInputDeco(
    String label, {
    bool isValid = false,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
      labelStyle: TextStyle(color: textSecondary),
      filled: true,
      fillColor: inputBg,
      suffixIcon: isValid ? Icon(Icons.check_circle, color: accentGreen) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: isValid
            ? BorderSide(color: accentGreen, width: 1.0)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accentGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  bool _isValLength(TextEditingController c, int l) =>
      c.text.trim().length == l;
  bool _isPanValid() => RegExp(
    r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$',
  ).hasMatch(_panCtrl.text.trim().toUpperCase());
  bool _isGstValid() => _gstCtrl.text.trim().isEmpty
      ? false
      : RegExp(
          r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9]{1}[A-Z]{1}[0-9A-Z]{1}$',
        ).hasMatch(_gstCtrl.text.trim().toUpperCase());
  bool _isIfscValid() => RegExp(
    r'^[A-Z]{4}0[A-Z0-9]{6}$',
  ).hasMatch(_ifscCtrl.text.trim().toUpperCase());

  // 🚀 RESPONSIVE ROW HELPER
  Widget _responsiveRow(bool isMobile, Widget child1, Widget child2) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    return Scaffold(
      backgroundColor: bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 🚀 FIX: TRIGGER MOBILE STACKING EARLIER (1100px instead of 800px)
          bool isMobile = constraints.maxWidth < 1100;

          // STEPPER PANEL
          Widget stepperPanel = Container(
            width: isMobile ? double.infinity : constraints.maxWidth * 0.35,
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            color: bgDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: textPrimary),
                      onPressed: () => context.go('/'),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    Text(
                      "Client Registration",
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (!isMobile || _currentStep == 0)
                  _buildStepIndicator(0, "Basic Business Details"),
                if (!isMobile || _currentStep == 1)
                  _buildStepIndicator(1, "Location & KYC"),
                if (!isMobile || _currentStep == 2)
                  _buildStepIndicator(2, "Bank & Payment Setup"),
                if (!isMobile || _currentStep == 3)
                  _buildStepIndicator(3, "Store Configuration"),
                if (!isMobile || _currentStep == 4)
                  _buildStepIndicator(4, "Legal & Consent"),
              ],
            ),
          );

          // FORM CONTENT
          Widget formContent = Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            child: _buildActiveFormStep(isMobile),
          );

          if (isMobile) {
            return SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  stepperPanel,
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardDark,
                      border: Border(
                        top: BorderSide(color: accentGreen.withOpacity(0.15)),
                      ),
                    ),
                    child: formContent,
                  ),
                ],
              ),
            );
          } else {
            return Row(
              children: [
                stepperPanel,
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardDark,
                      border: Border(
                        left: BorderSide(color: accentGreen.withOpacity(0.15)),
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: formContent,
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title) {
    bool isActive = _currentStep == stepIndex;
    bool isPast = _currentStep > stepIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPast || isActive ? accentGreen : Colors.transparent,
              border: Border.all(
                color: isPast || isActive ? accentGreen : textSecondary,
                width: 2,
              ),
            ),
            child: Center(
              child: isPast
                  ? Icon(Icons.check, color: bgDark, size: 18)
                  : Text(
                      "${stepIndex + 1}",
                      style: TextStyle(
                        color: isActive ? bgDark : textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? textPrimary : textSecondary,
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFormStep(bool isMobile) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isMobile);
      case 1:
        return _buildStep2(isMobile);
      case 2:
        return _buildStep3(isMobile);
      case 3:
        return _buildStep4(isMobile);
      case 4:
        return _buildStep5(isMobile);
      default:
        return const SizedBox();
    }
  }

  Widget _buildActionButtons(bool isMobile) {
    bool isLastStep = _currentStep == 4;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGreen,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0A0F0A)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : (isLastStep ? _submitRegistration : _nextStep),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isLastStep ? "COMPLETE REGISTRATION" : "NEXT STEP",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            if (_currentStep > 0) ...[
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  setState(() => _currentStep--);
                  _scrollController.jumpTo(0.0);
                },
                child: Text(
                  "BACK",
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 20,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                setState(() => _currentStep--);
                _scrollController.jumpTo(0.0);
              },
              child: Text(
                "BACK",
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentGreen,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0A0F0A)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isLoading
                ? null
                : (isLastStep ? _submitRegistration : _nextStep),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isLastStep ? "COMPLETE REGISTRATION" : "NEXT STEP",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FORMS WITH RESPONSIVE ROWS
  // ==========================================

  Widget _buildStep1(bool isMobile) {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Basic Business Details",
            style: TextStyle(
              color: textPrimary,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          TextFormField(
            key: _kStoreName,
            controller: _storeNameCtrl,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Store/Brand Name *",
              isValid: _storeNameCtrl.text.trim().length >= 3,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().length < 3)
                ? "Minimum 3 characters"
                : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: _kOwnerName,
            controller: _ownerNameCtrl,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Owner Full Name *",
              isValid: _ownerNameCtrl.text.trim().isNotEmpty,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => v!.trim().isEmpty ? "Required field" : null,
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kMobile,
              controller: _mobileCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _customInputDeco(
                "Mobile Number *",
                isValid: _isValLength(_mobileCtrl, 10),
              ).copyWith(counterText: ""),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.length != 10)
                  ? "Exactly 10 digits required"
                  : null,
            ),
            TextFormField(
              key: _kEmail,
              controller: _emailCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _customInputDeco(
                "Admin Email (For Login) *",
                isValid:
                    _emailCtrl.text.contains('@') &&
                    _emailCtrl.text.contains('.'),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || !v.contains('@') || !v.contains('.'))
                  ? "Valid email required"
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: _kBizType,
            initialValue: _businessType,
            dropdownColor: inputBg,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Business Type *",
              hint: "Select your business type",
              isValid: _businessType != null,
            ),
            items: _bizTypes
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _businessType = v),
            validator: (v) => v == null ? "Select type" : null,
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kBranches,
              controller: _branchesCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _customInputDeco(
                "Number of Branches *",
                isValid: _branchesCtrl.text.isNotEmpty,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                int val = int.tryParse(v ?? '') ?? 0;
                return val < 1 ? "Min 1 branch" : null;
              },
            ),
            TextFormField(
              key: _kYear,
              controller: _yearCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _customInputDeco(
                "Year of Establishment *",
                isValid: _yearCtrl.text.length == 4,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                int val = int.tryParse(v ?? '') ?? 0;
                return (val < 1800 || val > DateTime.now().year)
                    ? "Invalid year"
                    : null;
              },
            ),
          ),
          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildStep2(bool isMobile) {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Location & KYC",
            style: TextStyle(
              color: textPrimary,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          TextFormField(
            key: _kAddress,
            controller: _addressCtrl,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Complete Head Office Address *",
              isValid: _addressCtrl.text.trim().isNotEmpty,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => v!.trim().isEmpty ? "Required field" : null,
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kCity,
              controller: _cityCtrl,
              style: TextStyle(color: textPrimary),
              decoration: _customInputDeco(
                "City/Area *",
                isValid: _cityCtrl.text.trim().isNotEmpty,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.trim().isEmpty ? "Required field" : null,
            ),
            TextFormField(
              key: _kPincode,
              controller: _pincodeCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: _customInputDeco(
                "Pincode *",
                isValid: _isValLength(_pincodeCtrl, 6),
              ).copyWith(counterText: ""),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v == null || v.length != 6) ? "6-digit pincode" : null,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: _kState,
            initialValue: _selectedState,
            dropdownColor: inputBg,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "State *",
              hint: "Select your state",
              isValid: _selectedState != null,
            ),
            items: _states
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedState = v),
            validator: (v) => v == null ? "Required field" : null,
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kPan,
              controller: _panCtrl,
              style: TextStyle(color: textPrimary),
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: _customInputDeco(
                "PAN Number *",
                isValid: _isPanValid(),
              ).copyWith(counterText: ""),
              onChanged: (_) => setState(() {}),
              validator: (v) => !_isPanValid() ? "Invalid PAN" : null,
            ),
            TextFormField(
              key: _kGst,
              controller: _gstCtrl,
              style: TextStyle(color: textPrimary),
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              inputFormatters: [
                LengthLimitingTextInputFormatter(15),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: _customInputDeco(
                "GST Number (Optional)",
                isValid: _isGstValid(),
              ).copyWith(counterText: ""),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v != null && v.isNotEmpty && !_isGstValid())
                  ? "Invalid GST"
                  : null,
            ),
          ),
          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildStep3(bool isMobile) {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bank & Payment Setup",
            style: TextStyle(
              color: textPrimary,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          TextFormField(
            key: _kAccName,
            controller: _accNameCtrl,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Account Holder Name *",
              isValid: _accNameCtrl.text.trim().isNotEmpty,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => v!.trim().isEmpty ? "Required field" : null,
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kAccNo,
              focusNode: _accNoFocus,
              controller: _accNoCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _customInputDeco(
                "Account Number *",
                isValid: _fullAccountNumber.length >= 9,
              ),
              onChanged: (v) {
                if (_accNoFocus.hasFocus) _fullAccountNumber = v;
                setState(() {});
              },
              validator: (v) =>
                  (_fullAccountNumber.length < 9 ||
                      _fullAccountNumber.length > 18)
                  ? "9 to 18 digits required"
                  : null,
            ),
            TextFormField(
              key: _kConfAccNo,
              focusNode: _confirmAccNoFocus,
              controller: _confirmAccNoCtrl,
              style: TextStyle(color: textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _customInputDeco(
                "Confirm Account Number *",
                isValid:
                    _fullConfirmAccountNumber.isNotEmpty &&
                    _fullConfirmAccountNumber == _fullAccountNumber,
              ),
              onChanged: (v) {
                if (_confirmAccNoFocus.hasFocus) _fullConfirmAccountNumber = v;
                setState(() {});
              },
              validator: (v) =>
                  (_fullConfirmAccountNumber != _fullAccountNumber)
                  ? "Account numbers do not match"
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kIfsc,
              controller: _ifscCtrl,
              style: TextStyle(color: textPrimary),
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              inputFormatters: [
                LengthLimitingTextInputFormatter(11),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: _customInputDeco(
                "IFSC Code *",
                isValid: _isIfscValid(),
              ).copyWith(counterText: ""),
              onChanged: (_) => setState(() {}),
              validator: (v) => !_isIfscValid() ? "Invalid IFSC format" : null,
            ),
            TextFormField(
              key: _kUpi,
              controller: _upiCtrl,
              style: TextStyle(color: textPrimary),
              decoration: _customInputDeco(
                "Settlement UPI ID (Optional)",
                isValid: _upiCtrl.text.contains('@'),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v != null && v.isNotEmpty && !v.contains('@'))
                  ? "Invalid UPI ID"
                  : null,
            ),
          ),
          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildStep4(bool isMobile) {
    return Form(
      key: _formKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Store Configuration",
            style: TextStyle(
              color: textPrimary,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          _responsiveRow(
            isMobile,
            TextFormField(
              key: _kOpenTime,
              controller: _openTimeCtrl,
              style: TextStyle(color: textPrimary),
              decoration: _customInputDeco(
                "Store Opening Time",
                isValid: _openTimeCtrl.text.isNotEmpty,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.trim().isEmpty ? "Required" : null,
            ),
            TextFormField(
              key: _kCloseTime,
              controller: _closeTimeCtrl,
              style: TextStyle(color: textPrimary),
              decoration: _customInputDeco(
                "Store Closing Time",
                isValid: _closeTimeCtrl.text.isNotEmpty,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.trim().isEmpty ? "Required" : null,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: _kEmpCount,
            controller: _empCountCtrl,
            style: TextStyle(color: textPrimary),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _customInputDeco(
              "Total Current Employees *",
              isValid: _empCountCtrl.text.isNotEmpty,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              int val = int.tryParse(v ?? '') ?? 0;
              return val < 1 ? "Min 1 employee" : null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: _kVolume,
            initialValue: _monthlyVolume,
            dropdownColor: inputBg,
            style: TextStyle(color: textPrimary),
            decoration: _customInputDeco(
              "Expected Monthly Transaction Volume *",
              hint: "Select range",
              isValid: _monthlyVolume != null,
            ),
            items: _volumeOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _monthlyVolume = v),
            validator: (v) => v == null ? "Required field" : null,
          ),
          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildStep5(bool isMobile) {
    return Form(
      key: _formKeys[4],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Legal & Consent",
            style: TextStyle(
              color: textPrimary,
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          _buildConsentBox(
            title: "Platform Terms & Conditions",
            content:
                "By registering, you agree that (a) all business information provided is accurate and legally valid, (b) ClickOut has the right to verify KYC documents within 7 working days, (c) your account may be suspended if fraudulent activity is detected, (d) ClickOut is not liable for inventory discrepancies arising from third-party POS systems, (e) minimum contract period is 3 months, (f) 30-day written notice required for cancellation.",
            value: _tcAccepted,
            onChanged: (v) => setState(() => _tcAccepted = v!),
          ),

          _buildConsentBox(
            title: "Data & AI Analytics Consent",
            content:
                "You authorize ClickOut to (a) collect and process transaction data, customer behaviour patterns, and inventory movement data, (b) use anonymized store data to improve AI Growth Radar and churn detection models, (c) share aggregated non-identifiable data for industry benchmarking. Your raw customer data will never be sold to third parties. Data is stored on Firebase servers in asia-south1 region compliant with Indian IT Act 2000.",
            value: _dataConsent,
            onChanged: (v) => setState(() => _dataConsent = v!),
          ),

          _buildConsentBox(
            title: "Payment Settlement Terms (T+1)",
            content:
                "You agree that (a) all customer payments collected via ClickOut are settled T+1 business days to your registered bank account, (b) platform fee applies as per your selected subscription plan, (c) in case of disputed transactions, settlement is held up to 7 days pending investigation, (d) ClickOut reserves the right to adjust settlement amounts for verified refunds and chargebacks.",
            value: _settlementAgreed,
            onChanged: (v) => setState(() => _settlementAgreed = v!),
          ),

          _buildActionButtons(isMobile),
        ],
      ),
    );
  }

  Widget _buildConsentBox({
    required String title,
    required String content,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border.all(color: value ? accentGreen : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: ThemeData(unselectedWidgetColor: textSecondary),
        child: CheckboxListTile(
          activeColor: accentGreen,
          checkColor: bgDark,
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              content,
              style: TextStyle(color: textSecondary, height: 1.5, fontSize: 13),
            ),
          ),
          value: value,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
    );
  }
}
