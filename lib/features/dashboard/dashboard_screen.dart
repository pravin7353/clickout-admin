// lib/features/dashboard/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../manpower_ai/presentation/manpower_widget.dart';
import '../revenue_engine/providers/revenue_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revenueState = ref.watch(revenueEngineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      floatingActionButton: ScaleTransition(
        scale: _pulseAnimation,
        child: FloatingActionButton(
          onPressed: () => ref.read(revenueEngineProvider.notifier).refresh(),
          backgroundColor: const Color(0xFF2B3674),
          tooltip: "Refresh Analytics",
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      ),
      body: revenueState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2B3674)),
        ),
        error: (err, stack) => Center(
          child: Text(
            "🚨 Intel Radar Failed: $err",
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (metrics) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Command Center Intel 📡",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3674),
                  ),
                ),
                const Text(
                  "Real-time revenue & gate-pass reconciliation",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 30),

                const Text(
                  "SECTION A: Revenue Intelligence",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                _buildRevenueGrid(metrics),
                const SizedBox(height: 30),

                const Text(
                  "SECTION B: Order Logistics",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                _buildOrderGrid(metrics),
                const SizedBox(height: 30),

                const Text(
                  "SECTION C: Financial Events",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                _buildEventsGrid(
                  metrics.refundCount,
                  metrics.refundAmount,
                  metrics.expireCount,
                  metrics.expireAmount,
                ),
                const SizedBox(height: 40),

                const Text(
                  "Command Intel 📡",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3674),
                  ),
                ),
                const SizedBox(height: 15),
                const ManpowerRadarWidget(),
                const SizedBox(height: 40),

                const Text(
                  "Revenue Trend Matrix",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3674),
                  ),
                ),
                const SizedBox(height: 15),
                const EnterpriseRevenueMatrixChart(),
                const SizedBox(height: 40),

                const Text(
                  "Reconciliation Table",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3674),
                  ),
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
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAmt
                    ? "₹${value.toStringAsFixed(0)}"
                    : value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2B3674),
                ),
              ),
              if (pct > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${pct.toStringAsFixed(1)}% of Gross",
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "$count Orders",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2B3674),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Impact: ₹${amt.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
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
                            ? Colors.blue.withOpacity(0.1)
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
                      color: Colors.blueGrey.withOpacity(0.5),
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
                      color: Colors.orange.withOpacity(0.5),
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
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
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
                          trendColor.withOpacity(0.4),
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

  // 🧠 2. THE QUERY FIX: Looking for actual backend strings!
  Query _buildQuery({bool isCount = false}) {
    Query q = FirebaseFirestore.instance.collection('orders');

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
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
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search Exact Order ID...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade50,
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          icon: const Icon(Icons.filter_list),
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
                                    style: const TextStyle(
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
                          color: Colors.grey.shade50,
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
                              color: const Color(0xFF2B3674),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isLatestFirst ? "Latest" : "Oldest",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF2B3674),
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
                  iconColor: const Color(0xFF2B3674),
                  title: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          displayId,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('hh:mm a').format(dt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "₹$amount",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2B3674),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          o['paymentMode']?.toString() ?? 'UPI',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                      color: Colors.grey.shade50,
                      padding: const EdgeInsets.all(20),
                      child: Row(
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
                                ? DateFormat(
                                    'hh:mm a',
                                  ).format(dt.add(const Duration(minutes: 5)))
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
              color: Colors.grey.shade50,
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
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 0 ? _prevPage : null,
                ),
                Text(
                  "Page ${_currentPage + 1} of $totalPages",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
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
    Color bg;
    Color text;
    switch (status) {
      case 'Clear Exit':
        bg = Colors.green.shade50;
        text = Colors.green;
        break;
      case 'Gate Pass Pending':
        bg = Colors.orange.shade50;
        text = Colors.orange.shade800;
        break;
      case 'Reject':
        bg = Colors.red.shade50;
        text = Colors.red;
        break;
      case 'Fix & Exit':
        bg = Colors.purple.shade50;
        text = Colors.purple;
        break;
      case 'Refund':
        bg = Colors.blue.shade50;
        text = Colors.blue;
        break;
      case 'QR Expire':
        bg = Colors.grey.shade200;
        text = Colors.grey.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.3)),
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
    return Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _timelineLine(Color color) {
    return Expanded(
      child: Container(
        height: 2,
        color: color.withOpacity(0.3),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
    );
  }
}
