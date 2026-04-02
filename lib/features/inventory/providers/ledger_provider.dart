import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// 🚀 SAAS INJECTION
import 'package:clickout_admin/features/auth/auth_provider.dart';

// 📊 1. THE LEDGER MODEL
class InventoryLedger {
  final String productId;
  final String name;
  final int openingStock;
  final int purchasedStock;
  final int soldStock;
  final int damagedStock;
  final int expiredStock;
  final DateTime? lastSoldAt;

  InventoryLedger({
    required this.productId,
    this.name = 'Unknown Product',
    this.openingStock = 0,
    this.purchasedStock = 0,
    this.soldStock = 0,
    this.damagedStock = 0,
    this.expiredStock = 0,
    this.lastSoldAt,
  });

  int get closingStock =>
      openingStock + purchasedStock - soldStock - damagedStock - expiredStock;

  bool get isDeadStock {
    final int currentStock = closingStock;
    if (currentStock < 10) return false;
    if (lastSoldAt == null) return true;
    final daysSinceLastSale = DateTime.now().difference(lastSoldAt!).inDays;
    return daysSinceLastSale > 15;
  }
}

// 🚀 2. THE LEDGER ENGINE (Riverpod AsyncNotifier)
class LedgerNotifier extends AsyncNotifier<List<InventoryLedger>> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<InventoryLedger>> build() async {
    return _fetchLedger();
  }

  Future<List<InventoryLedger>> _fetchLedger() async {
    try {
      // ✅ BUG FIXED: Changed ref.read to ref.watch to prevent initialization crash
      final adminData = ref.watch(adminRoleProvider).value;
      final String? tenantId = adminData?['tenantId'];
      final String role = (adminData?['role'] ?? '').toString().toLowerCase();

      Query query = _db.collection('products');

      // 🚀 SAAS ISOLATION (Tenant Level)
      if (role != 'super_admin' && tenantId != null && tenantId.isNotEmpty) {
        query = query.where('tenantId', isEqualTo: tenantId);
      }

      // 🛡️ THE WALL: Branch Isolation (Strictly for Managers)
      final String? branchCode = adminData?['branchCode'];
      if (role == 'manager' && branchCode != null && branchCode.isNotEmpty) {
        query = query.where('branchCode', isEqualTo: branchCode);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        DateTime? parsedLastSold;
        if (data['lastSoldAt'] != null) {
          parsedLastSold = (data['lastSoldAt'] as Timestamp).toDate();
        }

        return InventoryLedger(
          productId: doc.id,
          name: data['name'] ?? 'Unknown Item',
          openingStock: data['openingStock'] ?? 0,
          purchasedStock: data['purchasedStock'] ?? 0,
          soldStock: data['soldStock'] ?? 0,
          damagedStock: data['damagedStock'] ?? 0,
          expiredStock: data['expiredStock'] ?? 0,
          lastSoldAt: parsedLastSold,
        );
      }).toList();
    } catch (e) {
      debugPrint("🚨 Ledger Error: $e");
      throw Exception("Failed to load Godown Ledger");
    }
  }

  // 🚨 FRAUD CONTROL: Log Damaged/Expired Items
  Future<void> markItemAsDamagedOrExpired(
    String productId,
    int quantity,
    String reason,
  ) async {
    final docRef = _db.collection('products').doc(productId);
    final fieldToUpdate = reason == 'EXPIRED' ? 'expiredStock' : 'damagedStock';

    // Yahan state update nahi ho rahi directly UI load time pe, so read is fine here
    final tenantId = ref.read(adminRoleProvider).value?['tenantId'];

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Product missing!");

      final currentBadStock = snapshot.data()![fieldToUpdate] ?? 0;
      final currentPhysical = snapshot.data()!['physicalStock'] ?? 0;

      transaction.update(docRef, {
        fieldToUpdate: currentBadStock + quantity,
        'physicalStock': currentPhysical - quantity,
      });

      // Maintain Audit Trail
      transaction.set(_db.collection('audit_logs').doc(), {
        'productId': productId,
        'quantity': quantity,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'reportedBy': 'Admin',
        'tenantId': tenantId, // 🚀 SAAS INJECTION
      });
    });

    ref.invalidateSelf();
  }
}

final ledgerProvider =
    AsyncNotifierProvider<LedgerNotifier, List<InventoryLedger>>(() {
      return LedgerNotifier();
    });
