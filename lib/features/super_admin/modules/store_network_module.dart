import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/store_network_provider.dart';
import '../providers/tenant_provider.dart';
import '../widgets/store_row_card.dart';
import '../screens/super_admin_screen.dart'; // Tokens

class StoreNetworkModule extends ConsumerWidget {
  const StoreNetworkModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storesStreamProvider);
    final tenantsAsync = ref.watch(tenantMasterProvider);
    final selectedFilter = ref.watch(storeTenantFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Network',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Global view of all branches across tenants.',
                    style: TextStyle(
                      color: EnterpriseColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Tenant Filter Dropdown
              tenantsAsync.maybeWhen(
                data: (tenants) {
                  return Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: EnterpriseColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: EnterpriseColors.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1A1A1A),
                        value: selectedFilter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: EnterpriseColors.textSecondary,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text('All Tenants'),
                          ),
                          ...tenants.map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.companyName),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            ref
                                .read(storeTenantFilterProvider.notifier)
                                .updateFilter(val);
                        },
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: storesAsync.when(
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (context, i) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 64,
                  decoration: BoxDecoration(
                    color: EnterpriseColors.surfaceGlass.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: EnterpriseColors.borderSubtle.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error: $e',
                      style: const TextStyle(color: Color(0xFFE53E3E)),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(storesStreamProvider),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (allStores) {
                // Client-side filter to avoid composite index errors
                final filteredStores = allStores.where((s) {
                  if (selectedFilter != 'ALL' &&
                      s['tenantId'] != selectedFilter)
                    return false;
                  return true;
                }).toList();

                final int total = filteredStores.length;
                final int active = filteredStores
                    .where((s) => s['isActive'] == true)
                    .length;
                final int inactive = total - active;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EnterpriseColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: EnterpriseColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$total Total Stores',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '• $active Active',
                            style: const TextStyle(
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '• $inactive Inactive',
                            style: const TextStyle(
                              color: Color(0xFFE53E3E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Store List
                    Expanded(
                      child: filteredStores.isEmpty
                          ? const Center(
                              child: Text(
                                'No stores found.',
                                style: TextStyle(
                                  color: EnterpriseColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredStores.length,
                              itemBuilder: (context, i) {
                                final store = filteredStores[i];

                                // Helper to find tenant name
                                String tName = 'Unknown';
                                tenantsAsync.whenData((tenants) {
                                  final match = tenants.where(
                                    (t) => t.id == store['tenantId'],
                                  );
                                  if (match.isNotEmpty)
                                    tName = match.first.companyName;
                                });

                                return StoreRowCard(
                                  store: store,
                                  tenantName: tName,
                                );
                              },
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
}
