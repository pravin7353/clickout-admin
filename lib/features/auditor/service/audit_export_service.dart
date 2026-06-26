// lib/features/dashboard/audit_export_service.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditExportService {
  static Future<void> downloadSmartReport(
    BuildContext context,
    String type,
    List<QueryDocumentSnapshot> records,
  ) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No records to export."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // ─── METRIC ACCUMULATORS ───────────────────────────────────────
      double grossSales = 0;
      double realizedRevenue = 0;
      double leakage = 0;
      double totalRefund = 0;
      double rejectedAmount = 0;
      double totalCGST = 0;
      double totalSGST = 0;
      double cashTotal = 0;
      double upiTotal = 0;
      int totalInvoices = 0;
      int rejectedCount = 0;
      int refundCount = 0;

      // ─── RAW LEDGER ROWS ───────────────────────────────────────────
      String ledger =
          "Invoice No,Date,Order ID,Payment Mode,UPI Txn ID,"
          "Product,Qty,Unit Price,Gross Amt,Taxable Value,"
          "GST %,CGST,SGST,Item Total,Exit Status,Refund\n";

      Map<String, Map<String, String>> storeCache = {};

      for (var doc in records) {
        final data = doc.data() as Map<String, dynamic>;

        final double amount =
            double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
        final String exitStatus =
            (data['exitStatus'] ?? data['paymentStatus'] ?? 'PENDING')
                .toString()
                .toUpperCase();
        final String payMode = (data['paymentMode'] ?? 'UPI')
            .toString()
            .toUpperCase();
        final bool isRefund =
            data['refundAmount'] != null &&
            (double.tryParse(data['refundAmount'].toString()) ?? 0) > 0;
        final double refundAmt =
            double.tryParse(data['refundAmount']?.toString() ?? '0') ?? 0;

        grossSales += amount;
        totalInvoices++;

        if (exitStatus == 'APPROVED') realizedRevenue += amount;
        if (exitStatus == 'PENDING') leakage += amount;
        if (exitStatus == 'REJECTED') {
          rejectedAmount += amount;
          rejectedCount++;
        }
        if (isRefund) {
          totalRefund += refundAmt;
          refundCount++;
        }
        if (payMode == 'CASH') cashTotal += amount;
        if (payMode == 'UPI' || payMode == 'ONLINE') upiTotal += amount;

        // Store cache for branch
        String bc = data['branchCode']?.toString() ?? '';
        if (bc.isNotEmpty && !storeCache.containsKey(bc)) {
          final sSnap = await FirebaseFirestore.instance
              .collection('stores')
              .where('branchCode', isEqualTo: bc)
              .limit(1)
              .get();
          if (sSnap.docs.isNotEmpty) {
            final sData = sSnap.docs.first.data();
            storeCache[bc] = {'gstin': sData['gstin']?.toString() ?? 'N/A'};
          }
        }

        final DateTime billDate =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final String dateStr = DateFormat('dd MMM yyyy HH:mm').format(billDate);
        final String invoiceNo = data['invoiceNo'] ?? doc.id;
        final String upiTxn =
            data['upiTransactionId'] ?? data['transactionId'] ?? 'N/A';

        final List items = data['cartItems'] ?? data['items'] ?? [];
        if (items.isEmpty) {
          ledger +=
              '"$invoiceNo","$dateStr","${doc.id}","$payMode","$upiTxn",'
              '"NO ITEMS","0","0","0","0","0","0","0","0","$exitStatus","$refundAmt"\n';
          continue;
        }

        for (var item in items) {
          final String name =
              item['name']?.toString().replaceAll('"', '""') ?? 'Unknown';
          final int qty =
              int.tryParse(
                item['qty']?.toString() ?? item['quantity']?.toString() ?? '1',
              ) ??
              1;
          final double price =
              double.tryParse(item['price']?.toString() ?? '') ??
              double.tryParse(item['unitPrice']?.toString() ?? '') ??
              double.tryParse(item['discountedPrice']?.toString() ?? '') ??
              double.tryParse(item['originalPrice']?.toString() ?? '') ??
              0;
          final double gstRate =
              double.tryParse(
                (item['gst'] ?? item['gstRate'] ?? item['taxRate'] ?? '0')
                    .toString()
                    .replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              0;
          final double gross = price * qty;
          final double taxable = gross / (1 + gstRate / 100);
          final double gstAmt = gross - taxable;
          final double cgst = gstAmt / 2;
          final double sgst = gstAmt / 2;

          totalCGST += cgst;
          totalSGST += sgst;

          ledger +=
              '"$invoiceNo","$dateStr","${doc.id}","$payMode","$upiTxn",'
              '"$name","$qty","${price.toStringAsFixed(2)}","${gross.toStringAsFixed(2)}",'
              '"${taxable.toStringAsFixed(2)}","$gstRate","${cgst.toStringAsFixed(2)}",'
              '"${sgst.toStringAsFixed(2)}","${gross.toStringAsFixed(2)}",'
              '"$exitStatus","$refundAmt"\n';
        }
      }

      // ─── AI VERDICT ───────────────────────────────────────────────
      final double refundRate = totalInvoices > 0
          ? (refundCount / totalInvoices) * 100
          : 0;
      final double leakageRate = grossSales > 0
          ? (leakage / grossSales) * 100
          : 0;
      final String riskLevel =
          (refundRate > 10 || leakageRate > 15 || rejectedCount > 5)
          ? 'HIGH [!]'
          : (refundRate > 5 || leakageRate > 8)
          ? 'MEDIUM [~]'
          : 'LOW [OK]';
      final String verdict = riskLevel == 'LOW [OK]'
          ? 'Store operationally healthy. All metrics within safe range.'
          : 'Anomalies detected. Immediate review recommended.';

      // ─── SECTION 1: SMART SUMMARY ──────────────────────────────────
      String summary = 'CLICKOUT — CA-GRADE SMART AUDIT REPORT\n';
      summary +=
          'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}\n';
      summary += 'Period: $type\n\n';

      summary += '== SECTION 1 -- EXECUTIVE SUMMARY ==\n';
      summary += 'Metric,Value,Formula\n';
      summary +=
          '"Total Gross Sales","₹${grossSales.toStringAsFixed(2)}","SUM(all invoices)"\n';
      summary +=
          '"Realized Revenue","₹${realizedRevenue.toStringAsFixed(2)}","exitStatus=APPROVED"\n';
      summary +=
          '"Financial Leakage","₹${leakage.toStringAsFixed(2)}","Paid but not exited"\n';
      summary +=
          '"Total Refunds","₹${totalRefund.toStringAsFixed(2)} ($refundCount txns)","refundAmount>0"\n';
      summary +=
          '"Rejected Orders","₹${rejectedAmount.toStringAsFixed(2)} ($rejectedCount orders)","exitStatus=REJECTED"\n';
      summary +=
          '"Total CGST Collected","₹${totalCGST.toStringAsFixed(2)}","SUM(cgst)"\n';
      summary +=
          '"Total SGST Collected","₹${totalSGST.toStringAsFixed(2)}","SUM(sgst)"\n';
      summary +=
          '"Total GST Liability","₹${(totalCGST + totalSGST).toStringAsFixed(2)}","CGST+SGST"\n';
      summary +=
          '"Net Taxable Revenue","₹${(grossSales - totalCGST - totalSGST).toStringAsFixed(2)}","Gross-GST"\n';
      summary +=
          '"Cash Collection","₹${cashTotal.toStringAsFixed(2)}","paymentMode=CASH"\n';
      summary +=
          '"UPI/Online Collection","₹${upiTotal.toStringAsFixed(2)}","paymentMode=UPI"\n';
      summary +=
          '"Average Basket Value","₹${totalInvoices > 0 ? (grossSales / totalInvoices).toStringAsFixed(2) : 0}","Revenue/Invoices"\n';
      summary += '"Total Invoices","$totalInvoices","COUNT(orders)"\n';
      summary +=
          '"Refund Rate","${refundRate.toStringAsFixed(1)}%","Refunds/Total"\n';
      summary +=
          '"Leakage Rate","${leakageRate.toStringAsFixed(1)}%","Leakage/Gross"\n';
      summary += '\n';

      summary += '══ AI AUDITOR VERDICT ══\n';
      summary += '"Risk Level","$riskLevel"\n';
      summary += '"Verdict","$verdict"\n';
      summary +=
          '"Refund Rate","${refundRate.toStringAsFixed(1)}% ${refundRate > 10 ? '-- ABNORMAL (safe: <5%)' : '-- Normal'}"\n';
      summary +=
          '"Leakage Rate","${leakageRate.toStringAsFixed(1)}% ${leakageRate > 15 ? '-- HIGH RISK' : '-- Safe'}"\n';
      summary +=
          '"Guard Rejections","$rejectedCount ${rejectedCount > 5 ? '-- Review required' : '-- Normal'}"\n';
      summary += '\n\n';

      summary += '== SECTION 2 -- RAW TRANSACTION LEDGER ==\n';

      // ─── COMBINE & DOWNLOAD ───────────────────────────────────────
      final String fullCsv = summary + ledger;
      final Uint8List bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(fullCsv),
      ]);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "ClickOut_CA_SmartReport_${type}_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv",
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ CA-Grade Smart Report Downloaded!"),
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
}
