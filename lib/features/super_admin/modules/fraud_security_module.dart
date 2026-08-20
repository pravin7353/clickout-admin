import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fraud_feed_provider.dart';
import '../screens/super_admin_screen.dart'; // Ensure EnterpriseThemeTokens extension is accessible here

class FraudSecurityModule extends ConsumerWidget {
  const FraudSecurityModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(fraudAlertsProvider);

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
                    'Fraud & Security Command',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Global threat detection, guard overrides, and AI risk radar.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ⚡ Real Firestore Threat Metrics
          alertsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Error loading metrics: $e',
              style: TextStyle(color: context.riskHigh),
            ),
            data: (alerts) {
              int critical = alerts
                  .where(
                    (a) =>
                        a['riskLevel'] == 'CRITICAL' ||
                        (a['action'] ?? '').toString().contains('CRITICAL'),
                  )
                  .length;
              int overrides = alerts
                  .where(
                    (a) => (a['action'] ?? '').toString().contains('OVERRIDE'),
                  )
                  .length;
              int matches = alerts.length;

              return Row(
                children: [
                  _buildThreatMetric(
                    context,
                    'CRITICAL THREATS',
                    '$critical',
                    context.riskHigh,
                    Icons.gpp_bad,
                  ),
                  const SizedBox(width: 16),
                  _buildThreatMetric(
                    context,
                    'SUSPECT MATCHES',
                    '$matches',
                    context.riskMedium,
                    Icons.person_search,
                  ),
                  const SizedBox(width: 16),
                  _buildThreatMetric(
                    context,
                    'GUARD OVERRIDES',
                    '$overrides',
                    context.accentNeon,
                    Icons.admin_panel_settings,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Alerts Stream
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
                      'Live Security Feed',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(color: context.borderSubtle, height: 1),
                  Expanded(
                    child: alertsAsync.when(
                      loading: () => ListView.builder(
                        itemCount: 6,
                        itemBuilder: (context, i) => Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.surfaceGlass.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Error: $e',
                              style: TextStyle(color: context.riskHigh),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  ref.invalidate(fraudAlertsProvider),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (alerts) {
                        if (alerts.isEmpty) {
                          return Center(
                            child: Text(
                              'No active threats detected. Systems secure.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: alerts.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: context.borderSubtle, height: 1),
                          itemBuilder: (context, i) {
                            final alert = alerts[i];
                            final level = alert['riskLevel'] ?? 'LOW';
                            final color = level == 'CRITICAL'
                                ? context.riskHigh
                                : (level == 'HIGH'
                                      ? context.riskMedium
                                      : context.accentNeon);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.warning_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                alert['title'] ?? 'Suspicious Activity',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${alert['storeName'] ?? 'Unknown Store'} • ${alert['tenantName'] ?? 'Platform'}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide(color: context.borderSubtle),
                                  elevation: 0,
                                ),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: context.bgBase,
                                    title: Text(
                                      alert['title'] ?? 'Suspicious Activity',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Text(
                                        alert.entries
                                            .map((e) => '${e.key}: ${e.value}')
                                            .join('\n'),
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  'Investigate',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 12,
                                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildThreatMetric(
    BuildContext context,
    String title,
    String value,
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
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
