import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'widgets/pos_scanner_dialog.dart';

import '../auth/auth_provider.dart';
import 'services/pos_order_service.dart';

// 🚨 BHAILOG DHYAN DE: Local Paths for Admin
import '../../core/services/cart_item.dart';
import 'providers/cart_provider.dart';
import '../coach/widgets/info_button.dart';
import '../../core/theme/app_theme.dart';

// ── UI DATA MODELS ──
class CartGroup {
  final String baseKey;
  CartItem? baseItem;
  CartItem? freeItem;
  CartItem? overflowItem;
  CartGroup({required this.baseKey});
}

List<CartGroup> buildCartGroups(Map<String, CartItem> items) {
  final Map<String, CartGroup> groups = {};
  items.forEach((key, item) {
    final baseKey = key.replaceAll('_FREE', '').replaceAll('_OVERFLOW', '');
    groups.putIfAbsent(baseKey, () => CartGroup(baseKey: baseKey));

    if (key.endsWith('_FREE')) {
      groups[baseKey]!.freeItem = item;
    } else if (key.endsWith('_OVERFLOW')) {
      groups[baseKey]!.overflowItem = item;
    } else {
      groups[baseKey]!.baseItem = item;
    }
  });
  return groups.values.toList();
}

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  bool _isInitializing = true;
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _searchResults = [];

  String _paymentMode = 'CASH';
  bool _isBilling = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _phoneCtrl.dispose();
    _searchFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  final Color _redBrand = const Color(0xFFE53E3E);
  final Color _greenBrand = const Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _loadInventoryToMemory();
  }

  Future<void> _loadInventoryToMemory() async {
    try {
      final adminData = await ref.read(adminRoleProvider.future);
      final String tenantId = adminData?['tenantId'] ?? '';

      if (tenantId.isEmpty) return;

      final prodSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final allItems = prodSnap.docs.map((d) => d.data()).toList();

      setState(() {
        _inventory = allItems;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() => _isInitializing = false);
    }
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final exactMatch = _inventory.where((item) {
      final dbBarcode = (item['barcode'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      return dbBarcode == q && dbBarcode.isNotEmpty;
    }).toList();

    if (exactMatch.isNotEmpty) {
      _handleBarcodeScan(exactMatch.first['barcode']);
      _searchCtrl.clear();
      _searchFocus.requestFocus();
      return;
    }

    final results = _inventory.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      final searchKey = (item['searchKey'] ?? '').toString().toLowerCase();
      return name.contains(q) || barcode.contains(q) || searchKey.contains(q);
    }).toList();

    setState(() => _searchResults = results);
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    final cleanInput = barcode.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final items = _inventory.where((item) {
      final dbBarcode = (item['barcode'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      return dbBarcode == cleanInput && dbBarcode.isNotEmpty;
    }).toList();

    if (items.isNotEmpty) {
      try {
        await ref.read(posCartProvider.notifier).addItem(items.first, 1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${items.first['name']} Added!"),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  "Product Not Found",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              "This barcode is not available in the system.\nKindly add this product to the inventory using the IDT Deposit module.",
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Dismiss",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/idt-deposits');
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text(
                  "Go to IDT Deposit",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _generateInvoice() async {
    final cartState = ref.read(posCartProvider);
    if (cartState.isEmpty || cartState.calcResult == null) return;
    setState(() => _isBilling = true);

    try {
      final adminData = await ref.read(adminRoleProvider.future);
      final String tId = adminData?['tenantId'] ?? '';
      final String bCode = adminData?['branchCode'] ?? '';

      if (tId.isEmpty || bCode.isEmpty)
        throw "Admin session sync error. Please refresh.";

      double calcTotalTax = cartState.items.values.fold(
        0.0,
        (sum, item) =>
            sum + (item.originalPrice * item.gst / 100 * item.quantity),
      );
      final itemsList = cartState.items.values.map((e) => e.toJson()).toList();

      await PosOrderService().createPosOrder(
        items: itemsList,
        totalAmount: cartState.calcResult!.newGrandTotal,
        gstTotal: calcTotalTax,
        paymentMode: _paymentMode,
        tenantId: tId,
        branchCode: bCode,
        customerPhone: _phoneCtrl.text.isNotEmpty
            ? "+91${_phoneCtrl.text}"
            : null,
      );

      ref.read(posCartProvider.notifier).clearCart();
      setState(() {
        _phoneCtrl.clear();
      });

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.colors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  "Bill Created!",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              "Order saved successfully. Print thermal receipt?",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 16,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Next Customer",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Sending to Thermal Printer..."),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: const Icon(Icons.print, size: 18),
                label: const Text(
                  "PRINT BILL",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isBilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final cartState = ref.watch(posCartProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = context.colors.scaffoldBg;
    final cardCol = context.colors.cardBg;
    final text1Col = context.colors.textPrimary;
    final text2Col = context.colors.textSecondary;
    final divCol = context.colors.border;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;
    final rightPanelWidth = screenWidth * 0.50;

    // ── LEFT PANEL WIDGET ──
    Widget leftContent = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Assisted Checkout",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: text1Col,
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: 'Assisted Checkout',
                en: 'Staff-assisted billing for customers without a mobile phone — senior citizens, walk-ins, or emergency cases. Add products by search or barcode scan. Bill is generated instantly with no security gate check required.',
                hi: 'Ye un customers ke liye hai jinke paas mobile nahi hai — senior citizens ya walk-in customers. Staff product search karke ya barcode scan karke cart mein add karta hai. Bill seedha checkout hota hai — koi guard verification nahi hogi kyunki staff khud process kar raha hai.',
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: _onSearch,
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty) {
                await _handleBarcodeScan(value.trim());
                _searchCtrl.clear();
              }
              _searchFocus.requestFocus();
            },
            style: TextStyle(color: text1Col),
            decoration: InputDecoration(
              hintText: "Type (e.g. 'inject') or open scanner...",
              hintStyle: TextStyle(color: text2Col),
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        PosScannerDialog(onScan: _handleBarcodeScan),
                  );
                },
              ),
              filled: true,
              fillColor: cardCol,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _searchCtrl.text.isEmpty
                ? Center(
                    child: Text(
                      "Start scanning or typing to add items.",
                      style: TextStyle(color: text2Col),
                    ),
                  )
                : _searchResults.isEmpty
                ? _buildCustomItemState(cardCol, text1Col)
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) => _buildCatalogTile(
                      _searchResults[i],
                      cardCol,
                      divCol,
                      text1Col,
                      text2Col,
                    ),
                  ),
          ),
        ],
      ),
    );

    // ── RIGHT PANEL WIDGET (🚀 FIX: Pura Scrollable Cart + Footer Ek Saath) ──
    Widget rightContent = ListView(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. HEADER
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Current Cart",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: text1Col,
                ),
              ),
              if (!cartState.isEmpty)
                TextButton(
                  onPressed: () async {
                    bool confirm =
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: cardCol,
                            title: Text(
                              "Clear Cart?",
                              style: TextStyle(color: text1Col),
                            ),
                            content: Text(
                              "Are you sure you want to remove all items?",
                              style: TextStyle(color: text2Col),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _redBrand,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Clear All"),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (confirm)
                      ref
                          .read(posCartProvider.notifier)
                          .clearCart(); // 🚀 FIX: Used ref directly to avoid scope issues
                  },
                  child: Text("Clear All", style: TextStyle(color: _redBrand)),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: divCol),

        // 2. CART ITEMS
        if (cartState.isEmpty)
          Container(
            height: 250,
            alignment: Alignment.center,
            child: Text("Cart is empty", style: TextStyle(color: text2Col)),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: buildCartGroups(cartState.items).map((group) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPosCartItemCard(
                    group,
                    ref.read(
                      posCartProvider.notifier,
                    ), // 🚀 FIX: Used ref to pass the notifier
                    isDark,
                    cardCol,
                    bgCol,
                    text1Col,
                    text2Col,
                    divCol,
                  ),
                );
              }).toList(),
            ),
          ),

        // 3. CHECKOUT FOOTER (Scrolls naturally at the end)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colors.scaffoldBg,
            border: Border(top: BorderSide(color: divCol)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: text1Col),
                decoration: InputDecoration(
                  labelText: "Customer Phone (Optional)",
                  labelStyle: TextStyle(color: text2Col),
                  prefixIcon: Icon(Icons.phone, size: 18, color: text2Col),
                  filled: true,
                  fillColor: cardCol,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Discount Applied",
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "- ₹${cartState.calcResult?.totalAppliedDiscount.toStringAsFixed(2) ?? '0.00'}",
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "GRAND TOTAL",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: text1Col,
                    ),
                  ),
                  Text(
                    "₹${cartState.calcResult?.newGrandTotal.toStringAsFixed(2) ?? '0.00'}",
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: isDark
                          ? Colors.blueAccent
                          : const Color(0xFF2B3674),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: ['CASH', 'UPI', 'CARD'].map((mode) {
                  bool isSel = _paymentMode == mode;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMode = mode),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF2B3674) : cardCol,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? Colors.transparent : divCol,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          mode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : text2Col,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _greenBrand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isBilling ? null : _generateInvoice,
                  icon: _isBilling
                      ? const SizedBox.shrink()
                      : const Icon(Icons.receipt_long),
                  label: _isBilling
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "CREATE BILL",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bgCol,
      body: Listener(
        onPointerDown: (_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && !_phoneFocus.hasFocus) {
              _searchFocus.requestFocus();
            }
          });
        },
        behavior: HitTestBehavior.translucent,
        child: isMobile
            ? Column(
                children: [
                  Expanded(flex: 1, child: leftContent),
                  Container(height: 2, color: divCol),
                  Expanded(
                    flex: 1,
                    child: Container(color: cardCol, child: rightContent),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftContent),
                  Container(
                    width: rightPanelWidth,
                    decoration: BoxDecoration(
                      color: cardCol,
                      border: Border(left: BorderSide(color: divCol)),
                    ),
                    child: rightContent,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPosCartItemCard(
    CartGroup group,
    PosCartNotifier cartNotifier,
    bool isDark,
    Color cardCol,
    Color bgCol,
    Color text1Col,
    Color text2Col,
    Color divCol,
  ) {
    final item = group.baseItem ?? group.overflowItem ?? group.freeItem!;
    int totalQty =
        (group.baseItem?.quantity ?? 0) +
        (group.overflowItem?.quantity ?? 0) +
        (group.freeItem?.quantity ?? 0);
    bool hasOffer =
        (group.baseItem?.clearanceActive ?? false) ||
        (group.freeItem?.quantity ?? 0) > 0;

    final Color greenBg = isDark
        ? const Color(0xFF16A34A).withValues(alpha: 0.15)
        : const Color(0xFFDCFCE7);
    final Color amberBg = isDark
        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
        : const Color(0xFFFEF3C7);
    final Color redBg = isDark
        ? const Color(0xFFE53E3E).withValues(alpha: 0.15)
        : const Color(0xFFFFEBEB);

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(10),
        border: hasOffer
            ? Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3))
            : Border.all(color: divCol),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: hasOffer ? greenBg : redBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: hasOffer
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFE53E3E),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: text1Col,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (hasOffer &&
                            group.baseItem != null &&
                            group.baseItem!.clearanceType != 'BOGO' &&
                            group.baseItem!.clearanceType != 'BUY_X_GET_Y')
                          Text(
                            "₹${item.originalPrice.toStringAsFixed(0)} ",
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: text2Col,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          hasOffer && group.baseItem != null
                              ? "₹${group.baseItem!.finalUnitPrice.toStringAsFixed(0)}/item"
                              : "₹${item.originalPrice.toStringAsFixed(0)}/item",
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: hasOffer
                                ? const Color(0xFF16A34A)
                                : text2Col,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (hasOffer &&
                        group.baseItem != null &&
                        group.baseItem!.flashExpiry > 0)
                      _buildCountdownTimer(group.baseItem!.flashExpiry),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBtn(
                      Icons.remove_rounded,
                      () => cartNotifier.decrement(group.baseKey),
                      bgCol,
                      divCol,
                      text1Col,
                      opacity: totalQty <= 1 ? 0.3 : 1.0,
                    ),
                    SizedBox(
                      width: 26,
                      child: Text(
                        "$totalQty",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: text1Col,
                        ),
                      ),
                    ),
                    _buildBtn(
                      Icons.add_rounded,
                      () async {
                        try {
                          final invItem = _inventory.firstWhere(
                            (i) => (i['barcode'] ?? '') == group.baseKey,
                            orElse: () => <String, dynamic>{},
                          );
                          if (invItem.isNotEmpty) {
                            bool isService =
                                (invItem['itemType'] ?? '')
                                    .toString()
                                    .toUpperCase() ==
                                'SERVICE';
                            int pStock = invItem['physicalStock'] ?? 0;
                            if (!isService && totalQty + 1 > pStock)
                              throw "Stock limit reached! Only $pStock available.";
                          }
                          await cartNotifier.increment(group.baseKey);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      bgCol,
                      divCol,
                      text1Col,
                      isAdd: true,
                    ),
                    const SizedBox(width: 10),

                    Text(
                      "₹${((group.baseItem?.totalPrice ?? 0) + (group.overflowItem?.totalPrice ?? 0)).toStringAsFixed(0)}",
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: text1Col,
                      ),
                    ),
                    const SizedBox(width: 6),

                    IconButton(
                      onPressed: () => cartNotifier.removeItem(group.baseKey),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: const Color(0xFFE53E3E),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (group.baseItem != null &&
              group.baseItem!.offerHint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: amberBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFF59E0B),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.baseItem!.offerHint,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (group.freeItem != null && group.freeItem!.quantity > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: greenBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFF16A34A),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Offer Applied",
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      "+${group.freeItem!.quantity} FREE",
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBtn(
    IconData icon,
    VoidCallback onTap,
    Color bgCol,
    Color divCol,
    Color text1Col, {
    bool isAdd = false,
    double opacity = 1.0,
  }) {
    return GestureDetector(
      onTap: opacity == 1.0 ? onTap : null,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isAdd
                ? const Color(0xFFE53E3E).withValues(alpha: 0.1)
                : bgCol,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAdd
                  ? const Color(0xFFE53E3E).withValues(alpha: 0.3)
                  : divCol,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isAdd ? const Color(0xFFE53E3E) : text1Col,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogTile(
    Map<String, dynamic> data,
    Color cardCol,
    Color divCol,
    Color text1Col,
    Color text2Col,
  ) {
    final double price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
    return Card(
      color: cardCol,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: divCol),
      ),
      child: ListTile(
        title: Text(
          data['name'] ?? 'Item',
          style: TextStyle(fontWeight: FontWeight.bold, color: text1Col),
        ),
        subtitle: Text(
          "₹$price",
          style: const TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.w900,
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _redBrand.withValues(alpha: 0.1),
            foregroundColor: _redBrand,
            elevation: 0,
          ),
          onPressed: () async {
            try {
              await ref.read(posCartProvider.notifier).addItem(data, 1);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text(
            "ADD",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomItemState(Color cardCol, Color text1Col) {
    return Center(
      child: SingleChildScrollView(
        // 🛡️ NAYA FIX: Keyboard/Mobile Screen Overflow Blocker
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "Product not available in the system.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: text1Col,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Kindly add this product to the inventory first.",
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.push('/idt-deposits');
              },
              icon: const Icon(Icons.add_box_outlined),
              label: const Text(
                "Go to IDT Deposit",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownTimer(int expiryMs) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)).asBroadcastStream(),
      builder: (context, snapshot) {
        final diff = expiryMs - DateTime.now().millisecondsSinceEpoch;
        if (diff <= 0) return const SizedBox.shrink();
        int h = (diff ~/ 3600000);
        int m = ((diff ~/ 60000) % 60);
        int s = ((diff ~/ 1000) % 60);
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text(
                "Ends in ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
