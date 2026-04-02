import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QuantumMetricsWidget extends StatelessWidget {
  final String storeId;

  const QuantumMetricsWidget({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    const Color cardDark = Color(0xFF111811);
    const Color accentOrange = Color(0xFFD4580A);
    const Color textPrimary = Color(0xFFF0F0F0);
    const Color textSecondary = Color(0xFF888888);

    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return StreamBuilder<DocumentSnapshot>(
      // 🚀 FIX 1: Firestore Cache Engine ON. Data ab instantly load hoga bina net wait kiye.
      stream: FirebaseFirestore.instance
          .collection('store_metrics')
          .doc(storeId)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        // 🚀 FIX 2: Agar purana data already hai, toh loading spinner MAT dikhao!
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState(cardDark, accentOrange);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildNoDataState(cardDark, textSecondary);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        // 🧠 Safe Number Parsing
        final double inventoryVal = (data['totalInventoryValue'] ?? 0)
            .toDouble();
        final double costVal = (data['totalCostValue'] ?? 0).toDouble();
        final double revenueVal = (data['projectedRevenue'] ?? 0).toDouble();
        final double discountBurn = (data['discountBurn'] ?? 0).toDouble();

        // 🚀 FIX 3: "Syncing..." wala text hamesha ke liye HATA diya. Jo number hai wahi dikhega.
        final double margin = revenueVal > 0
            ? ((revenueVal - costVal) / revenueVal) * 100
            : 0.0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: textSecondary.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎩 HEADER SECTION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: textSecondary.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          color: accentOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Promotion Analytics",
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(discountBurn),
                  ],
                ),
              ),

              // 📊 METRICS SECTION
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildMetricTile(
                        "Total Inventory Value",
                        currencyFormat.format(
                          inventoryVal,
                        ), // 🚀 Real number aayega
                        Icons.inventory_2_outlined,
                        Colors.blue,
                        "Base retail value before offers",
                      ),
                    ),
                    Container(
                      height: 50,
                      width: 1,
                      color: textSecondary.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildMetricTile(
                        "Promotion Impact",
                        currencyFormat.format(discountBurn),
                        Icons.local_offer_outlined,
                        discountBurn > 0 ? Colors.redAccent : Colors.green,
                        "Total discount given to customers",
                      ),
                    ),
                    Container(
                      height: 50,
                      width: 1,
                      color: textSecondary.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildMetricTile(
                        "Proj. Margin",
                        "${margin.toStringAsFixed(1)}%", // 🚀 Real number aayega
                        Icons.show_chart_rounded,
                        margin > 15 ? Colors.green : Colors.orange,
                        "Estimated profit margin",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.8)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF0F0F0),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: const Color(0xFF888888).withOpacity(0.6),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(double burn) {
    String text = "OPTIMAL PROMOTIONS";
    Color bgColor = Colors.green.withOpacity(0.1);
    Color textColor = Colors.green;

    if (burn > 5000) {
      text = "HIGH DISCOUNT BURN";
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color bg, Color accent) {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Center(child: CircularProgressIndicator(color: accent)),
    );
  }

  Widget _buildNoDataState(Color bg, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textSecondary.withOpacity(0.2), width: 1),
      ),
      child: const Center(
        child: Text(
          "Promotion Engine is waiting for its first offer...",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
