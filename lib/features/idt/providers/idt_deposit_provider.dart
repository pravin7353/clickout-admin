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
  bool isFetchingMore = false;
  bool hasMore = true;
  DocumentSnapshot? _lastDoc;
  String errorMsg = '';
  bool _isDisposed = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  IdtDepositNotifier(this.tenantId, this.role, this.branchCode) {
    fetchInitial();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> fetchInitial() async {
    if (_isDisposed) return;
    isLoading = true;
    errorMsg = '';
    _safeNotify();

    try {
      Query q = _db
          .collection('idt_deposits')
          .where('status', isEqualTo: 'VERIFIED')
          .orderBy('timestamp', descending: true)
          .limit(20);
      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty)
        q = q.where('tenantId', isEqualTo: tenantId);
      if (branchCode != null &&
          branchCode!.isNotEmpty &&
          branchCode != 'HQ' &&
          branchCode != 'ALL')
        q = q.where('branchCode', isEqualTo: branchCode);

      final snap = await q.get();
      records.clear();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        hasMore = snap.docs.length == 20;
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;
          records.add(data);
        }
      } else {
        hasMore = false;
      }
    } catch (e) {
      errorMsg = "Error: $e";
    }
    isLoading = false;
    _safeNotify();
  }

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
      if (role != 'super_admin' && tenantId != null && tenantId!.isNotEmpty)
        q = q.where('tenantId', isEqualTo: tenantId);
      if (branchCode != null &&
          branchCode!.isNotEmpty &&
          branchCode != 'HQ' &&
          branchCode != 'ALL')
        q = q.where('branchCode', isEqualTo: branchCode);

      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        hasMore = snap.docs.length == 20;
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

  // 🚀 FETCH PRODUCT FOR SCANNER UI
  Future<Map<String, dynamic>?> getProduct(String barcode) async {
    final docSnap = await _db
        .collection('products')
        .doc('${tenantId}_${branchCode}_$barcode')
        .get();
    if (docSnap.exists) return docSnap.data();
    return null;
  }

  // 🚀 DELETE DB ITEMS
  Future<void> deleteItems(List<Map<String, dynamic>> itemsToDelete) async {
    try {
      final batch = _db.batch();
      Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var item in itemsToDelete) {
        final docId = item['_docId'];
        if (docId == null) continue; // Skip local items
        if (!grouped.containsKey(docId)) grouped[docId] = [];
        grouped[docId]!.add(item);
      }

      for (var docId in grouped.keys) {
        final record = records.firstWhere((r) => r['docId'] == docId);
        List<dynamic> existingItems = List.from(record['items']);
        final itemsToRemove = grouped[docId]!;

        // Remove items based on barcode
        for (var rm in itemsToRemove) {
          existingItems.removeWhere((ex) => ex['barcode'] == rm['barcode']);
        }

        if (existingItems.isEmpty) {
          batch.delete(
            _db.collection('idt_deposits').doc(docId),
          ); // Delete entire document if empty
        } else {
          batch.update(_db.collection('idt_deposits').doc(docId), {
            'items': existingItems,
          });
        }
      }
      await batch.commit();
      await fetchInitial();
    } catch (e) {
      throw "Failed to delete: $e";
    }
  }

  // 🚀 THE GLOBAL FLAT BATCH PROCESSOR (Updated for Master Roster Schema)
  Future<void> markMultipleAsProcessed(
    List<Map<String, dynamic>> itemsToProcess,
  ) async {
    if (itemsToProcess.isEmpty) return;
    try {
      final batch = _db.batch();
      Map<String, List<Map<String, dynamic>>> groupedDb = {};
      List<Map<String, dynamic>> localItems = [];

      // 1. Separate Local (Scanned) and DB items
      for (var item in itemsToProcess) {
        if (item['isLocal'] == true) {
          localItems.add(item);
        } else {
          final docId = item['_docId'];
          if (docId != null) {
            if (!groupedDb.containsKey(docId)) groupedDb[docId] = [];
            final cleanItem = Map<String, dynamic>.from(item);
            cleanItem.remove('_docId');
            cleanItem.remove('_originalIndex');
            groupedDb[docId]!.add(cleanItem);
          }
        }
      }

      // 2. Process DB Items
      for (var docId in groupedDb.keys) {
        final updatedItems = groupedDb[docId]!;
        final record = records.firstWhere((r) => r['docId'] == docId);
        final docTenantId = record['tenantId'];
        final docBranchCode = record['branchCode'];

        for (var item in updatedItems) {
          await _updateOrSetProduct(
            batch,
            docTenantId,
            docBranchCode,
            item,
          ); // 🚀 AWAIT ADDED
        }
        batch.update(_db.collection('idt_deposits').doc(docId), {
          'status': 'PROCESSED',
          'items': updatedItems,
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Process Local Scanned Items (Directly go live)
      if (localItems.isNotEmpty) {
        List<Map<String, dynamic>> cleanLocalItems = [];
        for (var item in localItems) {
          await _updateOrSetProduct(
            batch,
            tenantId,
            branchCode,
            item,
          ); // 🚀 AWAIT ADDED
          final cleanItem = Map<String, dynamic>.from(item);
          cleanItem.remove('_localId');
          cleanItem.remove('isLocal');
          cleanItem.remove('_originalIndex');
          cleanLocalItems.add(cleanItem);
        }
        final depositRef = _db.collection('idt_deposits').doc();
        batch.set(depositRef, {
          'tenantId': tenantId,
          'branchCode': branchCode,
          'status': 'PROCESSED',
          'source': 'ADMIN_DIRECT_SCAN',
          'items': cleanLocalItems,
          'timestamp': FieldValue.serverTimestamp(),
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await fetchInitial();
    } catch (e) {
      throw Exception("Failed to Go Live: $e");
    }
  }

  // 🚀 PRODUCT MASTER SYNC LOGIC (EXACT AIR MAX SCHEMA)
  Future<void> _updateOrSetProduct(
    WriteBatch batch,
    String? tId,
    String? bCode,
    Map<String, dynamic> item,
  ) async {
    final barcode = item['barcode'];
    final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final productRef = _db
        .collection('products')
        .doc('${tId}_${bCode}_$barcode');

    // 🚀 NAYA FIX: Pehle check karenge ki product purana hai ya naya
    final docSnap = await productRef.get();

    if (docSnap.exists) {
      // ♻️ EXISTING ITEM: Sirf stock aur rate badhao
      batch.update(productRef, {
        'physicalStock': FieldValue.increment(qty),
        'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        'unitCost': double.tryParse(item['unitCost']?.toString() ?? '0') ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 🌟 NEW ITEM: EXACT MASTER ROSTER SCHEMA!
      batch.set(productRef, {
        'addedBy': 'IDT Terminal',
        'addedByEmail': 'idt@clickout.com',
        'barcode': barcode,
        'branchCode': bCode,
        'tenantId': tId,
        'createdAt':
            FieldValue.serverTimestamp(), // 🚀 CRITICAL FIX: Iske bina list me show nahi hota tha!
        'updatedAt': FieldValue.serverTimestamp(),
        'name': item['name'] ?? 'UNKNOWN ITEM',
        'searchKey': (item['name'] ?? 'UNKNOWN ITEM').toString().toLowerCase(),
        'isActive': true,
        'isPublished': true,
        'itemType': 'PRODUCT',
        'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
        'unitCost': double.tryParse(item['unitCost']?.toString() ?? '0') ?? 0,
        'gst': item['gst'] ?? '',
        'hsn': item['hsn'] ?? '',
        'expiryDate': item['expiryDate'] ?? '',
        'weight': item['weight'] ?? '',

        // Master Roster Default Stock Tracking Fields
        'openingStock': qty,
        'physicalStock': qty,
        'damagedStock': 0,
        'expiredStock': 0,
        'purchasedStock': 0,
        'reservedStock': 0,
        'soldStock': 0,
      });
    }
  }
}

final idtDepositProvider = ChangeNotifierProvider<IdtDepositNotifier>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  final activeStore = ref.watch(activeStoreProvider);
  final String? tenantId = activeStore?.tenantId ?? adminData?['tenantId'];
  final String role = (adminData?['role'] ?? '').toString().toLowerCase();
  final String? branchCode =
      activeStore?.branchCode ?? adminData?['branchCode'];
  return IdtDepositNotifier(tenantId, role, branchCode);
});
