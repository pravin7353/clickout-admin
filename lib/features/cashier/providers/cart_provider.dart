import 'package:flutter_riverpod/flutter_riverpod.dart';

// 📦 Item Model
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });
}

// 🧠 Modern Cart Logic (Using Latest 'Notifier')
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return []; // Initial State: Empty Cart
  }

  void addItem(String id, String name, double price) {
    final existingIndex = state.indexWhere((item) => item.id == id);

    if (existingIndex >= 0) {
      // Agar item pehle se hai, toh sirf quantity badhao
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            CartItem(
              id: state[i].id,
              name: state[i].name,
              price: state[i].price,
              quantity: state[i].quantity + 1,
            )
          else
            state[i],
      ];
    } else {
      // Naya item add karo
      state = [...state, CartItem(id: id, name: name, price: price)];
    }
  }

  void clearCart() {
    state = [];
  }

  // 💰 Total Bill Calculator
  double get totalAmount =>
      state.fold(0, (sum, item) => sum + (item.price * item.quantity));
}

// 🚀 Modern NotifierProvider
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});
