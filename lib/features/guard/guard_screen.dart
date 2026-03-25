import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'providers/guard_provider.dart';
import 'widgets/scanner_modal.dart';

class GuardScreen extends ConsumerWidget {
  const GuardScreen({super.key});

  // 👁️ THE DIGITAL GATE PASS (AUTOPSY PANEL)
  void _showAutopsyPanel(
    BuildContext context,
    Map<String, dynamic> data,
    String orderId,
  ) {
    DateTime date =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    double finalTotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    List<dynamic> itemsList = data['cartItems'] ?? data['items'] ?? [];

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
              width: 400, // Thoda patla rakha hai Guard ke liye
              height: double.infinity,
              color: const Color(0xFFF9FAFC),
              padding: const EdgeInsets.all(24),
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
                            color: Color(0xFF2B3674),
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Digital Gate Pass",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3674),
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
                  const Divider(height: 15),

                  // ORDER INFO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ORDER ID: ${orderId.toUpperCase()}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(date),
                          style: const TextStyle(
                            color: Colors.grey,
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
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ITEMS LIST (🚀 BUG FIXED HERE)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
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
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final item =
                                    itemsList[index] as Map<String, dynamic>;

                                // 🚀 THE FIX 1: Smart Quantity Extractor (Handles 'qty' and 'quantity')
                                int qty =
                                    int.tryParse(
                                      item['qty']?.toString() ??
                                          item['quantity']?.toString() ??
                                          '1',
                                    ) ??
                                    1;

                                // 🚀 THE FIX 2: Smart Price Extractor
                                double price =
                                    double.tryParse(
                                      item['price']?.toString() ??
                                          item['discountedPrice']?.toString() ??
                                          item['originalPrice']?.toString() ??
                                          '0',
                                    ) ??
                                    0.0;

                                // 🧠 CORRECT MATH FOR GUARD
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
                                      // 🟢 DYNAMIC QUANTITY BADGE
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "${qty}x", // 🚀 Ye ab hamesha exact DB quantity dikhayega!
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueAccent,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // 📦 PRODUCT DETAILS
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
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "@ ₹${price.toStringAsFixed(2)} / unit",
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 💰 ACCURATE ITEM TOTAL
                                      Text(
                                        "₹${itemTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: Colors.black,
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

                  // TOTAL
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "BILL TOTAL",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "₹${finalTotal.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.green,
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
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎩 HEADER
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.security,
                        color: Color(0xFF2B3674),
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Super Guard 🛡️",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2B3674),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Gate Intelligence & Live Radar",
                            style: TextStyle(
                              color: Colors.grey,
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
                        fontWeight: FontWeight.w800, // Bold thick text
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF232F3E,
                      ), // 🎩 Amazon Navy Blue
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8,
                        ), // Sharp corners like enterprise apps
                      ),
                      elevation: 4,
                      shadowColor: Colors.black45,
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

              // 🚨 LIVE RADAR
              const Text(
                "Live Exit Radar (Action Required)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3674),
                ),
              ),
              const SizedBox(height: 12),

              pendingState.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => _buildErrorCard(
                  "Radar offline: Firebase Index required! Check debug console.",
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
                        Color riskColor = Colors.orange;
                        String riskText = "Waiting";
                        if (minutesWaiting > 30) {
                          riskColor = Colors.red;
                          riskText = "CRITICAL: Stuck";
                        } else if (minutesWaiting > 10) {
                          riskColor = Colors.deepOrange;
                          riskText = "Delayed";
                        }

                        return Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: riskColor.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: riskColor.withOpacity(0.1),
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
                                    style: const TextStyle(
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
                                      color: riskColor.withOpacity(0.1),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
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

              // 📜 RECENT GATE ACTIVITY TABLE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Gate Activity",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B3674),
                          ),
                        ),
                        Chip(
                          label: const Text(
                            "Live Stream 🟢",
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.green.withOpacity(0.1),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    historyState.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => _buildErrorCard(
                        "Table offline: Firebase Index required! Check debug console.",
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
                                thumbColor: Colors.grey.shade400,
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
                                        Colors.grey.shade50,
                                      ),
                                      headingTextStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2B3674),
                                        fontSize: 12,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text("TIME")),
                                        DataColumn(label: Text("ORDER ID")),
                                        DataColumn(label: Text("GUARD ID")),
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
                                        String guardId =
                                            data['verifiedByGuardId'] ??
                                            data['rejectedByGuardId'] ??
                                            'EMP_UNKNOWN';
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
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                doc.id
                                                    .substring(0, 8)
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                guardId,
                                                style: const TextStyle(
                                                  color: Colors.black87,
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
                                                      ? Colors.green
                                                            .withOpacity(0.1)
                                                      : Colors.red.withOpacity(
                                                          0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  exitStatus,
                                                  style: TextStyle(
                                                    color: isApproved
                                                        ? Colors.green
                                                        : Colors.red,
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
                                                        ? Colors.orange
                                                        : Colors.grey,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    riskLevel,
                                                    style: TextStyle(
                                                      color: riskLevel == 'HIGH'
                                                          ? Colors.orange
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
                                              // 👁️ THE ACTION BUTTON WIRED UP!
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_red_eye,
                                                  color: Color(0xFF2B3674),
                                                ),
                                                tooltip: "View Gate Pass",
                                                onPressed: () =>
                                                    _showAutopsyPanel(
                                                      context,
                                                      data,
                                                      doc.id,
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
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.green,
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
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
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
}
