import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 SAAS INJECTION IMPORT
import 'package:clickout_admin/features/auth/auth_provider.dart';

class AuditVaultScreen extends ConsumerWidget {
  const AuditVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 SAAS INJECTION: Get admin context
    final adminData = ref.watch(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String role = (adminData?['role'] ?? '').toString().toLowerCase();

    Query auditQuery = FirebaseFirestore.instance.collection('audit_logs');

    // 🚀 SAAS ISOLATION: Filter logs by company
    if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
      auditQuery = auditQuery.where('tenantId', isEqualTo: tenantId);
    }
    auditQuery = auditQuery.orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // ⬛ 100% PITCH BLACK THEME
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        // 🚪 THE 100% WORKING ESCAPE DOOR
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Fallback for Web if stack gets lost
              Navigator.of(context).pushReplacementNamed('/auditor');
            }
          },
        ),
        title: const Text(
          "BACK TO COMMAND CENTER",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Audit Vault",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Immutable System Activity Logs",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: auditQuery.snapshots(), // 🚀 SAAS INJECTION FIX
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "No audit logs found.",
                            style: TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(color: Colors.white10, height: 1),
                        ),
                        itemBuilder: (context, index) {
                          final data =
                              snapshot.data!.docs[index].data()
                                  as Map<String, dynamic>;
                          final Timestamp? ts = data['timestamp'] as Timestamp?;
                          final String timeString = ts != null
                              ? DateFormat(
                                  'dd MMM yyyy, HH:mm:ss',
                                ).format(ts.toDate())
                              : 'Unknown Time';

                          final String actionType =
                              data['actionType'] ?? 'UNKNOWN';
                          final String actorEmail =
                              data['actorEmail'] ?? 'SYSTEM';
                          final String targetCol =
                              data['targetCollection'] ?? '';
                          final String targetId = data['targetId'] ?? '';
                          final String details = data['details'] ?? '';
                          final String severity = data['severity'] ?? 'INFO';

                          Color severityColor = Colors.blueAccent;
                          if (severity == 'WARNING') {
                            severityColor = Colors.orange;
                          }
                          if (severity == 'CRITICAL') {
                            severityColor = Colors.redAccent;
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: severityColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: severityColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          timeString,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        Text(
                                          severity,
                                          style: TextStyle(
                                            color: severityColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.02,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: severityColor
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  actionType,
                                                  style: TextStyle(
                                                    color: severityColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "$targetCol / $targetId",
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            details,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "Actor: $actorEmail",
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
