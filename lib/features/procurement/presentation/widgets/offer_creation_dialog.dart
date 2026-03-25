import 'package:flutter/material.dart';

class OfferPayload {
  final String type;
  final Map<String, dynamic> data;
  OfferPayload({required this.type, required this.data});
}

class OfferCreationDialog extends StatefulWidget {
  final String productId;
  final String productName;

  const OfferCreationDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<OfferCreationDialog> createState() => _OfferCreationDialogState();
}

class _OfferCreationDialogState extends State<OfferCreationDialog> {
  String _selectedType = 'PERCENTAGE';
  final _val1Ctrl = TextEditingController();
  final _val2Ctrl = TextEditingController();

  final List<Map<String, String>> _offerTypes = [
    {'value': 'PERCENTAGE', 'label': 'Flat % Discount'},
    {'value': 'FLAT_AMOUNT', 'label': 'Flat ₹ Amount Off'},
    {'value': 'BOGO', 'label': 'Buy 1 Get 1 Free (Same Item)'},
    {'value': 'BUY_X_GET_Y', 'label': 'Custom: Buy X Get Y Free'},
  ];

  @override
  void dispose() {
    _val1Ctrl.dispose();
    _val2Ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedType == 'BOGO') {
      Navigator.pop(
        context,
        OfferPayload(type: 'BOGO', data: {'buyQty': 1, 'freeQty': 1}),
      );
      return;
    }

    if (_val1Ctrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Please fill the required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double val1 = double.tryParse(_val1Ctrl.text) ?? 0.0;
    if (val1 <= 0) return;

    Map<String, dynamic> data = {};

    if (_selectedType == 'PERCENTAGE') {
      if (val1 > 99) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Discount cannot be more than 99%"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      data = {'percentage': val1};
    } else if (_selectedType == 'FLAT_AMOUNT') {
      data = {'amountOff': val1};
    } else if (_selectedType == 'BUY_X_GET_Y') {
      double val2 = double.tryParse(_val2Ctrl.text) ?? 0.0;
      if (val2 <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Please enter valid Free Quantity"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      data = {'buyQty': val1.toInt(), 'freeQty': val2.toInt()};
    }

    Navigator.pop(context, OfferPayload(type: _selectedType, data: data));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 20,
      backgroundColor: Colors.white,
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Create Promotion",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B3674),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Applying to: ${widget.productName}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 💼 BODY
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔽 DROPDOWN
                  const Text(
                    "Select Offer Strategy",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedType,
                        icon: const Icon(
                          Icons.arrow_drop_down_circle,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                        items: _offerTypes
                            .map(
                              (opt) => DropdownMenuItem<String>(
                                value: opt['value'],
                                child: Text(
                                  opt['label']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B3674),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedType = val!;
                            _val1Ctrl.clear();
                            _val2Ctrl.clear();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🎛️ DYNAMIC FORMS
                  if (_selectedType == 'PERCENTAGE') ...[
                    _buildInputField(
                      controller: _val1Ctrl,
                      label: "Discount Percentage (%)",
                      hint: "E.g. 50",
                      icon: Icons.percent,
                      instruction:
                          "Enter percentage value. Example: Entering '30' will give customer 30% discount on the MRP. Maximum allowed is 99%.",
                    ),
                  ] else if (_selectedType == 'FLAT_AMOUNT') ...[
                    _buildInputField(
                      controller: _val1Ctrl,
                      label: "Flat Discount Amount (₹)",
                      hint: "E.g. 100",
                      icon: Icons.currency_rupee,
                      instruction:
                          "Enter exact Rupee amount to deduct. Example: Entering '50' means the product price will directly reduce by ₹50.",
                    ),
                  ] else if (_selectedType == 'BOGO') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "BOGO is active! Customer adds 1 item to cart, and they automatically get another 1 for free.",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedType == 'BUY_X_GET_Y') ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _val1Ctrl,
                            label: "Buy Quantity (X)",
                            hint: "E.g. 2",
                            icon: Icons.shopping_basket,
                            instruction: "Items customer must buy.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            controller: _val2Ctrl,
                            label: "Free Quantity (Y)",
                            hint: "E.g. 1",
                            icon: Icons.card_giftcard,
                            instruction: "Items given free.",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            "Example: Buy Qty = 2, Free Qty = 1 means 'Buy 2 Get 1 Free'.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ⚡ ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _submit,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: const Text(
                      "ACTIVATE OFFER",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🧱 HELPER WIDGET FOR INPUTS
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String instruction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: Colors.blueAccent),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                instruction,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
