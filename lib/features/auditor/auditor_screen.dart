// lib/features/dashboard/auditor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: unused_import
import 'dart:convert';
// ignore: unused_import, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'providers/auditor_provider.dart';
import 'providers/ledger_provider.dart';
import '../auditor/widgets/cash_reconciliation_cart.dart';
import 'widgets/risk_alert_strip.dart';
//import 'widgets/time_intelligence_card.dart';
import 'widgets/audit_vault_screen.dart';
import '../invoice/invoice_rules_dialog.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';
import '../auditor/service/audit_export_service.dart';

// 🚀 INVOICE SERVICE IMPORT
import '../invoice/pdf_invoice_service.dart';

class AuditorScreen extends ConsumerWidget {
  const AuditorScreen({super.key});

  // 📥 THE ULTIMATE CA-GRADE CSV EXPORT (Item-Level Sales Register)
  Future<void> _downloadCsvReport(
    BuildContext context,
    String type,
    List<QueryDocumentSnapshot> records,
  ) async {
    if (!kIsWeb || records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No records to export."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // CA Grade Headers
      String csv =
          "Company Name,Branch Code,GSTIN,Bill Time,Exit Time,Order ID,Payment Mode,UPI Txn ID,Product Name,Qty,Unit Price,Gross Amount,Taxable Value,GST %,CGST Amount,SGST Amount,Item Total,Exit Status\n";

      // 🚀 SaaS Fix: Cache store details to prevent N+1 queries during export
      Map<String, Map<String, String>> storeCache = {};

      for (var doc in records) {
        final data = doc.data() as Map<String, dynamic>;

        // 🚀 DYNAMIC ROW-LEVEL STORE FETCHER
        String rowBranch = data['branchCode']?.toString() ?? "STORE";
        String companyName = "CLICKOUT RETAIL";
        String gstin = "N/A";

        if (rowBranch != "STORE" && rowBranch.isNotEmpty) {
          if (!storeCache.containsKey(rowBranch)) {
            final sSnap = await FirebaseFirestore.instance
                .collection('stores')
                .where('branchCode', isEqualTo: rowBranch)
                .limit(1)
                .get();
            if (sSnap.docs.isNotEmpty) {
              final sData = sSnap.docs.first.data();
              storeCache[rowBranch] = {
                'name':
                    (sData['storeName'] ??
                            sData['branchName'] ??
                            sData['companyName'] ??
                            companyName)
                        .toString()
                        .toUpperCase()
                        .replaceAll('"', '""'),
                'gstin': sData['gstin']?.toString() ?? gstin,
              };
            } else {
              storeCache[rowBranch] = {'name': companyName, 'gstin': gstin};
            }
          }
          companyName = storeCache[rowBranch]!['name']!;
          gstin = storeCache[rowBranch]!['gstin']!;
        }

        String branchCode = rowBranch;

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

        // 🚀 Ensure commas in string are safely escaped for CSV
        String safeCompany = '"$companyName"';
        String safeBranch = '"$branchCode"';
        String safeGstin = '"$gstin"';

        if (items.isEmpty) {
          csv +=
              '$safeCompany,$safeBranch,$safeGstin,"$billTime","$exitTime","${doc.id}","$mode","$upiTxn","NO ITEMS","0","0","0","0","0","0","0","0","$status"\n';
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
              '$safeCompany,$safeBranch,$safeGstin,"$billTime","$exitTime","${doc.id}","$mode","$upiTxn","$itemName","$qty","${price.toStringAsFixed(2)}","${grossAmt.toStringAsFixed(2)}","${taxableValue.toStringAsFixed(2)}","$gstRate","${cgst.toStringAsFixed(2)}","${sgst.toStringAsFixed(2)}","${grossAmt.toStringAsFixed(2)}","$status"\n';
        }

        // 🚀 DELTA FIX: ADD EXCHANGE DEDUCTION AS A LINE ITEM TO BALANCE THE SHEET
        if (data['type'] == 'EXCHANGE_INVOICE' &&
            data['exchangedItem'] != null) {
          var exItem = data['exchangedItem'];
          String exName =
              "RETURN: ${exItem['name']?.toString().replaceAll('"', '""') ?? 'Returned Item'}";
          int exQty =
              int.tryParse(
                exItem['qty']?.toString() ??
                    exItem['quantity']?.toString() ??
                    '1',
              ) ??
              1;
          double exPrice =
              double.tryParse(
                exItem['price']?.toString() ??
                    exItem['originalPrice']?.toString() ??
                    '0',
              ) ??
              0.0;
          double exGross = -(exPrice * exQty); // Negative for return

          csv +=
              '$safeCompany,$safeBranch,$safeGstin,"$billTime","$exitTime","${doc.id}","$mode","$upiTxn","$exName","$exQty","-${exPrice.toStringAsFixed(2)}","${exGross.toStringAsFixed(2)}","${exGross.toStringAsFixed(2)}","0","0","0","${exGross.toStringAsFixed(2)}","$status"\n';
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
          content: Text("✅ Dynamic CA-Grade CSV Downloaded!"),
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
    String paymentMode = (data['paymentMode'] ?? 'UPI')
        .toString()
        .toUpperCase();

    // 🚀 Billed-By Logic
    String cashierId = 'Self Checkout';
    if (paymentMode == 'CASH') {
      cashierId =
          data['scannedByName']?.toString() ??
          data['cashierName']?.toString() ??
          data['collectedBy']?.toString() ??
          data['cashierId']?.toString() ??
          'Unknown Cashier';
    }

    String rawGuard =
        data['verifiedByGuardId']?.toString() ??
        data['exitVerifiedBy']?.toString() ??
        '';
    String guardId = rawGuard.isNotEmpty ? rawGuard : 'Pending/None';
    double fraudScore = (data['fraudScore'] ?? 0.0).toDouble();
    List<dynamic> itemsList = data['cartItems'] ?? data['items'] ?? [];

    // 🧠 100% SYNCED: Fetching directly from Database
    double calculatedSubtotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    double totalBasePrice =
        double.tryParse(data['taxableValue']?.toString() ?? '0') ?? 0.0;
    double totalGSTAmount =
        double.tryParse(data['gstTotal']?.toString() ?? '0') ?? 0.0;
    double totalSavings =
        double.tryParse(data['totalSavings']?.toString() ?? '0') ?? 0.0;
    double totalBagWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;

    // 🚀 ORIGINAL BUSINESS LOGIC (Exchange aur Discount Zinda Hai!)
    double discount =
        double.tryParse(data['discount']?.toString() ?? '0') ?? 0.0;
    double exchangeDeduction = 0.0;
    String exchangeItemName = '';
    if (data['type'] == 'EXCHANGE_INVOICE' && data['exchangedItem'] != null) {
      var exItem = data['exchangedItem'];
      exchangeItemName = exItem['name'] ?? 'Returned Item';
      int exQty =
          int.tryParse(
            exItem['qty']?.toString() ?? exItem['quantity']?.toString() ?? '1',
          ) ??
          1;
      double exPrice =
          double.tryParse(
            exItem['price']?.toString() ??
                exItem['originalPrice']?.toString() ??
                '0',
          ) ??
          0.0;
      exchangeDeduction = exPrice * exQty;
    }

    // Final calculations based on DB
    double dbTotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    double finalTotal = dbTotal > 0
        ? dbTotal
        : (calculatedSubtotal - discount - exchangeDeduction);

    double dbWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;
    if (dbWeight > 0 && totalBagWeight == 0) totalBagWeight = dbWeight;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Autopsy",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
              height: MediaQuery.of(context).size.height,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.policy,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Order Autopsy",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
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

                  if (data['hasExchange'] == true)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_horizontal_circle,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "EXCHANGE PROCESSED",
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "Delta Invoice Generated: ${data['exchangeRef'] ?? 'Unknown'}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text(
                    "Tax Invoice / Bill of Supply",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF141414,
                        ), // 🔲 PITCH BLACK REALISTIC RECEIPT BG
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: () async {
                          Map<String, dynamic> result = {
                            'storeName': "CLICKOUT RETAIL",
                            'gstin': "N/A",
                            'address': "N/A",
                            'phone': "N/A",
                            'invPrefix': "INV-",
                            'documentTitle': "TAX INVOICE",
                            'terms': [
                              "1. Exchange within 7 days with original receipt.",
                              "2. Goods once sold will not be refunded.",
                            ],
                          };
                          try {
                            String bc =
                                (data['branchCode'] ??
                                        data['branchId'] ??
                                        data['storeId'])
                                    ?.toString()
                                    .trim() ??
                                '';
                            if (bc.isNotEmpty && bc != 'STORE') {
                              var sSnap = await FirebaseFirestore.instance
                                  .collection('stores')
                                  .where('branchCode', isEqualTo: bc)
                                  .limit(1)
                                  .get();
                              if (sSnap.docs.isNotEmpty) {
                                var sData = sSnap.docs.first.data();
                                result['storeName'] =
                                    (sData['storeName'] ??
                                            sData['branchName'] ??
                                            sData['companyName'] ??
                                            result['storeName'])
                                        .toString()
                                        .toUpperCase();
                                result['gstin'] =
                                    sData['gstin']?.toString() ??
                                    result['gstin'];
                                result['phone'] =
                                    sData['primaryContact'] ??
                                    sData['mobile'] ??
                                    sData['phone'] ??
                                    result['phone'];
                                String baseAddr =
                                    sData['address'] ??
                                    sData['fullAddress'] ??
                                    "";
                                String city = sData['city'] ?? "";
                                String pin =
                                    sData['pincode'] ??
                                    sData['zip'] ??
                                    sData['zipCode'] ??
                                    "";
                                List<String> addrParts = [];
                                if (baseAddr.isNotEmpty)
                                  addrParts.add(baseAddr);
                                if (city.isNotEmpty) addrParts.add(city);
                                if (pin.isNotEmpty) addrParts.add(pin);
                                if (addrParts.isNotEmpty)
                                  result['address'] = addrParts.join(", ");
                              }
                            }
                            String tid =
                                data['tenantId']?.toString().trim() ?? '';
                            if (tid.isNotEmpty && tid != 'ALL') {
                              var tSnap = await FirebaseFirestore.instance
                                  .collection('tenants')
                                  .doc(tid)
                                  .get();
                              if (tSnap.exists) {
                                var tData =
                                    tSnap.data() as Map<String, dynamic>;
                                var config =
                                    tData['invoiceConfig']
                                        as Map<String, dynamic>? ??
                                    {};
                                result['invPrefix'] =
                                    config['prefix']?.toString() ??
                                    config['invoicePrefix']?.toString() ??
                                    result['invPrefix'];
                                if (config['documentTitle'] != null)
                                  result['documentTitle'] =
                                      config['documentTitle'].toString();
                                if (config['terms'] != null &&
                                    config['terms'].toString().isNotEmpty) {
                                  result['terms'] = config['terms']
                                      .toString()
                                      .split(RegExp(r'\\n|\n'));
                                }
                              }
                            }
                          } catch (e) {}
                          return result;
                        }(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Colors.greenAccent,
                                ),
                              ),
                            );
                          }

