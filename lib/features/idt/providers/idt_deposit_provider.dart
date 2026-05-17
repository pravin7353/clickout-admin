import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:clickout_admin/features/auth/auth_provider.dart';
import 'package:clickout_admin/core/store/providers/store_provider.dart';

class IdtDepositNotifier extends ChangeNotifier {
  final String? tenantId;
  final String role;
  final String? branchCode;

  List<Map<String, dynamic>> records = [];
  bool isLoading = false;
  bool isFetchingMore = false; // 🚀 NAYA: Pagination
  bool hasMore = true; // 🚀 NAYA: Pagination
  DocumentSnapshot? _lastDoc; // 🚀 NAYA: Pagination
  String errorMsg = '';

  bool _isDisposed = false; // 🚀 NAYA: Safety Lock

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  IdtDepositNotifier(this.tenantId, this.role, this.branchCode) {
    fetchInitial();
  }

  @override
  void dispose() {
    _isDisposed = true; // 🚀 Jab screen band hogi, ye lock on ho jayega
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> fetchInitial() async {
    if (_isDisposed) return;

    isLoading = true;
    errorMsg = '';
    _safeNotify();

    try {
      Query q = _db
          .collection('idt_deposits')
          .where(
            'status',
            isEqualTo: 'VERIFIED',
          ) // 🚀 NAYA: Processed wale hamesha ke liye GAYAB!
          .orderBy('timestamp', descending: true)
          .limit(20);

      // 🚀 SAAS ISOLATION
      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty) {
        q = q.where('tenantId', isEqualTo: tenantId);
      }

      // 🚀 UNIVERSAL BRANCH LOCK
      if (branchCode != null &&
          branchCode!.isNotEmpty &&
          branchCode != 'HQ' &&
          branchCode != 'ALL') {
        q = q.where('branchCode', isEqualTo: branchCode);
      }

      final snap = await q.get();

      records.clear();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        hasMore =
            snap.docs.length ==
            20; // 🚀 BUG FIX: Limit 20 ki hai toh check bhi 20 ka hoga!
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;
          records.add(data);
        }
      } else {
        hasMore = false;
      }
    } catch (e) {
      debugPrint(
        "🔥 ASLI FIREBASE ERROR: $e",
      ); // 🚀 Konsol me link yahan dikhega

      if (e.toString().contains('index') ||
          e.toString().contains('FAILED_PRECONDITION')) {
        errorMsg = "🚨 Firebase Index Required! Check Debug Console.";
      } else {
        errorMsg = "Error: $e";
      }
    }

    isLoading = false;
    _safeNotify();
  }

  // 🚀 NAYA: LOAD MORE FUNCTION (Pagination Engine)
  Future<void> fetchMore() async {
    if (_isDisposed || isFetchingMore || !hasMore || _lastDoc == null) return;

    isFetchingMore = true;
    _safeNotify();

    try {
      Query q = _db
          .collection('idt_deposits')
          .where('status', isEqualTo: 'VERIFIED')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(20);

      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty) {
        q = q.where('tenantId', isEqualTo: tenantId);
      }
      if (branchCode != null &&
          branchCode!.isNotEmpty &&
          branchCode != 'HQ' &&
          branchCode != 'ALL') {
        q = q.where('branchCode', isEqualTo: branchCode);
      }

      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        hasMore =
            snap.docs.length ==
            20; // 🚀 BUG FIX: Limit 20 ki hai toh check bhi 20 ka hoga!
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;
          records.add(data);
        }
      } else {
        hasMore = false;
      }
    } catch (e) {
      debugPrint("Pagination Error: $e");
    }

    isFetchingMore = false;
    _safeNotify();
  }

  // 🚀 THE GLOBAL FLAT BATCH PROCESSOR (New Engine)
  Future<void> markMultipleAsProcessed(
    List<Map<String, dynamic>> flatItems,
  ) async {
    if (flatItems.isEmpty) return;

    try {
      final batch = _db.batch();

      // 1. Group items back to their original deposits
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var item in flatItems) {
        final docId = item['_docId'];
        if (docId == null) continue;

        if (!grouped.containsKey(docId)) grouped[docId] = [];

        // Remove tracking keys before saving to DB
        final cleanItem = Map<String, dynamic>.from(item);
        cleanItem.remove('_docId');
        cleanItem.remove('_originalIndex');
        grouped[docId]!.add(cleanItem);
      }

      // 2. Process each group
      for (var docId in grouped.keys) {
        final updatedItems = grouped[docId]!;
        final record = records.firstWhere((r) => r['docId'] == docId);
        final docTenantId = record['tenantId'];
        final docBranchCode = record['branchCode'];

        for (var item in updatedItems) {
          final barcode = item['barcode'];
          final int qty =
              int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

          final productRef = _db
              .collection('products')
              .doc('${docTenantId}_${docBranchCode}_$barcode');
          final docSnap = await productRef.get();

          if (docSnap.exists) {
            batch.update(productRef, {
              'physicalStock': FieldValue.increment(qty),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.set(productRef, {
              'barcode': barcode,
              'name': item['name'] ?? 'UNKNOWN ITEM',
              'branchCode': docBranchCode,
              'tenantId': docTenantId,
              'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
              'unitCost':
                  double.tryParse(item['unitCost']?.toString() ?? '0') ?? 0,
              'hsn': item['hsn'] ?? '',
              'gst': item['gst'] ?? '',
              'weight': item['weight'] ?? '',
              'expiryDate': item['expiryDate'] ?? '',
              'physicalStock': qty,
              'openingStock': qty,
              'damagedStock': 0,
              'expiredStock': 0,
              'soldStock': 0,
              'purchasedStock': 0,
              'reservedStock': 0,
              'itemType': 'PRODUCT',
              'applyPerUnit': true,
              'searchKey': (item['name'] ?? 'UNKNOWN ITEM')
                  .toString()
                  .toLowerCase(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        final depositRef = _db.collection('idt_deposits').doc(docId);
        batch.update(depositRef, {
          'status': 'PROCESSED',
          'items': updatedItems, // Naye forms ki value Firebase me save!
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. 🚀 COMMIT BATCH
      await batch.commit();
      await fetchInitial();
    } catch (e) {
      throw Exception("Failed to Go Live: $e");
    }
  }
}

// 🚀 The Riverpod hook for UI
final idtDepositProvider = ChangeNotifierProvider<IdtDepositNotifier>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  final activeStore = ref.watch(activeStoreProvider);

  final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();
  final String? branchCode =
      activeStore?.branchCode ?? adminData?['branchCode'];

  return IdtDepositNotifier(tenantId, role, branchCode);
});
