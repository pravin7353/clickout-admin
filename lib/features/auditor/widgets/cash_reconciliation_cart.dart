import 'package:flutter/material.dart';
import '../../coach/widgets/info_button.dart';
import '../../../core/theme/app_theme.dart';

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
    final inputBg = context.colors.scaffoldBg;
    final textColor = context.colors.textPrimary;
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
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).primaryColor,
              ), // 💎 Emerald Green Accent
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Cash Drawer Reconciliation",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              const InfoButton(
                title: 'Cash Drawer Reconciliation',
                en: 'Compare system-expected cash vs actual counted cash. Any variance indicates missing money or excess float.',
                hi: 'System ka expected cash aur actual cash drawer ka cash compare karo. Farq hai to ya paisa missing hai ya extra cash hai — dono investigate karo.',
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
                  Colors
                      .blueAccent, // This gets overridden inside _buildInfoTile
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: TextField(
                  controller: _countedCashCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Actual Counted Cash",
                    labelStyle: TextStyle(
                      color: Theme.of(context).textTheme.labelLarge?.color,
                    ),
                    prefixText: "₹ ",
                    prefixStyle: TextStyle(color: textColor),
                    filled: true,
                    fillColor: inputBg,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  onChanged: (v) => _calculateVariance(),
                ),
              ),
            ],
          ),
          if (_isCalculated) ...[
            Divider(height: 30, color: Theme.of(context).dividerColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Audit Status:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: varianceColor.withValues(alpha: 0.1),
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
    final inputBg = context.colors.scaffoldBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.labelLarge?.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