                          final meta =
                              snapshot.data ??
                              {
                                'storeName': "CLICKOUT RETAIL",
                                'gstin': "N/A",
                                'address': "N/A",
                                'phone': "N/A",
                                'invPrefix': "INV-",
                                'documentTitle': "TAX INVOICE",
                                'terms': [
                                  "1. Exchange within 7 days with original receipt.",
                                  "2. Goods once sold will not be refunded.",
                                ],
                              };

                          String storeDisplayName = meta['storeName'];
                          String gstin = meta['gstin'];
                          String branchCode =
                              (data['branchCode'] ??
                                      data['branchId'] ??
                                      data['storeId'])
                                  ?.toString() ??
                              "STORE";
                          String address = meta['address'];
                          String phone = meta['phone'];
                          String invPrefix = meta['invPrefix'];
                          List<String> terms = List<String>.from(meta['terms']);
                          String documentTitle = meta['documentTitle'];

                          DateTime billingDate =
                              (data['timestamp'] as Timestamp?)?.toDate() ??
                              DateTime.now();
                          String paymentMode =
                              data['paymentMode']?.toString() ??
                              data['mode']?.toString() ??
                              'CASH';
                          String upiTxnId =
                              data['upiTxnId']?.toString() ??
                              data['txnId']?.toString() ??
                              'N/A';

