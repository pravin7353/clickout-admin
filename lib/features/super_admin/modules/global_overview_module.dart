import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/super_admin_screen.dart'; // Tokens
import '../widgets/kpi_card.dart';
import '../widgets/audit_feed_item.dart';
import '../providers/fraud_feed_provider.dart'; // ⚡ NEW: Real threat provider
import '../providers/revenue_provider.dart'; // ⚡ NEW: Real MRR provider

final saasTenantsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.keepAlive();
      return FirebaseFirestore.instance
          .collection('tenants')
          .orderBy('createdAt', descending: true)
          // 🚀 COST FIX: Poore platform ke saare tenants bina limit ke stream
          // ho rahe the. TODO: pagination add karo jab tenant count 1000 se
          // zyada rehne lage.
          .limit(1000)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => {'docId': doc.id, ...doc.data()})
                .where((t) => t['isDeleted'] != true)
                .toList();
          });
    });

class GlobalOverviewModule extends ConsumerWidget {
  const GlobalOverviewModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(saasTenantsProvider);
    final alertsAsync = ref.watch(
      fraudAlertsProvider,
    ); // ⚡ NEW: Fetch live threats
    final revenueAsync = ref.watch(
      revenueMetricsProvider,
    ); // ⚡ NEW: Fetch live MRR

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live Operations Overview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Real-time aggregation of all global ClickOut platform metrics.",
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          tenantsAsync.when(
            loading: () => Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 16),
                    height: 110,
                    decoration: BoxDecoration(
                      color: context.surfaceGlass.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.borderSubtle.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            error: (err, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error: $err',
                    style: TextStyle(color: context.riskHigh),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(saasTenantsProvider),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (tenants) {
              int activeTenants = tenants
                  .where((t) => t['isActive'] == true)
                  .length;
              int totalBranches = tenants.fold(
                0,
                (sum, t) => sum + ((t['totalBranches'] as num?)?.toInt() ?? 0),
              );

              return Row(
                children: [
                  Expanded(
                    child: GlassKpiWidget(
                      title: "Active Tenants",
                      value: activeTenants.toString(),
                      trend: "+12% this week",
                      icon: Icons.domain,
                      isGood: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassKpiWidget(
                      title: "Live Branches",
                      value: totalBranches.toString(),
                      trend: "All systems nominal",
                      icon: Icons.storefront,
                      isGood: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: revenueAsync.when(
                      loading: () => const GlassKpiWidget(
                        title: "Platform MRR",
                        value: "...",
                        trend: "Calculating",
                        icon: Icons.currency_rupee,
                        isGood: true,
                      ),
                      error: (_, __) => const GlassKpiWidget(
                        title: "Platform MRR",
                        value: "Error",
                        trend: "Check connection",
                        icon: Icons.currency_rupee,
                        isGood: false,
                      ),
                      data: (metrics) {
                        final int mrr = (metrics['mrr'] as num?)?.toInt() ?? 0;
                        final String display = mrr >= 100000
                            ? "₹${(mrr / 100000).toStringAsFixed(1)}L"
                            : "₹$mrr";
                        return GlassKpiWidget(
                          title: "Platform MRR",
                          value: display,
                          trend: "${metrics['activeSubs'] ?? 0} active subs",
                          icon: Icons.currency_rupee,
                          isGood: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // ⚡ Live Threat Count
                  Expanded(
                    child: GlassKpiWidget(
                      title: "System Threats",
                      value: "${alertsAsync.value?.length ?? 0} Alerts",
                      trend: (alertsAsync.value?.length ?? 0) > 0
                          ? "Requires attention"
                          : "All clear",
                      icon: Icons.security,
                      isGood: (alertsAsync.value?.length ?? 0) == 0,
                      isWarning: (alertsAsync.value?.length ?? 0) > 0,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Global Transaction Volume (24h)",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Text(
                          "[ ENTERPRISE LINE CHART PLUG-IN HERE ]\nShows UPI vs Card vs Cash splits",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.surfaceGlass,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.accentNeon,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Live Audit Ticker",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('admin_audit_logs')
                              .orderBy('timestamp', descending: true)
                              .limit(20)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading feed',
                                  style: TextStyle(color: context.riskHigh),
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: context.accentNeon,
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  "No activity yet",
                                  style: TextStyle(
                                    color: context.textSecondary,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data =
                                    docs[index].data() as Map<String, dynamic>;
                                final action =
                                    data['action']?.toString() ??
                                    'SYSTEM_EVENT';
                                final actor =
                                    data['actor']?.toString() ?? 'System';
                                final company =
                                    data['companyName']?.toString() ?? '';
                                final timestamp =
                                    (data['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now();

                                // Time Ago Logic
                                String timeAgo(DateTime d) {
                                  final diff = DateTime.now().difference(d);
                                  if (diff.inDays > 0)
                                    return '${diff.inDays}d ago';
                                  if (diff.inHours > 0)
                                    return '${diff.inHours}h ago';
                                  if (diff.inMinutes > 0)
                                    return '${diff.inMinutes}m ago';
                                  return 'Just now';
                                }

                                // Color Logic
                                Color getActionColor(String act) {
                                  if (act == 'TENANT_ONBOARDED' ||
                                      act == 'TENANT_REACTIVATED')
                                    return context.accentNeon;
                                  if (act.startsWith('FRAUD_') ||
                                      act == 'TENANT_SUSPENDED')
                                    return context.riskHigh;
                                  if (act.startsWith('REFUND_') ||
                                      act == 'PLAN_CHANGED')
                                    return context.riskMedium;
                                  return context.textSecondary;
                                }

                                // Constructing meaningful text
                                String text = "[$action] by $actor";
                                if (company.isNotEmpty) text += " for $company";
                                if (data.containsKey('details'))
                                  text += " - ${data['details']}";

                                return ActivityFeedItem(
                                  time: timeAgo(timestamp),
                                  text: text,
                                  color: getActionColor(action),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
