import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// 🚀 SAAS INJECTIONS
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

class RiskEngineScreen extends ConsumerWidget {
  const RiskEngineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 SAAS CONTEXT
    final adminData = ref.watch(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String role = (adminData?['role'] ?? '').toString().toLowerCase();

    Query riskQuery = FirebaseFirestore.instance.collection('orders');
    if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
      riskQuery = riskQuery.where('tenantId', isEqualTo: tenantId);
    }
    riskQuery = riskQuery.orderBy('timestamp', descending: true).limit(100);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔴 HEADER
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Risk Engine 🚨",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Live Fraud Detection & Guard Rejections",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // 👁️ SURVEILLANCE ENGINE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: riskQuery.snapshots(), // 🚀 SAAS ISOLATED STREAM
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No data found.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final allOrders = snapshot.data!.docs;

                // 🧠 THE AI FILTER
                final rejectedLogs = allOrders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final exitStatus = (data['exitStatus'] ?? '')
                      .toString()
                      .toUpperCase();
                  return exitStatus == 'REJECTED';
                }).toList();

                if (rejectedLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.green,
                          size: 80,
                        ),
                        SizedBox(height: 20),
                        Text(
                          "SYSTEM SECURE",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          "No fraud or rejections detected today.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildRiskCard(
                            "Total Rejections",
                            "${rejectedLogs.length}",
                            Icons.do_not_disturb_alt,
                            Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildRiskCard(
                            "System Status",
                            "HIGH ALERT",
                            Icons.gpp_bad,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Rejection Logs",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                              columns: const [
                                DataColumn(label: Text("INCIDENT TIME")),
                                DataColumn(label: Text("ORDER ID")),
                                DataColumn(label: Text("AMOUNT")),
                                DataColumn(label: Text("PAYMENT MODE")),
                                DataColumn(label: Text("SEVERITY")),
                              ],
                              rows: rejectedLogs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                DateTime date =
                                    (data['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now();

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        DateFormat(
                                          'dd MMM, hh:mm a',
                                        ).format(date),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        doc.id,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "₹${data['totalAmount'] ?? '0'}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        (data['paymentMode'] ?? 'UNKNOWN')
                                            .toString()
                                            .toUpperCase(),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: const Text(
                                          "CRITICAL",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
