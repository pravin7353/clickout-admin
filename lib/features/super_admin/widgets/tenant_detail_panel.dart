import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/tenant_provider.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ⚡ NEW: Cloud Functions

class TenantDetailPanel extends StatelessWidget {
  final TenantModel tenant;
  const TenantDetailPanel({super.key, required this.tenant});

  // ⚡ ACTION: Suspend or Reactivate (Server Side & Secure)
  Future<void> _toggleTenantStatus(BuildContext context, bool suspend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          suspend ? 'Suspend Tenant?' : 'Reactivate Tenant?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          suspend
              ? 'This will immediately lock access for all staff of ${tenant.companyName}.'
              : 'This will restore access for ${tenant.companyName}.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: suspend
                  ? const Color(0xFFE53E3E)
                  : const Color(0xFF00C853),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              suspend ? 'SUSPEND' : 'REACTIVATE',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'toggleTenantStatus',
      );
      await callable.call({
        'tenantId': tenant.id,
        'companyName': tenant.companyName,
        'suspend': suspend,
      });
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error updating tenant: $e");
    }
  }

  // ⚡ ACTION: Change Plan (Server Side & Secure)
  Future<void> _changePlan(BuildContext context) async {
    String selected = tenant.subscriptionPlan;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111111),
            title: const Text(
              'Change Subscription Plan',
              style: TextStyle(color: Colors.white),
            ),
            content: DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1A1A1A),
              value: selected,
              style: const TextStyle(color: Colors.white),
              items: ['BASIC', 'PRO', 'ENTERPRISE'].map((p) {
                return DropdownMenuItem(value: p, child: Text(p));
              }).toList(),
              onChanged: (v) => setState(() => selected = v!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'UPDATE PLAN',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true && selected != tenant.subscriptionPlan) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'changeTenantPlan',
        );
        await callable.call({
          'tenantId': tenant.id,
          'companyName': tenant.companyName,
          'oldPlan': tenant.subscriptionPlan,
          'newPlan': selected,
        });
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint("Error changing plan: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450, // Fixed width for right-side drawer
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(left: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Column(
        children: [
          // 1. HEADER SECTION
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF111111),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tenant.companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      tenant.id,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tenant.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tenant ID copied!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Badge(text: tenant.plan, color: Colors.blue),
                    const SizedBox(width: 8),
                    _Badge(
                      text: tenant.billingStatus,
                      color: tenant.billingStatus == 'ACTIVE'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // ACTIONS
                Row(
                  children: [
                    if (tenant.isActive)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A1A),
                            side: const BorderSide(color: Color(0xFFE53E3E)),
                          ),
                          onPressed: () => _toggleTenantStatus(context, true),
                          child: const Text(
                            'Suspend',
                            style: TextStyle(color: Color(0xFFE53E3E)),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                          ),
                          onPressed: () => _toggleTenantStatus(context, false),
                          child: const Text(
                            'Reactivate',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        onPressed: () => _changePlan(context),
                        child: const Text(
                          'Change Plan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STAFF COUNT (Aggregation)
                  const Text(
                    'TEAM',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<AggregateQuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('staff')
                        .where('tenantId', isEqualTo: tenant.id)
                        .count()
                        .get(),
                    builder: (context, snapshot) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Registered Staff',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              snapshot.hasData
                                  ? '${snapshot.data!.count}'
                                  : '...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // STORES
                  const Text(
                    'STORES NETWORK',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('stores')
                        .where('tenantId', isEqualTo: tenant.id)
                        // 🚀 COST FIX: safety cap.
                        .limit(200)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty)
                        return const Text(
                          'No stores found.',
                          style: TextStyle(color: Colors.grey),
                        );

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isActive = data['isActive'] ?? false;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0x1AFFFFFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store,
                                  color: isActive ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? 'Unknown Store',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        data['branchCode'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // RECENT ACTIVITY
                  const Text(
                    'RECENT AUDIT LOGS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('admin_audit_logs')
                        .where('tenantId', isEqualTo: tenant.id)
                        .orderBy('timestamp', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty)
                        return const Text(
                          'No activity logs.',
                          style: TextStyle(color: Colors.grey),
                        );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final action = data['action'] ?? 'UNKNOWN';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.history,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        data['actor'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
