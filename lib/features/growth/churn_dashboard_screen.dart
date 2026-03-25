import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'providers/churn_engine_service.dart';

class ChurnDashboardScreen extends ConsumerWidget {
  const ChurnDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churnState = ref.watch(churnEngineProvider);
    const Color themeNavy = Color(0xFF2B3674);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          "Growth & Retention Radar 🎯",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: themeNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(churnEngineProvider),
            tooltip: "Rescan Database",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "VIP Customers At Risk (Churn Detection)",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeNavy,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Smart AI checks average visit cycles to identify high-value users who might be abandoning your store.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: churnState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: themeNavy),
                ),
                error: (err, stack) => Center(
                  child: Text(
                    "🚨 Error: $err",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (atRiskList) {
                  if (atRiskList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield,
                            size: 80,
                            color: Colors.green.withOpacity(0.5),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Your Revenue is Safe! 🟢",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "No VIPs are currently at risk of churning.",
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: atRiskList.length,
                    itemBuilder: (context, index) {
                      final customer = atRiskList[index];
                      final bool isHighRisk = customer.riskLevel == 'HIGH';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: isHighRisk
                                ? Colors.redAccent.withOpacity(0.3)
                                : Colors.orangeAccent.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // PROFILE ICON
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isHighRisk
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_off,
                                  color: isHighRisk
                                      ? Colors.red
                                      : Colors.orange,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 20),

                              // DETAILS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isHighRisk
                                                ? Colors.red
                                                : Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: Text(
                                            "${customer.riskLevel} RISK",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "📞 ${customer.phone}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "LTV: ₹${customer.totalSpent.toStringAsFixed(0)}  |  Total Visits: ${customer.totalVisits}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "Last Visit: ${DateFormat('dd MMM yyyy').format(customer.lastVisit)}",
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ACTION BUTTON
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _showWinbackDialog(
                                      context,
                                      ref,
                                      customer,
                                    ),
                                    icon: const Icon(
                                      Icons.mark_email_read,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "SEND 20% OFF",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    "via WhatsApp/SMS",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWinbackDialog(
    BuildContext context,
    WidgetRef ref,
    VIPCustomer customer,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Trigger Win-Back Campaign 🎁"),
        content: Text(
          "Send a 'COMEBACK20' flat 20% discount coupon to ${customer.name} (${customer.phone})? This will lock them from receiving further spam.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(churnEngineProvider.notifier)
                    .sendWinbackCoupon(customer.id, customer.name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Win-back Coupon Sent Successfully!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Yes, Send Coupon",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
