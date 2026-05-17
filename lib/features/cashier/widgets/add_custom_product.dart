import 'package:flutter/material.dart';

class AddCustomProductWidget extends StatefulWidget {
  final Function(String name, double price, int qty, double gst, bool isService)
  onAdd;

  const AddCustomProductWidget({super.key, required this.onAdd});

  @override
  State<AddCustomProductWidget> createState() => _AddCustomProductWidgetState();
}

class _AddCustomProductWidgetState extends State<AddCustomProductWidget> {
  bool _isProduct = true; // Toggle state (True = Product, False = Service)

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _gstCtrl = TextEditingController(text: '0');

  // Input Field Style matching your screenshot
  InputDecoration _inputStyle(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      // 🚀 FIX: Removed const from OutlineInputBorder
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Add Custom Item",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🔄 TOGGLE (Product / Service) EXACTLY LIKE SCREENSHOT
            // 🚀 WARNING BANNER FOR TEMP ITEM
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "⚠️ Temp Item: Kindly add this Product/Service to your inventory later.",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                _buildToggleBtn("Product", _isProduct),
                const SizedBox(width: 12),
                _buildToggleBtn("Service", !_isProduct),
              ],
            ),
            const SizedBox(height: 24),

            // 📝 INPUT FIELDS
            TextField(
              controller: _nameCtrl,
              decoration: _inputStyle("Item Name", Icons.shopping_bag_outlined),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputStyle(
                      "Unit Price (₹)",
                      Icons.currency_rupee,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputStyle(
                      "Quantity",
                      Icons.production_quantity_limits,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gstCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputStyle("GST Rate (%)", Icons.percent),
            ),
            const SizedBox(height: 24),

            // 🚀 ADD BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return;
                  widget.onAdd(
                    _nameCtrl.text.trim(),
                    double.tryParse(_priceCtrl.text) ?? 0.0,
                    int.tryParse(_qtyCtrl.text) ?? 1,
                    double.tryParse(_gstCtrl.text) ?? 0.0,
                    !_isProduct, // true if service
                  );
                },
                child: const Text(
                  "Add to Cart",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Exact Toggle UI from your Screenshot
  Widget _buildToggleBtn(String title, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isProduct = title == "Product"),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.green.withOpacity(0.1)
                : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.green : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
