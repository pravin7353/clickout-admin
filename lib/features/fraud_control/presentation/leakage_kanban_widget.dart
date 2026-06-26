import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fraud_provider.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';

class LeakageKanbanBoard extends ConsumerWidget {
  const LeakageKanbanBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(leakageBucketProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ScrollController horizontalController = ScrollController();

        // 🚀 PROPER TABLE FORMAT: Equal width distribution using Expanded
        Widget kanbanContent = Row(
          children: [
            Expanded(
              child: _buildColumn(
                context,
                "Normal (0-5m)",
                buckets.normal,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildColumn(
                context,
                "Warning (5-30m)",
                buckets.warning,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildColumn(
                context,
                "Critical (30-120m)",
                buckets.critical,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildColumn(
                context,
                "Escalated (2hr+)",
                buckets.escalated,
                isDark ? Colors.redAccent : Colors.red.shade900,
              ),
            ),
          ],
        );

        // 🚀 SMART SCROLLER: Only applies when screen shrinks below 1100px
        if (constraints.maxWidth < 1100) {
          return Scrollbar(
            controller: horizontalController,
            thumbVisibility: true, // Side scroller ALWAYS visible
            thickness: 8,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 16.0,
              ), // Gap between cards and scrollbar
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width:
                      1100, // Forces the minimum table width to prevent squeezing
                  child: kanbanContent,
                ),
              ),
            ),
          );
        }

        // Badi screen pe normal table jaisa stretch hoga
        return kanbanContent;
      },
    );
  }

  Widget _buildColumn(
    BuildContext context,
    String title,
    List<PendingOrder> orders,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InfoButton(
                        title: title,
                        en: title.contains('Normal')
                            ? 'Customer paid and is expected to exit soon. Wait time under 5 minutes — no action needed.'
                            : title.contains('Warning')
                            ? 'Customer has been waiting 5–30 minutes after payment. Keep an eye — may need a prompt.'
                            : title.contains('Critical')
                            ? 'Customer waiting 30 minutes to 2 hours. Immediate guard attention required. Possible leakage.'
                            : 'Customer has not exited for over 2 hours after payment. Escalate to manager — high leakage risk.',
                        hi: title.contains('Normal')
                            ? 'Customer ne payment kar di hai aur jald bahar aane wala hai. 5 minute se kam wait — koi action nahi chahiye.'
                            : title.contains('Warning')
                            ? '5 se 30 minute ho gaye payment ke baad. Nazar rakho — guard ko check karna chahiye.'
                            : title.contains('Critical')
                            ? '30 minute se 2 ghante ho gaye. Guard ko abhi dhyan dena chahiye — leakage ka khatra hai.'
                            : '2 ghante se zyada ho gaye payment ke baad bhi exit nahi hua. Manager ko escalate karo — high leakage risk.',
                        iconColor: color,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${orders.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: color.withOpacity(0.5),
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Clear",
                          style: TextStyle(
                            color: color.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final waitTime = DateTime.now()
                          .difference(order.paidAt)
                          .inMinutes;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.orderId.substring(0, 6).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: primaryText,
                                  ),
                                ),
                                Text(
                                  "${waitTime}m",
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "₹${order.amount.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
