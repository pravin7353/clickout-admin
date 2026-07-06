import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';
import '../../core/theme/app_theme.dart';

class InvoiceRulesDialog extends ConsumerStatefulWidget {
  const InvoiceRulesDialog({super.key});

  @override
  ConsumerState<InvoiceRulesDialog> createState() => _InvoiceRulesDialogState();
}

class _InvoiceRulesDialogState extends ConsumerState<InvoiceRulesDialog> {
  final _prefixCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();

  // 🗑️ HATA DIYA: _docTitle ab zaroorat nahi hai, PDF engine math se decide karega.

  bool _isLoading = true;
  bool _isSaving = false;
  String _tenantId = '';

  // 🎨 Premium Theme Constants
  final Color accentGreen = const Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _fetchRules();
  }

  // ⚙️ LOGIC REMAINS 100% UNTOUCHED
  Future<void> _fetchRules() async {
    final adminData = ref.read(adminRoleProvider).value;
    _tenantId = adminData?['tenantId'] ?? '';

    if (_tenantId.isNotEmpty && _tenantId != 'ALL' && _tenantId != 'GLOBAL') {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(_tenantId)
            .get();
        if (doc.exists) {
          final config =
              doc.data()?['invoiceConfig'] as Map<String, dynamic>? ?? {};

          // 🧹 THE AUTO-CLEANER: Database me agar purana saal save hai, toh usko filter kar dega
          String savedPrefix = config['invoicePrefix']?.toString().trim() ?? '';

          // Ye regex kisi bhi "XX-XX/" ya "XX-XX" pattern ko hata dega (eg: 23-24/)
          savedPrefix = savedPrefix.replaceAll(RegExp(r'\d{2}-\d{2}[/-]?'), '');

          // Agar sab hatne ke baad khali ho gaya, toh default 'INV/' dikhayega
          _prefixCtrl.text = savedPrefix.isNotEmpty ? savedPrefix : 'INV/';

          _hsnCtrl.text = config['hsnCode'] ?? '';
          _termsCtrl.text =
              config['terms'] ??
              '1. Exchange within 7 days with original receipt.\n2. Goods once sold will not be refunded.';
        }
      } catch (e) {
        debugPrint("Error fetching rules: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  // ⚙️ LOGIC REMAINS 100% UNTOUCHED
  Future<void> _saveRules() async {
    if (_tenantId.isEmpty || _tenantId == 'ALL' || _tenantId == 'GLOBAL') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Open a specific store to save rules."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('tenants').doc(_tenantId).set(
        {
          'invoiceConfig': {
            'invoicePrefix': _prefixCtrl.text.trim(),
            'hsnCode': _hsnCtrl.text.trim(),
            'terms': _termsCtrl.text.trim(),
          },
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Invoice Rules Saved!"),
            backgroundColor: accentGreen.withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🎨 Premium Colors based on theme
    final bgDark = context.colors.scaffoldBg;
    final cardDark = context.colors.cardBg;
    final textC = context.colors.textPrimary;
    final textMuted = context.colors.textSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? accentGreen.withOpacity(0.05)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: _isLoading
            ? SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(color: accentGreen),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🌟 PREMIUM HEADER
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: accentGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "Invoice Settings",
                                    style: TextStyle(
                                      color: textC,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const InfoButton(
                                    title: "Invoice Settings",
                                    en: "Customize your invoice number format and legal terms that print on every customer receipt.",
                                    hi: "Yahan apna invoice number ka format aur T&C set karo jo har customer ki receipt pe print hoga.",
                                  ),
                                ],
                              ),
                              Text(
                                "Configure billing rules and legal terms",
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // 📜 SCROLLABLE FORM CONTENT
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Row(
                          children: [
                            Text(
                              "BILLING IDENTIFIERS",
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const InfoButton(
                              title: "Invoice Prefix",
                              en: "This short code appears before every invoice number. e.g. 'MART01' → MART01/25-26/04-23-01",
                              hi: "Yeh chhota code har invoice number ke aage lagta hai. Jaise 'MART01' → MART01/25-26/04-23-01 banega.",
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildPremiumTextField(
                                label: "Invoice Prefix",
                                hint: "e.g., MART01",
                                controller: _prefixCtrl,
                                icon: Icons.tag,
                                isDark: isDark,
                                cardDark: cardDark,
                              ),
                            ),
                            const SizedBox(width: 16),
                            /*Expanded(
                              child: _buildPremiumTextField(
                                label: "Default HSN/SAC",
                                hint: "e.g., 9983",
                                controller: _hsnCtrl,
                                icon: Icons.account_balance,
                                isDark: isDark,
                                cardDark: cardDark,
                              ),
                            ),*/
                          ],
                        ),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Text(
                              "LEGAL & POLICIES",
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const InfoButton(
                              title: "Terms & Conditions",
                              en: "These lines print at the bottom of every invoice. Use it for exchange policy, refund rules, or any legal disclaimer.",
                              hi: "Yeh lines har invoice ke neeche print hoti hain. Exchange policy, refund rules, ya koi bhi legal warning yahan likhein.",
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildPremiumTextField(
                          label: "Exchange Policy / Terms & Conditions",
                          hint: "Enter your legal terms here...",
                          controller: _termsCtrl,
                          icon: Icons.gavel,
                          isDark: isDark,
                          cardDark: cardDark,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  // 🚀 PREMIUM FOOTER ACTIONS
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentGreen,
                            foregroundColor: Colors
                                .black, // Dark text on green button looks premium
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSaving ? null : _saveRules,
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
                                  "Save Configuration",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
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

  // 🎨 PREMIUM TEXT FIELD WIDGET
  Widget _buildPremiumTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required Color cardDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: Colors.grey, size: 18)
                : null,
            filled: true,
            fillColor: cardDark,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentGreen),
            ),
          ),
        ),
      ],
    );
  }
}
