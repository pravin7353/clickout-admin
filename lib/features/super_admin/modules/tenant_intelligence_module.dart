import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';
import '../providers/trust_score_provider.dart';
import '../widgets/add_tenant_dialog.dart';
import '../widgets/tenant_detail_panel.dart'; // ⚡ NEW: Panel Import
import '../screens/super_admin_screen.dart'; // Tokens

class TenantIntelligenceModule extends ConsumerStatefulWidget {
  const TenantIntelligenceModule({super.key});
  @override
  ConsumerState<TenantIntelligenceModule> createState() =>
      _TenantIntelligenceModuleState();
}

class _TenantIntelligenceModuleState
    extends ConsumerState<TenantIntelligenceModule> {
  String _search = '';
  String _planFilter = 'ALL';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Color _planColor(String plan) {
    if (plan == 'ENTERPRISE') return const Color(0xFF7F77DD);
    if (plan == 'PRO') return const Color(0xFF00C853);
    return const Color(0xFF378ADD);
  }

  Color _billingColor(String status) {
    if (status == 'SUSPENDED') return const Color(0xFFE53E3E);
    if (status == 'EXPIRED') return const Color(0xFFEF9F27);
    return const Color(0xFF00C853);
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(tenantMasterProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenant Intelligence',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All client workspaces on the ClickOut platform.',
                    style: TextStyle(
                      color: EnterpriseColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AddTenantDialog(),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Onboard Client',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: EnterpriseColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: EnterpriseColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.search,
                          color: EnterpriseColors.textSecondary,
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search company name...',
                            hintStyle: TextStyle(
                              color: EnterpriseColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (v) {
                            if (_debounceTimer?.isActive ?? false)
                              _debounceTimer!.cancel();
                            _debounceTimer = Timer(
                              const Duration(milliseconds: 500),
                              () {
                                setState(() => _search = v.toLowerCase());
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ...['ALL', 'BASIC', 'PRO', 'ENTERPRISE'].map((plan) {
                final isSelected = _planFilter == plan;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _planFilter = plan),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00C853)
                            : EnterpriseColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00C853)
                              : EnterpriseColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        plan,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : EnterpriseColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: tenantsAsync.when(
              loading: () => Column(
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 72,
                    decoration: BoxDecoration(
                      color: EnterpriseColors.surfaceGlass.withValues(
                        alpha: 0.5 - (index * 0.1).clamp(0.0, 0.5),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: EnterpriseColors.borderSubtle.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFE53E3E),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load tenants',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A201A),
                        side: const BorderSide(color: Color(0xFFE53E3E)),
                      ),
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFFE53E3E),
                        size: 16,
                      ),
                      onPressed: () => ref.invalidate(tenantMasterProvider),
                      label: const Text(
                        'Retry Connection',
                        style: TextStyle(color: Color(0xFFE53E3E)),
                      ),
                    ),
                  ],
                ),
              ),
              data: (tenants) {
                final filtered = tenants.where((t) {
                  final matchSearch = t.companyName.toLowerCase().contains(
                    _search,
                  );
                  final matchPlan =
                      _planFilter == 'ALL' || t.plan == _planFilter;
                  return matchSearch && matchPlan;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No tenants found.',
                      style: TextStyle(color: EnterpriseColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    return GestureDetector(
                      onTap: () {
                        // ⚡ Trigger Slide-in Panel from Right Edge
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: "Dismiss",
                          barrierColor: Colors.black54,
                          transitionDuration: const Duration(milliseconds: 300),
                          pageBuilder: (context, anim1, anim2) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Material(
                                child: TenantDetailPanel(tenant: t),
                              ),
                            );
                          },
                          transitionBuilder: (context, anim1, anim2, child) {
                            return SlideTransition(
                              position:
                                  Tween(
                                    begin: const Offset(1, 0),
                                    end: const Offset(0, 0),
                                  ).animate(
                                    CurvedAnimation(
                                      parent: anim1,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                              child: child,
                            );
                          },
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: EnterpriseColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: EnterpriseColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _planColor(
                                  t.plan,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  t.companyName.isNotEmpty
                                      ? t.companyName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: _planColor(t.plan),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.companyName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.id,
                                    style: const TextStyle(
                                      color: EnterpriseColors.textSecondary,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _planColor(
                                  t.plan,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t.plan,
                                style: TextStyle(
                                  color: _planColor(t.plan),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _billingColor(
                                  t.billingStatus,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t.billingStatus,
                                style: TextStyle(
                                  color: _billingColor(t.billingStatus),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final trustAsync = ref.watch(
                                  trustScoreProvider(t.id),
                                );
                                return trustAsync.when(
                                  loading: () => const SizedBox(
                                    width: 60,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => const SizedBox.shrink(),
                                  data: (score) {
                                    if (score == null)
                                      return const SizedBox.shrink();
                                    final Color scoreColor = score >= 90
                                        ? const Color(0xFF00C853)
                                        : (score >= 70
                                              ? const Color(0xFFEF9F27)
                                              : const Color(0xFFE53E3E));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scoreColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            color: scoreColor,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${score.toStringAsFixed(0)}% Trust',
                                            style: TextStyle(
                                              color: scoreColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final trustAsync = ref.watch(
                                  trustScoreProvider(t.id),
                                );
                                return trustAsync.when(
                                  loading: () => const SizedBox(
                                    width: 60,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  error: (_, __) => const SizedBox.shrink(),
                                  data: (score) {
                                    if (score == null)
                                      return const SizedBox.shrink();
                                    final Color scoreColor = score >= 90
                                        ? const Color(0xFF00C853)
                                        : (score >= 70
                                              ? const Color(0xFFEF9F27)
                                              : const Color(0xFFE53E3E));
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scoreColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified,
                                            color: scoreColor,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${score.toStringAsFixed(0)}% Trust',
                                            style: TextStyle(
                                              color: scoreColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${t.maxStores}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const Text(
                                  'stores',
                                  style: TextStyle(
                                    color: EnterpriseColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
                                  style: const TextStyle(
                                    color: EnterpriseColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const Text(
                                  'joined',
                                  style: TextStyle(
                                    color: EnterpriseColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: EnterpriseColors.textSecondary,
                              size: 18,
                            ),
                          ],
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
    );
  }
}
