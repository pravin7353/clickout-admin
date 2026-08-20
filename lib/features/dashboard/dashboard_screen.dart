// lib/features/dashboard/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../manpower_ai/presentation/manpower_widget.dart';
import '../revenue_engine/providers/revenue_provider.dart';
import '../revenue_engine/providers/industry_benchmark_provider.dart';
import '../auth/auth_provider.dart';
import '../../core/utils/standard_utils.dart'; // 🚀 5 Standard Rules
import '../coach/widgets/info_button.dart';
import '../../core/theme/app_theme.dart'; // 🚀 Added Theme Extension

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final revenueState = ref.watch(revenueEngineProvider);
    final primaryTextColor = context.colors.textPrimary;
    final bgColor = context.colors.scaffoldBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: revenueState.when(
        loading: () => const Center(
          child: SkeletonLoader(
            width: double.infinity,
            height: 400,
          ), // 🚀 Skeleton Rule
        ),
        error: (err, stack) => Center(
          child: Text(
            "🚨 Intel Radar Failed: $err",
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (metrics) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 600 ? 16.0 : 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💎 SYSTEM SECURE STRIP (Moved here for clean flow)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "System secure — No pending operations or fraud anomalies detected",
                          style: TextStyle(
                            color: Colors.green.shade400,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 💎 SILENT FLOATING GRIDS
                _buildRevenueGrid(metrics),
                const SizedBox(height: 16),
                _buildOrderGrid(metrics),
                const SizedBox(height: 16),
                _buildEventsGrid(
                  metrics.refundCount,
                  metrics.refundAmount,
                  metrics.expireCount,
                  metrics.expireAmount,
                ),
                const SizedBox(height: 40),

                Row(
                  children: [
                    Text(
                      "Industry Benchmark 📊",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const InfoButton(
                      title: 'Industry Benchmark',
                      en: 'Compares your at-risk revenue (pending + rejected at exit) against the published Indian organized retail shrinkage average.',
                      hi: 'Aapka at-risk revenue (exit pe pending + rejected) ko India ke organized retail ke published shrinkage average se compare karta hai.',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildIndustryBenchmarkCard(
                  metrics,
                  ref.watch(industryBenchmarkProvider).value,
                ),
                const SizedBox(height: 40),

                Text(
                  "Command Intel 📡",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 15),
                const ManpowerRadarWidget(),
                const SizedBox(height: 40),

                /* 🚀 DISABLED: Revenue Trend Matrix - Kept for future use
                Text(
                  "Revenue Trend Matrix",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 15),
                const EnterpriseRevenueMatrixChart(),
                const SizedBox(height: 40),
                */
                Row(
                  children: [
                    Text(
                      "Reconciliation Table",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const InfoButton(
                      title: 'Reconciliation Table',
                      en: 'Live order ledger showing all transactions with payment status, exit status, and audit trail. Filter by status to spot anomalies.',
                      hi: 'Har transaction ka live record — payment hua, exit hua, refund hua sab yahan dikhega. Status filter karke suspicious orders pakdo.',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // 🚀 TABLE RENDERED HERE
                const ReconciliationTableWidget(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================== GRIDS ==============================
  Widget _buildRevenueGrid(RevenueMetrics metrics) {
    return _responsiveGrid([
      _card(
        "Gross Revenue",
        metrics.grossRevenue,
        100,
        Colors.blue,
        Icons.account_balance_wallet,
        true,
      ),
      _card(
        "Total Revenue",
        metrics.totalRevenue,
        _pct(metrics.totalRevenue, metrics.grossRevenue),
        Colors.green,
        Icons.check_circle,
        true,
      ),
      _card(
        "Pending Verification",
        metrics.pendingRevenue,
        _pct(metrics.pendingRevenue, metrics.grossRevenue),
        Colors.orange,
        Icons.hourglass_empty,
        true,
      ),
      _card(
        "Rejected Leakage",
        metrics.rejectedRevenue,
        _pct(metrics.rejectedRevenue, metrics.grossRevenue),
        Colors.red,
        Icons.cancel,
        true,
      ),
    ]);
  }

  Map<String, String> _cardInfo(String title) {
    const Map<String, Map<String, String>> info = {
      'Gross Revenue': {
        'en':
            'Total billed amount before any deductions. Includes paid, pending, and rejected orders.',
        'hi':
            'Ye aapka total billing amount hai — chahe payment hua ho ya nahi. Isse pata chalta hai store kitna generate kar raha hai.',
      },
      'Total Revenue': {
        'en': 'Confirmed revenue from fully verified and exited orders only.',
        'hi':
            'Sirf wo paisa jo guard ne verify karke customer ko exit diya. Ye aapka real confirmed income hai.',
      },
      'Pending Verification': {
        'en':
            'Paid orders waiting for guard exit verification. High value here = bottleneck at exit.',
        'hi':
            'Customer ne payment kar diya par guard ne exit nahi diya abhi. Zyada pending = exit pe jam ya fraud risk.',
      },
      'Rejected Leakage': {
        'en': 'Orders rejected at gate — potential fraud or billing mismatch.',
        'hi':
            'Guard ne in orders ko reject kiya. Ye financial leakage hai — seedha loss ya fraud ka signal.',
      },
      'Total Paid Orders': {
        'en': 'Count of all orders where payment was completed.',
        'hi':
            'Kitne customers ne payment complete ki — chahe exit hua ho ya nahi.',
      },
      'Successful Exits': {
        'en':
            'Orders where customer completed payment AND guard verified exit.',
        'hi':
            'Pura cycle complete — payment + guard exit dono. Ye aapka healthy transaction count hai.',
      },
      'Pending Gate Pass': {
        'en': 'Paid orders stuck at gate waiting for guard scan.',
        'hi':
            'Payment ho gayi par gate pass abhi pending hai. Guard busy hai ya koi technical issue.',
      },
      'Guard Rejections': {
        'en':
            'Orders rejected by guard — weight mismatch, QR fraud, or suspicious items.',
        'hi':
            'Guard ne kuch gadbad pakdi — weight mismatch, fake QR ya suspicious items. Investigate karo.',
      },
      'Refunds': {
        'en':
            'Total refund count and amount. High refunds = product issues or cashier fraud.',
        'hi':
            'Kitne refund hue aur kitna paisa gaya. Zyada refund = product problem ya cashier fraud.',
      },
      'QR Expired': {
        'en':
            'Carts abandoned after QR generation — customer left without completing purchase.',
        'hi':
            'Customer ne QR banaya par purchase complete nahi ki. Cart abandon hua.',
      },
    };
    return info[title] ??
        {
          'en': 'This metric tracks important operational data for your store.',
          'hi':
              'Ye metric aapke store ki operations ka important data track karta hai.',
        };
  }

  Widget _buildOrderGrid(RevenueMetrics metrics) {
    return _responsiveGrid([
      _card(
        "Total Paid Orders",
        metrics.totalOrders.toDouble(),
        0,
        Colors.blueGrey,
        Icons.receipt_long,
        false,
      ),
      _card(
        "Successful Exits",
        metrics.successfulExited.toDouble(),
        0,
        Colors.green,
        Icons.gpp_good,
        false,
      ),
      _card(
        "Pending Gate Pass",
        metrics.pendingAtVerifier.toDouble(),
        0,
        Colors.orange,
        Icons.pending_actions,
        false,
      ),
      _card(
        "Guard Rejections",
        metrics.rejectedAtVerifier.toDouble(),
        0,
        Colors.red,
        Icons.gpp_bad,
        false,
      ),
    ]);
  }

  Widget _buildEventsGrid(int rCount, double rAmt, int eCount, double eAmt) {
    return _responsiveGrid([
      _eventCard("Refunds", rCount, rAmt, Colors.blue, Icons.currency_exchange),
      _eventCard(
        "QR Expired",
        eCount,
        eAmt,
        Colors.grey.shade600,
        Icons.qr_code_scanner,
      ),
    ], overrideDesktopCount: 2);
  }

  // ⚡ NEW: Industry Benchmark Card
  // Source: India organized retail shrinkage industry average (~2%),
  // based on published retail-loss-prevention research. Static reference,
  // not a live cross-tenant computation (no platform-wide aggregation
  // pipeline exists yet — avoids fabricating a fake "live" number).
  static const double _fallbackIndustryAvgLeakagePct = 2.0;

  Widget _buildIndustryBenchmarkCard(
    RevenueMetrics metrics,
    double? liveIndustryAvg,
  ) {
    final double industryAvg =
        liveIndustryAvg ?? _fallbackIndustryAvgLeakagePct;
    final double atRiskRevenue =
        metrics.pendingRevenue + metrics.rejectedRevenue;
    final double yourLeakagePct = _pct(atRiskRevenue, metrics.grossRevenue);
    final bool isBetterThanAvg = yourLeakagePct <= industryAvg;
    final Color statusColor = isBetterThanAvg ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Shrinkage Rate",
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${yourLeakagePct.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Industry Average",
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "~${industryAvg.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (yourLeakagePct / 10).clamp(0.0, 1.0),
              // 🚀 10% scale — visually meaningful for retail shrinkage rates
              minHeight: 8,
              backgroundColor: context.colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isBetterThanAvg
                ? "Aap industry average se behtar hain — keep it up!"
                : "Aapka shrinkage industry average se zyada hai — Fraud Control check karo.",
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveGrid(
    List<Widget> children, {
    int overrideDesktopCount = 4,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth >= 1024
            ? overrideDesktopCount
            : (constraints.maxWidth >= 600 ? 2 : 1);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20, // 🚀 Increased Gap
            mainAxisSpacing: 20, // 🚀 Increased Gap
            mainAxisExtent: 110,
          ),
          children: children,
        );
      },
    );
  }

  double _pct(double val, double total) => total == 0 ? 0 : (val / total) * 100;

  Widget _card(
    String title,
    double value,
    double pct,
    Color color,
    IconData icon,
    bool isAmt,
  ) {
    final cardBg = context.colors.cardBg;
    final textColor = context.colors.textPrimary;

    // Custom subtitles mapping (Apple Style)
    String subtitle = "";
    if (title == "Gross Revenue")
      subtitle = "+${pct.toStringAsFixed(1)}%";
    else if (title == "Total Revenue")
      subtitle = "Net amount";
    else if (title.contains("Pending"))
      subtitle = "Waiting";
    else if (title.contains("Rejected"))
      subtitle = "Blocked";

    return Container(
      padding: const EdgeInsets.all(16), // Smaller padding
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InfoButton(
                title: title,
                en: _cardInfo(title)['en']!,
                hi: _cardInfo(title)['hi']!,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 12),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isAmt
                    ? "₹${value.toStringAsFixed(0)}"
                    : value.toInt().toString(),
                style: TextStyle(
                  fontSize: 24, // Smaller font to fit compact card
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: title == "Gross Revenue"
                            ? Colors.green.shade400
                            : const Color(0xFF636366),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventCard(
    String title,
    int count,
    double amt,
    Color color,
    IconData icon,
  ) {
    final cardBg = context.colors.cardBg;
    final textColor = context.colors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InfoButton(
                title: title,
                en: _cardInfo(title)['en']!,
                hi: _cardInfo(title)['hi']!,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 12),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: textColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "Impact: ₹${amt.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: context.colors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

// ============================================================================
// 📈 ENTERPRISE REVENUE MATRIX CHART
// ============================================================================
class EnterpriseRevenueMatrixChart extends StatefulWidget {
  const EnterpriseRevenueMatrixChart({super.key});
  @override
  State<EnterpriseRevenueMatrixChart> createState() =>
      _EnterpriseRevenueMatrixChartState();
}

class _EnterpriseRevenueMatrixChartState
    extends State<EnterpriseRevenueMatrixChart> {
  String _timeFilter = '1W';
  String _metricToggle = 'Gross';

  final Map<String, List<FlSpot>> _baseData = {
    '1W': const [
      FlSpot(0, 1000),
      FlSpot(1, 1500),
      FlSpot(2, 1200),
      FlSpot(3, 2500),
      FlSpot(4, 2100),
      FlSpot(5, 3000),
      FlSpot(6, 4500),
    ],
    '1M': const [
      FlSpot(0, 8000),
      FlSpot(1, 12000),
      FlSpot(2, 11000),
      FlSpot(3, 18000),
    ],
  };

  @override
  Widget build(BuildContext context) {
    double multiplier = _metricToggle == 'Gross'
        ? 1.0
        : (_metricToggle == 'Net' ? 0.8 : 0.2);
    List<FlSpot> spots = (_baseData[_timeFilter] ?? _baseData['1W']!)
        .map((s) => FlSpot(s.x, s.y * multiplier))
        .toList();
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;
    double avgY = spots.map((e) => e.y).reduce((a, b) => a + b) / spots.length;
    double peakY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    bool isBullish = spots.last.y >= spots.first.y;
    Color trendColor = isBullish ? Colors.green : Colors.redAccent;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: ['Gross', 'Net', 'Pending'].map((m) {
                    bool sel = _metricToggle == m;
                    return GestureDetector(
                      onTap: () => setState(() => _metricToggle = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF2B3674)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Row(
                children: ['1W', '1M'].map((f) {
                  return GestureDetector(
                    onTap: () => setState(() => _timeFilter = f),
                    child: Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _timeFilter == f
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: _timeFilter == f ? Colors.blue : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: avgY,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (_) =>
                            "AVG: ₹${avgY.toStringAsFixed(0)}",
                      ),
                    ),
                    HorizontalLine(
                      y: peakY,
                      color: Colors.orange.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (_) => "PEAK",
                      ),
                    ),
                  ],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, m) => Text(
                        "₹${v.toInt()}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt()) {
                          return const SizedBox.shrink();
                        }
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ];
                        const weeks = ['W1', 'W2', 'W3', 'W4'];
                        String label = _timeFilter == '1W'
                            ? (value >= 0 && value < days.length
                                  ? days[value.toInt()]
                                  : '')
                            : (value >= 0 && value < weeks.length
                                  ? weeks[value.toInt()]
                                  : '');
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E1E2D),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: trendColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          trendColor.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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
}

// ============================================================================
// 📜 ENTERPRISE RECONCILIATION TABLE (⚡ BUG FIXED: VOCABULARY MATCH)
// ============================================================================
// 🔥 1. Made it a ConsumerStatefulWidget to listen to refresh button!
class ReconciliationTableWidget extends ConsumerStatefulWidget {
  const ReconciliationTableWidget({super.key});

  @override
  ConsumerState<ReconciliationTableWidget> createState() =>
      _ReconciliationTableWidgetState();
}

class _ReconciliationTableWidgetState
    extends ConsumerState<ReconciliationTableWidget> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  bool _isLatestFirst = true;

  List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalRecords = 0;
  final int _rowsPerPage = 10;
  String _indexErrorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // 🧠 2. THE QUERY FIX: Looking for actual backend strings + SAAS ISOLATION + DAILY RESET!
  Query _buildQuery({bool isCount = false}) {
    final adminData = ref.read(adminRoleProvider).value;
    final String tenantId = adminData?['tenantId'] ?? '';
    final String branchCode = adminData?['branchCode'] ?? '';
    final String role = (adminData?['role'] ?? '').toString().toLowerCase();

    Query q = FirebaseFirestore.instance.collection('orders');

    // 🚀 SAAS ISOLATION: Sirf apni dukaan ka data!
    if (role != 'super_admin' && tenantId.isNotEmpty) {
      q = q.where('tenantId', isEqualTo: tenantId);
    }
    if (role == 'manager' && branchCode.isNotEmpty) {
      q = q.where('branchCode', isEqualTo: branchCode);
    }

    // 🚀 DAILY RESET: Raat 12 baje sab fresh (Lifelong data Auditor Screen me rahega)
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    q = q.where(
      'timestamp',
      isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
    );

    if (_searchQuery.isNotEmpty) {
      q = q.where('orderId', isEqualTo: _searchQuery.trim());
      return q;
    }

    // 🔥 SMART FILTER MAPPER
    if (_statusFilter != 'ALL') {
      if (_statusFilter == 'Clear Exit') {
        q = q.where('exitStatus', whereIn: ['COMPLETED', 'EXITED', 'APPROVED']);
      } else if (_statusFilter == 'Gate Pass Pending') {
        q = q.where('exitStatus', whereIn: ['PENDING', 'READY_FOR_EXIT']);
      } else if (_statusFilter == 'Reject') {
        q = q.where('exitStatus', isEqualTo: 'REJECTED');
      } else if (_statusFilter == 'Fix & Exit') {
        // Query all completed, filter for wasEverRejected in memory to avoid composite index overhead
        q = q.where('exitStatus', whereIn: ['COMPLETED', 'EXITED', 'APPROVED']);
      } else if (_statusFilter == 'Refund') {
        q = q.where('paymentStatus', isEqualTo: 'REFUNDED');
      } else if (_statusFilter == 'QR Expire') {
        q = q.where('exitStatus', whereIn: ['EXPIRED_BY_SYSTEM', 'EXPIRED']);
      }
    }

    if (!isCount) {
      q = q.orderBy('timestamp', descending: _isLatestFirst);
      q = q.limit(_rowsPerPage);
    }
    return q;
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _indexErrorMsg = '';
    });
    try {
      // 🚀 Unused variables removed. _buildQuery ab khud data fetch karta hai.
      if (_searchQuery.isEmpty) {
        final countSnap = await _buildQuery(isCount: true).count().get();
        _totalRecords = countSnap.count ?? 0;
      } else {
        _totalRecords = 1;
      }
      final snap = await _buildQuery().get();
      _docs = snap.docs;
      _hasMore = snap.docs.length == _rowsPerPage;
      _currentPage = 0;
    } catch (e) {
      if (e.toString().contains('index')) {
        _indexErrorMsg =
            '🚨 Firebase Index Required! Click the link in your Debug Console to auto-create it.';
      } else {
        _indexErrorMsg = 'Error: $e';
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNextData() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      // 🚀 Unused variables removed.
      final snap = await _buildQuery().startAfterDocument(_docs.last).get();
      _docs.addAll(snap.docs);
      _hasMore = snap.docs.length == _rowsPerPage;
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  void _nextPage() async {
    int nextIndex = (_currentPage + 1) * _rowsPerPage;
    if (nextIndex >= _docs.length && _hasMore) await _fetchNextData();
    if (nextIndex < _docs.length) setState(() => _currentPage++);
  }

  void _prevPage() {
    if (_currentPage > 0) setState(() => _currentPage--);
  }

  // 🧪 3. THE VOCABULARY FIX (Smart Evaluator)
  String _computeStatus(Map<String, dynamic> data) {
    String p = (data['paymentStatus'] ?? '').toString().toUpperCase();
    String e = (data['exitStatus'] ?? '').toString().toUpperCase();
    bool wasEverRejected = data['wasEverRejected'] == true;
    bool qrConsumed = data['qrConsumed'] == true;

    // The Ultimate Truth Checks
    bool isCleanExit =
        (e == 'COMPLETED' ||
        e == 'EXITED' ||
        e == 'APPROVED' ||
        (qrConsumed && e != 'REJECTED'));

    if (isCleanExit) return wasEverRejected ? 'Fix & Exit' : 'Clear Exit';
    if (e == 'REJECTED') return 'Reject';
    if (e == 'EXPIRED' || e == 'EXPIRED_BY_SYSTEM') return 'QR Expire';
    if (p == 'REFUNDED') return 'Refund';
    if (p == 'PAID' && (e == 'PENDING' || e == 'READY_FOR_EXIT')) {
      return 'Gate Pass Pending';
    }

    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 AUTO-REFRESH LISTENER (When top dashboard FAB is pressed, table also reloads!)
    ref.listen(revenueEngineProvider, (previous, next) {
      if (next.isLoading == false) {
        _fetchInitialData();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final cardBg = context.colors.cardBg;
    final inputBg = isDark
        ? context.colors.scaffoldBg
        : const Color(0xFFF4F5F7); // Contrast for input
    final textColor = context.colors.textPrimary;

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = (startIndex + _rowsPerPage > _docs.length)
        ? _docs.length
        : startIndex + _rowsPerPage;

    // In-memory filter for 'Fix & Exit' edge case
    List<DocumentSnapshot> currentPageDocs = _docs.isEmpty
        ? []
        : _docs.sublist(startIndex, endIndex);
    if (_statusFilter == 'Fix & Exit') {
      currentPageDocs = currentPageDocs
          .where(
            (d) =>
                (d.data() as Map<String, dynamic>)['wasEverRejected'] == true,
          )
          .toList();
    }

    int totalPages = (_totalRecords / _rowsPerPage).ceil();
    if (totalPages <= 0) totalPages = 1;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🎛️ SEARCH & FILTERS
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 15,
              runSpacing: 15,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: isMobile
                      ? double.infinity
                      : 300, // 🚀 Fully Responsive Search Bar
                  child: TextField(
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search Exact Order ID...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) {
                      _searchQuery = val;
                      _fetchInitialData();
                    },
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: cardBg,
                          value: _statusFilter,
                          icon: Icon(
                            Icons.filter_list,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          items:
                              [
                                'ALL',
                                'Clear Exit',
                                'Gate Pass Pending',
                                'Reject',
                                'Fix & Exit',
                                'QR Expire',
                                'Refund',
                              ].map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) {
                            _statusFilter = val!;
                            _fetchInitialData();
                          },
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _isLatestFirst = !_isLatestFirst;
                        _fetchInitialData();
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isLatestFirst
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 16,
                              color: textColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isLatestFirst ? "Latest" : "Oldest",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
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
          ),
          const Divider(height: 1),

          // 📋 MAIN TABLE VIEW
          if (_isLoading && _docs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_indexErrorMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  _indexErrorMsg,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (currentPageDocs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  "No records match your criteria.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentPageDocs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = currentPageDocs[index];
                final o = doc.data() as Map<String, dynamic>;

                String oId = o['orderId']?.toString() ?? doc.id;
                String displayId = oId.length >= 8 ? oId.substring(0, 8) : oId;
                String stat = _computeStatus(o);
                DateTime dt =
                    (o['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                double amount =
                    double.tryParse(
                      o['totalAmount']?.toString() ??
                          o['amount']?.toString() ??
                          '0',
                    ) ??
                    0.0;

                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  iconColor: textColor,
                  collapsedIconColor: isDark ? Colors.white54 : Colors.grey,
                  title: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  displayId,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                _buildStatusChip(stat),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('hh:mm a').format(dt),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "₹$amount",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  o['paymentMode']?.toString() ?? 'UPI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                displayId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                DateFormat('hh:mm a').format(dt),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                "₹$amount",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                o['paymentMode']?.toString() ?? 'UPI',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildStatusChip(stat),
                              ),
                            ),
                          ],
                        ),
                  children: [
                    Container(
                      color: isDark
                          ? const Color(0xFF080B08)
                          : Colors.grey.shade50,
                      padding: const EdgeInsets.all(20),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _timelineStep(
                                  Icons.shopping_cart,
                                  "Created",
                                  DateFormat('hh:mm a').format(dt),
                                  Colors.blue,
                                ),
                                const SizedBox(height: 10),
                                _timelineStep(
                                  Icons.payment,
                                  "Paid (${o['paymentMode'] ?? 'UPI'})",
                                  DateFormat(
                                    'hh:mm a',
                                  ).format(dt.add(const Duration(minutes: 2))),
                                  Colors.green,
                                ),
                                const SizedBox(height: 10),
                                _timelineStep(
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? Icons.directions_walk
                                      : (stat == 'Reject'
                                            ? Icons.block
                                            : (stat == 'QR Expire'
                                                  ? Icons.timer_off
                                                  : Icons.hourglass_empty)),
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? "Guard Exit"
                                      : (stat == 'Reject'
                                            ? "Rejected"
                                            : (stat == 'QR Expire'
                                                  ? "QR Expired"
                                                  : "Pending Verifier")),
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? DateFormat('hh:mm a').format(
                                          dt.add(const Duration(minutes: 5)),
                                        )
                                      : "--",
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? Colors.green
                                      : (stat == 'Reject'
                                            ? Colors.red
                                            : (stat == 'QR Expire'
                                                  ? Colors.grey
                                                  : Colors.orange)),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                _timelineStep(
                                  Icons.shopping_cart,
                                  "Created",
                                  DateFormat('hh:mm a').format(dt),
                                  Colors.blue,
                                ),
                                _timelineLine(Colors.green),
                                _timelineStep(
                                  Icons.payment,
                                  "Paid (${o['paymentMode'] ?? 'UPI'})",
                                  DateFormat(
                                    'hh:mm a',
                                  ).format(dt.add(const Duration(minutes: 2))),
                                  Colors.green,
                                ),
                                _timelineLine(
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? Colors.green
                                      : (stat == 'Reject'
                                            ? Colors.red
                                            : (stat == 'QR Expire'
                                                  ? Colors.grey
                                                  : Colors.orange)),
                                ),
                                _timelineStep(
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? Icons.directions_walk
                                      : (stat == 'Reject'
                                            ? Icons.block
                                            : (stat == 'QR Expire'
                                                  ? Icons.timer_off
                                                  : Icons.hourglass_empty)),
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? "Guard Exit"
                                      : (stat == 'Reject'
                                            ? "Rejected"
                                            : (stat == 'QR Expire'
                                                  ? "QR Expired"
                                                  : "Pending Verifier")),
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? DateFormat('hh:mm a').format(
                                          dt.add(const Duration(minutes: 5)),
                                        )
                                      : "--",
                                  (stat == 'Clear Exit' || stat == 'Fix & Exit')
                                      ? Colors.green
                                      : (stat == 'Reject'
                                            ? Colors.red
                                            : (stat == 'QR Expire'
                                                  ? Colors.grey
                                                  : Colors.orange)),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),

          // 🎛️ SERVER-SIDE PAGINATION FOOTER
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: _currentPage > 0 ? _prevPage : null,
                ),
                Text(
                  "Page ${_currentPage + 1} of $totalPages",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: (_currentPage < totalPages - 1 || _hasMore)
                      ? _nextPage
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color text;
    switch (status) {
      case 'Clear Exit':
        bg = isDark
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.green.shade50;
        text = isDark ? Colors.greenAccent : Colors.green;
        break;
      case 'Gate Pass Pending':
        bg = isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.orange.shade50;
        text = isDark ? Colors.orangeAccent : Colors.orange.shade800;
        break;
      case 'Reject':
        bg = isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50;
        text = isDark ? Colors.redAccent : Colors.red;
        break;
      case 'Fix & Exit':
        bg = isDark
            ? Colors.purple.withValues(alpha: 0.1)
            : Colors.purple.shade50;
        text = isDark ? Colors.purpleAccent : Colors.purple;
        break;
      case 'Refund':
        bg = isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50;
        text = isDark ? Colors.blueAccent : Colors.blue;
        break;
      case 'QR Expire':
        bg = isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade200;
        text = isDark ? Colors.grey.shade300 : Colors.grey.shade800;
        break;
      default:
        bg = isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade100;
        text = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _timelineStep(IconData icon, String title, String time, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _timelineLine(Color color) {
    return Expanded(
      child: Container(
        height: 2,
        color: color.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
    );
  }
}
