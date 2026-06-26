import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../refund/providers/refund_engine_provider.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';

class RefundDecisionScreen extends ConsumerStatefulWidget {
  const RefundDecisionScreen({super.key});

  @override
  ConsumerState<RefundDecisionScreen> createState() =>
      _RefundDecisionScreenState();
}

class _RefundDecisionScreenState extends ConsumerState<RefundDecisionScreen> {
  final _searchController = TextEditingController();

  void _search() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(refundEngineProvider.notifier).searchOrderForRefund(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refundState = ref.watch(refundEngineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark; // 🚀 ADDED

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎩 HEADER
          Row(
            children: [
              Text(
                "Refund Decision Engine 💸",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF2B3674),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: 'Refund Decision Engine',
                en: 'Admin tool to process customer refunds in 3 tiers. Tier 1 (Wallet) keeps money inside the system — fastest and preferred. Tier 2 (Source/Bank) sends money back to original payment method — takes T+3 days. Tier 3 (Partial) refunds only a specific amount. Every refund is irreversible and logged in The Black Box with admin name, reason, and timestamp.',
                hi: 'Customer refund process karne ka admin tool — 3 tier mein. Tier 1 (Wallet) mein paisa system ke andar rehta hai — sabse fast. Tier 2 (Source/Bank) mein paisa wapas bank mein jaata hai — T+3 din lagte hain. Tier 3 (Partial) mein sirf kuch amount refund hoti hai. Har refund irreversible hai aur The Black Box mein admin ke naam, reason, aur time ke saath record hoti hai.',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "3-Tier Smart Refunds. Protect revenue by prioritizing Wallet refunds over Source.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // 🔍 THE UPGRADED ENTERPRISE SEARCH BAR
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 650),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Enter Order ID to process refund (e.g. 2DVGUUT8...)",
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Icon(
                    Icons.search,
                    color: Colors.blueAccent.shade700,
                    size: 24,
                  ),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onPressed: _search,
                    child: const Text(
                      "FETCH INTEL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(height: 40),

          // 📊 RESULTS PANEL
          refundState.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),
            error: (err, _) => _buildErrorBox(err.toString()),
            data: (order) {
              if (order == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A221A)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.manage_search,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Awaiting Order ID",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        "Enter an Order ID above to load the Decision Matrix.",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              final status = (order['status'] ?? '').toString().toUpperCase();
              if (status == 'REFUNDED') {
                return _buildSuccessBox(
                  "🔒 ALREADY REFUNDED. IDEMPOTENCY LOCK ACTIVE.",
                );
              }

              final totalAmount =
                  double.tryParse(order['totalAmount']?.toString() ?? '0') ??
                  0.0;
              final trustScore = order['trustScore'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoCard(
                        "Total Amount",
                        "₹${totalAmount.toStringAsFixed(2)}",
                        Colors.blueAccent.shade700,
                      ),
                      const SizedBox(width: 20),
                      _buildInfoCard(
                        "Trust Score",
                        "$trustScore/100",
                        trustScore > 80 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Text(
                        "Select Refund Tier:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2B3674),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const InfoButton(
                        title: 'Refund Tiers',
                        en: 'Tier 1 Wallet: Instant, money stays in app — recommended for high trust score (80+). Tier 2 Source: Refund to original bank/UPI — use for low trust or disputed orders, takes T+3 days. Tier 3 Partial: Enter a custom amount less than the total — use when only part of the order is being refunded.',
                        hi: 'Tier 1 Wallet: Turant, paisa app mein rehta hai — high trust score (80+) wale customers ke liye best. Tier 2 Source: Bank/UPI mein wapas — low trust ya disputed orders ke liye, T+3 din lagte hain. Tier 3 Partial: Custom amount daalo — jab sirf order ka kuch hissa refund karna ho.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          title: "Tier 1: Wallet (Instant)",
                          subtitle: "Retains capital inside the system.",
                          icon: Icons.account_balance_wallet,
                          color: Colors.green,
                          isRecommended: trustScore >= 80,
                          onTap: () => _executeRefund(
                            order['id'],
                            'WALLET',
                            totalAmount,
                            false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionCard(
                          title: "Tier 2: Source (Bank)",
                          subtitle: "Takes T+3 Days. High risk profiles.",
                          icon: Icons.account_balance,
                          color: Colors.orange,
                          isRecommended: trustScore < 80,
                          onTap: () => _executeRefund(
                            order['id'],
                            'SOURCE',
                            totalAmount,
                            false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildActionCard(
                          title: "Tier 3: Partial",
                          subtitle: "Refund only specific items.",
                          icon: Icons.pie_chart,
                          color: Colors.purple,
                          isRecommended: false,
                          onTap: () => _executeRefund(
                            order['id'],
                            'PARTIAL',
                            totalAmount,
                            true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 🚀 TRIGGERS THE NEW PROFESSIONAL DIALOG
  void _executeRefund(
    String orderId,
    String tier,
    double maxAmount,
    bool isPartial,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EnterpriseRefundDialog(
        orderId: orderId,
        maxAmount: maxAmount,
        tierType: tier,
        isPartial: isPartial,
        onConfirm: (finalAmount, reason) async {
          await ref
              .read(refundEngineProvider.notifier)
              .processRefund(
                orderId: orderId,
                refundTier: tier,
                refundAmount: finalAmount,
                reason: reason,
              );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isRecommended ? color : Colors.grey.withValues(alpha: 0.2),
            width: isRecommended ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      "RECOMMENDED",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBox(String err) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "🚨 System Alert: $err",
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            msg,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🎨 THE HIGHLY PROFESSIONAL DIALOG WIDGET (WITH PARTIAL AMOUNT LOGIC)
// ============================================================================
class EnterpriseRefundDialog extends StatefulWidget {
  final String orderId;
  final double maxAmount;
  final String tierType;
  final bool isPartial;
  final Future<void> Function(double finalAmount, String reason) onConfirm;

  const EnterpriseRefundDialog({
    super.key,
    required this.orderId,
    required this.maxAmount,
    required this.tierType,
    required this.isPartial,
    required this.onConfirm,
  });

  @override
  State<EnterpriseRefundDialog> createState() => _EnterpriseRefundDialogState();
}

class _EnterpriseRefundDialogState extends State<EnterpriseRefundDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _customAmountCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _customAmountCtrl.dispose();
    super.dispose();
  }

  void _processRefund() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🚨 Refund reason is strictly required for Audit logs.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double finalRefundAmount = widget.maxAmount;

    // 🚀 PARTIAL REFUND VALIDATION
    if (widget.isPartial) {
      finalRefundAmount = double.tryParse(_customAmountCtrl.text.trim()) ?? 0.0;
      if (finalRefundAmount <= 0 || finalRefundAmount > widget.maxAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "🚨 Invalid Partial Amount! Must be greater than 0 and less than total.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await widget.onConfirm(finalRefundAmount, _reasonCtrl.text.trim());

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); // Close Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ ₹${finalRefundAmount.toStringAsFixed(2)} Refund to ${widget.tierType} Initiated Successfully!",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color themeColor = Colors.blueAccent;
    IconData tierIcon = Icons.account_balance;
    String title = "Bank Source Refund";
    String settlementText = "Takes 3-5 Business Days (T+3)";

    if (widget.tierType == 'WALLET') {
      themeColor = Colors.green;
      tierIcon = Icons.account_balance_wallet;
      title = "Instant Wallet Refund";
      settlementText = "Immediate Credit to ClickOut Wallet";
    } else if (widget.tierType == 'PARTIAL') {
      themeColor = Colors.purple;
      tierIcon = Icons.pie_chart;
      title = "Partial Order Refund";
      settlementText = "Custom amount processing";
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 24,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: themeColor.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tierIcon, color: themeColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: themeColor,
                          ),
                        ),
                        Text(
                          "Action Requires Authorization",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 💼 BODY
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏦 FUTURE BANKING DATA MOCK (Read Only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A221A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          "Order ID",
                          widget.orderId,
                          isHighlight: true,
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          "Max Eligible Amount",
                          "₹${widget.maxAmount.toStringAsFixed(2)}",
                          isHighlight: true,
                          color: Colors.black87,
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          "Original Gateway Txn",
                          "pay_MockTxn8921...",
                          isSub: true,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow("Payment Mode", "UPI", isSub: true),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          "Settlement",
                          settlementText,
                          isSub: true,
                          color: themeColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💸 DYNAMIC INPUT: Custom Amount for Partial Refund
                  if (widget.isPartial) ...[
                    const Text(
                      "Refund Amount (₹) *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : Colors.black87, // 🚀 DARK MODE FIX
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter amount up to ₹${widget.maxAmount}",
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: themeColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ✍️ AUDIT REASON INPUT
                  const Text(
                    "Audit Compliance Reason (Required) *",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 2,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ), // 🚀 DARK MODE FIX
                    decoration: InputDecoration(
                      hintText:
                          "E.g., Customer cancelled at gate, Item out of stock...",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This action is irreversible and will be permanently recorded in The Black Box.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ⚡ ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _processRefund,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.shield, size: 18),
                    label: Text(
                      _isLoading ? "AUTHORIZING..." : "AUTHORIZE REFUND",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
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

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isSub = false,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? Colors.grey.shade600 : Colors.grey.shade500,
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                color ??
                (isHighlight
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.grey.shade500),
            fontSize: isHighlight ? 16 : 12,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold,
            fontFamily: isSub ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
