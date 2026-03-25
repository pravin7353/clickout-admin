import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 ADDED RIVERPOD
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 ADDED AUTH PROVIDER
import '../services/guard_service.dart';

// 🚀 CHANGED TO ConsumerStatefulWidget
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

    // 🚀 SAAS INJECTION: Fetch Tenant ID
    final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

    final result = await GuardService.processValidScan(
      _orderIdCtrl.text,
      tenantId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);

    _showResult(
      result['msg']?.toString() ?? 'Error',
      result['success'] == true,
    );
  }

  void _processOverride() async {
    if (!_canSubmitOverride) return;

    setState(() => _isLoading = true);

    // 🚀 SAAS INJECTION: Fetch Tenant ID
    final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

    final Map<String, dynamic> result =
        await GuardService.processManualOverride(
          _selectedReason,
          tenantId,
          linkedOrderId: _overrideIdCtrl.text.isNotEmpty
              ? _overrideIdCtrl.text
              : null,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);

    final String message =
        result['msg']?.toString() ?? 'Unknown Error Occurred';
    final bool isSuccess = result['success'] == true;

    _showResult(message, isSuccess, isOverride: true);
  }

  void _showResult(String msg, bool success, {bool isOverride = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? (isOverride
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle)
                  : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: success
            ? (isOverride ? const Color(0xFFD13212) : const Color(0xFF0F9D58))
            : const Color(0xFF232F3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showOverrideMode
                        ? "Gate Override Protocol"
                        : "Verify Gate Pass",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _showOverrideMode
                          ? const Color(0xFFD13212)
                          : const Color(0xFF232F3E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!_showOverrideMode) ...[
                TextField(
                  controller: _orderIdCtrl,
                  autofocus: true,
                  onSubmitted: (_) => _processScan(),
                  decoration: InputDecoration(
                    labelText: "Scan or Type Order ID",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFF232F3E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Color(0xFF232F3E),
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
                      backgroundColor: const Color(0xFF232F3E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _processScan,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
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
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF232F3E),
                  ),
                  decoration: InputDecoration(
                    labelText: "Override Reason (Required)",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Color(0xFFD13212),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF232F3E),
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
                              : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedReason = val!),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _overrideIdCtrl,
                  decoration: InputDecoration(
                    labelText: "Linked Order ID (Optional)",
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Color(0xFFD13212),
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
                      backgroundColor: _canSubmitOverride
                          ? const Color(0xFFD13212)
                          : Colors.grey.shade300,
                      foregroundColor: _canSubmitOverride
                          ? Colors.white
                          : Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _processOverride,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
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
                          ? Colors.grey.shade600
                          : const Color(0xFFD13212),
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
