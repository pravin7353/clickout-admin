import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 Added Riverpod for SaaS
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 Tenant Config
import 'package:clickout_admin/core/utils/hierarchy_filter.dart'; // 🚀 Isolation Rules

class OfferPayload {
  final String type;
  final Map<String, dynamic> data;
  OfferPayload({required this.type, required this.data});
}

// 🚀 UPGRADED to ConsumerStatefulWidget for Tenant Identity
class OfferCreationDialog extends ConsumerStatefulWidget {
  final String productId;
  final String productName;

  const OfferCreationDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<OfferCreationDialog> createState() =>
      _OfferCreationDialogState();
}

class _OfferCreationDialogState extends ConsumerState<OfferCreationDialog> {
  String _selectedType = 'PERCENTAGE';
  final _val1Ctrl = TextEditingController();
  final _val2Ctrl = TextEditingController();

  // 🚀 SAAS ENGINE: Live Product Fetching for Target Offers
  List<Map<String, dynamic>> _productsList = [];
  bool _isLoadingProducts = true;
  String? _selectedTargetProductId;
  String? _selectedTargetProductName;

  // 🚀 SAAS ENGINE: Upgraded Promotion Catalog
  final List<Map<String, String>> _offerTypes = [
    {'value': 'PERCENTAGE', 'label': 'Flat % Discount'},
    {'value': 'FLAT_AMOUNT', 'label': 'Flat ₹ Amount Off'},
    {'value': 'BOGO', 'label': 'Buy 1 Get 1 Free (Same Item)'},
    {'value': 'BUY_X_GET_Y', 'label': 'Buy X Get Y Free (Same Item)'},
    {
      'value': 'BUY_X_GET_Y_CROSS',
      'label': 'Buy X Get Y Free (Different Item)',
    },
    {'value': 'TIERED_QTY', 'label': 'Tiered Discount (Buy X get Y% off)'},
    {'value': 'BUNDLE_PRICE', 'label': 'Fixed Bundle Price (Any X for ₹Y)'},
    {'value': 'FLASH_SALE', 'label': 'Flash Sale (Limited Time)'},
    {
      'value': 'CROSS_PRODUCT',
      'label': 'Cross-Product (Buy this, get % off that)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchProductsForDropdown();
  }

  // 📡 🚀 THE FIX: Fetch Products safely bypassing the NoSQL missing field trap
  Future<void> _fetchProductsForDropdown() async {
    try {
      final adminData = ref.read(adminRoleProvider).value;

      // 🚀 Apply SaaS Isolation
      Query baseQuery = HierarchyFilter.apply(
        FirebaseFirestore.instance.collection('products'),
        adminData,
      );

      final snap = await baseQuery.get();

      if (mounted) {
        setState(() {
          // 🚀 Filter in memory to save products that don't even have the 'isBlocked' field
          _productsList = snap.docs
              .where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['isBlocked'] != true;
              })
              .map((d) {
                final data = d.data() as Map<String, dynamic>;
                return {
                  'id': d.id,
                  'name': data['name'] ?? 'Unknown Item',
                  'barcode': data['barcode'] ?? '',
                };
              })
              .toList();
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

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
        OfferPayload(type: _selectedType, data: {'active': true}),
      );
      return;
    }

    dynamic v1;
    final v2 = double.tryParse(_val2Ctrl.text.trim()) ?? 0;

    // 🚀 Dynamic Validation
    if (_selectedType == 'CROSS_PRODUCT') {
      v1 = _val1Ctrl.text.trim();
    } else {
      v1 = double.tryParse(_val1Ctrl.text.trim()) ?? 0;
      if (v1 <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Please enter a valid primary number value."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    Map<String, dynamic> payloadData = {'value1': v1, 'value2': v2};

    // 🚀 THE MASTER FIX: Sync keys with what OfferEngineService actually expects!
    if (_selectedType == 'PERCENTAGE') {
      payloadData['discountPercent'] = v1;
    } else if (_selectedType == 'FLAT_AMOUNT') {
      payloadData['discountAmount'] = v1;
    } else if (_selectedType == 'BUY_X_GET_Y' ||
        _selectedType == 'BUY_X_GET_Y_CROSS') {
      payloadData['buyQty'] = v1.toInt();
      payloadData['freeQty'] = v2.toInt();
    } else if (_selectedType == 'TIERED_QTY') {
      payloadData['minQty'] = v1.toInt();
      payloadData['discountPercent'] = v2;
    } else if (_selectedType == 'BUNDLE_PRICE') {
      payloadData['bundleQty'] = v1.toInt();
      payloadData['bundlePrice'] = v2;
    } else if (_selectedType == 'FLASH_SALE') {
      payloadData['discountPercent'] = v1;
      payloadData['durationHours'] = v2.toInt();
    } else if (_selectedType == 'CROSS_PRODUCT') {
      payloadData['discountPercent'] = v1;
    }

    // 🚀 Cross-Product Validation: Target Product Required!
    if (_selectedType == 'CROSS_PRODUCT' ||
        _selectedType == 'BUY_X_GET_Y_CROSS') {
      if (_selectedTargetProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 Please search and select a Target Product!"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      payloadData['targetProductId'] = _selectedTargetProductId;
      payloadData['targetProductName'] = _selectedTargetProductName;
    }

    Navigator.pop(
      context,
      OfferPayload(type: _selectedType, data: payloadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const Color bgDark = Color(0xFF080B08);
    const Color cardDark = Color(0xFF111811);
    const Color accentGreen = Color(0xFF00C853);
    const Color accentOrange = Color(0xFFD4580A);
    const Color textPrimary = Color(0xFFF0F0F0);
    const Color textSecondary = Color(0xFF888888);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: accentGreen, width: 1.5),
      ),
      elevation: 24,
      backgroundColor: bgDark,
      insetPadding: EdgeInsets.all(isMobile ? 16 : 24),
      child: SizedBox(
        width: isMobile ? double.infinity : 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🎩 HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(color: textSecondary.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: accentOrange,
                      size: 24,
                    ),
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
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Applying to: ${widget.productName}",
                          style: const TextStyle(
                            color: accentGreen,
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
            Flexible(
              child: SingleChildScrollView(
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
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A221A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: cardDark,
                          value: _selectedType,
                          icon: const Icon(
                            Icons.arrow_drop_down_circle,
                            color: accentOrange,
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
                                      color: textPrimary,
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
                              _selectedTargetProductId = null;
                              _selectedTargetProductName = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🎛️ DYNAMIC INPUTS ENGINE
                    if (_selectedType == 'PERCENTAGE') ...[
                      _buildInputField(
                        controller: _val1Ctrl,
                        label: "Discount Percentage (%)",
                        hint: "E.g. 15",
                        icon: Icons.percent,
                        instruction:
                            "Reduces selling price by this percentage.",
                      ),
                    ] else if (_selectedType == 'FLAT_AMOUNT') ...[
                      _buildInputField(
                        controller: _val1Ctrl,
                        label: "Flat Discount Amount (₹)",
                        hint: "E.g. 50",
                        icon: Icons.currency_rupee,
                        instruction:
                            "Directly subtracts this amount from the MRP.",
                      ),
                    ] else if (_selectedType == 'BOGO') ...[
                      _buildInfoBox(
                        "BOGO is active! Customer adds 1 to cart, and automatically gets another 1 for free.",
                        Icons.check_circle,
                        accentGreen,
                      ),
                    ] else if (_selectedType == 'CROSS_PRODUCT') ...[
                      _buildProductSelector(),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _val1Ctrl,
                        label: "Discount on Target Product (%)",
                        hint: "E.g. 10",
                        icon: Icons.percent,
                        instruction:
                            "Example: Buy Iron, Get 10% Off on Harpic.",
                      ),
                    ] else if (_selectedType == 'BUY_X_GET_Y_CROSS') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _val1Ctrl,
                              label: "Buy Qty (X)",
                              hint: "E.g. 1",
                              icon: Icons.shopping_basket,
                              instruction: "Trigger qty.",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputField(
                              controller: _val2Ctrl,
                              label: "Free Qty (Y)",
                              hint: "E.g. 1",
                              icon: Icons.card_giftcard,
                              instruction: "Reward qty.",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProductSelector(),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _val1Ctrl,
                              label: _getLabel1(),
                              hint: "Value X",
                              icon: Icons.keyboard_double_arrow_right,
                              instruction: "Trigger condition.",
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputField(
                              controller: _val2Ctrl,
                              label: _getLabel2(),
                              hint: "Value Y",
                              icon: Icons.star_border,
                              instruction: "The reward/discount.",
                            ),
                          ),
                        ],
                      ),
                      if (_selectedType == 'FLASH_SALE')
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: _buildInfoBox(
                            "URGENCY: This offer will self-destruct after the specified hours.",
                            Icons.timer,
                            accentOrange,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // ⚡ ACTIONS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: textSecondary.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: bgDark,
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
                    icon: const Icon(Icons.local_offer, size: 18),
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

  String _getLabel1() {
    switch (_selectedType) {
      case 'BUY_X_GET_Y':
        return "Buy Qty (X)";
      case 'TIERED_QTY':
        return "Min Qty Needed";
      case 'BUNDLE_PRICE':
        return "Bundle Size (Qty)";
      case 'FLASH_SALE':
        return "Discount (%)";
      default:
        return "Input 1";
    }
  }

  String _getLabel2() {
    switch (_selectedType) {
      case 'BUY_X_GET_Y':
        return "Free Qty (Y)";
      case 'TIERED_QTY':
        return "Discount (%)";
      case 'BUNDLE_PRICE':
        return "Total Bundle Price (₹)";
      case 'FLASH_SALE':
        return "Duration (Hours)";
      default:
        return "Input 2";
    }
  }

  Widget _buildInfoBox(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔍 THE NEW LIVE PRODUCT SEARCH AUTOCOMPLETE
  Widget _buildProductSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Search Target Product (To Apply Discount/Give Free)",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 6),
        _isLoadingProducts
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4580A)),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => option['name'] ?? '',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.trim().isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return _productsList.where((option) {
                        return option['name'].toString().toLowerCase().contains(
                          textEditingValue.text.trim().toLowerCase(),
                        );
                      });
                    },
                    onSelected: (selection) {
                      setState(() {
                        _selectedTargetProductId = selection['id'];
                        _selectedTargetProductName = selection['name'];
                      });
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: constraints.maxWidth,
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111811),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD4580A),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: const Color(
                                            0xFF888888,
                                          ).withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.inventory_2_outlined,
                                          color: Color(0xFFD4580A),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            option['name'] ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFFF0F0F0),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder:
                        (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: (val) {
                              if (_selectedTargetProductId != null) {
                                setState(() {
                                  _selectedTargetProductId = null;
                                  _selectedTargetProductName = null;
                                });
                              }
                            },
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFFF0F0F0),
                            ),
                            decoration: InputDecoration(
                              hintText: "E.g., Type 'Surf' or 'Harpic'...",
                              hintStyle: TextStyle(
                                color: const Color(0xFF888888).withValues(alpha: 0.5),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 18,
                                color: Color(0xFF888888),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1A221A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD4580A),
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                  );
                },
              ),
        if (_selectedTargetProductName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00C853),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Target Linked: $_selectedTargetProductName",
                    style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String instruction,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFFF0F0F0),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF888888).withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
            filled: true,
            fillColor: const Color(0xFF1A221A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4580A), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF888888)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                instruction,
                style: const TextStyle(
                  color: Color(0xFF888888),
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
