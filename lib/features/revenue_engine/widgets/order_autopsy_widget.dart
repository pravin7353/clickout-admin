import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

// 🚀 FUTURE PROVIDER: To safely fetch Employee details asynchronously
final employeeNameProvider = FutureProvider.family<String, String>((
  ref,
  empId,
) async {
  if (empId.isEmpty) return "SYSTEM / KIOSK";
  try {
    // 🚀 FIX: Agar order Employee ne nahi, kisi Manager (User) ne banaya hai, toh Users table me bhi dhoondhega!
    final empDoc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(empId)
        .get();
    if (empDoc.exists && empDoc.data()?['name'] != null) {
      return empDoc.data()!['name'];
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(empId)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc.data()?['name'] ??
          userDoc.data()?['displayName'] ??
          "Manager";
    }

    return "Unknown Staff ($empId)";
  } catch (e) {
    return "Verification Failed";
  }
});

class OrderAutopsyDrawer extends ConsumerWidget {
  final Map<String, dynamic> order;

  const OrderAutopsyDrawer({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String cashierId = order['userId'] ?? order['cashierId'] ?? '';
    final employeeAsync = ref.watch(employeeNameProvider(cashierId));

    // 🧠 CA LEVEL MATH: Parse Items and Subtotals
    List items = order['items'] ?? [];
    double calculatedSubtotal = 0.0;

    List<Widget> itemRows = items.map((item) {
      double price =
          double.tryParse(
            item['unitPrice']?.toString() ?? item['price']?.toString() ?? '0',
          ) ??
          0.0;
      int qty =
          int.tryParse(
            item['quantity']?.toString() ?? item['qty']?.toString() ?? '1',
          ) ??
          1;
      double rowTotal = price * qty;
      calculatedSubtotal += rowTotal;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "${item['productName'] ?? 'Unknown Item'} x $qty",
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              "₹${rowTotal.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    }).toList();

    // 🧾 GST Reverse Calculation (Assuming 18% Inclusive for Retail)
    double storedTotal =
        double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;

    // Use storedTotal if items array is empty, else use calculated
    double activeTotal = calculatedSubtotal > 0
        ? calculatedSubtotal
        : storedTotal;

    double taxableValue = activeTotal / 1.18;
    double cgst = (activeTotal - taxableValue) / 2;
    double sgst = cgst;

    bool hasMismatch =
        calculatedSubtotal > 0 &&
        (calculatedSubtotal - storedTotal).abs() > 1.0;

    return Container(
      width: MediaQuery.of(context).size.width > 600
          ? 500
          : double.infinity, // Responsive Drawer
      color: context.colors.scaffoldBg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order Autopsy 🔬",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // 👨‍💼 HANDLED BY FIX
          employeeAsync.when(
            loading: () => const Text(
              "Identifying Staff...",
              style: TextStyle(color: Colors.grey),
            ),
            error: (_, __) => const Text(
              "Staff ID Error",
              style: TextStyle(color: Colors.red),
            ),
            data: (name) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: const Text(
                "Handled By",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              subtitle: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            "Line Items",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: itemRows.isNotEmpty
                  ? itemRows
                  : [const Text("No line items saved in DB.")],
            ),
          ),

          const SizedBox(height: 20),
          // 🧾 TAX & DISCREPANCY BLOCK
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasMismatch
                    ? context.colors.danger
                    : context.colors.border,
              ),
              borderRadius: BorderRadius.circular(12),
              color: hasMismatch
                  ? context.colors.danger.withValues(alpha: 0.1)
                  : context.colors.cardBg,
            ),
            child: Column(
              children: [
                _taxRow("Taxable Value", taxableValue),
                _taxRow("CGST (9%)", cgst),
                _taxRow("SGST (9%)", sgst),
                const Divider(),
                _taxRow("Calculated Total", activeTotal, isBold: true),
                _taxRow(
                  "Stored Bill Amount",
                  storedTotal,
                  isBold: true,
                  color: Colors.blueAccent,
                ),
                if (hasMismatch) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red,
                    child: const Text(
                      "🚨 AMOUNT MISMATCH DETECTED! Possible Cashier Tampering.",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taxRow(
    String label,
    double val, {
    bool isBold = false,
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            "₹${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
