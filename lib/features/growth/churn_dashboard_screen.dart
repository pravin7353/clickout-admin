import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'providers/churn_engine_service.dart';

class ChurnDashboardScreen extends ConsumerWidget {
  const ChurnDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churnState = ref.watch(churnEngineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF080B08)
        : const Color(0xFFF4F5F7); // 🚀 FIX: Premium Light Gray
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
              "Store Traffic & Retention Radar",
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Tracking all walk-ins, regular customers, and predicting churn for your VIPs.",
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

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
                            Icons.group_off_rounded,
                            size: 80,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "No Traffic Data Yet",
                            style: TextStyle(
                              fontSize: 20,
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Customers will appear here once they scan the store QR.",
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

                  final branchCode =
                      ref.watch(adminRoleProvider).value?['branchCode'] ??
                      "UNKNOWN";
                  int? sortColumnIndex;
                  bool sortAscending = true;
                  Set<String> selectedCustomerIds =
                      {}; // 🚀 NEW: Multi-select state

                  Widget listViewWidget = StatefulBuilder(
                    builder: (context, setLocalState) {
                      void onSort<T>(
                        Comparable<T> Function(VIPCustomer) getField,
                        int columnIndex,
                        bool ascending,
                      ) {
                        atRiskList.sort((a, b) {
                          final aValue = getField(a);
                          final bValue = getField(b);
                          return ascending
                              ? Comparable.compare(aValue, bValue)
                              : Comparable.compare(bValue, aValue);
                        });
                        setLocalState(() {
                          sortColumnIndex = columnIndex;
                          sortAscending = ascending;
                        });
                      }

                      return Column(
                        children: [
                          /*// 🚀 STEP 2: Bulk Action Bar
                          if (selectedCustomerIds.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1B251B)
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.green.shade900
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${selectedCustomerIds.length} Customers Selected",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.greenAccent
                                          : Colors.green.shade800,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.greenAccent.shade700
                                          : Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "Send Offer",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () => _showBulkOfferDialog(
                                      context,
                                      ref,
                                      selectedCustomerIds,
                                      setLocalState,
                                    ),
                                  ),
                                ],
                              ),
                            ),*/
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF111811)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DataTable(
                                    sortColumnIndex: sortColumnIndex,
                                    sortAscending: sortAscending,
                                    headingRowColor: WidgetStateProperty.all(
                                      isDark
                                          ? Colors.white10
                                          : Colors.grey.shade100,
                                    ), // 🚀 Luxury UI: Solid premium heading
                                    dataRowMinHeight: 55,
                                    dataRowMaxHeight: 55,
                                    columnSpacing: 25,
                                    horizontalMargin:
                                        20, // 🚀 Luxury UI: More space on sides
                                    columns: [
                                      DataColumn(
                                        label: Checkbox(
                                          value:
                                              selectedCustomerIds.length ==
                                                  atRiskList.length &&
                                              atRiskList.isNotEmpty,
                                          onChanged: (bool? checked) {
                                            setLocalState(() {
                                              if (checked == true) {
                                                selectedCustomerIds.addAll(
                                                  atRiskList.map((c) => c.id),
                                                );
                                              } else {
                                                selectedCustomerIds.clear();
                                              }
                                            });
                                          },
                                          activeColor: Colors.orange,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Customer Name",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        onSort: (col, asc) => onSort<String>(
                                          (c) => c.name.toLowerCase(),
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Branch",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Category",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        onSort: (col, asc) => onSort<String>(
                                          (c) => c.category,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Visits",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        numeric: true,
                                        onSort: (col, asc) => onSort<num>(
                                          (c) => c.totalVisits,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Last Visit",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        onSort: (col, asc) => onSort<DateTime>(
                                          (c) => c.lastVisit,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Total Spent",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        numeric: true,
                                        onSort: (col, asc) => onSort<num>(
                                          (c) => c.totalSpent,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Risk Level",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        onSort: (col, asc) => onSort<String>(
                                          (c) => c.riskLevel,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Expected Loss",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        numeric: true,
                                        onSort: (col, asc) => onSort<num>(
                                          (c) => c.expectedLoss,
                                          col,
                                          asc,
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          "Action",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: atRiskList.map((customer) {
                                      final bool isHighRisk =
                                          customer.riskLevel == 'HIGH';

                                      Widget categoryBadge = Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            customer.category == 'VIP'
                                                ? "👑 "
                                                : (customer.category ==
                                                          'CUSTOMER'
                                                      ? "👤 "
                                                      : "🚶 "),
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            customer.category == 'VIP'
                                                ? "VIP"
                                                : (customer.category ==
                                                          'CUSTOMER'
                                                      ? "Customer"
                                                      : "Dropout"),
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );

                                      Widget riskBadge = Text(
                                        "⚪ N/A",
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                      if (customer.category == 'VIP') {
                                        Color rColor = isHighRisk
                                            ? Colors.red
                                            : (customer.riskLevel == 'MEDIUM'
                                                  ? Colors.orange
                                                  : Colors.green);
                                        String rIcon = isHighRisk
                                            ? "🔴"
                                            : (customer.riskLevel == 'MEDIUM'
                                                  ? "🟠"
                                                  : "🟢");
                                        riskBadge = Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "$rIcon ",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              customer.riskLevel,
                                              style: TextStyle(
                                                color: rColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Checkbox(
                                              value: selectedCustomerIds
                                                  .contains(customer.id),
                                              onChanged: (bool? selected) {
                                                setLocalState(() {
                                                  if (selected == true) {
                                                    selectedCustomerIds.add(
                                                      customer.id,
                                                    );
                                                  } else {
                                                    selectedCustomerIds.remove(
                                                      customer.id,
                                                    );
                                                  }
                                                });
                                              },
                                              activeColor: Colors.orange,
                                            ),
                                          ),
                                          DataCell(
                                            customer.name == 'Anon'
                                                ? Tooltip(
                                                    message:
                                                        "Customer has not added personal details",
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.privacy_tip,
                                                          size: 14,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          "Anon",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Text(
                                                    customer.name,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textColor,
                                                    ),
                                                  ),
                                          ),
                                          DataCell(
                                            Text(
                                              customer.branchCode,
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          DataCell(categoryBadge),
                                          DataCell(
                                            Text(
                                              customer.totalVisits.toString(),
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                              ).format(customer.lastVisit),
                                              style: TextStyle(
                                                fontWeight: FontWeight
                                                    .w500, // 🚀 Luxury UI: Medium weight
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              "₹${customer.totalSpent.toStringAsFixed(0)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight
                                                    .bold, // 🚀 Luxury UI: Pure luxury bold text
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          DataCell(riskBadge),
                                          DataCell(
                                            Text(
                                              "₹${customer.expectedLoss.toStringAsFixed(0)}",
                                              style: TextStyle(
                                                color: customer.expectedLoss > 0
                                                    ? Colors.redAccent
                                                    : textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    customer.isPushEnabled
                                                    ? (isDark
                                                          ? const Color(
                                                              0xFF00C853,
                                                            )
                                                          : Colors.green)
                                                    : Colors.grey.shade600,
                                                textStyle: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _handlePushAction(
                                                    context,
                                                    ref,
                                                    customer,
                                                  ),
                                              child: Text(
                                                customer.pushCount >= 3
                                                    ? "[Max Limit]"
                                                    : "[Send Notification]",
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  return Column(children: [Expanded(child: listViewWidget)]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePushAction(
    BuildContext context,
    WidgetRef ref,
    VIPCustomer customer,
  ) {
    if (!customer.hasApp) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111811)
              : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.phonelink_erase, color: Colors.red),
              SizedBox(width: 10),
              Text("App Not Installed"),
            ],
          ),
          content: const Text(
            "APP NOT INSTALLED - PUSH UNAVAILABLE.\n\nThis customer hasn't logged into the ClickOut App yet. Notifications cannot be delivered.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }

    if (customer.pushCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ This customer has already received the maximum limit of 3 push notifications.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!customer.isPushEnabled) {
      // 🚀 STEP 4: Proper Modal instead of SnackBar if not reached
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111811)
              : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.lock_clock, color: Colors.orange),
              SizedBox(width: 10),
              Text("Trigger Not Reached"),
            ],
          ),
          content: Text(
            "The AI lifecycle trigger window has not opened for ${customer.name} yet.\n\nNext push unlocks 24 hours before their Level ${customer.maxAllowedPushes + 1} risk cycle.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Okay"),
            ),
          ],
        ),
      );
      return;
    }

    // 🚀 STEP 5: SMART DYNAMIC OFFER BUILDER (TIER BASED RECOMMENDATIONS)
    String shortId = customer.id.length >= 4
        ? customer.id.substring(customer.id.length - 4).toUpperCase()
        : customer.id.toUpperCase();

    String recOfferName = "Special Offer";
    String recDiscount = "10";
    String recCodeBase = "OFFER";
    Color tierColor = Colors.green;
    String tierTitle = "Level 0: Engagement";

    if (customer.pushCount == 0) {
      recOfferName = "Time for a visit! 🏪";
      recDiscount = "5";
      recCodeBase = "WLC"; // Welcome
      tierColor = Colors.blue;
      tierTitle = "Level 1: Welcome Routine";
    } else if (customer.pushCount == 1) {
      recOfferName = "Special 10% OFF inside! 🎁";
      recDiscount = "10";
      recCodeBase = "MIS"; // Miss You
      tierColor = Colors.orange;
      tierTitle = "Level 2: Medium Risk";
    } else {
      recOfferName = "Last Chance: VIP 20% OFF! 🔥";
      recDiscount = "20";
      recCodeBase = "VIP"; // High Risk
      tierColor = Colors.red;
      tierTitle = "Level 3: High Risk";
    }

    final offerNameCtrl = TextEditingController(text: recOfferName);
    final discountCtrl = TextEditingController(text: recDiscount);
    final codeCtrl = TextEditingController(text: "${recCodeBase}_$shortId");
    final expiryCtrl = TextEditingController(text: "3");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bgColor = isDark ? const Color(0xFF111811) : Colors.white;
            final inputBg = isDark
                ? const Color(0xFF1A221A)
                : Colors.grey.shade50;
            final textColor = isDark ? Colors.white : const Color(0xFF2B3674);

            return Dialog(
              backgroundColor:
                  Colors.transparent, // 🚀 Makes custom shape possible
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                width: 450, // 🚀 Fixed luxury width
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🚀 Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tierColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.rocket_launch_rounded,
                                  color: tierColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Targeted Push #${customer.pushCount + 1}",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: isSending
                                ? null
                                : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 🚀 Dynamic AI Recommendation Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tierColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: tierColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tierTitle,
                                    style: TextStyle(
                                      color: tierColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "AI pre-filled a $recDiscount% discount. Edit dynamically.",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🚀 Premium Input Fields
                      _buildLuxuryTextField(
                        "Offer Name",
                        Icons.local_offer_rounded,
                        offerNameCtrl,
                        inputBg,
                        textColor,
                        isDark,
                        (v) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLuxuryTextField(
                              "Discount %",
                              Icons.percent_rounded,
                              discountCtrl,
                              inputBg,
                              textColor,
                              isDark,
                              (v) => setState(() {}),
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLuxuryTextField(
                              "Valid (Days)",
                              Icons.timer_rounded,
                              expiryCtrl,
                              inputBg,
                              textColor,
                              isDark,
                              (v) => setState(() {}),
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildLuxuryTextField(
                        "Coupon Code",
                        Icons.qr_code_rounded,
                        codeCtrl,
                        inputBg,
                        textColor,
                        isDark,
                        (v) => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      // 🚀 Message Preview Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF151E15)
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.green.shade900
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Customer App Preview",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.greenAccent
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Hi ${customer.name}, use code ${codeCtrl.text.toUpperCase()} for ${discountCtrl.text}% OFF! Valid for ${expiryCtrl.text} days.",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🚀 Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isSending
                                  ? null
                                  : () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF00C853)
                                    : Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      setState(() => isSending = true);
                                      try {
                                        await ref
                                            .read(churnEngineProvider.notifier)
                                            .sendTargetedOffer(
                                              userId: customer.id,
                                              customerName: customer.name,
                                              currentPushCount:
                                                  customer.pushCount,
                                              offerName: offerNameCtrl.text,
                                              discountPercent:
                                                  double.tryParse(
                                                    discountCtrl.text,
                                                  ) ??
                                                  10.0,
                                              couponCode: codeCtrl.text
                                                  .toUpperCase()
                                                  .replaceAll(" ", ""),
                                              expiryDays:
                                                  int.tryParse(
                                                    expiryCtrl.text,
                                                  ) ??
                                                  3,
                                            );
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "✅ Push & Offer Delivered! (${3 - (customer.pushCount + 1)} left)",
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          setState(() => isSending = false);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Send Now",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.send_rounded, size: 16),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🚀 Premium Helper Widget (Add this right after _handlePushAction closes)
  Widget _buildLuxuryTextField(
    String label,
    IconData icon,
    TextEditingController controller,
    Color bg,
    Color textCol,
    bool isDark,
    Function(String) onChanged, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: textCol, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        filled: true,
        fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.greenAccent : Colors.green,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // 🚀 STEP 2: Bulk Offer Popup UI
  void _showBulkOfferDialog(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    StateSetter setParentState,
  ) {
    final offerNameCtrl = TextEditingController(text: "VIP Special Offer");
    final discountCtrl = TextEditingController(text: "15");
    final codeCtrl = TextEditingController(text: "VIP15");
    final expiryCtrl = TextEditingController(text: "7");
    bool isSending = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF111811) : Colors.white,
            title: const Text("Create Bulk Offer 🎁"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: offerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Offer Name",
                      prefixIcon: Icon(Icons.local_offer),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Discount %",
                      prefixIcon: Icon(Icons.percent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Coupon Code",
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expiryCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Valid for (Days)",
                      prefixIcon: Icon(Icons.timer),
                    ),
                  ),
                ],
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: isSending
                    ? null
                    : () async {
                        setState(() => isSending = true);
                        try {
                          await ref
                              .read(churnEngineProvider.notifier)
                              .sendBulkOffer(
                                targetUserIds: selectedIds,
                                offerName: offerNameCtrl.text,
                                discountPercent: double.parse(
                                  discountCtrl.text,
                                ),
                                couponCode: codeCtrl.text
                                    .toUpperCase()
                                    .replaceAll(" ", ""),
                                expiryDays: int.parse(expiryCtrl.text),
                              );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            setParentState(() => selectedIds.clear());
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "✅ Bulk Offers Sent Successfully!",
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
                                content: Text("🚨 Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Send to Users",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// 🚀 THE MAGIC: SHOP GROWTH SETUP DIALOG
// ============================================================================
class ShopGrowthSetupDialog extends ConsumerStatefulWidget {
  const ShopGrowthSetupDialog({super.key});

  @override
  ConsumerState<ShopGrowthSetupDialog> createState() =>
      _ShopGrowthSetupDialogState();
}

class _ShopGrowthSetupDialogState extends ConsumerState<ShopGrowthSetupDialog> {
  double _highRiskMult = 2.1;
  double _medRiskMult = 1.2;
  double _vipThreshold = 5000;
  String _businessType = "General Retail";
  final TextEditingController _customCategoryCtrl =
      TextEditingController(); // 🚀 NEW: Custom Input Controller
  final int _expectedCycleDays = 15;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  // 🚀 EXPANDED CATEGORIES: Added back the full enterprise list
  final List<String> _categories = [
    "General Retail",
    "Salons & Wellness",
    "IT Hardware",
    "IT Software",
    "Apparel & Fashion",
    "F&B / Restaurants",
    "Pharmacy / Medical",
    "Electronics & Appliances",
    "Home & Furniture",
    "Grocery & Supermarkets",
    "Automotive & Parts",
    "Books & Stationery",
    "Toys & Games",
    "Sports & Fitness",
    "Jewelry & Watches",
    "Cosmetics & Beauty",
    "Pet Supplies",
    "Other Services",
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final roleData = ref.read(adminRoleProvider).value;
      if (roleData == null) return;

      final tenantId = roleData['tenantId'];
      final branchCode = roleData['branchCode'] ?? 'UNKNOWN';

      final doc = await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc('${tenantId}_$branchCode')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _highRiskMult = (data['churnMultiplierHigh'] ?? 2.1).toDouble();
          _medRiskMult = (data['churnMultiplierMedium'] ?? 1.2).toDouble();
          _vipThreshold = (data['vipThreshold'] ?? 5000).toDouble();

          // 🚀 SMART LOAD: Check if it's a custom category
          String loadedType = data['businessType'] ?? "General Retail";
          if (_categories.contains(loadedType)) {
            _businessType = loadedType;
          } else {
            _businessType = "Other Services";
            _customCategoryCtrl.text =
                loadedType; // Populate the custom text field
          }
        });
      }
    } catch (e) {
      debugPrint(
        "Config Load Error: $e",
      ); // 🚀 FIX: Resolved empty catch warning
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    // 🚀 VALIDATION: Custom category blank nahi honi chahiye
    if (_businessType == "Other Services" &&
        _customCategoryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚨 Please enter a custom category name!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final roleData = ref.read(adminRoleProvider).value;
      final tenantId = roleData?['tenantId'];
      final branchCode = roleData?['branchCode'] ?? 'UNKNOWN';

      // 🚀 FINAL VALUE: Agar custom hai, toh text field ki value save karo
      final finalCategory = _businessType == "Other Services"
          ? _customCategoryCtrl.text.trim()
          : _businessType;

      await FirebaseFirestore.instance
          .collection('growth_configs')
          .doc('${tenantId}_$branchCode')
          .set({
            'tenantId': tenantId,
            'branchCode': branchCode,
            'businessType':
                finalCategory, // 🚀 SAVES THE CUSTOM VALIDATED CATEGORY
            'churnMultiplierHigh': _highRiskMult,
            'churnMultiplierMedium': _medRiskMult,
            'vipThreshold': _vipThreshold,
            'expectedCycleDays': _expectedCycleDays,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      ref.invalidate(growthConfigStatusProvider);
      ref.invalidate(churnEngineProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(
        "Config Save Error: $e",
      ); // 🚀 FIX: Resolved empty catch warning
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final branchCode =
        ref.watch(adminRoleProvider).value?['branchCode'] ?? 'UNKNOWN';

    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(color: Colors.green)),
        ),
      );
    } // 🚀 FIX: Added curly braces to resolve linter warning

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF111811) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Store Growth Setup",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            "Configure AI churn rules per specific store branch",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Target Store (Auto-Assigned)",
                            style: TextStyle(color: Colors.green, fontSize: 11),
                          ),
                          Text(
                            branchCode,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
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
              ),
              const SizedBox(height: 20),

              // 🚀 NEW: Business Category Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Store Business Category",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _categories.contains(_businessType)
                        ? _businessType
                        : "General Retail",
                    dropdownColor: isDark
                        ? const Color(0xFF1A221A)
                        : Colors.white,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: Colors.green, width: 2),
                      ),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => _businessType = val!),
                  ),

                  // 🚀 NEW: Dynamic Custom Input Field
                  if (_businessType == "Other Services") ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customCategoryCtrl,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            "Enter custom category (e.g. Organic Farm Fresh)",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: const Icon(
                          Icons.edit,
                          color: Colors.grey,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1A221A)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.green.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Colors.green, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 25),
              _buildSliderRow(
                "High risk trigger (beyond cycle)",
                _highRiskMult,
                1.5,
                4.0,
                (val) => setState(() => _highRiskMult = val),
                "${_highRiskMult.toStringAsFixed(1)}x",
                isDark,
                textColor,
              ),
              const SizedBox(height: 15),
              _buildSliderRow(
                "Medium risk trigger (beyond cycle)",
                _medRiskMult,
                1.0,
                2.0,
                (val) => setState(() => _medRiskMult = val),
                "${_medRiskMult.toStringAsFixed(1)}x",
                isDark,
                textColor,
              ),
              const SizedBox(height: 15),
              _buildSliderRow(
                "VIP spend threshold (₹)",
                _vipThreshold,
                1000,
                20000,
                (val) => setState(() => _vipThreshold = val),
                "₹${_vipThreshold.toInt()}",
                isDark,
                textColor,
              ),
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "RISK THRESHOLDS (AUTO-CALCULATED)",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildCalcRow(
                "High risk fires after",
                "${(_expectedCycleDays * _highRiskMult).toInt()} days no visit",
                Colors.redAccent,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Medium risk fires after",
                "${(_expectedCycleDays * _medRiskMult).toInt()} days no visit",
                Colors.orangeAccent,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Coupon - high risk",
                "20% off",
                textColor,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildCalcRow(
                "Coupon - medium risk",
                "10% off",
                textColor,
                textColor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isSaving ? null : _saveConfig,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    "Save AI config for this store ↗",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String trailing,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor, fontSize: 13)),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.shade800,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.1),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                trailing,
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
        Text(label, style: TextStyle(color: textColor, fontSize: 13)),
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
