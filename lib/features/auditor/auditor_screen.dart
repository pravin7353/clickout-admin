// lib/features/dashboard/auditor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;

import 'providers/auditor_provider.dart';
import 'providers/ledger_provider.dart';
import '../auditor/widgets/cash_reconciliation_cart.dart';
import 'widgets/risk_alert_strip.dart';
import 'widgets/time_intelligence_card.dart';
import 'widgets/audit_vault_screen.dart';

// 🚀 INVOICE SERVICE IMPORT
import '../invoice/pdf_invoice_service.dart';

// 🏢 SAAS TENANT CONFIGURATION
class TenantConfig {
  static const String companyName = "CLICKOUT RETAIL PVT. LTD.";
  static const String branchCode = "MART01";
  static const String gstin = "27AAAAA1234A1Z5";
  static const IconData logoIcon = Icons.storefront;
}

class AuditorScreen extends ConsumerWidget {
  const AuditorScreen({super.key});

  // 📥 THE ULTIMATE CA-GRADE CSV EXPORT (Item-Level Sales Register)
  void _downloadCsvReport(
    BuildContext context,
    String type,
    List<QueryDocumentSnapshot> records,
  ) {
    if (!kIsWeb) return;

    try {
      // CA Grade Headers
      String csv =
          "Company Name,Branch Code,GSTIN,Bill Time,Exit Time,Order ID,Payment Mode,UPI Txn ID,Product Name,Qty,Unit Price,Gross Amount,Taxable Value,GST %,CGST Amount,SGST Amount,Item Total,Exit Status\n";

      for (var doc in records) {
        final data = doc.data() as Map<String, dynamic>;

        // Timestamps
        DateTime billDate =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        String billTime = DateFormat('dd MMM yyyy HH:mm:ss').format(billDate);

        DateTime? xDate =
            (data['verifiedAt'] as Timestamp?)?.toDate() ??
            (data['exitTimestamp'] as Timestamp?)?.toDate();
        String exitTime = xDate != null
            ? DateFormat('dd MMM yyyy HH:mm:ss').format(xDate)
            : 'PENDING';

        // Order Details
        String mode = data['paymentMode'] ?? 'UPI';
        String upiTxn =
            data['upiTransactionId'] ?? data['transactionId'] ?? 'N/A';
        String status =
            data['exitStatus'] ?? data['paymentStatus'] ?? 'PENDING';
        List<dynamic> items = data['cartItems'] ?? data['items'] ?? [];

        if (items.isEmpty) {
          csv +=
              '"${TenantConfig.companyName}","${TenantConfig.branchCode}","${TenantConfig.gstin}","$billTime","$exitTime","${doc.id}","$mode","$upiTxn","NO ITEMS","0","0","0","0","0","0","0","0","$status"\n';
          continue;
        }

        // Item Level Breakdown (The Math Engine)
        for (var item in items) {
          String itemName =
              item['name']?.toString().replaceAll('"', '""') ?? 'Unknown Item';
          int qty =
              int.tryParse(
                item['qty']?.toString() ?? item['quantity']?.toString() ?? '1',
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

          double grossAmt = price * qty;

          // GST Extraction
          double gstRate = 0.0;
          if (item['gst'] != null && item['gst'].toString().isNotEmpty) {
            String rawGst = item['gst'].toString().replaceAll(
              RegExp(r'[^0-9.]'),
              '',
            );
            gstRate = double.tryParse(rawGst) ?? 0.0;
          }

          // Tax Math
          double taxableValue = grossAmt / (1 + (gstRate / 100));
          double totalGst = grossAmt - taxableValue;
          double cgst = totalGst / 2;
          double sgst = totalGst / 2;

          csv +=
              '"${TenantConfig.companyName}","${TenantConfig.branchCode}","${TenantConfig.gstin}","$billTime","$exitTime","${doc.id}","$mode","$upiTxn","$itemName","$qty","${price.toStringAsFixed(2)}","${grossAmt.toStringAsFixed(2)}","${taxableValue.toStringAsFixed(2)}","$gstRate","${cgst.toStringAsFixed(2)}","${sgst.toStringAsFixed(2)}","${grossAmt.toStringAsFixed(2)}","$status"\n';
        }
      }

      // Download Trigger
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "ClickOut_CA_Report_$type.csv")
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ CA-Grade CSV Downloaded!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Export Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔬 THE UPGRADED ORDER AUTOPSY
  void _showAutopsyPanel(
    BuildContext context,
    Map<String, dynamic> data,
    String orderId,
  ) {
    DateTime billingDate =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    String eStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
    bool isCleanExit = ['COMPLETED', 'EXITED', 'APPROVED'].contains(eStatus);

    DateTime? exitDate;
    if (isCleanExit) {
      exitDate =
          (data['verifiedAt'] as Timestamp?)?.toDate() ??
          (data['exitTimestamp'] as Timestamp?)?.toDate();
    }

    String rawCashier = data['cashierId']?.toString() ?? '';
    String cashierId = rawCashier.isNotEmpty ? rawCashier : 'ONLINE PAY';

    // 🚀 BINDING FIX: Strict Guard ID Check
    String rawGuard =
        data['verifiedByGuardId']?.toString() ??
        data['exitVerifiedBy']?.toString() ??
        '';
    String guardId = rawGuard.isNotEmpty ? rawGuard : 'Pending/None';

    String paymentMode = (data['paymentMode'] ?? 'UPI')
        .toString()
        .toUpperCase();
    String upiTxnId =
        data['upiTransactionId'] ?? data['transactionId'] ?? 'N/A';

    double fraudScore = (data['fraudScore'] ?? 0.0).toDouble();
    List<dynamic> itemsList = data['cartItems'] ?? data['items'] ?? [];

    double calculatedSubtotal = 0.0;
    double totalBasePrice = 0.0;
    double totalGSTAmount = 0.0;

    for (var item in itemsList) {
      int qty =
          int.tryParse(
            item['qty']?.toString() ?? item['quantity']?.toString() ?? '1',
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

      double itemTotal = price * qty;
      calculatedSubtotal += itemTotal;

      double gstRate = 0.0;
      if (item['gst'] != null && item['gst'].toString().isNotEmpty) {
        String rawGst = item['gst'].toString().replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        gstRate = double.tryParse(rawGst) ?? 0.0;
      }

      double base = itemTotal / (1 + (gstRate / 100));
      totalBasePrice += base;
      totalGSTAmount += (itemTotal - base);
    }

    double discount =
        double.tryParse(data['discount']?.toString() ?? '0') ?? 0.0;
    double finalTotal = calculatedSubtotal - discount;
    if (finalTotal < 0) finalTotal = 0;

    double cgst = totalGSTAmount / 2;
    double sgst = totalGSTAmount / 2;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Autopsy",
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
              width: MediaQuery.of(context).size.width > 600
                  ? 500
                  : double.infinity,
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
                            Icons.policy,
                            color: Color(0xFF2B3674),
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Order Autopsy",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B3674),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // 🚀 PDF FIX: Changed to shareInvoice to force web download
                          IconButton(
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.redAccent,
                            ),
                            tooltip: "Download PDF Invoice",
                            onPressed: () {
                              PdfInvoiceService.printInvoice(data, orderId);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStaffFetcherCard(
                          "Billed By",
                          cashierId,
                          Icons.point_of_sale,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStaffFetcherCard(
                          "Exited By",
                          guardId,
                          Icons.security,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Tax Invoice Receipt",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            TenantConfig.logoIcon,
                            size: 28,
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            TenantConfig.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            "GSTIN: ${TenantConfig.gstin}",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildReceiptRow(
                                  "Bill Time",
                                  DateFormat(
                                    'dd MMM, hh:mm a',
                                  ).format(billingDate),
                                ),
                                _buildReceiptRow(
                                  "Exit Time",
                                  exitDate != null
                                      ? DateFormat(
                                          'dd MMM, hh:mm a',
                                        ).format(exitDate)
                                      : "PENDING",
                                  color: exitDate != null
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                _buildReceiptRow(
                                  "Order ID",
                                  orderId.length >= 8
                                      ? orderId.substring(0, 8).toUpperCase()
                                      : orderId,
                                ),
                                if (paymentMode == 'UPI')
                                  _buildReceiptRow(
                                    "UPI Txn",
                                    upiTxnId,
                                    color: Colors.blueAccent,
                                  ),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Text(
                              "- - - - - - - - - - - - - - - - - - - - - -",
                              style: TextStyle(
                                color: Colors.grey,
                                letterSpacing: 2,
                              ),
                              maxLines: 1,
                            ),
                          ),

                          Expanded(
                            child: itemsList.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No items recorded in DB.",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: itemsList.length,
                                    itemBuilder: (context, index) {
                                      final item =
                                          itemsList[index]
                                              as Map<String, dynamic>;
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
                                                item['discountedPrice']
                                                    ?.toString() ??
                                                item['originalPrice']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12.0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${qty}x",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${item['name'] ?? 'Unknown Item'}",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Text(
                                                    "@ ₹${price.toStringAsFixed(2)} / unit",
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              "₹${(qty * price).toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "- - - - - - - - - - - - - - - - - - - - - -",
                              style: TextStyle(
                                color: Colors.grey,
                                letterSpacing: 2,
                              ),
                              maxLines: 1,
                            ),
                          ),

                          _buildReceiptRow(
                            "Gross Subtotal",
                            calculatedSubtotal,
                          ),
                          if (discount > 0)
                            _buildReceiptRow(
                              "Discount Applied",
                              -discount,
                              color: Colors.green,
                            ),
                          _buildReceiptRow("Taxable Value", totalBasePrice),
                          _buildReceiptRow("CGST", cgst),
                          _buildReceiptRow("SGST", sgst),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "- - - - - - - - - - - - - - - - - - - - - -",
                              style: TextStyle(
                                color: Colors.grey,
                                letterSpacing: 2,
                              ),
                              maxLines: 1,
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "GRAND TOTAL",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "₹${finalTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fraudScore > 50
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fraudScore > 50
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AI FRAUD SCORE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: fraudScore > 50
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fraudScore > 50
                                  ? "High Risk Detected"
                                  : "Clear & Safe",
                              style: TextStyle(
                                color: fraudScore > 50
                                    ? Colors.red
                                    : Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: fraudScore > 50 ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "${fraudScore.toInt()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
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

  // 🚀 FALLBACK FIX: Shows Phone Number if Name is missing
  Widget _buildStaffFetcherCard(
    String label,
    String uid,
    IconData icon,
    Color color,
  ) {
    if (uid == 'ONLINE PAY') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Online Pay",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.purple,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (uid == 'Pending/None')
                  const Text(
                    "Pending",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  )
                else
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('employees')
                        .doc(uid)
                        .get()
                        .then(
                          (v) => v.exists
                              ? v
                              : FirebaseFirestore.instance
                                    .collection('guards')
                                    .doc(uid)
                                    .get(),
                        ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          "Loading...",
                          style: TextStyle(fontSize: 12),
                        );
                      }

                      // 🚀 THE FIX: Agar Data null aaye toh raw 'uid' (phone number) print kar do
                      String name = uid;
                      if (snapshot.data?.data() != null) {
                        name = (snapshot.data!.data() as Map)['name'] ?? uid;
                      }

                      return Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    dynamic amountOrString, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            amountOrString is num
                ? (amountOrString < 0
                      ? "-₹${amountOrString.abs().toStringAsFixed(2)}"
                      : "₹${amountOrString.toStringAsFixed(2)}")
                : amountOrString.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialState = ref.watch(dailyFinancialsProvider);
    final ledgerState = ref.watch(ledgerProvider);
    final ledgerNotifier = ref.read(ledgerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 600;
                  return Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: isMobile
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: Color(0xFF2B3674),
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Financial Intelligence",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2B3674),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  "Audit Command Center (Realized Accounting)",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isMobile) const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuditVaultScreen(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade800,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.archive,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                "THE BLACK BOX",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              financialState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (finData) {
                  return Column(
                    children: [
                      RiskAlertStrip(alerts: finData.activeAlerts),
                      const SizedBox(height: 24),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = constraints.maxWidth < 600
                              ? 1
                              : (constraints.maxWidth < 900 ? 2 : 4);
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.5,
                            children: [
                              _buildPremiumCard(
                                "Realized Revenue",
                                "₹${finData.totalRevenue.toStringAsFixed(0)}",
                                Icons.account_balance_wallet,
                                Colors.green,
                                subtitle: "Only verified exits",
                              ),
                              _buildPremiumCard(
                                "Financial Leakage",
                                "₹${finData.totalLeakage.toStringAsFixed(0)}",
                                Icons.hourglass_bottom,
                                Colors.orange.shade700,
                                subtitle: "Paid but pending exit",
                              ),
                              _buildPremiumCard(
                                "Guard Rejects",
                                "${finData.rejectedCount} Orders",
                                Icons.gpp_bad,
                                Colors.redAccent,
                                subtitle: "Security interventions",
                              ),
                              _buildPremiumCard(
                                "Refunds Initiated",
                                "₹${finData.refundAmount.toStringAsFixed(0)}",
                                Icons.currency_exchange,
                                Colors.purple,
                                subtitle: "${finData.refundCount} transactions",
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isMobile = constraints.maxWidth < 800;
                          return Flex(
                            direction: isMobile
                                ? Axis.vertical
                                : Axis.horizontal,
                            children: [
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: CashReconciliationCard(
                                  expectedCash: finData.cashExpected,
                                ),
                              ),
                              SizedBox(
                                width: isMobile ? 0 : 24,
                                height: isMobile ? 24 : 0,
                              ),
                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: _buildUpiReconciliationCard(
                                  finData.digitalExpected,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      const TimeIntelligenceCard(),
                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 15,
                              children: [
                                const Text(
                                  "Global Audit Ledger",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B3674),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.table_view,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        "Export Today",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(
                                          color: Colors.green,
                                        ),
                                      ),
                                      onPressed: () => _downloadCsvReport(
                                        context,
                                        "Today",
                                        ledgerState.records,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.table_view,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        "Export All",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(
                                          color: Colors.blue,
                                        ),
                                      ),
                                      onPressed: () => _downloadCsvReport(
                                        context,
                                        "All",
                                        ledgerState.records,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDropdownFilter(
                                  "Time",
                                  ['ALL_TIME', 'TODAY', 'LAST_7_DAYS'],
                                  ledgerState.currentFilters.timeRange,
                                  (val) => ledgerNotifier.updateFilter(
                                    timeRange: val,
                                  ),
                                ),
                                _buildDropdownFilter(
                                  "Mode",
                                  ['ALL', 'CASH', 'UPI', 'CARD'],
                                  ledgerState.currentFilters.mode,
                                  (val) =>
                                      ledgerNotifier.updateFilter(mode: val),
                                ),
                              ],
                            ),
                            const Divider(height: 30),

                            if (ledgerState.records.isEmpty &&
                                ledgerState.isLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (ledgerState.records.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    "No records found.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else ...[
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
                                      "Swipe/Scroll horizontally to view full table",
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
                                        minWidth: 900,
                                      ),
                                      child: DataTable(
                                        columnSpacing: 30,
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              Colors.grey.shade50,
                                            ),
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2B3674),
                                          fontSize: 12,
                                        ),
                                        columns: const [
                                          DataColumn(
                                            label: Text("DATE & TIME"),
                                          ),
                                          DataColumn(label: Text("ORDER ID")),
                                          DataColumn(label: Text("AMOUNT")),
                                          DataColumn(label: Text("MODE")),
                                          DataColumn(label: Text("STATUS")),
                                          DataColumn(label: Text("INVOICE")),
                                        ],
                                        rows: ledgerState.records.asMap().entries.map((
                                          entry,
                                        ) {
                                          int idx = entry.key;
                                          final data =
                                              entry.value.data()
                                                  as Map<String, dynamic>;
                                          DateTime date =
                                              (data['timestamp'] as Timestamp?)
                                                  ?.toDate() ??
                                              DateTime.now();
                                          String paymentMode =
                                              (data['paymentMode'] ?? 'CASH')
                                                  .toString()
                                                  .toUpperCase();
                                          String pStatus =
                                              (data['paymentStatus'] ??
                                                      data['status'] ??
                                                      'PENDING')
                                                  .toString()
                                                  .toUpperCase();
                                          String eStatus =
                                              (data['exitStatus'] ?? '')
                                                  .toString()
                                                  .toUpperCase();

                                          String displayStatus = pStatus;
                                          Color statusColor = Colors.orange;
                                          IconData statusIcon = Icons.pending;

                                          if (pStatus == 'REFUNDED') {
                                            displayStatus = 'REFUNDED';
                                            statusColor = Colors.purple;
                                            statusIcon =
                                                Icons.currency_exchange;
                                          } else if (pStatus == 'PAID' ||
                                              pStatus == 'SUCCESS') {
                                            if ([
                                              'COMPLETED',
                                              'EXITED',
                                              'APPROVED',
                                            ].contains(eStatus)) {
                                              displayStatus = 'REALIZED';
                                              statusColor = Colors.green;
                                              statusIcon = Icons.check_circle;
                                            } else if (eStatus == 'REJECTED') {
                                              displayStatus = 'REJECTED';
                                              statusColor = Colors.red;
                                              statusIcon = Icons.cancel;
                                            } else {
                                              displayStatus =
                                                  'LEAKAGE / PENDING';
                                              statusColor =
                                                  Colors.orange.shade700;
                                              statusIcon =
                                                  Icons.hourglass_bottom;
                                            }
                                          }

                                          Color modeColor =
                                              paymentMode == 'CASH'
                                              ? Colors.orange
                                              : Colors.blueAccent;

                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >((states) {
                                                  if (states.contains(
                                                    WidgetState.hovered,
                                                  )) {
                                                    return Colors.blue
                                                        .withOpacity(0.04);
                                                  }
                                                  return idx % 2 == 0
                                                      ? Colors.grey.withOpacity(
                                                          0.02,
                                                        )
                                                      : Colors.white;
                                                }),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  DateFormat(
                                                    'dd MMM, hh:mm a',
                                                  ).format(date),
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  entry.value.id
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
                                                  "₹${data['totalAmount'] ?? '0'}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
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
                                                    color: modeColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    paymentMode,
                                                    style: TextStyle(
                                                      color: modeColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Icon(
                                                      statusIcon,
                                                      color: statusColor,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      displayStatus,
                                                      style: TextStyle(
                                                        color: statusColor,
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
                                                    Icons.receipt_long,
                                                    color: Color(0xFF2B3674),
                                                  ),
                                                  tooltip:
                                                      "View E-Invoice & Autopsy",
                                                  onPressed: () =>
                                                      _showAutopsyPanel(
                                                        context,
                                                        data,
                                                        entry.value.id,
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

                            if (ledgerState.hasMore &&
                                ledgerState.records.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Center(
                                  child: ledgerState.isLoading
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF2B3674),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () => ref
                                              .read(ledgerProvider)
                                              .fetchMore(),
                                          child: const Text(
                                            "Fetch Next 10 Records",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2B3674),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpiReconciliationCard(double expectedUpi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: Colors.blueAccent.shade700),
              const SizedBox(width: 10),
              const Text(
                "Online Payment Collection",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2B3674),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bank Settlement Expected",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "₹${expectedUpi.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, color: Colors.green, size: 14),
                    SizedBox(width: 5),
                    Text(
                      "Secured",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
    String label,
    List<String> items,
    String currentValue,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          DropdownButton<String>(
            value: items.contains(currentValue) ? currentValue : items.first,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2B3674)),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF2B3674),
              fontSize: 12,
            ),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String subtitle = "",
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2B3674),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
