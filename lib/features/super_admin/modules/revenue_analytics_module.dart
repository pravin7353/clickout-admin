import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/revenue_provider.dart';
import '../screens/super_admin_screen.dart'; // Tokens

class RevenueAnalyticsModule extends ConsumerWidget {
  const RevenueAnalyticsModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);

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
                    'Revenue & Billing Analytics',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Platform MRR, tenant subscriptions, and transaction volume.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.surfaceGlass,
                  side: BorderSide(color: context.borderSubtle),
                ),
                onPressed: () {},
                icon: Icon(
                  Icons.download,
                  size: 16,
                  color: context.textPrimary,
                ),
                label: Text(
                  'Export CSV',
                  style: TextStyle(color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // High-level Metrics
          // ⚡ Real Firestore High-level Metrics
          ref
              .watch(revenueMetricsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Metrics Error: $e',
                  style: TextStyle(color: context.riskHigh),
                ),
                data: (metrics) {
                  // Simple formatter for large numbers (e.g., 4200000 -> 4.2M)
                  String formatCurrency(int amount) {
                    if (amount >= 1000000)
                      return '₹${(amount / 1000000).toStringAsFixed(1)}M';
                    if (amount >= 1000)
                      return '₹${(amount / 1000).toStringAsFixed(1)}K';
                    return '₹$amount';
                  }

                  return Row(
                    children: [
                      _buildRevenueCard(
                        context,
                        'PLATFORM MRR',
                        formatCurrency(metrics['mrr']),
                        'Live',
                        context.accentNeon,
                      ),
                      const SizedBox(width: 16),
                      _buildRevenueCard(
                        context,
                        'ACTIVE SUBSCRIPTIONS',
                        '${metrics['activeSubs']}',
                        'Live',
                        Colors.blueAccent,
                      ),
                      const SizedBox(width: 16),
                      _buildRevenueCard(
                        context,
                        'PENDING DUES',
                        formatCurrency(metrics['pendingDues']),
                        'Action Req',
                        context.riskMedium,
                      ),
                    ],
                  );
                },
              ),
          const SizedBox(height: 24),

          // Transactions Stream
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
                      'Global Transaction Feed',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(color: context.borderSubtle, height: 1),
                  Expanded(
                    child: transactionsAsync.when(
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
                                  ref.invalidate(recentTransactionsProvider),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (transactions) {
                        if (transactions.isEmpty) {
                          return Center(
                            child: Text(
                              'No recent transactions.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: context.borderSubtle, height: 1),
                          itemBuilder: (context, i) {
                            final txn = transactions[i];
                            final amount = txn['amount'] ?? 0;
                            final method = txn['paymentMethod'] ?? 'UPI';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: context.accentNeonGlow,
                                child: Icon(
                                  Icons.currency_rupee,
                                  color: context.accentNeon,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '₹$amount via $method',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Tenant: ${txn['tenantId'] ?? 'Unknown'} • Store: ${txn['storeId'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              trailing: Text(
                                'SUCCESS',
                                style: TextStyle(
                                  color: context.accentNeon,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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

  Widget _buildRevenueCard(
    BuildContext context,
    String title,
    String value,
    String trend,
    Color trendColor,
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
            Text(
              title,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
