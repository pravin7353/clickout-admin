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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF4F6F8),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "QR Reactivation Desk ⏳",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2B3674),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 15,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      adminName,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
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

                  // 🔍 THE SEARCH BAR
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                                  return _BailoutCard(
                                    orderDoc: orders[index],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A221A) : Colors.green.shade50,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderId = widget.orderDoc.id;
    final customerName = data['customerName'] ?? 'Walk-in Customer';
    final amount = data['totalAmount'] ?? 0;
    final int regenCount = data['qrRegenCount'] ?? 0;

    final Timestamp? expiresAt = data['qrExpiresAt'];
    final int diffMins = expiresAt != null
        ? DateTime.now().difference(expiresAt.toDate()).inMinutes
        : 0;

    Color stripColor = Colors.green;
    String timeText = "Expired $diffMins mins ago";
    if (diffMins > 60) {
      stripColor = Colors.red;
    } else if (diffMins > 15) {
      stripColor = Colors.orange;
    }
    if (_isReactivated) stripColor = Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(
              left: BorderSide(color: stripColor, width: 6),
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.transparent,
              ),
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.transparent,
              ),
              right: BorderSide(
                color: isDark ? Colors.white10 : Colors.transparent,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌟 TOP ROW: Order ID & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderId.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stripColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isReactivated ? "Live" : timeText,
                              style: TextStyle(
                                color: stripColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _isReactivated
                        ? const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "REACTIVATED",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleBailout(orderId),
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.flash_on, size: 16),
                              label: Text(
                                _isLoading ? "WAIT..." : "BAILOUT",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  height: 1,
                ),
                const SizedBox(height: 12),

                // 🌟 BOTTOM ROW: Customer Data (RESPONSIVE WRAP)
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "₹$amount",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$regenCount / 2 Used",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
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
