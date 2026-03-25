import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/fraud_provider.dart';
import 'leakage_kanban_widget.dart';

class FraudControlScreen extends ConsumerWidget {
  const FraudControlScreen({super.key});

  void _toggleSuspension(
    BuildContext context,
    String staffId,
    String currentStatus,
    String displayName,
  ) {
    final isSuspended = currentStatus == 'SUSPENDED';
    final newStatus = isSuspended ? 'ACTIVE' : 'SUSPENDED';

    FirebaseFirestore.instance.collection('employees').doc(staffId).set({
      'status': newStatus,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuspended ? Icons.check_circle : Icons.block,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              isSuspended
                  ? "$displayName's access RESTORED!"
                  : "🚨 $displayName SUSPENDED!",
            ),
          ],
        ),
        backgroundColor: isSuspended
            ? Colors.green.shade700
            : Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suspectsState = ref.watch(suspectStaffProvider);
    final highRiskOrdersState = ref.watch(highRiskOrdersProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security,
                  color: Colors.redAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Fraud Control & Radar",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B3674),
                    ),
                  ),
                  Text(
                    "Live employee monitoring & leakage tracking",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text(
            "Live Leakage Radar",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B3674),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 400, child: LeakageKanbanBoard()),
          const SizedBox(height: 32),

          const Text(
            "Suspect Watchlist (Low Trust Score)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B3674),
            ),
          ),
          const SizedBox(height: 16),
          suspectsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                Text("Error: $err", style: const TextStyle(color: Colors.red)),
            data: (suspects) {
              if (suspects.isEmpty) {
                return _buildSafeZone(
                  "No high-risk staff detected. Team is clean.",
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.8,
                ),
                itemCount: suspects.length,
                itemBuilder: (context, index) {
                  final doc = suspects[index];
                  final data = doc.data() as Map<String, dynamic>;

                  int trustScore =
                      int.tryParse(data['trustScore']?.toString() ?? '100') ??
                      100;
                  String name = data['name']?.toString() ?? '';
                  String phone =
                      data['phone']?.toString() ??
                      data['mobile']?.toString() ??
                      data['phoneNo']?.toString() ??
                      '';
                  String email = data['email']?.toString() ?? '';

                  String displayTitle =
                      "Guard ID: ${doc.id.substring(0, 6).toUpperCase()}";
                  if (phone.isNotEmpty) displayTitle = phone;
                  if (email.isNotEmpty) displayTitle = email.split('@')[0];
                  if (name.isNotEmpty) displayTitle = name;

                  String currentStatus =
                      data['status']?.toString().toUpperCase() ?? 'ACTIVE';
                  bool isSuspended = currentStatus == 'SUSPENDED';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSuspended ? Colors.grey.shade100 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSuspended
                            ? Colors.grey.shade400
                            : Colors.red.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isSuspended
                                      ? Colors.grey
                                      : Colors.black87,
                                  decoration: isSuspended
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSuspended
                                    ? Colors.grey.shade300
                                    : Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                trustScore.toString(),
                                style: TextStyle(
                                  color: isSuspended
                                      ? Colors.grey.shade700
                                      : Colors.red,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Doc ID: ${doc.id.substring(0, 8)}...",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (isSuspended)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Status: SUSPENDED",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(
                              isSuspended ? Icons.restore : Icons.block,
                              size: 16,
                              color: isSuspended ? Colors.green : Colors.red,
                            ),
                            label: Text(
                              isSuspended ? "Restore Access" : "Suspend Access",
                              style: TextStyle(
                                color: isSuspended ? Colors.green : Colors.red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isSuspended
                                    ? Colors.green.shade300
                                    : Colors.red.shade200,
                              ),
                              backgroundColor: isSuspended
                                  ? Colors.green.shade50
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _toggleSuspension(
                              context,
                              doc.id,
                              currentStatus,
                              displayTitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),

          const Text(
            "High Risk Transactions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B3674),
            ),
          ),
          const SizedBox(height: 16),
          highRiskOrdersState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                Text("Error: $err", style: const TextStyle(color: Colors.red)),
            data: (orders) {
              if (orders.isEmpty) {
                return _buildSafeZone(
                  "No high-risk transactions detected recently.",
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    title: Text(
                      "Order: ${doc.id.substring(0, 8).toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Status: ${data['exitStatus'] ?? 'UNKNOWN'}",
                    ),
                    trailing: Text(
                      "₹${data['totalAmount'] ?? '0'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSafeZone(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            msg,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
