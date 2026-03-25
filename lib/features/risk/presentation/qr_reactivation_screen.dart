import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../providers/qr_reactivation_provider.dart';

class QrReactivationScreen extends ConsumerStatefulWidget {
  const QrReactivationScreen({super.key});

  @override
  ConsumerState<QrReactivationScreen> createState() =>
      _QrReactivationScreenState();
}

class _QrReactivationScreenState extends ConsumerState<QrReactivationScreen> {
  late Timer _timeUpdater;
  String _currentTime = "";
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeUpdater = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _timeUpdater.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProfileProvider);
    final ordersState = ref.watch(expiredOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: adminState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
        error: (err, stack) => _buildErrorBanner(err.toString()),
        data: (adminProfile) {
          if (adminProfile == null) {
            return _buildErrorBanner(
              "Admin profile not found. Please relogin.",
            );
          }

          final storeId = adminProfile['branchCode'] ?? 'UNASSIGNED';
          final adminName = adminProfile['name'] ?? 'Admin';
          final role = (adminProfile['role'] ?? '').toString().toLowerCase();
          final isSuperAdmin = role == 'super_admin' || role == 'admin';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🎩 THE ENTERPRISE HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "QR Reactivation Desk ⏳",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2B3674),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSuperAdmin
                                    ? "ALL STORES (Super Admin)"
                                    : "Store: $storeId",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                adminName,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentTime,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🔍 THE SEARCH BAR (Warnings Fixed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (val) {
                        // 🚀 FIXED: Using updateQuery instead of direct .state mutation
                        ref
                            .read(bailoutSearchQueryProvider.notifier)
                            .updateQuery(val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: "Search by Order ID...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.blueAccent,
                        ),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  // 🚀 FIXED: Using updateQuery instead of direct .state mutation
                                  ref
                                      .read(bailoutSearchQueryProvider.notifier)
                                      .updateQuery('');
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),

                  // 📜 THE LIST ENGINE
                  Expanded(
                    child: ordersState.when(
                      loading: () => _buildShimmerLoading(),
                      error: (err, stack) => _buildErrorBanner(err.toString()),
                      data: (orders) {
                        if (orders.isEmpty) {
                          return _buildEmptyState();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.red,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    ref
                                            .read(bailoutSearchQueryProvider)
                                            .isNotEmpty
                                        ? "1 Order Found via Search"
                                        : "${orders.length} Expired QRs Awaiting Bailout",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: orders.length,
                                itemBuilder: (context, index) {
                                  final doc = orders[index];
                                  return _BailoutCard(
                                    orderDoc: doc,
                                    currentStoreId: storeId,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          "🚨 System Alert: $error",
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
          SizedBox(height: 16),
          Text(
            "✅ No Expired QRs Found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Store operations are running smoothly.",
            style: TextStyle(color: Colors.green, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(100),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _BailoutCard extends ConsumerStatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> orderDoc;
  final String currentStoreId;

  const _BailoutCard({required this.orderDoc, required this.currentStoreId});

  @override
  ConsumerState<_BailoutCard> createState() => _BailoutCardState();
}

class _BailoutCardState extends ConsumerState<_BailoutCard> {
  bool _isLoading = false;
  bool _isReactivated = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.orderDoc.data();
    final orderId = widget.orderDoc.id;
    final customerName = data['customerName'] ?? 'Walk-in Customer';
    final amount = data['totalAmount'] ?? 0;
    final int regenCount = data['qrRegenCount'] ?? 0;

    final Timestamp expiresAt = data['qrExpiresAt'];
    final diffMins = DateTime.now().difference(expiresAt.toDate()).inMinutes;

    Color stripColor = Colors.green;
    String timeText = "Expired $diffMins mins ago";
    if (diffMins > 60) {
      stripColor = Colors.red;
    } else if (diffMins > 15)
      stripColor = Colors.orange;
    if (_isReactivated) stripColor = Colors.green;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // 🚀 FIXED: .withOpacity() to .withValues(alpha: ...)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(left: BorderSide(color: stripColor, width: 8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        orderId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        // 🚀 FIXED: .withOpacity() to .withValues(alpha: ...)
                        decoration: BoxDecoration(
                          color: stripColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isReactivated ? "Live" : timeText,
                          style: TextStyle(
                            color: stripColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "₹$amount",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.refresh, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "$regenCount / 2 Used",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _isReactivated
                ? const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "✅ REACTIVATED\nExpires in 1 hr",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _handleBailout(orderId),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.flash_on, size: 18),
                      label: Text(
                        _isLoading ? "PROCESSING..." : "BAILOUT ⚡",
                        style: const TextStyle(
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

  Future<void> _handleBailout(String orderId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 10),
                Text("Confirm Bailout"),
              ],
            ),
            content: const Text(
              "You are reactivating an expired Gate Pass. This is recorded in the Audit Log. Proceed?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Yes, Authorize",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(qrBailoutProvider.notifier)
          .reactivateQR(orderId, widget.currentStoreId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isReactivated = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
