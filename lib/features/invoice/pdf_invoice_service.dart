import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 Added for DB fetch

class PdfInvoiceService {
  static Future<void> printInvoice(
    Map<String, dynamic> data,
    String orderId,
  ) async {
    final pdf = pw.Document();
    final format = PdfPageFormat.roll80;

    // 🧠 DEFAULT META
    String storeName =
        data['storeName']?.toString().toUpperCase() ?? 'CLICKOUT RETAIL';
    String address = 'N/A';
    String phone = 'N/A';
    String gstin = 'N/A';
    String invPrefix = 'INV/';
    List<String> terms = [
      "1. Exchange within 7 days with original receipt.",
      "2. Goods once sold will not be refunded.",
    ];

    // 🚀 SMART FIREBASE FETCH (Maps exact fields from your UI)
    try {
      String bc =
          (data['branchCode'] ?? data['branchId'] ?? data['storeId'])
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
          storeName = (sData['storeName'] ?? sData['branchName'] ?? storeName)
              .toString()
              .toUpperCase();

          // Mapped to exact UI labels and Firestore structure
          phone =
              sData['managerPhone'] ??
              (sData['contactNumbers'] != null &&
                      sData['contactNumbers'].isNotEmpty
                  ? sData['contactNumbers'][0]
                  : phone);

          String gst = sData['gstNumber'] ?? sData['gstin'] ?? '';
          if (gst.isEmpty && sData['licenses'] is List) {
            for (var c in sData['licenses']) {
              if (c['type'] == 'GSTIN') {
                gst = c['number'] ?? '';
                break;
              }
            }
          }
          if (gst.isNotEmpty) gstin = gst;

          var loc = sData['location'] as Map<String, dynamic>?;
          String baseAddr =
              loc?['address'] ??
              sData['completeStoreAddress'] ??
              sData['address'] ??
              "";
          String city = loc?['city'] ?? sData['city'] ?? "";
          String pin = loc?['pincode'] ?? sData['pincode'] ?? "";
          List<String> addrParts = [];
          if (baseAddr.isNotEmpty) addrParts.add(baseAddr);
          if (city.isNotEmpty) addrParts.add(city);
          if (pin.isNotEmpty) addrParts.add(pin);
          if (addrParts.isNotEmpty) address = addrParts.join(", ");
        }
      }

