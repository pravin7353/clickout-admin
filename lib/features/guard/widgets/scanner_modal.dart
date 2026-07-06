import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../services/guard_service.dart';
import '../../coach/widgets/info_button.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class ScannerModal extends ConsumerStatefulWidget {
  const ScannerModal({super.key});

  @override
  ConsumerState<ScannerModal> createState() => _ScannerModalState();
}

class _ScannerModalState extends ConsumerState<ScannerModal> {
  final TextEditingController _orderIdCtrl = TextEditingController();
  final TextEditingController _overrideIdCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showOverrideMode = false;

  String _selectedReason = 'Select a reason';
  final List<String> _overrideReasons = [
    'Select a reason',
    'Scanner Broken',
    'VIP Customer',
    'Emergency/Fire',
    'System Glitch',
  ];

  bool get _canSubmitOverride =>
      _selectedReason != 'Select a reason' && !_isLoading;

  void _processScan() async {
    if (_orderIdCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    // 🚀 SAAS INJECTION: Fetch Tenant & Branch for Strict Isolation
    final adminData = ref.read(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String? branchCode = adminData?['branchCode'];

    final Map<String, dynamic> result = await GuardService.processValidScan(
      _orderIdCtrl.text,
      tenantId,
      branchCode,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context); // Close the scanner modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg']), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // 🚨 OVERRIDE SUBMIT HANDLER (Cleaned up & Wired)
  void _submitOverride() async {
    if (!_canSubmitOverride) return;
    setState(() => _isLoading = true);

    // 🚀 SAAS INJECTION
    final adminData = ref.read(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];

    final Map<String, dynamic> result =
        await GuardService.processManualOverride(
          _selectedReason,
          tenantId,
          linkedOrderId: _overrideIdCtrl.text.isNotEmpty
              ? _overrideIdCtrl.text
              : null,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result['msg'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD13212), // Emergency Red
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['msg']),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ➖ DRAG HANDLE
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24, // ⚪ Dark Mode Handle
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // 🏷️ HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _showOverrideMode
                            ? "Gate Override Protocol"
                            : "Verify Gate Pass",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _showOverrideMode
                              ? Colors.redAccent
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InfoButton(
                        title: _showOverrideMode
                            ? 'Gate Override Protocol'
                            : 'Verify Gate Pass',
                        en: _showOverrideMode
                            ? 'Emergency override — allows exit WITHOUT a valid Gate Pass QR. Use only for: scanner failure, VIP customer, emergency, or system glitch. Every override is logged with reason and timestamp. Misuse is traceable.'
                            : 'Scan or type the Order ID from customer\'s ClickOut app Gate Pass. System checks: payment status, weight match, QR validity, and tenant isolation. Green = authorize exit. Red = reject and flag.',
                        hi: _showOverrideMode
                            ? 'Emergency mein bina QR ke exit dene ka option. Sirf tab use karo jab scanner kharab ho, VIP ho, ya emergency ho. Har override ka reason aur time log hota hai — misuse pakda jayega.'
                            : 'Customer ke ClickOut app ka Order ID scan karo ya type karo. System check karta hai — payment hua, weight match hai, QR valid hai. Green = exit do. Red = reject karo aur flag lagao.',
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 🔍 STANDARD SCAN MODE
              if (!_showOverrideMode) ...[
                TextField(
                  controller: _orderIdCtrl,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B2559),
                    fontWeight: FontWeight.bold,
                  ),
                  onSubmitted: (_) => _processScan(),
                  decoration: InputDecoration(
                    labelText: "Scan or Type Order ID",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF1F5F9),
                    prefixIcon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.green, // 🚀 CHANGED TO GREEN
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // 🚀 CHANGED TO GREEN
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _processScan,
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1B2559),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "AUTHORIZE EXIT",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ]
              // 🚨 OVERRIDE MODE
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  dropdownColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  decoration: InputDecoration(
                    labelText: "Override Reason (Required)",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B2559),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  items: _overrideReasons.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        style: TextStyle(
                          color: r == 'Select a reason'
                              ? Colors.grey
                              : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1B2559)),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedReason = val!),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _overrideIdCtrl,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B2559),
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: "Linked Order ID (Optional)",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.redAccent, // 🚨 EMERGENCY RED BUTTON
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _showOverrideMode
                        ? (_canSubmitOverride ? _submitOverride : null)
                        : _processScan,
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1B2559),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "FORCE OPEN GATE",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 🔄 TOGGLE BUTTON
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _showOverrideMode = !_showOverrideMode;
                    _orderIdCtrl.clear();
                    _overrideIdCtrl.clear();
                    _selectedReason = 'Select a reason';
                  }),
                  child: Text(
                    _showOverrideMode
                        ? "Cancel & Return to Standard Scan"
                        : "Scanner Broken? Manual Override",
                    style: TextStyle(
                      color: _showOverrideMode
                          ? Colors.grey.shade400
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
