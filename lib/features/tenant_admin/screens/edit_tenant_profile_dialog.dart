import 'dart:convert'; // 🚀 Added for JSON parsing
import 'package:http/http.dart' as http; // 🚀 Added for Real APIs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

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

  // --- CORE CONTROLLERS ---
  final _brandCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _estYearCtrl = TextEditingController();

  // --- ENTERPRISE RECOVERY ---
  final _recoveryPhoneCtrl = TextEditingController();
  final _recoveryEmailCtrl = TextEditingController();

  // --- LOCATION CONTROLLERS ---
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // --- BANKING CONTROLLERS ---
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  // 🚀 SMART UX EXTENSIONS
  final FocusNode _accNoFocus = FocusNode();
  String _rawAccountNumber = '';

  // Validation States
  bool _isFetchingLocation = false;
  bool _isLocationVerified = false;
  bool _isFetchingBank = false;
  bool _isBankVerified = false;

  // --- ENTERPRISE SELECTORS ---
  String? _selectedState;

  // Goods vs Services
  bool _dealsInGoods = true;
  bool _dealsInServices = false;

  // Industry Multi-Select
  final TextEditingController _industrySearchCtrl = TextEditingController();
  final List<String> _selectedIndustries = [];
  final List<String> _commonIndustries = [
    'Supermarket',
    'Department Store',
    'Electronics',
    'Pharmacy',
    'Fashion Retail',
    'Restaurant',
    'IT Services',
    'Hardware',
    'Salon',
    'FMCG',
  ];
  List<String> _filteredIndustries = [];

  // Dynamic Licenses
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

  final List<String> _states = [
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

    // 🔐 ACCOUNT NUMBER MASKING ENGINE
    _accNoFocus.addListener(() {
      if (!_accNoFocus.hasFocus) {
        if (_rawAccountNumber.length >= 4) {
          _accNoCtrl.text =
              '•' * (_rawAccountNumber.length - 4) +
              _rawAccountNumber.substring(_rawAccountNumber.length - 4);
        }
      } else {
        _accNoCtrl.text = _rawAccountNumber;
      }
    });
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _estYearCtrl.dispose();
    _recoveryPhoneCtrl.dispose();
    _recoveryEmailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _bankNameCtrl.dispose();
    _industrySearchCtrl.dispose();
    _accNoFocus.dispose();
    super.dispose();
  }

  // 🧠 READINESS ENGINE
  double get _readinessScore {
    double score = 10.0; // Base score
    if (_brandCtrl.text.isNotEmpty) score += 15;
    if (_phoneCtrl.text.length == 10) score += 15;
    if (_selectedIndustries.isNotEmpty) score += 15;
    if (_pincodeCtrl.text.length == 6 && _cityCtrl.text.isNotEmpty) score += 20;
    if (_rawAccountNumber.length >= 9 && _ifscCtrl.text.length == 11)
      score += 25;
    return score > 100 ? 100 : score;
  }

  // ⚡ REAL-TIME PINCODE API WITH GRACEFUL DEGRADATION
  Future<void> _onPincodeChanged(String val) async {
    if (val.length == 6) {
      setState(() {
        _isFetchingLocation = true;
        _isLocationVerified = false;
      });

      try {
        final response = await http
            .get(Uri.parse('https://api.postalpincode.in/pincode/$val'))
            .timeout(const Duration(seconds: 3)); // 3-second enterprise timeout

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
              });
            }
            return;
          }
        }
      } catch (e) {
        debugPrint("Pincode API Fallback Triggered: $e");
      }

      // Fallback: Enable manual entry if API fails or returns invalid
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _isLocationVerified = false;
          _cityCtrl.clear();
          _selectedState = null;
        });
      }
    } else {
      setState(() {
        _isLocationVerified = false;
        _isFetchingLocation = false;
      });
    }
  }

  // 📡 REAL-TIME IFSC API WITH GRACEFUL DEGRADATION
  Future<void> _onIfscChanged(String val) async {
    if (val.length == 11) {
      setState(() {
        _isFetchingBank = true;
        _isBankVerified = false;
      });

      try {
        final response = await http
            .get(Uri.parse('https://ifsc.razorpay.com/${val.toUpperCase()}'))
            .timeout(const Duration(seconds: 3)); // 3-second enterprise timeout

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              _bankNameCtrl.text = "${data['BANK']} (${data['BRANCH']})";
              _isBankVerified = true;
              _isFetchingBank = false;
              if (_accNameCtrl.text.isEmpty)
                _accNameCtrl.text = _brandCtrl.text.toUpperCase();
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("IFSC API Fallback Triggered: $e");
      }

      // Fallback: Enable manual entry if API fails or returns invalid
      if (mounted) {
        setState(() {
          _isFetchingBank = false;
          _isBankVerified = false;
          _bankNameCtrl.clear();
        });
      }
    } else {
      setState(() {
        _isBankVerified = false;
        _isFetchingBank = false;
        _bankNameCtrl.clear();
      });
    }
  }

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

  // 🛡️ DYNAMIC COMPLIANCE VALIDATION ENGINE
  Map<String, dynamic> _getLicenseConfig(String type) {
    switch (type) {
      case 'GSTIN':
        return {
          'label': 'GST Number *',
          'hint': 'e.g. 27ABCDE1234F1Z5',
          'maxLength': 15,
          'keyboard': TextInputType.text,
          'formatters': [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          'regex': r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[A-Z0-9]{3}$',
          'errorMsg': 'Invalid 15-digit GSTIN format',
        };
      case 'FSSAI':
        return {
          'label': 'FSSAI License Number *',
          'hint': '14-digit numeric code',
          'maxLength': 14,
          'keyboard': TextInputType.number,
          'formatters': [FilteringTextInputFormatter.digitsOnly],
          'regex': r'^[0-9]{14}$',
          'errorMsg': 'Must be exactly 14 digits',
        };
      case 'Drug License':
        return {
          'label': 'Drug License ID *',
          'hint': 'e.g. MH-DRUG-1234',
          'maxLength': 30,
          'keyboard': TextInputType.text,
          'formatters': [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\/\-]')),
          ],
          'regex': r'^[A-Z0-9\/\-]{6,30}$',
          'errorMsg': 'Invalid format (Min 6 chars)',
        };
      case 'Fire NOC':
      case 'Trade License':
      case 'Liquor License':
        return {
          'label': '$type Number *',
          'hint': 'Registration ID',
          'maxLength': 30,
          'keyboard': TextInputType.text,
          'formatters': [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\/\-]')),
          ],
          'regex': r'^[A-Z0-9\/\-]{5,30}$',
          'errorMsg': 'Invalid format (Min 5 chars)',
        };
      default:
        return {
          'label': 'Registration Code *',
          'hint': 'Enter registration code',
          'maxLength': 30,
          'keyboard': TextInputType.text,
          'formatters': <TextInputFormatter>[],
          'regex': r'^.{3,30}$',
          'errorMsg': 'Required (Min 3 chars)',
        };
    }
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
        _estYearCtrl.text = data['establishedYear']?.toString() ?? '';

        final contact = data['contact'] as Map<String, dynamic>? ?? {};
        _phoneCtrl.text = contact['phone'] ?? '';
        _emailCtrl.text = contact['email'] ?? '';
        _recoveryPhoneCtrl.text = contact['recoveryPhone'] ?? '';
        _recoveryEmailCtrl.text = contact['recoveryEmail'] ?? '';

        if (data['goods_or_services'] != null) {
          final List<dynamic> gs = data['goods_or_services'];
          _dealsInGoods = gs.contains('Goods');
          _dealsInServices = gs.contains('Services');
        }

        if (data['industries'] != null) {
          _selectedIndustries.clear();
          for (var ind in data['industries']) {
            _selectedIndustries.add(ind.toString());
          }
        }

        final location = data['location'] as Map<String, dynamic>? ?? {};
        _addressCtrl.text = location['address'] ?? '';
        _cityCtrl.text = location['city'] ?? '';
        _pincodeCtrl.text = location['pincode'] ?? '';
        _selectedState = _states.contains(location['state'])
            ? location['state']
            : null;

        if (data['licenses'] != null) {
          _dynamicLicenses.clear();
          for (var lic in data['licenses']) {
            _dynamicLicenses.add({
              'type': lic['type']?.toString() ?? 'Other',
              'number': lic['number']?.toString() ?? '',
            });
          }
        } else {
          if (_dynamicLicenses.isEmpty) _addLicenseRow();
        }

        final bank = data['bankDetails'] as Map<String, dynamic>? ?? {};
        _accNameCtrl.text = bank['accountName'] ?? '';
        _rawAccountNumber = bank['accountNo'] ?? '';
        _accNoCtrl.text = _rawAccountNumber;
        _ifscCtrl.text = bank['ifsc'] ?? '';
        _upiCtrl.text = bank['upi'] ?? '';
        _bankNameCtrl.text = bank['bankName'] ?? '';

        if (_pincodeCtrl.text.length == 6 && _cityCtrl.text.isNotEmpty)
          _isLocationVerified = true;
        if (_ifscCtrl.text.length == 11 && _bankNameCtrl.text.isNotEmpty)
          _isBankVerified = true;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            'establishedYear': int.tryParse(_estYearCtrl.text.trim()) ?? 0,

            'goods_or_services': [
              _dealsInGoods ? 'Goods' : null,
              _dealsInServices ? 'Services' : null,
            ].whereType<String>().toList(),

            'industries': _selectedIndustries,
            'licenses': _dynamicLicenses
                .where((l) => l['number']!.trim().isNotEmpty)
                .toList(),

            'contact.phone': _phoneCtrl.text.trim(),
            // Primary email is completely locked from updates here
            'contact.recoveryPhone': _recoveryPhoneCtrl.text.trim(),
            'contact.recoveryEmail': _recoveryEmailCtrl.text
                .trim()
                .toLowerCase(),

            'location.address': _addressCtrl.text.trim(),
            'location.city': _cityCtrl.text.trim(),
            'location.pincode': _pincodeCtrl.text.trim(),
            'location.state': _selectedState,

            'bankDetails.accountName': _accNameCtrl.text.trim(),
            'bankDetails.accountNo': _rawAccountNumber,
            'bankDetails.ifsc': _ifscCtrl.text.trim().toUpperCase(),
            'bankDetails.bankName': _bankNameCtrl.text.trim(),
            'bankDetails.upi': _upiCtrl.text.trim(),

            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("OS Profile Configured Securely"),
            backgroundColor: Theme.of(context).primaryColor,
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

  // --- PREMIUM UX INPUT DECORATION ---
  InputDecoration _deco(
    BuildContext context,
    String label, {
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isReadOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillCol = isDark
        ? (isReadOnly ? Colors.white10 : const Color(0xFF080B08))
        : (isReadOnly ? Colors.grey.shade100 : const Color(0xFFF8FAFC));
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade300;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white54 : Colors.black54,
        fontSize: 13,
      ),
      filled: true,
      fillColor: fillCol,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String title, Color brandColor) => Padding(
    padding: const EdgeInsets.only(top: 35, bottom: 15),
    child: Text(
      title,
      style: TextStyle(
        color: brandColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.success),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = context.colors.success;
    final bgCol = context.colors.scaffoldBg;
    final textCol = context.colors.textPrimary;
    final mutedCol = context.colors.textSecondary;

    return Dialog(
      backgroundColor: bgCol,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: brandColor.withValues(alpha: 0.2)),
      ),
      child: Container(
        width: 850,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(
          0,
        ), // Removed outer padding for edge-to-edge header
        child: Column(
          children: [
            // ── HEADER WITH READINESS SCORE ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF080B08)
                    : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Corporate Profile Engine",
                        style: TextStyle(
                          color: textCol,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            "Retail OS Readiness: ",
                            style: TextStyle(color: mutedCol, fontSize: 13),
                          ),
                          Text(
                            "${_readinessScore.toInt()}%",
                            style: TextStyle(
                              color: brandColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: mutedCol),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── SCROLLABLE FORM BODY ──
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 💡 SMART OS GUIDANCE BANNER
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: brandColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "This profile acts as the master configuration for your Retail OS. Information stored here automatically synchronizes store deployments, invoices, compliance tracking, and settlement logic.",
                                style: TextStyle(
                                  color: brandColor,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      _sectionTitle("1. Core Business Identity", brandColor),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _brandCtrl,
                              style: TextStyle(
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: _deco(
                                context,
                                "Registered Company / Brand Name *",
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _ownerCtrl,
                              style: TextStyle(color: textCol),
                              decoration: _deco(
                                context,
                                "Authorized Owner Name *",
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
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
                              style: TextStyle(color: textCol),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _deco(
                                context,
                                "Master Contact Number *",
                                prefixIcon: const Icon(Icons.phone, size: 18),
                              ).copyWith(counterText: ""),
                              validator: (v) {
                                if (v == null || v.isEmpty) return "Required";
                                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                                  return "Invalid Indian Mobile";
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              readOnly: true,
                              style: TextStyle(
                                color: mutedCol,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: _deco(
                                context,
                                "Primary Admin Email (Locked)",
                                isReadOnly: true,
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: mutedCol,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Primary Delivery Sector",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: Text(
                                "Goods / Physical Products",
                                style: TextStyle(color: textCol, fontSize: 14),
                              ),
                              value: _dealsInGoods,
                              activeColor: brandColor,
                              checkColor: isDark ? Colors.black : Colors.white,
                              onChanged: (val) =>
                                  setState(() => _dealsInGoods = val ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: Text(
                                "Services",
                                style: TextStyle(color: textCol, fontSize: 14),
                              ),
                              value: _dealsInServices,
                              activeColor: brandColor,
                              checkColor: isDark ? Colors.black : Colors.white,
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

                      TextFormField(
                        controller: _industrySearchCtrl,
                        style: TextStyle(color: textCol),
                        decoration:
                            _deco(
                              context,
                              "Search & Add Operational Industry Nodes *",
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(Icons.add_circle, color: brandColor),
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
                            color: isDark
                                ? const Color(0xFF080B08)
                                : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredIndustries.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(
                                  _filteredIndustries[index],
                                  style: TextStyle(color: textCol),
                                ),
                                trailing: Icon(
                                  Icons.add,
                                  color: brandColor,
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
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: isDark
                                    ? brandColor.withValues(alpha: 0.15)
                                    : brandColor.withValues(alpha: 0.1),
                                deleteIconColor: brandColor,
                                onDeleted: () {
                                  setState(
                                    () => _selectedIndustries.remove(industry),
                                  );
                                },
                                side: BorderSide(
                                  color: brandColor.withValues(alpha: 0.3),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      _sectionTitle("2. Global HQ Location", brandColor),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeCtrl,
                              style: TextStyle(color: textCol),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              onChanged: _onPincodeChanged,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _deco(
                                context,
                                "Postal Pincode *",
                                suffixIcon: _isFetchingLocation
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
                                  v!.length != 6 ? "6 Digits required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _cityCtrl,
                              style: TextStyle(color: textCol),
                              onChanged: (_) => setState(() {}),
                              decoration: _deco(context, "City *"),
                              validator: (v) => v!.isEmpty ? "Required" : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedState,
                              dropdownColor: isDark
                                  ? const Color(0xFF080B08)
                                  : Colors.white,
                              style: TextStyle(color: textCol),
                              decoration: _deco(context, "State *"),
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
                        controller: _addressCtrl,
                        style: TextStyle(color: textCol),
                        decoration: _deco(context, "Complete Office Address *"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),

                      _sectionTitle("3. Security & Legal Slate", brandColor),
                      const Text(
                        "Add licenses only if applicable to your business. This helps unlock automated compliance checks.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ..._dynamicLicenses.asMap().entries.map((entry) {
                        int idx = entry.key;
                        Map<String, String> lic = entry.value;

                        // 🚀 FETCH DYNAMIC COMPLIANCE CONFIG
                        final config = _getLicenseConfig(
                          lic['type'] ?? 'Other',
                        );
                        final currentValue = lic['number'] ?? '';
                        final isValid = RegExp(
                          config['regex'] as String,
                        ).hasMatch(currentValue.toUpperCase());
                        final hasInput = currentValue.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment
                                .start, // Align to top to handle error messages
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _licenseTypes.contains(lic['type'])
                                      ? lic['type']
                                      : 'Other',
                                  dropdownColor: isDark
                                      ? const Color(0xFF080B08)
                                      : Colors.white,
                                  style: TextStyle(color: textCol),
                                  decoration: _deco(context, "Compliance Type"),
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
                                    _dynamicLicenses[idx]['number'] =
                                        ''; // 🧹 Auto-wipe mismatched garbage data
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  key: ValueKey(
                                    "${idx}_${lic['type']}",
                                  ), // 🔄 Force UI rebuild when type changes
                                  initialValue: currentValue,
                                  style: TextStyle(color: textCol),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: config['maxLength'],
                                  keyboardType: config['keyboard'],
                                  inputFormatters: config['formatters'],
                                  decoration:
                                      _deco(
                                        context,
                                        config['label'] as String,
                                      ).copyWith(
                                        hintText: config['hint'] as String,
                                        counterText: "",
                                        suffixIcon: hasInput
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
                                      ),
                                  onChanged: (v) {
                                    _dynamicLicenses[idx]['number'] = v
                                        .trim()
                                        .toUpperCase();
                                    setState(
                                      () {},
                                    ); // 🔄 Trigger live icon validation update
                                  },
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return "Required";
                                    if (!RegExp(
                                      config['regex'] as String,
                                    ).hasMatch(v.toUpperCase()))
                                      return config['errorMsg'] as String;
                                    return null;
                                  },
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
                      TextButton.icon(
                        onPressed: _addLicenseRow,
                        icon: Icon(Icons.add, color: brandColor, size: 16),
                        label: Text(
                          "Add Another Slate",
                          style: TextStyle(
                            color: brandColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      _sectionTitle("4. Banking & Settlement Node", brandColor),
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: brandColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              color: brandColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "This primary account acts as the default gateway for settlements, payouts, and automated invoice reconciliations.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ifscCtrl,
                              style: TextStyle(color: textCol),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 11,
                              onChanged: _onIfscChanged,
                              decoration: _deco(
                                context,
                                "IFSC Code *",
                                suffixIcon: _isFetchingBank
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
                              validator: (v) =>
                                  !RegExp(
                                    r'^[A-Z]{4}0[A-Z0-9]{6}$',
                                  ).hasMatch(v!)
                                  ? "Invalid IFSC"
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _bankNameCtrl,
                              readOnly: _isBankVerified, // Lock if auto-fetched
                              style: TextStyle(
                                color: _isBankVerified ? mutedCol : textCol,
                              ),
                              decoration: _deco(
                                context,
                                "Resolved Clearing Branch",
                                isReadOnly: _isBankVerified,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              focusNode: _accNoFocus,
                              controller: _accNoCtrl,
                              style: TextStyle(color: textCol),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                if (_accNoFocus.hasFocus) _rawAccountNumber = v;
                                setState(() {}); // Trigger readiness update
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _deco(
                                context,
                                "Master Settlement Account *",
                              ),
                              validator: (v) => _rawAccountNumber.length < 9
                                  ? "Invalid Account boundary"
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _accNameCtrl,
                              style: TextStyle(color: textCol),
                              decoration: _deco(
                                context,
                                "Account Holder Name *",
                              ),
                              validator: (v) =>
                                  v!.trim().isEmpty ? "Required" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 58,
                        child: TextFormField(
                          controller: _upiCtrl,
                          style: TextStyle(color: textCol),
                          decoration: _deco(
                            context,
                            "Settlement UPI Tag (Optional)",
                            prefixIcon: const Icon(
                              Icons.qr_code_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),

                      // 🛡️ NEW: ENTERPRISE RECOVERY SYSTEM
                      _sectionTitle(
                        "5. Enterprise Recovery System",
                        brandColor,
                      ),
                      const Text(
                        "Used exclusively for account recovery and emergency security verification if primary access is lost.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _recoveryEmailCtrl,
                              style: TextStyle(color: textCol),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _deco(
                                context,
                                "Backup Recovery Email (Optional)",
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              validator: (v) =>
                                  (v != null &&
                                      v.isNotEmpty &&
                                      !v.contains('@'))
                                  ? "Invalid Email"
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              controller: _recoveryPhoneCtrl,
                              style: TextStyle(color: textCol),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _deco(
                                context,
                                "Backup Recovery Phone (Optional)",
                                prefixIcon: const Icon(
                                  Icons.phone_android,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ).copyWith(counterText: ""),
                              validator: (v) =>
                                  (v != null &&
                                      v.isNotEmpty &&
                                      !RegExp(r'^[6-9]\d{9}$').hasMatch(v))
                                  ? "Invalid Mobile"
                                  : null,
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

            // ── FOOTER ACTIONS ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
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
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isSaving ? null : _saveData,
                    icon: _isSaving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.black : Colors.white,
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
