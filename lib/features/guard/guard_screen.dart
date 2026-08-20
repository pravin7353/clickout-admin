import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'providers/guard_provider.dart';
import 'widgets/scanner_modal.dart';
import 'services/guard_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../coach/widgets/info_button.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class GuardScreen extends ConsumerWidget {
  const GuardScreen({super.key});

  // 🛑 REJECT GATEPASS LOGIC & POPUP
  void _handleReject(BuildContext context, String orderId, WidgetRef ref) {
    final TextEditingController reasonCtrl = TextEditingController();
    bool isRejecting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: context.colors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.colors.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad, color: Colors.redAccent),
                SizedBox(width: 10),
                Text(
                  "Reject Gate Pass",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Why are you blocking this exit?",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText:
                        "E.g., Extra unbilled items found, Weight Mismatch...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isRejecting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                icon: isRejecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.block, size: 18),
                label: Text(
                  isRejecting ? "BLOCKING..." : "CONFIRM REJECT",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: isRejecting
                    ? null
                    : () async {
                        if (reasonCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text("Reason is required!"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        setState(() => isRejecting = true);
                        final adminData = ref.read(adminRoleProvider).value;
                        final tenantId = adminData?['tenantId'];

                        final branchCode = adminData?['branchCode'];
                        final success = await GuardService.rejectGatePass(
                          orderId, // 🚀 Direct pass, no 'orderId:' label
                          tenantId, // 🚀 Direct pass, no 'tenantId:' label
                          branchCode: branchCode,
                        );

                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "🚨 Gate Pass Rejected & Logged!",
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } else {
                          setState(() => isRejecting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text("Error rejecting pass"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // 👁️ THE DIGITAL GATE PASS (AUTOPSY PANEL) - 🚀 UPGRADED TO DARK THEME & RESPONSIVE
  void _showAutopsyPanel(
    BuildContext context,
    Map<String, dynamic> data,
    String orderId,
    WidgetRef ref,
  ) {
    DateTime date =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    double finalTotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    List<dynamic> itemsList = data['cartItems'] ?? data['items'] ?? [];
    String eStatus = (data['exitStatus'] ?? '').toString().toUpperCase();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "GatePass",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 24,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            child: Container(
              // 🚀 RESPONSIVE WIDTH: Auto-adjusts for mobile vs desktop
              width: MediaQuery.of(context).size.width > 600
                  ? 450
                  : MediaQuery.of(context).size.width,
              height: double.infinity,
              color: context.colors.scaffoldBg, // ⬛ PREMIUM DARK
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                left: 24,
                right: 24,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: Colors.blueAccent,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Digital Gate Pass",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 15, color: Colors.white10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ORDER ID: ${orderId.toUpperCase()}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(date),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Verify Items in Cart:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: itemsList.isEmpty
                          ? const Center(
                              child: Text(
                                "No items found.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: itemsList.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(color: Colors.white10),
                              itemBuilder: (context, index) {
                                final item =
                                    itemsList[index] as Map<String, dynamic>;
                                int qty =
                                    int.tryParse(
                                      item['qty']?.toString() ??
                                          item['quantity']?.toString() ??
                                          '1',
                                    ) ??
                                    1;
                                double price =
                                    double.tryParse(
                                      item['price']?.toString() ??
                                          item['discountedPrice']?.toString() ??
                                          item['originalPrice']?.toString() ??
                                          '0',
                                    ) ??
                                    0.0;
                                double itemTotal = qty * price;
                                String itemName =
                                    item['name']?.toString() ??
                                    'Unknown Product';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "${qty}x",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueAccent,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "@ ₹${price.toStringAsFixed(2)} / unit",
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "₹${itemTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "BILL TOTAL",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.greenAccent,
                          ),
                        ),
                        Text(
                          "₹${finalTotal.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (eStatus == 'PENDING' || eStatus == 'READY_FOR_EXIT') ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(
                            alpha: 0.1,
                          ),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.gpp_bad),
                        label: const Text(
                          "REJECT & BLOCK EXIT",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        onPressed: () => _handleReject(context, orderId, ref),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingState = ref.watch(pendingExitsProvider);
    final historyState = ref.watch(gateHistoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor, // 🌓 DYNAMIC BACKGROUND
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Super Guard 🛡️",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const InfoButton(
                                title: 'Super Guard — Gate Intelligence',
                                en: 'Real-time exit control system. Every customer who pays via ClickOut app gets a Gate Pass (QR). Guard scans it here to authorize exit.\n\nApprove = customer exits normally.\nReject = weight mismatch, QR fraud, or suspicious items detected.\nOverride = emergency exit without QR (requires reason logging).\n\nEvery rejection is logged as a fraud alert automatically.',
                                hi: 'Ye exit control system hai. Jo customer ClickOut app se payment karta hai use Gate Pass milta hai. Guard yahan scan karta hai exit ke liye.\n\nApprove = normal exit.\nReject = weight mismatch ya suspicious activity pakdi.\nOverride = emergency mein bina QR exit — reason log hota hai automatically.\n\nHar rejection fraud alert mein jaata hai — koi cheez chhupti nahi.',
                              ),
                            ],
                          ),
                          Text(
                            "Gate Intelligence & Live Radar",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.labelLarge?.color,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: const Text(
                      "Scan Gate Pass",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // 🚀 CHANGED TO GREEN
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ScannerModal(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                "Live Exit Radar (Action Required)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),

              pendingState.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                ),
                error: (err, stack) => _buildErrorCard(
                  "Radar offline: Firebase Index required! Check console.",
                ),
                data: (pendingDocs) {
                  if (pendingDocs.isEmpty) {
                    return _buildSafeCard(
                      "Store is Clear. No pending exits detected.",
                    );
                  }
                  return SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: pendingDocs.length,
                      itemBuilder: (context, index) {
                        final data =
                            pendingDocs[index].data() as Map<String, dynamic>;
                        final orderId = pendingDocs[index].id
                            .substring(0, 8)
                            .toUpperCase();
                        DateTime date =
                            (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final minutesWaiting = DateTime.now()
                            .difference(date)
                            .inMinutes;
                        Color riskColor = Colors.orangeAccent;
                        String riskText = "Waiting";
                        if (minutesWaiting > 30) {
                          riskColor = Colors.redAccent;
                          riskText = "CRITICAL: Stuck";
                        } else if (minutesWaiting > 10) {
                          riskColor = Colors.deepOrangeAccent;
                          riskText = "Delayed";
                        }

                        return Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: riskColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: riskColor.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    orderId,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: riskColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "$minutesWaiting mins",
                                      style: TextStyle(
                                        color: riskColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                "Amount: ₹${data['totalAmount'] ?? '0'}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: riskColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    riskText,
                                    style: TextStyle(
                                      color: riskColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
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
                        Text(
                          "Recent Gate Activity",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Chip(
                          label: const Text(
                            "Live Stream 🟢",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.greenAccent.withValues(
                            alpha: 0.1,
                          ),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    historyState.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                      error: (err, stack) => _buildErrorCard(
                        "Table offline: Firebase Index required! Check console.",
                      ),
                      data: (historyDocs) {
                        if (historyDocs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Text(
                                "No verification logs for today.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.swipe,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Scroll horizontally to view full table",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: RawScrollbar(
                                thumbColor: Colors.grey.shade600,
                                radius: const Radius.circular(4),
                                thickness: 6,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 800,
                                    ),
                                    child: DataTable(
                                      columnSpacing: 30,
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFF121212),
                                      ),
                                      headingTextStyle: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text("TIME")),
                                        DataColumn(label: Text("ORDER ID")),
                                        DataColumn(label: Text("GUARD NAME")),
                                        DataColumn(label: Text("STATUS")),
                                        DataColumn(label: Text("AI RISK")),
                                        DataColumn(label: Text("ACTION")),
                                      ],
                                      rows: historyDocs.map((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        DateTime date =
                                            (data['verifiedAt'] as Timestamp?)
                                                ?.toDate() ??
                                            (data['rejectedAt'] as Timestamp?)
                                                ?.toDate() ??
                                            (data['timestamp'] as Timestamp?)
                                                ?.toDate() ??
                                            DateTime.now();
                                        String exitStatus =
                                            (data['exitStatus'] ?? 'UNKNOWN')
                                                .toString()
                                                .toUpperCase();

                                        // 🚀 CHANGED TO GUARD NAME FOR BETTER READABILITY
                                        String guardName =
                                            data['verifiedByGuardName'] ??
                                            data['rejectedByGuardName'] ??
                                            'Guard';

                                        String riskLevel =
                                            (data['riskLevel'] ?? 'LOW')
                                                .toString()
                                                .toUpperCase();
                                        bool isApproved =
                                            exitStatus == 'APPROVED' ||
                                            exitStatus == 'COMPLETED';

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                DateFormat(
                                                  'hh:mm a',
                                                ).format(date),
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                doc.id
                                                    .substring(0, 8)
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                guardName,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isApproved
                                                      ? Colors.greenAccent
                                                            .withValues(
                                                              alpha: 0.1,
                                                            )
                                                      : Colors.redAccent
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  exitStatus,
                                                  style: TextStyle(
                                                    color: isApproved
                                                        ? Colors.greenAccent
                                                        : Colors.redAccent,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  Icon(
                                                    riskLevel == 'HIGH'
                                                        ? Icons
                                                              .warning_amber_rounded
                                                        : Icons.shield_outlined,
                                                    color: riskLevel == 'HIGH'
                                                        ? Colors.orangeAccent
                                                        : Colors.grey,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    riskLevel,
                                                    style: TextStyle(
                                                      color: riskLevel == 'HIGH'
                                                          ? Colors.orangeAccent
                                                          : Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_red_eye,
                                                  color: Colors.blueAccent,
                                                ),
                                                tooltip: "View Gate Pass",
                                                onPressed: () =>
                                                    _showAutopsyPanel(
                                                      context,
                                                      data,
                                                      doc.id,
                                                      ref,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _buildSafeCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.greenAccent),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
