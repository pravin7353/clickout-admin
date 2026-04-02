import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart'; // 🚀 Added for Tenant ID
import 'providers/churn_engine_service.dart';

class ChurnDashboardScreen extends ConsumerWidget {
  const ChurnDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churnState = ref.watch(churnEngineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF080B08) : const Color(0xFFF4F6F8);
    final themeNavy = isDark
        ? const Color(0xFF00C853)
        : const Color(0xFF2B3674);
    final textColor = isDark ? Colors.white : const Color(0xFF2B3674);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Growth & Retention Radar 🎯",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: isDark ? const Color(0xFF111811) : themeNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const ShopGrowthSetupDialog(),
            ),
            tooltip: "Shop Growth Setup",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(churnEngineProvider),
            tooltip: "Rescan Database",
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(
          MediaQuery.of(context).size.width < 600 ? 16.0 : 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "VIP Customers At Risk (Churn Detection)",
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Smart AI checks average visit cycles to identify high-value users who might be abandoning your store.",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // 🚀 STEP 3: WARNING BANNER IF NO CONFIG IS SAVED
            ref
                .watch(growthConfigStatusProvider)
                .when(
                  data: (hasConfig) => hasConfig
                      ? const SizedBox.shrink()
                      : Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.amber.shade700,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Action Required: Setup Growth Radar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.amber.shade400
                                            : Colors.amber.shade900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Your Growth Radar is using generic default settings. Set up your store category for accurate AI churn detection.",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) =>
                                      const ShopGrowthSetupDialog(),
                                ),
                                child: const Text(
                                  "SETUP NOW",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

            Expanded(
              child: churnState.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: themeNavy)),
                error: (err, stack) => Center(
                  child: Text(
                    "🚨 Error: $err",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (atRiskList) {
                  if (atRiskList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield,
                            size: 80,
                            color: Colors.green.withOpacity(0.5),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "Your Revenue is Safe! 🛡️",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "No VIPs are currently at risk of churning.",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 🚀 FIX: Properly defined the ListView inside a variable
                  Widget listViewWidget = ListView.builder(
                    itemCount: atRiskList.length,
                    itemBuilder: (context, index) {
                      final customer = atRiskList[index];
                      final bool isHighRisk = customer.riskLevel == 'HIGH';
                      final bool isMobile =
                          MediaQuery.of(context).size.width < 600;

                      Widget cardContent = Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isHighRisk
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_off,
                                color: isHighRisk ? Colors.red : Colors.orange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 10,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isHighRisk
                                              ? Colors.red
                                              : Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          "${customer.riskLevel} RISK",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // 🔒 PRIVACY LOCK: Manager cannot see customer phone numbers
                                  /* 
                                  Text(
                                    "📱 ${customer.phone}",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  */
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(
                                        isDark ? 0.2 : 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.redAccent.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.redAccent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          "Potential Loss: ₹${customer.expectedLoss.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "LTV: ₹${customer.totalSpent.toStringAsFixed(0)}  |  Total Visits: ${customer.totalVisits}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Last Visit: ${DateFormat('dd MMM yyyy').format(customer.lastVisit)}",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isMobile) const SizedBox(height: 15),
                                ],
                              ),
                            ),
                            if (!isMobile)
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? const Color(0xFF00C853)
                                          : Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => _showWinbackDialog(
                                      context,
                                      ref,
                                      customer,
                                    ),
                                    icon: const Icon(
                                      Icons
                                          .notifications_active, // 🔔 Changed Icon
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "SEND NOTIFICATION", // 🚀 Changed Text
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "via Client App Push", // 🚀 Changed Text
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );

                      return Card(
                        color: isDark ? const Color(0xFF111811) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: isHighRisk
                                ? Colors.redAccent.withOpacity(
                                    isDark ? 0.5 : 0.3,
                                  )
                                : Colors.orangeAccent.withOpacity(
                                    isDark ? 0.5 : 0.3,
                                  ),
                            width: 2,
                          ),
                        ),
                        elevation: isDark ? 0 : 3,
                        child: isMobile
                            ? Column(
                                children: [
                                  cardContent,
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      bottom: 20,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? const Color(0xFF00C853)
                                              : Colors.green,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _showWinbackDialog(
                                          context,
                                          ref,
                                          customer,
                                        ),
                                        icon: const Icon(
                                          Icons
                                              .notifications_active, // 🔔 Changed Icon
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "SEND APP NOTIFICATION", // 🚀 Changed Text
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : cardContent,
                      );
                    },
                  );

                  return Column(
                    children: [
                      Expanded(
                        child: listViewWidget,
                      ), // 🚀 Using the correct variable here
                      if (atRiskList.length >= 50)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B3674), Colors.black87],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                color: Colors.amber,
                                size: 30,
                              ),
                              const SizedBox(width: 15),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Unlock 150+ More At-Risk VIPs",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Your current plan shows the top 50 VIPs. Upgrade to ClickOut Pro to save your entire customer base.",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {},
                                child: const Text(
                                  "UPGRADE NOW",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWinbackDialog(
    BuildContext context,
    WidgetRef ref,
    VIPCustomer customer,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111811) : Colors.white,
              title: Text(
                "Trigger Win-Back Campaign 🎯",
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              content: Text(
                "Send a Push Notification with a 'COMEBACK20' (20% OFF) coupon to ${customer.name}'s ClickOut app? This will lock them from receiving further spam.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          setState(() => isSending = true);
                          try {
                            await ref
                                .read(churnEngineProvider.notifier)
                                .sendWinbackCoupon(customer.id, customer.name);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Win-back Coupon Sent Successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => isSending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Yes, Send Coupon",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// 🚀 ENTERPRISE SHOP GROWTH SETUP DIALOG (CATEGORY-AWARE AI)
// ============================================================================

class CategoryConfig {
  final String name;
  final IconData icon;
  final int cycle;
  final double high;
  final double med;
  final double vip;

  CategoryConfig(
    this.name,
    this.icon,
    this.cycle,
    this.high,
    this.med,
    this.vip,
  );
}

class ShopGrowthSetupDialog extends ConsumerStatefulWidget {
  const ShopGrowthSetupDialog({super.key});

  @override
  ConsumerState<ShopGrowthSetupDialog> createState() =>
      _ShopGrowthSetupDialogState();
}

class _ShopGrowthSetupDialogState extends ConsumerState<ShopGrowthSetupDialog> {
  final List<CategoryConfig> categories = [
    CategoryConfig('Grocery', Icons.shopping_cart, 15, 3.0, 2.0, 2000),
    CategoryConfig('Apparel & Fashion', Icons.checkroom, 60, 2.5, 1.8, 5000),
    CategoryConfig('Electronics', Icons.devices, 180, 2.0, 1.5, 25000),
    CategoryConfig(
      'Health & Beauty',
      Icons.health_and_safety,
      30,
      2.5,
      1.8,
      3000,
    ),
    CategoryConfig('Home & Furniture', Icons.chair, 365, 1.5, 1.2, 50000),
    CategoryConfig('Hardware & DIY', Icons.handyman, 90, 2.5, 1.8, 4000),
    CategoryConfig('Footwear', Icons.do_not_step, 120, 2.0, 1.5, 4000),
    CategoryConfig('Toys & Hobbies', Icons.toys, 45, 2.5, 1.8, 2000),
    CategoryConfig('Pet Care', Icons.pets, 30, 2.0, 1.5, 1500),
    CategoryConfig('Auto Parts', Icons.directions_car, 180, 2.0, 1.5, 8000),
    CategoryConfig('Jewelry & Luxury', Icons.diamond, 365, 2.0, 1.5, 100000),
    CategoryConfig(
      'Sports & Outdoors',
      Icons.sports_basketball,
      90,
      2.5,
      1.8,
      5000,
    ),
    CategoryConfig('Liquor & Beverages', Icons.liquor, 7, 3.0, 2.0, 1500),
    CategoryConfig('Food & Beverage', Icons.restaurant, 15, 2.5, 1.5, 1000),
    CategoryConfig('Salons & Wellness', Icons.spa, 30, 2.5, 1.8, 2000),
    CategoryConfig('Custom', Icons.edit, 30, 2.5, 2.0, 2000),
  ];

  late CategoryConfig selectedCategory;
  int _cycleDays = 30;
  double _highMult = 2.5;
  double _medMult = 2.0;
  double _vipThresh = 2000;
  bool _isLoading = false;
  final TextEditingController _customCategoryCtrl = TextEditingController();

  // 🚀 PER-STORE LOGIC VARIABLES
  List<Map<String, dynamic>> _myStores = [];
  String? _selectedBranchCode;
  bool _isInitialized = false; // 🚀 ADDED: To prevent Race Conditions

  @override
  void initState() {
    super.initState();
    selectedCategory = categories.first;
    _applyCategory(selectedCategory);
    // 🚀 REMOVED synchronous fetch from here
  }

  Future<void> _setupInitialData(Map<String, dynamic> userRoleData) async {
    final tenantId = userRoleData['tenantId'];
    final role = userRoleData['role'];
    final userBranch =
        userRoleData['branchCode']; // Store Manager ki apni branch

    if (role == 'MANAGER' ||
        role == 'STORE_MANAGER' ||
        role == 'GUARD' ||
        role == 'CASHIER') {
      if (mounted && userBranch != null) {
        setState(() {
          _selectedBranchCode = userBranch;
          _myStores = [
            {'branchCode': userBranch, 'storeName': 'Your Store'},
          ];
        });
        _loadExistingConfig(userBranch);
      }
    } else {
      // 🚀 TENANT/SUPER ADMIN LOGIC: Fetch all stores for the dropdown
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
            _loadExistingConfig(_selectedBranchCode!);
          }
        });
      }
    }
  }

  void _applyCategory(CategoryConfig c) {
    setState(() {
      selectedCategory = c;
      _cycleDays = c.cycle;
      _highMult = c.high;
      _medMult = c.med;
      _vipThresh = c.vip;
      if (c.name != 'Custom') _customCategoryCtrl.clear();
    });
  }

  Future<void> _loadExistingConfig(String branchCode) async {
    final tenantId = ref.read(adminRoleProvider).value?['tenantId'];
    if (tenantId == null) return;

    try {
      // 🚀 ROOT COLLECTION READ
      final docId = "${tenantId}_$branchCode";
      final doc = await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          String dbCat = data['businessType'] ?? 'Grocery';
          var catMatch = categories.where((c) => c.name == dbCat);

          if (catMatch.isNotEmpty) {
            selectedCategory = catMatch.first;
          } else {
            selectedCategory = categories.last; // Custom
            _customCategoryCtrl.text = dbCat;
          }

          _cycleDays = data['expectedCycleDays'] ?? 30;
          _highMult = (data['churnMultiplierHigh'] ?? 2.5).toDouble();
          _medMult = (data['churnMultiplierMedium'] ?? 2.0).toDouble();
          _vipThresh = (data['vipThreshold'] ?? 2000).toDouble();
        });
      } else {
        // Reset to default if no config exists for this branch
        _applyCategory(categories.first);
      }
    } catch (e) {
      debugPrint("No config found: $e");
    }
  }

  Future<void> _saveConfig() async {
    final tenantId = ref.read(adminRoleProvider).value?['tenantId'];
    if (tenantId == null || _selectedBranchCode == null) return;

    if (selectedCategory.name == 'Custom' &&
        _customCategoryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a custom category name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final finalCategoryName = selectedCategory.name == 'Custom'
          ? _customCategoryCtrl.text.trim()
          : selectedCategory.name;

      // 🚀 THE ULTIMATE FIX: ROOT COLLECTION WRITE (tenantId_branchCode)
      final docId = "${tenantId}_$_selectedBranchCode";
      await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc(docId)
          .set({
            'tenantId': tenantId,
            'branchCode': _selectedBranchCode,
            'businessType': finalCategoryName,
            'expectedCycleDays': _cycleDays,
            'churnMultiplierHigh': _highMult,
            'churnMultiplierMedium': _medMult,
            'vipThreshold': _vipThresh,
            'couponHigh': "20%",
            'couponMed': "10%",
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Store AI Profile Updated Successfully! 🚀"),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(churnEngineProvider);
        ref.invalidate(growthConfigStatusProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleData = ref.watch(adminRoleProvider).value;

    // 🚀 THE MAGIC FIX: Wait for provider to load, then initialize safely!
    if (roleData != null && !_isInitialized) {
      _isInitialized = true;
      Future.microtask(() => _setupInitialData(roleData));
    }

    // 🚀 SMART ROLE CHECK
    final role = roleData?['role'];
    final isViewOnly = role == 'TENANT_ADMIN' || role == 'SUPER_ADMIN';
    final isManager =
        role == 'MANAGER' ||
        role == 'STORE_MANAGER' ||
        role == 'GUARD' ||
        role == 'CASHIER';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDark = isDark ? const Color(0xFF111811) : Colors.white;
    final cardDark = isDark ? const Color(0xFF1A221A) : Colors.grey.shade50;
    final textPrimary = isDark ? Colors.white : const Color(0xFF2B3674);
    final textSecondary = isDark ? Colors.white70 : Colors.grey.shade700;
    final accentGreen = isDark ? const Color(0xFF00C853) : Colors.green;
    final w = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: bgDark,
      insetPadding: EdgeInsets.all(w < 600 ? 10 : 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Container(
        width: w < 600 ? double.infinity : 900,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
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
                      "Store Growth Setup",
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Configure AI churn rules per specific store branch",
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🚀 SMART TARGET STORE SELECTOR (UI changes based on Role)
            if (isManager)
              // 🔒 MANAGER VIEW: No dropdown, store is permanently locked to their branch
              Container(
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentGreen.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store_mall_directory, color: accentGreen),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Target Store (Auto-Assigned)",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedBranchCode ?? "Loading...",
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "LOCKED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // 🚁 TENANT VIEW: Dropdown is active so they can switch and view different stores
              Container(
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentGreen.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.store, color: accentGreen),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBranchCode,
                          dropdownColor: cardDark,
                          isExpanded: true,
                          hint: Text(
                            "Select a Store to View Config",
                            style: TextStyle(color: textSecondary),
                          ),
                          items: _myStores.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['branchCode'],
                              child: Text(
                                "${s['storeName'] ?? 'Store'} (${s['branchCode']})",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBranchCode = val);
                              _loadExistingConfig(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SELECT BUSINESS CATEGORY FOR THIS STORE",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🚀 CATEGORY GRID
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: w < 600 ? 2 : (w < 900 ? 3 : 4),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final c = categories[index];
                        final isSelected = c == selectedCategory;
                        return InkWell(
                          onTap: isViewOnly ? null : () => _applyCategory(c),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentGreen.withOpacity(0.1)
                                  : cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? accentGreen
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  c.icon,
                                  color: isSelected
                                      ? accentGreen
                                      : (c.name == 'Custom'
                                            ? Colors.blue
                                            : Colors.amber),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? accentGreen
                                          : textPrimary,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    if (selectedCategory.name == 'Custom') ...[
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _customCategoryCtrl,
                        readOnly: isViewOnly, // 🔒 Locked
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: "Enter Custom Category Name",
                          labelStyle: TextStyle(color: textSecondary),
                          filled: true,
                          fillColor: cardDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 25),

                    // 🚀 PREVIEW CARDS
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Expected visit cycle",
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "$_cycleDays days",
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "VIP threshold",
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "₹${_vipThresh.toInt()}",
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // 🚀 SLIDERS (CUSTOMIZE CYCLE DAYS)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CUSTOMIZE ENGINE LOGIC",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 🚀 ADDED 'divisions' para for strict snapping steps! (e.g. 199 steps = ₹500 chunks)
                          // 🔒 Sliders Locked if View-Only
                          _buildSliderRow(
                            "Expected visit cycle (days)",
                            _cycleDays.toDouble(),
                            1,
                            365,
                            364,
                            isViewOnly
                                ? null
                                : (v) => setState(() => _cycleDays = v.toInt()),
                            "${_cycleDays}d",
                            textPrimary,
                          ),
                          _buildSliderRow(
                            "High risk trigger (beyond cycle)",
                            _highMult,
                            1.5,
                            5.0,
                            35,
                            isViewOnly
                                ? null
                                : (v) {
                                    if (v > _medMult) {
                                      setState(() => _highMult = v);
                                    }
                                  },
                            "${_highMult.toStringAsFixed(1)}x",
                            textPrimary,
                          ),
                          _buildSliderRow(
                            "Medium risk trigger (beyond cycle)",
                            _medMult,
                            1.1,
                            4.9,
                            38,
                            isViewOnly
                                ? null
                                : (v) {
                                    if (v < _highMult) {
                                      setState(() => _medMult = v);
                                    }
                                  },
                            "${_medMult.toStringAsFixed(1)}x",
                            textPrimary,
                          ),
                          _buildSliderRow(
                            "VIP spend threshold (₹)",
                            _vipThresh,
                            500,
                            100000,
                            199,
                            isViewOnly
                                ? null
                                : (v) => setState(() => _vipThresh = v),
                            "₹${_vipThresh.toInt()}",
                            textPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 🚀 AUTO-CALCULATED RESULTS
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "RISK THRESHOLDS (AUTO-CALCULATED)",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildCalcRow(
                            "High risk fires after",
                            "${(_cycleDays * _highMult).toInt()} days no visit",
                            Colors.redAccent,
                            textPrimary,
                          ),
                          const Divider(height: 30, color: Colors.white12),
                          _buildCalcRow(
                            "Medium risk fires after",
                            "${(_cycleDays * _medMult).toInt()} days no visit",
                            Colors.orangeAccent,
                            textPrimary,
                          ),
                          const Divider(height: 30, color: Colors.white12),
                          _buildCalcRow(
                            "Coupon — high risk",
                            "20% off",
                            textPrimary,
                            textPrimary,
                          ),
                          const Divider(height: 30, color: Colors.white12),
                          _buildCalcRow(
                            "Coupon — medium risk",
                            "10% off",
                            textPrimary,
                            textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🚀 ACTION BUTTON / VIEW ONLY STATE
            Container(
              padding: const EdgeInsets.only(top: 20),
              width: double.infinity,
              child: isViewOnly
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "View-Only Mode (Store Managers configure this)",
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white
                            : const Color(0xFF2B3674),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (_isLoading || _selectedBranchCode == null)
                          ? null
                          : _saveConfig,
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
                              "Save AI config for this store ↗",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 🚀 ADDED int 'divisions' parameter to enable strict stepping
  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    void Function(double)? onChanged,
    String trailText,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: Colors.grey.shade500,
                  inactiveTrackColor: Colors.grey.shade300.withOpacity(0.2),
                  thumbColor: Colors.grey.shade400,
                  overlayColor: Colors.grey.withOpacity(0.1),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ), // 🎯 Snap lock active!
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                trailText,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalcRow(
    String label,
    String value,
    Color valueColor,
    Color textColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
