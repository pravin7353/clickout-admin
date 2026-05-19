import 'package:flutter/material.dart';

class UnknownItemDialog extends StatefulWidget {
  final String barcode;
  final Function(Map<String, dynamic>) onSave;

  const UnknownItemDialog({
    super.key,
    required this.barcode,
    required this.onSave,
  });

  @override
  State<UnknownItemDialog> createState() => _UnknownItemDialogState();
}

class _UnknownItemDialogState extends State<UnknownItemDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: "1");

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          const Text("Unknown Product"),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Barcode: ${widget.barcode}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "Product Name *",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "MRP (₹)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Unit Cost (₹)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Received Quantity",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_nameCtrl.text.isEmpty) return;
            widget.onSave({
              'barcode': widget.barcode,
              'name': _nameCtrl.text,
              'price': double.tryParse(_priceCtrl.text) ?? 0.0,
              'unitCost': double.tryParse(_costCtrl.text) ?? 0.0,
              'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
            });
          },
          child: const Text("Add to Deposit"),
        ),
      ],
    );
  }
}
