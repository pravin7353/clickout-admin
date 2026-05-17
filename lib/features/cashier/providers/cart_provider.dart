import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🚀 ABSOLUTE IMPORTS: Folder depth ka koi tension nahi
import 'package:clickout_admin/core/services/cart_item.dart';
import 'package:clickout_admin/core/services/offer_engine_service.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

// ── MODERN STATE CLASS ──
class PosCartState {
  final Map<String, CartItem> rawItems;
  final OfferCalculationResult? calcResult;

  PosCartState({this.rawItems = const {}, this.calcResult});

  Map<String, CartItem> get items => calcResult?.updatedCartItems ?? {};
  bool get isEmpty => rawItems.isEmpty;
}

// 🚀 THE NEW PERSISTENT POS CART ENGINE (Riverpod 2.x Standard)
class PosCartNotifier extends Notifier<PosCartState> {
  List<Map<String, dynamic>> _activeOffers = [];

  @override
  PosCartState build() {
    _initCart(); // Fire and forget
    return PosCartState(); // Initial empty state
  }

  // 💾 1. PERSISTENCE
  Future<void> _initCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localJson = prefs.getString('pos_cart_data');
    Map<String, CartItem> loadedItems = {};

    if (localJson != null) {
      try {
        List<dynamic> decoded = jsonDecode(localJson);
        for (var item in decoded) {
          CartItem ci = CartItem.fromJson(item);
          loadedItems[ci.barcode] = ci;
        }
      } catch (_) {}
    }

    state = PosCartState(rawItems: loadedItems, calcResult: state.calcResult);
    await _fetchOffers();
  }

  Future<void> _saveCart(Map<String, CartItem> currentItems) async {
    final prefs = await SharedPreferences.getInstance();
    final adminData = await ref.read(adminRoleProvider.future);
    final String tId = adminData?['tenantId'] ?? '';
    final String bCode = adminData?['branchCode'] ?? '';

    if (currentItems.isEmpty) {
      await prefs.remove('pos_cart_data');
      if (tId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('carts')
            .doc('${tId}_${bCode}_POS')
            .delete(); // 🚀 FIX: Sync to Firebase!
      }
    } else {
      List<Map<String, dynamic>> saveable = currentItems.values
          .map((i) => i.toJson())
          .toList();
      await prefs.setString('pos_cart_data', jsonEncode(saveable));
      if (tId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('carts')
            .doc('${tId}_${bCode}_POS')
            .set({
              'items': saveable,
              'tenantId': tId,
              'branchCode': bCode,
              'lastUpdated': FieldValue.serverTimestamp(),
            }); // 🚀 FIX: Auto-Sync Cart to Database!
      }
    }
  }

  // 🎁 2. OFFER ENGINE SYNC
  Future<void> _fetchOffers() async {
    // 🚀 FIX: 'await .future' ensures tenantId is ready before fetching offers!
    final adminData = await ref.read(adminRoleProvider.future);
    final tenantId = adminData?['tenantId'] ?? '';
    if (tenantId.isEmpty) return;

    final snap = await FirebaseFirestore.instance
        .collection('products')
        .where('tenantId', isEqualTo: tenantId)
        .where('clearanceActive', isEqualTo: true)
        .get();

    _activeOffers = snap.docs.map((d) => d.data()).toList();
    _applyOffers(state.rawItems);
  }

  void _applyOffers(Map<String, CartItem> items) {
    if (items.isEmpty) {
      state = PosCartState(rawItems: {}, calcResult: null);
      _saveCart({});
      return;
    }

    // 🚀 BOGO FIX: Populate liveStockLogs correctly!
    Map<String, int> stock = {};
    for (var o in _activeOffers) {
      String bc =
          o['barcode']?.toString().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '') ??
          '';
      if (bc.isNotEmpty) stock[bc] = o['physicalStock'] ?? o['stock'] ?? 999;
    }

    final result = OfferEngineService.applyAllOffers(
      cartItems: items,
      activeOffers: _activeOffers,
      liveStockLogs: stock, // 🚀 BOGO ENGINE RESTORED
    );

    state = PosCartState(rawItems: items, calcResult: result);
    _saveCart(items);
  }

  // 🛡️ 3. VALIDATED ACTIONS (Stock limits & Blocks)
  Future<void> addItem(Map<String, dynamic> pData, int qty) async {
    String barcode = pData['barcode'] ?? pData['id'] ?? '';
    bool isService =
        (pData['itemType'] ?? '').toString().toUpperCase() == 'SERVICE';
    int physicalStock = pData['physicalStock'] ?? 0;

    final currentItems = Map<String, CartItem>.from(state.rawItems);
    int currentQty = currentItems[barcode]?.quantity ?? 0;
    int newQty = currentQty + qty;

    // 🛑 OUT OF STOCK BLOCKER
    if (!isService && newQty > physicalStock) {
      throw "Out of stock! Only $physicalStock available.";
    }

    double price = double.tryParse(pData['price']?.toString() ?? '0') ?? 0.0;
    double gst =
        double.tryParse(
          pData['gstRate']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
              '0',
        ) ??
        0.0;

    // 🚀 FIX: Database se actual weight fetch kar raha hai
    double itemWeight =
        double.tryParse(
          pData['weight']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0',
        ) ??
        0.0;

    currentItems[barcode] = CartItem(
      barcode: barcode,
      name: pData['name'] ?? 'Item',
      originalPrice: price,
      gst: gst,
      weight: itemWeight, // 🚀 FIX: Hardcoded 0 removed
      quantity: newQty,
    );

    _applyOffers(currentItems);
  }

  Future<void> increment(String barcode) async {
    final base = barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
    final currentItems = Map<String, CartItem>.from(state.rawItems);
    final existing = currentItems[base];
    if (existing == null) return;

    // 🚀 0-LAG FIX: Database check yahan se hata diya hai. Ab UI me instant RAM check hoga!
    currentItems[base] = existing.copyWith(quantity: existing.quantity + 1);
    _applyOffers(currentItems);
  }

  void decrement(String barcode) {
    final base = barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
    final currentItems = Map<String, CartItem>.from(state.rawItems);
    final existing = currentItems[base];

    // 🛑 BLOCK DECREMENT BELOW 1
    if (existing != null && existing.quantity > 1) {
      currentItems[base] = existing.copyWith(quantity: existing.quantity - 1);
      _applyOffers(currentItems);
    }
  }

  void removeItem(String barcode) {
    final base = barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
    final currentItems = Map<String, CartItem>.from(state.rawItems);
    currentItems.remove(base);
    _applyOffers(currentItems);
  }

  void clearCart() {
    state = PosCartState(rawItems: {}, calcResult: null);
    _saveCart({});
  }
}

// 🚀 MODERN RIVERPOD PROVIDER
final posCartProvider = NotifierProvider<PosCartNotifier, PosCartState>(
  () => PosCartNotifier(),
);
