import 'package:flutter/material.dart';

class CashReconciliationCard extends StatefulWidget {
  final double expectedCash;
  const CashReconciliationCard({super.key, required this.expectedCash});

  @override
  State<CashReconciliationCard> createState() => _CashReconciliationCardState();
}

class _CashReconciliationCardState extends State<CashReconciliationCard> {
  final TextEditingController _countedCashCtrl = TextEditingController();
  double _variance = 0.0;
  bool _isCalculated = false;

  void _calculateVariance() {
    double counted = double.tryParse(_countedCashCtrl.text) ?? 0.0;
    setState(() {
      _variance = counted - widget.expectedCash;
      _isCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color varianceColor = Colors.green;
    String varianceText = "Perfect Match ✅";

    if (_isCalculated) {
      if (_variance < 0) {
        varianceColor = Colors.redAccent;
        varianceText = "SHORTAGE (₹${_variance.abs().toStringAsFixed(2)}) 🚨";
      } else if (_variance > 0) {
        varianceColor = Colors.orange;
        varianceText = "EXCESS (₹${_variance.toStringAsFixed(2)}) ⚠️";
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF2B3674)),
              SizedBox(width: 10),
              Text(
                "Cash Drawer Reconciliation",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B3674),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  "System Expected",
                  "₹${widget.expectedCash.toStringAsFixed(0)}",
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TextField(
                  controller: _countedCashCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Actual Counted Cash",
                    prefixText: "₹ ",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => _calculateVariance(),
                ),
              ),
            ],
          ),
          if (_isCalculated) ...[
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Audit Status:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: varianceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    varianceText,
                    style: TextStyle(
                      color: varianceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
