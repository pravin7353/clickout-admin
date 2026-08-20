import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/super_admin_screen.dart'; // Tokens

// ⚡ NEW: Real-time System Health Provider
final systemHealthProvider = StreamProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('system_health')
      .doc('live_metrics')
      .snapshots()
      .map((snap) => snap.data() ?? {});
});

class InfraHealthModule extends ConsumerWidget {
  const InfraHealthModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(
      systemHealthProvider,
    ); // ⚡ Listen to real metrics

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Infrastructure Health',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live metrics for Google Cloud, Neon.tech PostgreSQL, and Firebase.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.accentNeonGlow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.accentNeon.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
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
                    Text(
                      'ALL SYSTEMS OPERATIONAL',
                      style: TextStyle(
                        color: context.accentNeon,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ⚡ Real Core System Vitals & Nodes
          Expanded(
            child: healthAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: context.accentNeon),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error loading metrics: $e',
                  style: TextStyle(color: context.riskHigh),
                ),
              ),
              data: (metrics) {
                // Fetch fields or use fallback
                final latency = metrics['apiLatency']?.toString() ?? '--';
                final fsLoad = metrics['firestoreLoad']?.toString() ?? '--';
                final pgConn = metrics['pgConnections']?.toString() ?? '--';
                final status =
                    (metrics['overallStatus']?.toString() ?? 'Stable')
                        .toUpperCase();

                Color getStatusColor(String s) {
                  if (s == 'OPTIMAL' || s == 'STABLE' || s == 'ONLINE')
                    return context.accentNeon;
                  if (s == 'WARNING' || s == 'HIGH LOAD')
                    return context.riskMedium;
                  return context.riskHigh;
                }

                // Handle dynamic edge nodes list
                final List<dynamic> edgeNodes = metrics['edgeNodes'] ?? [];

                return Column(
                  children: [
                    Row(
                      children: [
                        _buildVitalCard(
                          context,
                          'API LATENCY',
                          '${latency}ms',
                          status,
                          getStatusColor(status),
                          Icons.speed,
                        ),
                        const SizedBox(width: 16),
                        _buildVitalCard(
                          context,
                          'FIRESTORE LOAD',
                          '$fsLoad%',
                          status,
                          getStatusColor(status),
                          Icons.storage,
                        ),
                        const SizedBox(width: 16),
                        _buildVitalCard(
                          context,
                          'PG DB (NEON.TECH)',
                          '$pgConn Active',
                          status,
                          getStatusColor(status),
                          Icons.memory,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surfaceGlass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Global Edge Nodes',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(color: context.borderSubtle, height: 1),
                            Expanded(
                              child: edgeNodes.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No node data available.',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(20),
                                      itemCount: edgeNodes.length,
                                      itemBuilder: (context, i) {
                                        final node =
                                            edgeNodes[i]
                                                as Map<String, dynamic>;
                                        final nodeStatus =
                                            (node['status']?.toString() ??
                                                    'Unknown')
                                                .toUpperCase();
                                        return _buildNodeRow(
                                          context,
                                          node['region'] ?? 'Unknown Region',
                                          nodeStatus,
                                          node['uptime'] ?? '--%',
                                          getStatusColor(nodeStatus),
                                        );
                                      },
                                    ),
                            ),
                          ],
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

  Widget _buildVitalCard(
    BuildContext context,
    String title,
    String value,
    String status,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: $status',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeRow(
    BuildContext context,
    String region,
    String status,
    String uptime,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgBase,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.dns, color: context.textSecondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              region,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Text(
            'Uptime: $uptime',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
