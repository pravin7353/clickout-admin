import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🚀 YAHI WO IMPORT THA JO MAINE GALTI SE HATA DIYA THA
import 'package:flutter_riverpod/legacy.dart';

import 'package:clickout_admin/features/auth/auth_provider.dart';

class LedgerFilters {
  String mode;
  String status;
  String timeRange;

  LedgerFilters({
    this.mode = 'ALL',
    this.status = 'ALL',
    this.timeRange = 'ALL_TIME',
  });
}

// 🚀 AAPKA ORIGINAL CHANGENOTIFIER
class LedgerNotifier extends ChangeNotifier {
  final String? tenantId;
  final String role;
  final String? branchCode;

  List<QueryDocumentSnapshot> records = [];
  bool isLoading = false;
  bool hasMore = true;
  LedgerFilters currentFilters = LedgerFilters();

  final int _limit = 10;

  LedgerNotifier(this.tenantId, this.role, this.branchCode) {
    fetchInitial();
  }

  void updateFilter({String? mode, String? status, String? timeRange}) {
    if (mode != null) currentFilters.mode = mode;
    if (status != null) currentFilters.status = status;
    if (timeRange != null) currentFilters.timeRange = timeRange;
    fetchInitial();
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('orders');

    // 🚀 SAAS ISOLATION LOGIC (LEVEL 1 & LEVEL 2)
    if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty) {
      query = query.where('tenantId', isEqualTo: tenantId);
    }
    if (role == 'manager' && branchCode != null && branchCode!.isNotEmpty) {
      query = query.where('branchCode', isEqualTo: branchCode);
    }

    if (currentFilters.mode != 'ALL') {
      query = query.where('paymentMode', isEqualTo: currentFilters.mode);
    }
    if (currentFilters.status != 'ALL') {
      query = query.where('exitStatus', isEqualTo: currentFilters.status);
    }

    if (currentFilters.timeRange == 'TODAY') {
      final now = DateTime.now();
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(now.year, now.month, now.day),
        ),
      );
    } else if (currentFilters.timeRange == 'LAST_7_DAYS') {
      final now = DateTime.now();
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          now.subtract(const Duration(days: 7)),
        ),
      );
    }
    return query.orderBy('timestamp', descending: true).limit(_limit);
  }

  Future<void> fetchInitial() async {
    isLoading = true;
    notifyListeners();
    try {
      final snap = await _buildQuery().get();
      records = snap.docs;
      hasMore = snap.docs.length == _limit;
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMore() async {
    if (isLoading || !hasMore || records.isEmpty) return;
    isLoading = true;
    notifyListeners();
    try {
      final lastDoc = records.last;
      Query query = _buildQuery().startAfterDocument(lastDoc);
      final snap = await query.get();
      records.addAll(snap.docs);
      hasMore = snap.docs.length == _limit;
    } catch (e) {
      debugPrint("Fetch more error: $e");
    }
    isLoading = false;
    notifyListeners();
  }
}

// 🚀 PERFECTLY WORKING (Because of legacy.dart import)
final ledgerProvider = ChangeNotifierProvider<LedgerNotifier>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();
  final String? branchCode = adminData?['branchCode'];

  return LedgerNotifier(tenantId, role, branchCode);
});