      // 🏢 TENANT FALLBACK (For GST & Terms)
      String tid = data['tenantId']?.toString().trim() ?? '';
      if (tid.isNotEmpty && tid != 'ALL') {
        var tSnap = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tid)
            .get();
        if (tSnap.exists) {
          var tData = tSnap.data() as Map<String, dynamic>;
          if (gstin == 'N/A' || gstin.isEmpty) {
            gstin = tData['gstin'] ?? tData['gstNumber'] ?? 'N/A';
          }
          var config = tData['invoiceConfig'] as Map<String, dynamic>? ?? {};
          invPrefix =
              config['prefix']?.toString() ??
              config['invoicePrefix']?.toString() ??
              invPrefix;
          if (config['terms'] != null &&
              config['terms'].toString().isNotEmpty) {
            terms = config['terms'].toString().split(RegExp(r'\\n|\n'));
          }
        }
      }
    } catch (e) {
      // Silent fallback
    }

    final DateTime date = (data['timestamp'] != null)
        ? (data['timestamp'] as dynamic).toDate()
        : DateTime.now();
    final String invoiceNo =
        data['invoiceNo']?.toString() ??
        "$invPrefix${orderId.toUpperCase().substring(0, 8)}";
    final String payMode = data['paymentMode']?.toString() ?? 'CASH';

    final List<dynamic> items = data['cartItems'] ?? data['items'] ?? [];

    double computedTaxable = 0.0;
    double computedGst = 0.0;
    double computedGross = 0.0;

    for (var item in items) {
      int qty =
          int.tryParse(
            item['qty']?.toString() ?? item['quantity']?.toString() ?? '1',
          ) ??
          1;
      double itemOrig =
          double.tryParse(
            item['originalPrice']?.toString() ?? item['mrp']?.toString() ?? '0',
          ) ??
          0.0;
      double price =
          double.tryParse(item['price']?.toString() ?? '') ??
          double.tryParse(item['unitPrice']?.toString() ?? '') ??
          double.tryParse(item['discountedPrice']?.toString() ?? '') ??
          itemOrig;
      double itemTotal = qty * price;
      computedGross += itemTotal;

      double gstRate = 0.0;
      if (item['gst'] != null) {
        gstRate =
            double.tryParse(
              item['gst'].toString().replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0.0;
      }
      double base = itemTotal / (1 + (gstRate / 100));
      computedTaxable += base;
      computedGst += (itemTotal - base);
    }

    double subtotal =
        double.tryParse(data['taxableValue']?.toString() ?? '0') ?? 0.0;
    if (subtotal == 0.0) subtotal = computedTaxable;

    double gstTotal =
        double.tryParse(data['gstTotal']?.toString() ?? '0') ?? 0.0;
    if (gstTotal == 0.0) gstTotal = computedGst;

    double grossSubtotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ??
        computedGross;
    double discount =
        double.tryParse(data['discount']?.toString() ?? '0') ?? 0.0;
    double grandTotal =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    double totalBagWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;
    double totalSavings =
        double.tryParse(data['totalSavings']?.toString() ?? '0') ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (address.isNotEmpty && address != 'N/A')
                pw.Center(
                  child: pw.Text(
                    address,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (phone != 'N/A' || gstin != 'N/A')
                pw.Center(
                  child: pw.Text(
                    "Ph: ${phone == 'N/A' ? '' : phone} | GSTIN: ${gstin == 'N/A' ? '' : gstin}",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),

              pw.SizedBox(height: 6),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Inv: $invoiceNo",
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yy HH:mm').format(date),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "Pay Mode: $payMode",
                style: const pw.TextStyle(fontSize: 8),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      "ITEM",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      "QTY",
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "RATE",
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "AMT",
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 4),

              ...items.map((item) {
                String name = item['name']?.toString() ?? 'Item';
                int qty =
                    int.tryParse(
                      item['qty']?.toString() ??
                          item['quantity']?.toString() ??
                          '1',
                    ) ??
                    1;
                double itemOrig =
                    double.tryParse(
                      item['originalPrice']?.toString() ??
                          item['mrp']?.toString() ??
                          '0',
                    ) ??
                    0.0;
                double price =
                    double.tryParse(item['price']?.toString() ?? '') ??
                    double.tryParse(item['unitPrice']?.toString() ?? '') ??
                    double.tryParse(
                      item['discountedPrice']?.toString() ?? '',
                    ) ??
                    itemOrig;
                double total = qty * price;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          name,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          "$qty",
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          price.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          total.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 4),

              _buildTotalRow(
                "Gross Subtotal:",
                grossSubtotal.toStringAsFixed(2),
              ),
              _buildTotalRow("Taxable Value:", subtotal.toStringAsFixed(2)),
              _buildTotalRow("Total GST:", gstTotal.toStringAsFixed(2)),
              if (totalBagWeight > 0)
                _buildTotalRow(
                  "Total Weight:",
                  totalBagWeight >= 1000
                      ? "${(totalBagWeight / 1000).toStringAsFixed(2)} KG"
                      : "${totalBagWeight.toStringAsFixed(0)} g",
                ),
              if (discount > 0)
                _buildTotalRow("Discount:", "-${discount.toStringAsFixed(2)}"),
              if (totalSavings > 0)
                _buildTotalRow(
                  "Total Savings:",
                  "Rs. ${totalSavings.toStringAsFixed(2)}",
                ),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 4),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "GRAND TOTAL",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Rs. ${grandTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 1),
              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  "Thank you for shopping with us!",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              ...terms.map(
                (t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Center(
                    child: pw.Text(
                      t.trim(),
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  "Powered by ClickOut OS",
                  style: const pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$invoiceNo',
    );
  }

  static pw.Widget _buildTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
