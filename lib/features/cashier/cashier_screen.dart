import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 Naya Import
import 'providers/cart_provider.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  String _paymentMode = 'CASH';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _products = [
    {
      'id': 'P001',
      'name': 'Maggie Noodles 2-Min',
      'price': 14.0,
      'icon': Icons.fastfood,
    },
    {
      'id': 'P002',
      'name': 'Coca Cola 500ml',
      'price': 40.0,
      'icon': Icons.local_drink,
    },
    {
      'id': 'P003',
      'name': 'Lays Magic Masala',
      'price': 20.0,
      'icon': Icons.shopping_bag,
    },
    {
      'id': 'P004',
      'name': 'Dairy Milk Silk',
      'price': 80.0,
      'icon': Icons.cake,
    },
  ];

  Future<void> _generateGatePass() async {
    final cart = ref.read(cartProvider);
    final total = ref.read(cartProvider.notifier).totalAmount;
    final currentUser =
        FirebaseAuth.instance.currentUser; // 👈 Fixed Cashier Info

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cart is empty!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'cashierId': currentUser?.uid ?? 'UNKNOWN',
        'cashierName': currentUser?.email ?? 'Cashier',
        'branchCode': 'MAIN_BRANCH',
        'items': cart
            .map(
              (e) => {
                'id': e.id,
                'name': e.name,
                'price': e.price,
                'qty': e.quantity,
              },
            )
            .toList(),
        'totalAmount': total,
        'paymentMode': _paymentMode,
        'paymentStatus': 'PAID',
        'exitStatus': 'PENDING',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Order Generated! Gate-Pass Ready."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartProvider.notifier).totalAmount;
    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget productsSection = Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Billing 🛒",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B3674),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final p = _products[index];
                  return InkWell(
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .addItem(p['id'], p['name'], p['price']),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(p['icon'], size: 40, color: Colors.blueAccent),
                          const SizedBox(height: 10),
                          Text(
                            p['name'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "₹${p['price']}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    Widget cartSection = Container(
      width: isMobile ? double.infinity : 350,
      height: isMobile ? 400 : double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Current Order",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Text(
                      "Cart is empty",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text("₹${item.price} x ${item.quantity}"),
                        trailing: Text(
                          "₹${item.price * item.quantity}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "₹$total",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: const InputDecoration(
              labelText: "Payment Mode",
              border: OutlineInputBorder(),
            ),
            items: [
              'CASH',
              'UPI',
              'CARD',
            ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (val) => setState(() => _paymentMode = val!),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _generateGatePass,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "GENERATE GATE-PASS",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: isMobile
          ? Column(children: [productsSection, cartSection])
          : Row(children: [productsSection, cartSection]),
    );
  }
}
