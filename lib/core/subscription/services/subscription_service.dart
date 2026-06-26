// lib/core/subscription/services/subscription_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';
import '../../constants/db_collections.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // Usage Ledger — current month key: "2025-06"
  // ─────────────────────────────────────────────

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  DocumentReference _usageRef(String tenantId) {
    return _db
        .collection(DbCollections.tenants)
        .doc(tenantId)
        .collection(DbCollections.usageLedger)
        .doc(_currentMonthKey());
  }

  // ─────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────

  Stream<SubscriptionUsage> watchUsage(String tenantId) {
    return _usageRef(tenantId).snapshots().map((snap) {
      if (!snap.exists) return SubscriptionUsage.empty();
      return SubscriptionUsage.fromFirestore(
        snap.data() as Map<String, dynamic>,
      );
    });
  }

  // ─────────────────────────────────────────────
  // INCREMENT HELPERS (atomic — existing logic safe)
  // ─────────────────────────────────────────────

  Future<void> incrementTransaction(String tenantId) async {
    await _usageRef(tenantId).set({
      'transactionCount': FieldValue.increment(1),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementStaff(String tenantId) async {
    await _usageRef(tenantId).set({
      'staffCount': FieldValue.increment(1),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> decrementStaff(String tenantId) async {
    await _usageRef(tenantId).set({
      'staffCount': FieldValue.increment(-1),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementCampaign(String tenantId) async {
    await _usageRef(tenantId).set({
      'campaignCount': FieldValue.increment(1),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> decrementCampaign(String tenantId) async {
    await _usageRef(tenantId).set({
      'campaignCount': FieldValue.increment(-1),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