                          String cName =
                              (data['customerName'] ??
                                      data['buyerName'] ??
                                      data['clientName'] ??
                                      data['customer'] ??
                                      "Walk-in Customer")
                                  .toString();
                          if (cName.trim().isEmpty ||
                              cName.trim().toLowerCase() == 'customer' ||
                              cName == 'null')
                            cName = "Walk-in Customer";
                          String cPhone =
                              (data['customerPhone'] ??
                                      data['buyerPhone'] ??
                                      data['phone'] ??
                                      "")
                                  .toString();
                          if (cPhone == 'null') cPhone = "";

                          Widget buildRecRow(
                            String label,
                            String value, {
                            Color color = Colors.white,
                          }) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 3.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 🏢 1. STORE HEADER
                                Text(
                                  documentTitle,
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.storefront,
                                  size: 32,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  storeDisplayName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (address != "N/A")
                                  Text(
                                    address,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  "Ph: $phone  |  GSTIN: $gstin",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Branch: $branchCode",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: Text(
                                    "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      letterSpacing: 2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                                // 📄 2. INVOICE META (Fixed invoice DB Fetch)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Inv No: ",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    data['invoiceNo']
                                                        ?.toString() ??
                                                    "$invPrefix${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Date: ",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              TextSpan(
                                                text: DateFormat(
                                                  'dd-MM-yyyy',
                                                ).format(billingDate),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Time: ",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              TextSpan(
                                                text: DateFormat(
                                                  'hh:mm a',
                                                ).format(billingDate),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: "Pay Mode: ",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              TextSpan(
                                                text: paymentMode,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (paymentMode == 'UPI') ...[
                                          const SizedBox(height: 4),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                const TextSpan(
                                                  text: "Txn ID: ",
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: upiTxnId,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),

                                // 👤 3. CUSTOMER DETAILS
                                if (data['customerName'] != null ||
                                    data['customerPhone'] != null) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                      style: TextStyle(
                                        color: Colors.white24,
                                        letterSpacing: 2,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "BILLED TO:",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (cPhone.isNotEmpty)
                                          Text(
                                            "Ph: $cPhone",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: Text(
                                    "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      letterSpacing: 2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                                // 🛒 4. ITEMS TABLE HEADER
                                Row(
                                  children: const [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "ITEM",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        "QTY",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "RATE",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        "AMOUNT",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 🛒 5. ITEMS LIST
                                if (itemsList.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Text(
                                        "No items recorded.",
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...itemsList.map((item) {
                                    int qty =
                                        int.tryParse(
                                          item['qty']?.toString() ??
                                              item['quantity']?.toString() ??
                                              '1',
                                        ) ??
                                        1;
                                    double itemOriginalPrice =
                                        double.tryParse(
                                          item['originalPrice']?.toString() ??
                                              '0',
                                        ) ??
                                        0.0;
                                    double price =
                                        double.tryParse(
                                          item['price']?.toString() ?? '',
                                        ) ??
                                        double.tryParse(
                                          item['unitPrice']?.toString() ?? '',
                                        ) ??
                                        double.tryParse(
                                          item['discountedPrice']?.toString() ??
                                              '',
                                        ) ??
                                        itemOriginalPrice;
                                    double gstRate = 0.0;
                                    if (item['gst'] != null) {
                                      gstRate =
                                          double.tryParse(
                                            item['gst'].toString().replaceAll(
                                              RegExp(r'[^0-9.]'),
                                              '',
                                            ),
                                          ) ??
                                          0.0;
                                    }
                                    double itemTotal = qty * price;
                                    String itemName =
                                        item['name']?.toString() ??
                                        item['productName']?.toString() ??
                                        'Unknown Item';
                                    String clearanceType =
                                        item['clearanceType']?.toString() ?? '';
                                    if (price == 0 ||
                                        clearanceType == 'FREE_ITEM' ||
                                        clearanceType == 'BOGO') {
                                      itemName = "[FREE] $itemName";
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 4,
                                                child: Text(
                                                  itemName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  "$qty",
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  price.toStringAsFixed(2),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  itemTotal.toStringAsFixed(2),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (gstRate > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2.0,
                                              ),
                                              child: Text(
                                                "HSN: ${item['hsn'] ?? 'N/A'} | GST: ${gstRate.toStringAsFixed(0)}%",
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white38,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      letterSpacing: 2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                                // 💰 6. TAX, DISCOUNTS & TOTALS (Full Unified UI)
                                buildRecRow(
                                  "Gross Subtotal:",
                                  "₹${calculatedSubtotal.toStringAsFixed(2)}",
                                ),

                                if (exchangeDeduction > 0)
                                  buildRecRow(
                                    "Returned: $exchangeItemName",
                                    "-₹${exchangeDeduction.toStringAsFixed(2)}",
                                    color: Colors.purpleAccent,
                                  ),

                                if (discount > 0)
                                  buildRecRow(
                                    "Discount Applied:",
                                    "-₹${discount.toStringAsFixed(2)}",
                                    color: Colors.greenAccent,
                                  ),

                                buildRecRow(
                                  "Taxable Value:",
                                  "₹${totalBasePrice.toStringAsFixed(2)}",
                                ),
                                buildRecRow(
                                  "Total GST:",
                                  "₹${totalGSTAmount.toStringAsFixed(2)}",
                                ),

                                buildRecRow(
                                  "Total Bag Weight:",
                                  totalBagWeight >= 1000
                                      ? "${(totalBagWeight / 1000).toStringAsFixed(2)} KG"
                                      : "${totalBagWeight.toStringAsFixed(0)} g",
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      letterSpacing: 2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                                if (totalSavings > 0) ...[
                                  buildRecRow(
                                    "TOTAL SAVINGS:",
                                    "₹${totalSavings.toStringAsFixed(2)}",
                                    color: Colors.greenAccent,
                                  ),
                                  const SizedBox(height: 5),
                                ],

                                // 🏆 7. GRAND TOTAL
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      finalTotal < 0
                                          ? "REFUND DUE"
                                          : (exchangeDeduction > 0
                                                ? "GRAND TOTAL (DELTA)"
                                                : "GRAND TOTAL"),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: finalTotal < 0
                                            ? Colors.purpleAccent
                                            : Colors.white,
                                      ),
                                    ),
                                    Text(
                                      finalTotal < 0
                                          ? "-₹${finalTotal.abs().toStringAsFixed(2)}"
                                          : "₹${finalTotal.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: finalTotal < 0
                                            ? Colors.purpleAccent
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    "- - - - - - - - - - - - - - - - - - - - - - - - - - -",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      letterSpacing: 2,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                                // 🙏 8. FOOTER (DYNAMIC T&C)
                                const Text(
                                  "Thank You for Shopping with Us!",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...terms.map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2.0),
                                    child: Text(
                                      t.trim(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
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
                      color: const Color(
                        0xFF2A2A2A,
                      ), // 🔲 GREY COMBINATION THEME
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fraudScore > 50
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "AI FRAUD SCORE",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: fraudScore > 50
                                        ? Colors.redAccent
                                        : Colors.green.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const InfoButton(
                                  title: "AI Fraud Score",
                                  en: "A 0–100 risk score from our AI engine. Above 50 means suspicious patterns — weight mismatch, rapid checkout, or unusual cart items.",
                                  hi: "0 se 100 tak ka risk number. 50 se zyada matlab order mein kuch suspicious hai — weight mismatch, bahut jaldi checkout, ya unusual items.",
                                ),
                              ],
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

                  if (data['paymentStatus'] == 'PENDING_DELTA_PAYMENT' ||
                      data['paymentStatus'] == 'PENDING') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors
                              .black, // Dark text for contrast on neon green
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.point_of_sale,
                          color: Colors.black,
                        ),
                        label: Text(
                          "COLLECT ₹${finalTotal.toStringAsFixed(0)} & APPROVE GATEPASS",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () =>
                            _collectPayment(context, orderId, finalTotal, data),
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

  // 💰 🚀 THE DELTA PAYMENT COLLECTOR
  void _collectPayment(
    BuildContext context,
    String orderId,
    double amount,
    Map<String, dynamic> data,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Collect Delta Payment",
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "How did the customer pay the pending ₹${amount.toStringAsFixed(0)}?",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.money, color: Colors.white, size: 18),
            label: const Text(
              "CASH",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () =>
                _processDeltaPayment(context, ctx, orderId, 'CASH', data),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            icon: const Icon(Icons.qr_code, color: Colors.white, size: 18),
            label: const Text(
              "UPI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () =>
                _processDeltaPayment(context, ctx, orderId, 'UPI', data),
          ),
        ],
      ),
    );
  }

  Future<void> _processDeltaPayment(
    BuildContext mainContext,
    BuildContext dialogContext,
    String orderId,
    String mode,
    Map<String, dynamic> data,
  ) async {
    try {
      // 🧠 STEP 1: SMART INVOICE ENGINE (Checks if already exists)
      String invoiceNo = data['invoiceNo']?.toString() ?? '';

      if (invoiceNo.isEmpty) {
        String tenantId = data['tenantId']?.toString() ?? '';
        String branchCode = data['branchCode']?.toString() ?? 'STORE';
        String prefix = "INV/"; // Default Fallback

        // 🔄 THE LOOP: Fetch Custom Admin Prefix from Database
        if (tenantId.isNotEmpty && tenantId != 'ALL' && tenantId != 'GLOBAL') {
          var tDoc = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .get();
          if (tDoc.exists) {
            var config =
                tDoc.data()?['invoiceConfig'] as Map<String, dynamic>? ?? {};
            String adminPrefix =
                config['invoicePrefix']?.toString().trim() ?? '';
            if (adminPrefix.isNotEmpty) {
              prefix = adminPrefix;
              // Formatting: Add slash or dash if Admin forgot to put it at the end
              if (!prefix.endsWith('/') && !prefix.endsWith('-')) prefix += '/';
            }
          }
        }

        // 📅 STEP 2: Generate YY-YY and MM-DD
        final now = DateTime.now();
        int startYear = now.month >= 4 ? now.year : now.year - 1;
        String fyStr =
            "${(startYear % 100).toString().padLeft(2, '0')}-${((startYear + 1) % 100).toString().padLeft(2, '0')}";
        String dateStr =
            "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        String todayKey =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        // ⚡ STEP 3: Atomic Daily Counter (Safe from Race Conditions)
        String tenantPrefix = tenantId.isNotEmpty && tenantId != 'ALL'
            ? tenantId
            : 'GLOBAL';
        DocumentReference counterRef = FirebaseFirestore.instance
            .collection('daily_invoice_counters')
            .doc("${tenantPrefix}_${branchCode}_$todayKey");
        int seq = await FirebaseFirestore.instance.runTransaction((
          transaction,
        ) async {
          DocumentSnapshot snapshot = await transaction.get(counterRef);
          if (!snapshot.exists) {
            transaction.set(counterRef, {'count': 1});
            return 1;
          } else {
            int newCount =
                (snapshot.data() as Map<String, dynamic>)['count'] + 1;
            transaction.update(counterRef, {'count': newCount});
            return newCount;
          }
        });

        // 🎯 STEP 4: Combine everything (e.g., MART/26-27/04-23-01)
        invoiceNo = "$prefix$fyStr/$dateStr-${seq.toString().padLeft(2, '0')}";
      }

      // 💾 STEP 5: SAVE EVERYTHING TO DATABASE
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {
          'paymentStatus': 'PAID',
          'paymentMode': mode,
          'exitStatus': 'APPROVED',
          'verifiedAt': FieldValue.serverTimestamp(),
          'invoiceNo': invoiceNo, // 🔥 THE MISSING FIELD HAS BEEN ADDED!
        },
      );

      if (dialogContext.mounted) Navigator.pop(dialogContext); // Close alert
      if (mainContext.mounted) {
        Navigator.pop(mainContext); // Close autopsy panel
        ScaffoldMessenger.of(mainContext).showSnackBar(
          const SnackBar(
            content: Text("✅ Payment Collected! Gatepass Activated."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
                  // 🚀 SaaS Fix: Removed N+1 FutureBuilder to prevent UI freeze and read explosions.
                  // We now directly render the denormalized name/ID stored in the order document.
                  Text(
                    uid,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🗑️ _buildReceiptRow successfully removed as it is no longer used

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialState = ref.watch(dailyFinancialsProvider);
    final ledgerState = ref.watch(ledgerProvider);
    final ledgerNotifier = ref.read(ledgerProvider.notifier);

    // 🎨 DYNAMIC LIGHT/DARK THEME
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF4F5F7);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textDimColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
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

                  Widget headerText = Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: textColor,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Command Center",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Audit Command Center (Realized Accounting)",
                              style: TextStyle(
                                color: textDimColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  Widget theBlackBox = GestureDetector(
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
                        color: isDark ? Colors.black : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.archive, color: Colors.white, size: 20),
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
                  );

                  // 🚀 NEW: INVOICE RULES BUTTON
                  Widget invoiceRulesBtn = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.gavel, size: 18),
                    label: const Text(
                      "INVOICE RULES",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const InvoiceRulesDialog(),
                    ),
                  );

                  // 🚀 FIX: Prevent 'Expanded' crashes inside unbounded columns
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headerText,
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [invoiceRulesBtn, theBlackBox],
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: headerText),
                        const SizedBox(width: 16),
                        invoiceRulesBtn,
                        const SizedBox(width: 12),
                        theBlackBox,
                      ],
                    );
                  }
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
                                context,
                                "Realized Revenue",
                                "₹${finData.totalRevenue.toStringAsFixed(0)}",
                                Icons.account_balance_wallet,
                                Colors.green,
                                subtitle: "Only verified exits",
                                infoWidget: const InfoButton(
                                  title: "Realized Revenue",
                                  en: "Total revenue from orders where the customer has physically exited the store. Pending exits are excluded.",
                                  hi: "Sirf woh orders count hote hain jahan customer store se bahar ja chuka hai. Jo abhi andar hain woh is mein nahi aate.",
                                ),
                              ),
                              _buildPremiumCard(
                                context,
                                "Financial Leakage",
                                "₹${finData.totalLeakage.toStringAsFixed(0)}",
                                Icons.hourglass_bottom,
                                Colors.orange.shade700,
                                subtitle: "Paid but pending exit",
                                infoWidget: const InfoButton(
                                  title: "Financial Leakage",
                                  en: "Orders where payment was received but store exit is still pending. This amount is at risk if the customer backtracks.",
                                  hi: "Payment ho gayi par customer abhi tak bahar nahi gaya. Yeh amount risky hai — guard verify kare tab hi safe hoga.",
                                ),
                              ),
                              _buildPremiumCard(
                                context,
                                "Guard Rejects",
                                "${finData.rejectedCount} Orders",
                                Icons.gpp_bad,
                                Colors.redAccent,
                                subtitle: "Security interventions",
                                infoWidget: const InfoButton(
                                  title: "Guard Rejects",
                                  en: "Orders flagged and stopped by the security guard at exit. These are mismatched or suspicious transactions requiring investigation.",
                                  hi: "Guard ne exit pe jo orders rok diye. Yeh mismatch ya suspicious transactions hain — fraud ka pehla signal hota hai.",
                                ),
                              ),
                              _buildPremiumCard(
                                context,
                                "Refunds Initiated",
                                "₹${finData.refundAmount.toStringAsFixed(0)}",
                                Icons.currency_exchange,
                                Colors.purple,
                                subtitle: "${finData.refundCount} transactions",
                                infoWidget: const InfoButton(
                                  title: "Refunds Initiated",
                                  en: "Total money refunded to customers today. Every refund is logged and linked to the original order for full traceability.",
                                  hi: "Aaj customers ko wapas kiya gaya paisa. Har refund original order se linked hai — audit trail bilkul safe hai.",
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isMobile = constraints.maxWidth < 800;
                          // 🚀 FIX: Safe Layout - No Expanded inside ScrollView for mobile vertical view
                          if (isMobile) {
                            return Column(
                              children: [
                                CashReconciliationCard(
                                  expectedCash: finData.cashExpected,
                                ),
                                const SizedBox(height: 24),
                                _buildUpiReconciliationCard(
                                  context,
                                  finData.digitalExpected,
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(
                                  child: CashReconciliationCard(
                                    expectedCash: finData.cashExpected,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildUpiReconciliationCard(
                                    context,
                                    finData.digitalExpected,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // 🚀 REMOVED: const TimeIntelligenceCard(),
                      // const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 15,
                              children: [
                                Text(
                                  "Global Audit Ledger",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                _SmartExportButton(
                                  records: ledgerState.records,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDropdownFilter(
                                  context,
                                  "Time",
                                  ['ALL_TIME', 'TODAY', 'LAST_7_DAYS'],
                                  ledgerState.currentFilters.timeRange,
                                  (val) => ledgerNotifier.updateFilter(
                                    timeRange: val,
                                  ),
                                ),
                                _buildDropdownFilter(
                                  context,
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
                              // 🚀 FIX: Removed RawScrollbar which causes layout crashes on Web
                              // Simplified horizontal scroll wrapper for DataTable
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 900,
                                      ),
                                      child: DataTable(
                                        columnSpacing: 30,
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              Colors.greenAccent.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.greenAccent,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                        dataTextStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontFamily: 'monospace',
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
                                                    return Colors.greenAccent
                                                        .withOpacity(0.1);
                                                  }
                                                  if (isDark) {
                                                    return idx % 2 == 0
                                                        ? const Color.fromARGB(
                                                            255,
                                                            33,
                                                            33,
                                                            33,
                                                          )
                                                        : const Color.fromARGB(
                                                            255,
                                                            32,
                                                            31,
                                                            31,
                                                          );
                                                  } else {
                                                    return idx % 2 == 0
                                                        ? Colors.grey.shade50
                                                        : Colors.white;
                                                  }
                                                }),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  DateFormat(
                                                    'dd MMM, hh:mm a',
                                                  ).format(date),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white54
                                                        : Colors.black87,
                                                    fontFamily: 'monospace',
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
                                                Builder(
                                                  builder: (context) {
                                                    String btnText = "Pending";
                                                    Color btnColor =
                                                        Colors.grey;

                                                    // 🚀 LOGIC FOR EXACT BUTTON STATUSES
                                                    if (pStatus == 'REFUNDED') {
                                                      btnText = "Refunded";
                                                      btnColor =
                                                          Colors.redAccent;
                                                    } else if (pStatus ==
                                                        'PENDING_DELTA_PAYMENT') {
                                                      btnText = "Fix & Exit";
                                                      btnColor =
                                                          Colors.purpleAccent;
                                                    } else if (pStatus ==
                                                        'PENDING') {
                                                      btnText = "Pending";
                                                      btnColor = Colors.grey;
                                                    } else if (pStatus ==
                                                            'PAID' ||
                                                        pStatus == 'SUCCESS') {
                                                      if ([
                                                        'COMPLETED',
                                                        'EXITED',
                                                        'APPROVED',
                                                      ].contains(eStatus)) {
                                                        btnText = "Clear Exit";
                                                        btnColor =
                                                            Colors.greenAccent;
                                                      } else if (eStatus ==
                                                          'REJECTED') {
                                                        btnText = "Fix Reject";
                                                        btnColor =
                                                            Colors.redAccent;
                                                      } else {
                                                        btnText =
                                                            "Gate Pass Pending";
                                                        btnColor =
                                                            Colors.orangeAccent;
                                                      }
                                                    }

                                                    return InkWell(
                                                      onTap: () =>
                                                          _showAutopsyPanel(
                                                            context,
                                                            data,
                                                            entry.value.id,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .transparent,
                                                          border: Border.all(
                                                            color: btnColor
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              btnText,
                                                              style: TextStyle(
                                                                color: btnColor,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            const Icon(
                                                              Icons
                                                                  .keyboard_arrow_down,
                                                              color: Colors
                                                                  .white54,
                                                              size: 14,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
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

  Widget _buildUpiReconciliationCard(BuildContext context, double expectedUpi) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
              Icon(Icons.account_balance, color: Colors.blueAccent.shade200),
              const SizedBox(width: 10),
              Text(
                "Online Payment Collection",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: "Online Payment Collection",
                en: "Total UPI/online amount expected from today's verified transactions. Cross-check this with your payment gateway (Razorpay/PhonePe) dashboard.",
                hi: "Aaj ke verified UPI payments ka total. Razorpay/PhonePe se match karo — koi gap ho toh turant investigate karo.",
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
                      "SETTLEMENT_EXPECTED",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "₹${expectedUpi.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
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
    BuildContext context,
    String label,
    List<String> items,
    String currentValue,
    Function(String) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          DropdownButton<String>(
            dropdownColor: bgColor,
            value: items.contains(currentValue) ? currentValue : items.first,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: textColor),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: textColor,
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
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String subtitle = "",
    Widget? infoWidget,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
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
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (infoWidget != null) ...[
                      const SizedBox(width: 4),
                      infoWidget,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(isDark ? 0.8 : 1.0),
                      fontSize: 11,
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

class _SmartExportButton extends StatefulWidget {
  final List<QueryDocumentSnapshot> records;
  const _SmartExportButton({required this.records});

  @override
  State<_SmartExportButton> createState() => _SmartExportButtonState();
}

class _SmartExportButtonState extends State<_SmartExportButton> {
  String _selected = 'Today';
  bool _isLoading = false;

  static const List<Map<String, dynamic>> _options = [
    {'label': 'Today', 'icon': Icons.today},
    {'label': 'Monthly', 'icon': Icons.calendar_month},
    {'label': 'Quarterly', 'icon': Icons.bar_chart},
    {'label': 'Yearly', 'icon': Icons.calendar_today},
    {'label': 'All Time', 'icon': Icons.all_inclusive},
  ];

  String _quarterLabel(DateTime now) {
    if (now.month >= 4 && now.month <= 6) return 'AMJ';
    if (now.month >= 7 && now.month <= 9) return 'JAS';
    if (now.month >= 10 && now.month <= 12) return 'OND';
    return 'JFM';
  }

  DateTime _quarterStart(DateTime now) {
    if (now.month >= 4 && now.month <= 6) return DateTime(now.year, 4, 1);
    if (now.month >= 7 && now.month <= 9) return DateTime(now.year, 7, 1);
    if (now.month >= 10 && now.month <= 12) return DateTime(now.year, 10, 1);
    return DateTime(now.year, 1, 1);
  }

  String get _displayLabel {
    if (_selected == 'Quarterly') {
      return 'Quarterly (${_quarterLabel(DateTime.now())})';
    }
    return _selected;
  }

  List<QueryDocumentSnapshot> _filtered() {
    final now = DateTime.now();
    return widget.records.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) return _selected == 'All Time';
      switch (_selected) {
        case 'Today':
          return ts.year == now.year &&
              ts.month == now.month &&
              ts.day == now.day;
        case 'Monthly':
          return ts.year == now.year && ts.month == now.month;
        case 'Quarterly':
          return ts.isAfter(
            _quarterStart(now).subtract(const Duration(seconds: 1)),
          );
        case 'Yearly':
          return ts.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = Colors.greenAccent.shade400;
    final Color bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color text = isDark ? Colors.white : const Color(0xFF0F172A);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── DROPDOWN ──────────────────────────────────────────────
        PopupMenuButton<String>(
          initialValue: _selected,
          onSelected: (val) => setState(() => _selected = val),
          color: bg,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent.withOpacity(0.2)),
          ),
          offset: const Offset(0, 44),
          itemBuilder: (_) => _options
              .map(
                (opt) => PopupMenuItem<String>(
                  value: opt['label'] as String,
                  child: Row(
                    children: [
                      Icon(
                        _selected == opt['label']
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 15,
                        color: _selected == opt['label'] ? accent : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        opt['icon'] as IconData,
                        size: 15,
                        color: _selected == opt['label'] ? accent : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          color: text,
                          fontWeight: _selected == opt['label']
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (opt['label'] == 'Quarterly') ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${_quarterLabel(DateTime.now())})',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
              color: accent.withOpacity(0.05),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.summarize_outlined, size: 15, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Smart Export: $_displayLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: accent, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // ── DOWNLOAD BUTTON ───────────────────────────────────────
        _isLoading
            ? SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            : Tooltip(
                message: 'Download $_displayLabel Report',
                child: InkWell(
                  onTap: () async {
                    setState(() => _isLoading = true);
                    await AuditExportService.downloadSmartReport(
                      context,
                      _displayLabel,
                      _filtered(),
                    );
                    setState(() => _isLoading = false);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
