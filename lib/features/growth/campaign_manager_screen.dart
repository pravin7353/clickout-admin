import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class CampaignManagerScreen extends ConsumerStatefulWidget {
  const CampaignManagerScreen({super.key});

  @override
  ConsumerState<CampaignManagerScreen> createState() =>
      _CampaignManagerScreenState();
}

class _CampaignManagerScreenState extends ConsumerState<CampaignManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  String _selectedType = 'DATA_COLLECTION';
  final _rewardCtrl = TextEditingController(text: '20% OFF');
  final _sponsorCtrl = TextEditingController(text: 'Your Store');
  bool _isActive = true;
  bool _isLoading = false;

  String? _selectedBranchCode;
  List<Map<String, dynamic>> _myStores = [];
  bool _isInitialized = false;

  final List<String> _campaignTypes = [
    'DATA_COLLECTION',
    'CROSS_SELL',
    'SENSOR_GAME',
  ];

  Future<void> _setupStores(Map<String, dynamic> roleData) async {
    final tenantId = roleData['tenantId'];
    final role = roleData['role'];
    final userBranch = roleData['branchCode'];

    if (role == 'SUPER_ADMIN') {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('isDeleted', isNotEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _myStores = snap.docs.map((d) => d.data()).toList();
          if (_myStores.isNotEmpty) {
            _selectedBranchCode = _myStores.first['branchCode'];
          }
        });
      }
    } else if (role == 'MANAGER' ||
        role == 'STORE_MANAGER' ||
        role == 'GUARD') {
      if (mounted) {
        setState(() {
          _selectedBranchCode = userBranch;
          _myStores = [
            {
              'branchCode': userBranch,
              'storeName': 'Your Store',
              'tenantId': tenantId,
            },
          ];
        });
      }
    } else {
      final snap = await FirebaseFirestore.instance
          .collection('stores')
          .where('tenantId', isEqualTo: tenantId)
          .where('isDeleted', isNotEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _myStores = snap.docs.map((d) => d.data()).toList();
          if (_myStores.isNotEmpty) {
            _selectedBranchCode = _myStores.first['branchCode'];
          }
        });
      }
    }
  }

  Future<void> _saveCampaign() async {
    if (!_formKey.currentState!.validate() || _selectedBranchCode == null) {
      return;
    }

    final roleData = ref.read(adminRoleProvider).value;
    final branchCode = _selectedBranchCode!;

    final selectedStore = _myStores.firstWhere(
      (s) => s['branchCode'] == branchCode,
      orElse: () => {},
    );
    final targetTenantId = selectedStore['tenantId'] ?? roleData?['tenantId'];

    if (targetTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Target Tenant Identity Missing")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isActive) {
        final activeSnaps = await _db
            .collection('engagement_campaigns')
            .where('tenantId', isEqualTo: targetTenantId)
            .where('branchCode', isEqualTo: branchCode)
            .where('isActive', isEqualTo: true)
            .get();

        final batch = _db.batch();
        for (var doc in activeSnaps.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
      }

      final newDoc = _db.collection('engagement_campaigns').doc();
      await newDoc.set({
        'campaignId': newDoc.id,
        'tenantId': targetTenantId,
        'branchCode': branchCode,
        'type': _selectedType,
        'rewardValue': _rewardCtrl.text.trim(),
        'sponsorTenantId': _sponsorCtrl.text.trim(),
        'isActive': _isActive,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Campaign live on Customer App!"),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $e"),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCampaign(String campaignId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Campaign?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'This will permanently delete this campaign.',
          style: TextStyle(
            color: Theme.of(context).textTheme.labelLarge?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('engagement_campaigns').doc(campaignId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Campaign deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleActive(
    String campaignId,
    String tenantId,
    String branchCode,
    bool currentlyActive,
  ) async {
    try {
      if (!currentlyActive) {
        // Deactivate all others first
        final activeSnaps = await _db
            .collection('engagement_campaigns')
            .where('tenantId', isEqualTo: tenantId)
            .where('branchCode', isEqualTo: branchCode)
            .where('isActive', isEqualTo: true)
            .get();
        final batch = _db.batch();
        for (var doc in activeSnaps.docs) {
          batch.update(doc.reference, {'isActive': false});
        }
        await batch.commit();
      }
      await _db.collection('engagement_campaigns').doc(campaignId).update({
        'isActive': !currentlyActive,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 800;

    final roleData = ref.watch(adminRoleProvider).value;
    if (roleData != null && !_isInitialized) {
      _isInitialized = true;
      Future.microtask(() => _setupStores(roleData));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Campaign Manager 🎯',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: isMobile
            ? Column(
                children: [
                  _buildControlsForm(roleData),
                  const SizedBox(height: 24),
                  _buildLivePreview(),
                  const SizedBox(height: 24),
                  _buildCampaignHistory(roleData),
                ],
              )
            : Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildControlsForm(roleData)),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildLivePreview()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCampaignHistory(roleData),
                ],
              ),
      ),
    );
  }

  Widget _buildControlsForm(Map<String, dynamic>? roleData) {
    final isManager =
        roleData?['role'] == 'MANAGER' || roleData?['role'] == 'STORE_MANAGER';
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Engagement Task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'This will instantly appear on the Customer App\'s home screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            // Target Store
            Text(
              'TARGET STORE BRANCH',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            if (isManager)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '🔒 Locked to Branch: ${_selectedBranchCode ?? ''}',
                  style: const TextStyle(
                    color: const Color(0xFF22C55E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedBranchCode,
                dropdownColor: Theme.of(context).cardColor,
                decoration: const InputDecoration(),
                items: _myStores
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s['branchCode'],
                        child: Text(
                          "${s['storeName'] ?? 'Store'} (${s['branchCode']})",
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBranchCode = v);
                },
              ),
            const SizedBox(height: 20),

            // Campaign Type
            Text(
              'CAMPAIGN STRATEGY',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedType,
              dropdownColor: Theme.of(context).cardColor,
              decoration: const InputDecoration(),
              items: _campaignTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 20),

            // Reward
            Text(
              'REWARD / OFFER VALUE',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rewardCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. 20% OFF or Free Coffee',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            // Sponsor
            Text(
              'SPONSOR BRAND / STORE NAME',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sponsorCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. VINOD HAIR STUDIO',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            // Toggle
            SwitchListTile(
              title: Text(
                'Set as Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                'Replaces any currently running campaign.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: _isActive,
              activeColor: const Color(0xFF22C55E),
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCampaign,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'PUBLISH TO CUSTOMER APP 🚀',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    String title = 'Exclusive Offer';
    String sub = 'Complete task to unlock';
    IconData icon = Icons.star_rounded;
    Color color = Colors.orange;

    final reward = _rewardCtrl.text.isEmpty ? 'Reward' : _rewardCtrl.text;
    final sponsor = _sponsorCtrl.text.isEmpty ? 'Partner' : _sponsorCtrl.text;

    if (_selectedType == 'DATA_COLLECTION') {
      title = 'Complete Profile';
      sub = 'Get $reward from $sponsor';
      icon = Icons.card_giftcard_rounded;
      color = AppTheme.danger;
    } else if (_selectedType == 'CROSS_SELL') {
      title = 'Hot Nearby!';
      sub = 'Claim $reward at $sponsor';
      icon = Icons.local_fire_department_rounded;
      color = AppTheme.warning;
    } else if (_selectedType == 'SENSOR_GAME') {
      title = 'Walk & Win';
      sub = 'Unlock $reward today!';
      icon = Icons.directions_walk_rounded;
      color = AppTheme.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'CUSTOMER APP PREVIEW',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontSize: 11, letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        Container(
          height: 320,
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Unlock Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignHistory(Map<String, dynamic>? roleData) {
    if (_selectedBranchCode == null) return const SizedBox.shrink();

    final selectedStore = _myStores.firstWhere(
      (s) => s['branchCode'] == _selectedBranchCode,
      orElse: () => {},
    );
    final tenantId = selectedStore['tenantId'] ?? roleData?['tenantId'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Campaign History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedBranchCode ?? '',
                  style: const TextStyle(
                    color: const Color(0xFF22C55E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('engagement_campaigns')
                .where('tenantId', isEqualTo: tenantId)
                .where('branchCode', isEqualTo: _selectedBranchCode)
                .orderBy(
                  'createdAt',
                  descending: true,
                ) // ⚡ Restored: Native Indexing
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading campaigns',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                );
              }

              final docs =
                  snapshot.data?.docs ??
                  []; // ⚡ Removed: Client-side sorting workaround

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 40,
                          color: Theme.of(context).textTheme.labelLarge?.color,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No campaigns yet. Create one above!',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isActive = data['isActive'] == true;
                  final type = data['type'] ?? '';
                  final reward = data['rewardValue'] ?? '';
                  final sponsor = data['sponsorTenantId'] ?? '';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null
                      ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                      : 'Pending...';

                  Color typeColor = const Color(0xFF378ADD);
                  if (type == 'DATA_COLLECTION') typeColor = AppTheme.danger;
                  if (type == 'CROSS_SELL') typeColor = AppTheme.warning;
                  if (type == 'SENSOR_GAME') typeColor = AppTheme.success;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF22C55E).withOpacity(0.4)
                            : Theme.of(context).dividerColor,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Active dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF22C55E)
                                : Theme.of(context).dividerColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$sponsor · $dateStr',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Toggle active
                        GestureDetector(
                          onTap: () => _toggleActive(
                            doc.id,
                            tenantId,
                            _selectedBranchCode!,
                            isActive,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF22C55E).withOpacity(0.1)
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive ? 'LIVE' : 'OFF',
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF22C55E)
                                    : Theme.of(
                                        context,
                                      ).textTheme.labelLarge?.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Delete
                        IconButton(
                          onPressed: () => _deleteCampaign(doc.id),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppTheme.danger,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
