import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';

// 🚀 SAAS INJECTION: Added auth_provider import
import 'package:clickout_admin/features/auth/auth_provider.dart';

class ManagerFilters {
  String role;
  ManagerFilters({this.role = 'ALL'});
}

// 🚀 UNIFIED ENGINE: Ab sirf ek 'staff' collection use hoga!
class ManagerNotifier extends ChangeNotifier {
  final String? tenantId; // 👈 SAAS INJECTION
  final String role; // 👈 SAAS INJECTION
  final String? branchCode; // 🚀 NAYA: Branch Level Isolation!

  List<Map<String, dynamic>> records = [];
  bool isLoading = false;
  bool hasMore = true;
  int totalStaffCount = 0;
  String indexErrorMsg = '';

  Timestamp? _lastTimestamp;
  ManagerFilters currentFilters = ManagerFilters();
  final int _limit = 15;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ManagerNotifier(this.tenantId, this.role, this.branchCode) {
    // 👈 SAAS & BRANCH INJECTION
    fetchInitial();
  }

  void updateFilter({String? role}) {
    if (role != null) currentFilters.role = role;
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    isLoading = true;
    indexErrorMsg = '';
    notifyListeners();

    try {
      // 💸 COST SAVER: Unified Count Query
      Query countQuery = _db
          .collection('staff')
          .where('isDeleted', isEqualTo: false);

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty) {
        countQuery = countQuery.where('tenantId', isEqualTo: tenantId);
      }

      // 🛡️ BRANCH ISOLATION (Manager ko sirf uski branch dikhegi)
      if (role == 'manager' && branchCode != null && branchCode!.isNotEmpty) {
        countQuery = countQuery.where('branchCode', isEqualTo: branchCode);
      }

      if (currentFilters.role != 'ALL') {
        countQuery = countQuery.where('role', isEqualTo: currentFilters.role);
      }

      final c = await countQuery.count().get();
      totalStaffCount = c.count ?? 0;

      _lastTimestamp = null;
      records.clear();
      await _fetchData();
    } catch (e) {
      if (e.toString().contains('index')) {
        indexErrorMsg = "🚨 Firebase Index Required! Check Debug Console.";
      } else {
        indexErrorMsg = "Error: $e";
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    notifyListeners();
    await _fetchData();
    isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchData() async {
    try {
      Query q = _db
          .collection('staff')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true);

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty) {
        q = q.where('tenantId', isEqualTo: tenantId);
      }

      // 🛡️ BRANCH ISOLATION (Manager ko sirf uski branch dikhegi)
      if (role == 'manager' && branchCode != null && branchCode!.isNotEmpty) {
        q = q.where('branchCode', isEqualTo: branchCode);
      }

      if (currentFilters.role != 'ALL') {
        q = q.where('role', isEqualTo: currentFilters.role);
      }

      if (_lastTimestamp != null) q = q.startAfter([_lastTimestamp]);

      q = q.limit(_limit);
      final snap = await q.get();

      List<Map<String, dynamic>> temp = [];
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['docId'] = doc.id;
        data['collectionName'] = 'staff'; // Strict routing for toggle/delete
        temp.add(data);
      }

      if (temp.isNotEmpty) {
        _lastTimestamp = temp.last['createdAt'] as Timestamp?;
        records.addAll(temp);
      }

      hasMore = temp.length == _limit;
    } catch (e) {
      if (e.toString().contains('index')) {
        indexErrorMsg = "🚨 Firebase Index Required! Check Debug Console.";
      }
      debugPrint("Table Engine Error: $e");
    }
  }
}

final managerProvider = ChangeNotifierProvider<ManagerNotifier>((ref) {
  // 🚀 SAAS INJECTION: Pass tenant data to the Provider
  final adminData = ref.watch(adminRoleProvider).value;
  final String? tenantId = adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();
  final String? branchCode = adminData?['branchCode']; // 🚀 FETCH BRANCH CODE

  return ManagerNotifier(tenantId, role, branchCode); // 🚀 PASS BRANCH CODE
});
