import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/features/coach/widgets/info_button.dart';
import '../../../core/theme/app_theme.dart';

class AuditVaultScreen extends ConsumerStatefulWidget {
  const AuditVaultScreen({super.key});

  @override
  ConsumerState<AuditVaultScreen> createState() => _AuditVaultScreenState();
}

class _AuditVaultScreenState extends ConsumerState<AuditVaultScreen> {
  int _currentPage = 0;
  final int _pageSize = 50; // 🚀 Paginate 50 logs per page
  String _selectedSeverity = 'ALL'; // 🚀 Added Filter State
  String _selectedTimeRange = 'ALL_TIME'; // 🚀 Added Date Filter State

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final adminData = ref.watch(adminRoleProvider).value;
    final String? tenantId = adminData?['tenantId'];
    final String role = (adminData?['role'] ?? '').toString().toLowerCase();

    Query auditQuery = FirebaseFirestore.instance.collection(
      'admin_audit_logs',
    );

    if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
      auditQuery = auditQuery.where('tenantId', isEqualTo: tenantId);
    }

    // 🚀 Limit to last 500 logs to prevent memory crash, we paginate locally
    auditQuery = auditQuery.limit(500);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        backgroundColor: c.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: c.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushReplacementNamed('/auditor');
            }
          },
        ),
        title: Text(
          "BACK TO COMMAND CENTER",
          style: TextStyle(
            color: c.textSecondary,
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
              Row(
                children: [
                  Text(
                    "Audit Vault",
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  InfoButton(
                    title: "Audit Vault",
                    en: "Command-line view of all system actions.",
                    hi: "System logs ka command-prompt view.",
                    iconColor: c.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Immutable System Activity Terminal",
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                  // 🚀 DOUBLE FILTERS (DATE + SEVERITY)
                  Wrap(
                    spacing: 12,
                    children: [
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTimeRange,
                            dropdownColor: c.cardBg,
                            icon: Icon(
                              Icons.calendar_month,
                              color: c.textPrimary,
                              size: 14,
                            ),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL_TIME',
                                child: Text('All Time'),
                              ),
                              DropdownMenuItem(
                                value: 'TODAY',
                                child: Text('Today'),
                              ),
                              DropdownMenuItem(
                                value: 'LAST_7_DAYS',
                                child: Text('Last 7 Days'),
                              ),
                              DropdownMenuItem(
                                value: 'THIS_MONTH',
                                child: Text('This Month'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedTimeRange = val!;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                      ),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSeverity,
                            dropdownColor: c.cardBg,
                            icon: Icon(
                              Icons.filter_list,
                              color: c.textPrimary,
                              size: 16,
                            ),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            items: ['ALL', 'CRITICAL', 'WARNING', 'INFO']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e == 'ALL' ? 'All Severities' : e,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSeverity = val!;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 💻 TERMINAL BOX
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A), // 🚀 Pitch Black Terminal
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: auditQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "> No audit logs found...",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      }

                      // 🚀 APPLY DUAL FILTERS (DATE & SEVERITY)
                      final now = DateTime.now();
                      final startOfToday = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      );
                      final startOfMonth = DateTime(now.year, now.month, 1);
                      final last7Days = startOfToday.subtract(
                        const Duration(days: 7),
                      );

                      var docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        // 1. Time Filter
                        if (_selectedTimeRange != 'ALL_TIME') {
                          final ts = data['timestamp'] as Timestamp?;
                          if (ts == null) return false;
                          final logDate = ts.toDate();

                          if (_selectedTimeRange == 'TODAY' &&
                              logDate.isBefore(startOfToday))
                            return false;
                          if (_selectedTimeRange == 'LAST_7_DAYS' &&
                              logDate.isBefore(last7Days))
                            return false;
                          if (_selectedTimeRange == 'THIS_MONTH' &&
                              logDate.isBefore(startOfMonth))
                            return false;
                        }

                        // 2. Severity Filter
                        if (_selectedSeverity != 'ALL') {
                          final action =
                              data['action'] ?? data['actionType'] ?? '';
                          String severity =
                              data['severity'] ??
                              (action.startsWith('FRAUD')
                                  ? 'CRITICAL'
                                  : action.contains('SUSPEND')
                                  ? 'WARNING'
                                  : 'INFO');
                          if (action.contains('LOCKED') ||
                              action.contains('SUSPEND'))
                            severity = 'WARNING';
                          if (action.contains('REVOKE') ||
                              action.contains('DELETE') ||
                              action.contains('REMOVE'))
                            severity = 'CRITICAL';
                          if (severity != _selectedSeverity) return false;
                        }

                        return true;
                      }).toList();

                      // 🚀 DART MEMORY SORTING (Desc: Newest First)
                      docs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final tA = aData['timestamp'] as Timestamp?;
                        final tB = bData['timestamp'] as Timestamp?;
                        if (tA == null || tB == null) return 0;
                        return tB.compareTo(tA);
                      });

                      // 🚀 PAGINATION LOGIC
                      final totalPages = (docs.length / _pageSize).ceil();
                      if (_currentPage >= totalPages && totalPages > 0) {
                        _currentPage = totalPages - 1;
                      }

                      final startIndex = _currentPage * _pageSize;
                      final endIndex = (startIndex + _pageSize > docs.length)
                          ? docs.length
                          : startIndex + _pageSize;
                      final pageDocs = docs.sublist(startIndex, endIndex);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 🖥️ TERMINAL HEADER
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.terminal,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "root@clickout-os:~# tail -f /var/log/audit.log",
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 📜 TERMINAL LOGS
                          Expanded(
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                physics: const BouncingScrollPhysics(),
                                itemCount: pageDocs.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      pageDocs[index].data()
                                          as Map<String, dynamic>;
                                  final Timestamp? ts =
                                      data['timestamp'] as Timestamp?;
                                  final String timeStr = ts != null
                                      ? DateFormat(
                                          'yy-MM-dd HH:mm:ss',
                                        ).format(ts.toDate())
                                      : '00-00-00 00:00:00';

                                  final String action =
                                      data['action'] ??
                                      data['actionType'] ??
                                      'UNKNOWN';
                                  final String actor =
                                      data['actor'] ??
                                      data['actorEmail'] ??
                                      'SYSTEM';
                                  final String target =
                                      data['companyName'] ??
                                      data['targetCollection'] ??
                                      data['targetId'] ??
                                      data['tenantId'] ??
                                      '';
                                  final String details =
                                      data['details'] ??
                                      data['branchCode'] ??
                                      '';

                                  // 🚀 FIX: Removed 'final' so we can override it based on action triggers
                                  String severity =
                                      data['severity'] ??
                                      (action.startsWith('FRAUD')
                                          ? 'CRITICAL'
                                          : action.contains('SUSPEND')
                                          ? 'WARNING'
                                          : 'INFO');

                                  // 🚀 STRICT COLOR CODING LOGIC
                                  Color sevColor =
                                      Colors.lightBlueAccent; // INFO
                                  if (severity == 'WARNING' ||
                                      action.contains('LOCKED') ||
                                      action.contains('SUSPEND')) {
                                    sevColor = Colors.orangeAccent;
                                    severity = 'WARNING';
                                  }
                                  if (severity == 'CRITICAL' ||
                                      action.contains('REVOKE') ||
                                      action.contains('DELETE') ||
                                      action.contains('REMOVE')) {
                                    sevColor = Colors.redAccent;
                                    severity = 'CRITICAL';
                                  }

                                  // 🚀 SINGLE LINE CMD PROMPT FORMAT WITH HEAVY COLORS
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: SelectableText.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "[$timeStr] ",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "[$severity] ",
                                            style: TextStyle(
                                              color: sevColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "$action ",
                                            style: TextStyle(
                                              color: sevColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text: "by <$actor> ",
                                            style: const TextStyle(
                                              color: Colors.purpleAccent,
                                            ),
                                          ),
                                          if (target.isNotEmpty)
                                            TextSpan(
                                              text: "on [$target] ",
                                              style: const TextStyle(
                                                color: Colors.yellowAccent,
                                              ),
                                            ),
                                          TextSpan(
                                            text: "» $details",
                                            style: TextStyle(
                                              color: severity == 'CRITICAL'
                                                  ? Colors.red.shade200
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // ⏭️ PAGINATION FOOTER
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                              border: Border(
                                top: BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Showing ${startIndex + 1}-${endIndex} of ${docs.length} logs",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back_ios,
                                        size: 14,
                                        color: Colors.greenAccent,
                                      ),
                                      onPressed: _currentPage > 0
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      disabledColor: Colors.grey.shade800,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      "PAGE ${_currentPage + 1} / $totalPages",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.greenAccent,
                                      ),
                                      onPressed: _currentPage < totalPages - 1
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      disabledColor: Colors.grey.shade800,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
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
