import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 SAAS INJECTION

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

  // 🚀 L1/L2 ISOLATION VARIABLES
  String? _selectedBranchCode;
  List<Map<String, dynamic>> _myStores = [];
  bool _isInitialized = false;

  // 🚀 SYNTAX FIX
  final List<String> _campaignTypes = [
    'DATA_COLLECTION',
    'CROSS_SELL',
    'SENSOR_GAME',
  ];

  // 🚀 INITIALIZE STORES FOR L1/L2/SUPER_ADMIN
  Future<void> _setupStores(Map<String, dynamic> roleData) async {
    final tenantId = roleData['tenantId'];
    final role = roleData['role'];
    final userBranch = roleData['branchCode'];

    if (role == 'SUPER_ADMIN') {
      // 🚀 SUPER ADMIN: Fetch ALL stores globally across the platform!
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
    final branchCode = _selectedBranchCode!; // 🚀 Apply selected branch

    // 🚀 FIX FOR SUPER ADMIN: Extract actual tenantId directly from the selected store!
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
      // 🚀 Step 1: Deactivate all existing campaigns for this tenant
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

      // 🚀 Step 2: Push new campaign
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
            content: Text("🚀 Campaign live on Customer App!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 800;

    Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: CONTROLS
        Expanded(flex: 3, child: _buildControlsForm(isDark)),
        if (!isMobile) const SizedBox(width: 30),
        // RIGHT: LIVE PREVIEW
        if (!isMobile) Expanded(flex: 2, child: _buildLivePreview(isDark)),
      ],
    );

    if (isMobile) {
      content = Column(
        children: [
          _buildControlsForm(isDark),
          const SizedBox(height: 30),
          _buildLivePreview(isDark),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? isDark
                ? const Color(0xFF080B08)
                : const Color(0xFFF4F7FE)
          : const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          "Campaign Manager 🎯",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark
            ? isDark
                  ? const Color(0xFF111811)
                  : Colors.white
            : const Color(0xFF2B3674),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }

  Widget _buildControlsForm(bool isDark) {
    final roleData = ref.watch(adminRoleProvider).value;
    if (roleData != null && !_isInitialized) {
      _isInitialized = true;
      Future.microtask(() => _setupStores(roleData));
    }

    final isManager =
        roleData?['role'] == 'MANAGER' || roleData?['role'] == 'STORE_MANAGER';
    final cardColor = isDark
        ? isDark
              ? const Color(0xFF111811)
              : Colors.white
        : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Engagement Task",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "This will instantly appear on the Customer App's home screen.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // 🚀 TARGET STORE (L1/L2 ISOLATION)
            Text(
              "Target Store Branch",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            if (isManager)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "🔒 Locked to Branch: ${_selectedBranchCode ?? ''}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedBranchCode,
                dropdownColor: cardColor,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                items: _myStores
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s['branchCode'],
                        child: Text(
                          "${s['storeName'] ?? 'Store'} (${s['branchCode']})",
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBranchCode = v);
                },
              ),
            const SizedBox(height: 20),

            // CAMPAIGN TYPE
            Text(
              "Campaign Strategy",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              dropdownColor: cardColor,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _campaignTypes.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t, style: TextStyle(color: textColor)),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 20),

            // REWARD VALUE
            Text(
              "Reward/Offer Value",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rewardCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "e.g. 20% OFF or Free Coffee",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 20),

            // SPONSOR / BRAND
            Text(
              "Sponsor Brand / Store Name",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sponsorCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "e.g. VINOD HAIR STUDIO",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 24),

            // STATUS TOGGLE
            SwitchListTile(
              title: Text(
                "Set as Active",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: const Text("Replaces any currently running campaign."),
              value: _isActive,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 30),

            // SUBMIT
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF00C853)
                      : const Color(0xFF2B3674),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _saveCampaign,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "PUBLISH TO CUSTOMER APP 🚀",
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

  // 🚀 LIVE PREVIEW (Mirrors Customer App UI)
  Widget _buildLivePreview(bool isDark) {
    String title = "Exclusive Offer";
    String sub = "Complete task to unlock";
    IconData icon = Icons.star_rounded;
    Color color = Colors.orange;

    final type = _selectedType;
    final reward = _rewardCtrl.text.isEmpty ? 'Reward' : _rewardCtrl.text;
    final sponsor = _sponsorCtrl.text.isEmpty ? 'Partner' : _sponsorCtrl.text;

    if (type == 'DATA_COLLECTION') {
      title = "Complete Profile";
      sub = "Get $reward from $sponsor";
      icon = Icons.card_giftcard_rounded;
      color = const Color(0xFFE53E3E);
    } else if (type == 'CROSS_SELL') {
      title = "Hot Nearby!";
      sub = "Claim $reward at $sponsor";
      icon = Icons.local_fire_department_rounded;
      color = const Color(0xFFF59E0B);
    } else if (type == 'SENSOR_GAME') {
      title = "Walk & Win";
      sub = "Unlock $reward today!";
      icon = Icons.directions_walk_rounded;
      color = const Color(0xFF22C55E);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "CUSTOMER APP PREVIEW",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 2,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 344,
          width: 250, // Mobile width constraint
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
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
                  "Unlock Now",
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
}
