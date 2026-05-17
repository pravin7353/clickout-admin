import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QuantumMetricsWidget extends StatelessWidget {
  final String storeId;

  const QuantumMetricsWidget({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    // 🎨 DYNAMIC PREMIUM THEME (Sunset Orange)
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color cardDark = isDark
        ? const Color(0xFF111811)
        : const Color(0xFFFFFFFF);
    final Color accentOrange = const Color(0xFFFF6D00); // 🚀 Sunset Amber
    final Color textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color textSecondary =
        theme.textTheme.labelLarge?.color ?? Colors.grey;

    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return StreamBuilder<DocumentSnapshot>(
      // 🚀 Firestore Cache Engine ON
      stream: FirebaseFirestore.instance
          .collection('store_metrics')
          .doc(storeId)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState(cardDark, accentOrange, textSecondary);
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

        final double margin = revenueVal > 0
            ? ((revenueVal - costVal) / revenueVal) * 100
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎩 HEADER SECTION
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: accentOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
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

            // 📊 METRICS SECTION (INDIVIDUAL CARDS)
            LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 600;

                if (isMobile) {
                  return Column(
                    children: [
                      _buildIsolatedCard(
                        "Total Inventory Value",
                        currencyFormat.format(inventoryVal),
                        Icons.inventory_2_outlined,
                        Colors.blue,
                        "Base retail value before offers",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildIsolatedCard(
                        "Promotion Impact",
                        currencyFormat.format(discountBurn),
                        Icons.local_offer_outlined,
                        discountBurn > 0 ? Colors.redAccent : Colors.green,
                        "Total discount given to customers",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildIsolatedCard(
                        "Proj. Margin",
                        "${margin.toStringAsFixed(1)}%",
                        Icons.show_chart_rounded,
                        margin > 15 ? Colors.green : Colors.orange,
                        "Estimated profit margin",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildIsolatedCard(
                        "Total Inventory Value",
                        currencyFormat.format(inventoryVal),
                        Icons.inventory_2_outlined,
                        Colors.blue,
                        "Base retail value before offers",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildIsolatedCard(
                        "Promotion Impact",
                        currencyFormat.format(discountBurn),
                        Icons.local_offer_outlined,
                        discountBurn > 0 ? Colors.redAccent : Colors.green,
                        "Total discount given to customers",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildIsolatedCard(
                        "Proj. Margin",
                        "${margin.toStringAsFixed(1)}%",
                        Icons.show_chart_rounded,
                        margin > 15 ? Colors.green : Colors.orange,
                        "Estimated profit margin",
                        cardDark,
                        textSecondary,
                        textPrimary,
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildIsolatedCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
    Color cardDark,
    Color textSecondary,
    Color textPrimary,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textSecondary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.6),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
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

  Widget _buildLoadingState(Color bg, Color accent, Color textSecondary) {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textSecondary.withOpacity(0.1)),
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
      child: Center(
        child: Text(
          "Promotion Engine is waiting for its first offer...",
          style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
