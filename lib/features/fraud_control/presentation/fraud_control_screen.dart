import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';

import '../providers/fraud_provider.dart';
import 'leakage_kanban_widget.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';
import 'package:clickout_admin/core/theme/app_theme.dart';

class FraudControlScreen extends ConsumerWidget {
  const FraudControlScreen({super.key});

  void _toggleSuspension(
    BuildContext context,
    WidgetRef ref,
    String staffId,
    String currentStatus,
    String displayName,
  ) {
    final isSuspended = currentStatus == 'SUSPENDED';
    final newStatus = isSuspended ? 'ACTIVE' : 'SUSPENDED';

    FirebaseFirestore.instance.collection('employees').doc(staffId).set({
      'status': newStatus,
    }, SetOptions(merge: true));

    // 🚀 THE BLACK BOX (Audit Trail)
    final adminData = ref.read(adminRoleProvider).value;
    FirebaseFirestore.instance.collection('audit_logs').add({
      'actionType': isSuspended ? 'RESTORE_STAFF' : 'SUSPEND_STAFF',
      'targetCollection': 'employees',
      'targetId': staffId,
      'details': isSuspended
          ? 'Restored access for $displayName'
          : 'Suspended access for $displayName due to fraud suspicion.',
      'severity': isSuspended ? 'INFO' : 'CRITICAL',
      'actorEmail': adminData?['email'] ?? 'System Manager',
      'tenantId': adminData?['tenantId'] ?? 'UNKNOWN',
      'branchCode': adminData?['branchCode'] ?? 'UNKNOWN',
      'timestamp': FieldValue.serverTimestamp(),
    });

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

    // 🎨 THEME INJECTION
    final textColor = context.colors.textPrimary;

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
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security,
                  color: Colors.redAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              // 🚀 FIX: Wrap Column in Expanded so text doesn't push out of the screen
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Fraud Control & Radar",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const InfoButton(
                          title: 'Fraud Control & Radar',
                          en: 'Central command for store fraud detection. Shows paid-but-not-exited orders (leakage), staff with low trust scores, and high-risk transactions. Suspend suspicious guards instantly — every action is logged in the Audit Trail.',
                          hi: 'Store fraud ka central dashboard. Yahan dikhta hai — kaunsa order paid hua par exit nahi hua (leakage), kaunse staff ka trust score low hai, aur kaunse transactions risky hain. Suspicious guard ko turant suspend karo — har action audit trail mein save hota hai.',
                        ),
                      ],
                    ),
                    const Text(
                      "Live employee monitoring & leakage tracking",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Text(
                "Live Leakage Radar",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: 'Live Leakage Radar',
                en: 'Tracks orders that are PAID but customer has NOT exited yet. Sorted by wait time: Normal (0–5m), Warning (5–30m), Critical (30–120m), Escalated (2hr+). Long wait = possible leakage or guard negligence.',
                hi: 'Yeh un orders ko track karta hai jo PAID hain par customer abhi tak bahar nahi gaya. Wait time ke hisaab se: Normal, Warning, Critical, Escalated. Zyada wait time = leakage ya guard ki laparwahi ka signal.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 400, child: LeakageKanbanBoard()),
          const SizedBox(height: 32),

          Row(
            children: [
              Text(
                "Suspect Watchlist (Low Trust Score)",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: 'Suspect Watchlist',
                en: 'Lists staff members whose trust score has dropped below the safe threshold. Trust score decreases with overrides, rejected scans, or suspicious activity. Tap "Suspend Access" to block their login immediately.',
                hi: 'Woh staff members jinka trust score safe level se neeche gir gaya hai. Override karne se, failed scans se, ya suspicious activity se score ghatta hai. "Suspend Access" dabao toh unka login turant band ho jaata hai.',
              ),
            ],
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // 🚀 RESPONSIVE FIX: Mobile/Split-screen pe 1 column, Desktop pe 3
                  crossAxisCount: MediaQuery.of(context).size.width < 900
                      ? 1
                      : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: MediaQuery.of(context).size.width < 900
                      ? 3.0
                      : 1.8,
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

                  final cardBg = context.colors.cardBg;
                  final suspendedBg = context.colors.scaffoldBg;
                  final primaryText = context.colors.textPrimary;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSuspended ? suspendedBg : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSuspended
                            ? Colors.grey.shade600
                            : Colors.red.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
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
                                      : primaryText,
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
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.1),
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
                              ref,
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

          Row(
            children: [
              Text(
                "High Risk Transactions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              const InfoButton(
                title: 'High Risk Transactions',
                en: 'Orders flagged by the system as suspicious — unusual amounts, repeated failures, or mismatched exit status. These require manual review by the admin.',
                hi: 'System ne inhe suspicious mark kiya hai — unusual amount, baar baar fail hona, ya exit status mismatch. In orders ko admin ko manually review karna chahiye.',
              ),
            ],
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
                separatorBuilder: (context, index) =>
                    Divider(color: context.colors.border),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      "Status: ${data['exitStatus'] ?? 'UNKNOWN'}",
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    trailing: Text(
                      "₹${data['totalAmount'] ?? '0'}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
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
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green),
          const SizedBox(width: 12),
          // 🚀 FIX: Wrap Text in Expanded to prevent RenderFlex crash on small screens
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
