import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart'; // ⚡ NEW: Cloud Functions

// 🏢 1. TENANT MODEL
class TenantModel {
  final String id;
  final String companyName;
  final String plan;
  final int maxStores;
  final bool isActive;
  final DateTime createdAt;
  // 🟢 NEW CODE: Added fields for subscription and billing
  final String subscriptionPlan;
  final String billingStatus;
  final DateTime? subscriptionEndDate;
  final int monthlyAmount;

  TenantModel({
    required this.id,
    required this.companyName,
    required this.plan,
    required this.maxStores,
    required this.isActive,
    required this.createdAt,
    // 🟢 NEW CODE: Required constructor params
    required this.subscriptionPlan,
    required this.billingStatus,
    this.subscriptionEndDate,
    required this.monthlyAmount,
  });

  factory TenantModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // 🟢 NEW CODE: Parse plan and calculate monthlyAmount
    final parsedPlan = (data['subscriptionPlan'] ?? 'BASIC')
        .toString()
        .toUpperCase();
    final int amount =
        data['monthlyAmount'] as int? ??
        (parsedPlan == 'ENTERPRISE'
            ? 9999
            : (parsedPlan == 'PRO' ? 2999 : 999));

    return TenantModel(
      id: doc.id,
      companyName: data['companyName'] ?? 'Unknown',
      plan: parsedPlan,
      maxStores: data['maxStores'] ?? 1,
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // 🟢 NEW CODE: Map new fields
      subscriptionPlan: parsedPlan,
      billingStatus: (data['billingStatus'] ?? 'ACTIVE')
          .toString()
          .toUpperCase(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)
          ?.toDate(),
      monthlyAmount: amount,
    );
  }
}

// ⚙️ 2. TENANT MASTER ENGINE
class TenantMasterNotifier extends AsyncNotifier<List<TenantModel>> {
  final _db = FirebaseFirestore.instance;

  @override
  Future<List<TenantModel>> build() async {
    ref.keepAlive(); // ⚡ API Optimization & Caching: Data cache me rahega
    return _fetchTenants();
  }

  Future<List<TenantModel>> _fetchTenants() async {
    try {
      final snap = await _db
          .collection('tenants')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => TenantModel.fromDoc(doc)).toList();
    } catch (e) {
      throw Exception("Failed to load tenants: $e");
    }
  }

  // 🚀 CORE SAAS ONBOARDING (Atomic Transaction)
  Future<void> onboardNewTenant({
    required String companyName,
    required String plan,
    required String adminName,
    required String adminPhone,
    required String adminEmail,
  }) async {
    final phoneRegex = RegExp(r'^[6-9][0-9]{9}$');
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

    if (companyName.trim().isEmpty ||
        !phoneRegex.hasMatch(adminPhone.trim()) ||
        !emailRegex.hasMatch(adminEmail.trim())) {
      throw Exception(
        "Validation Failed: Invalid input data for SaaS onboarding.",
      );
    }

    try {
      // ⚡ CORE FIX: Call Secure Cloud Function instead of Client-Side Batch Write
      final callable = FirebaseFunctions.instance.httpsCallable(
        'onboardTenant',
      );
      await callable.call({
        'companyName': companyName.trim(),
        'plan': plan,
        'adminName': adminName.trim(),
        'adminPhone': adminPhone.trim(),
        'adminEmail': adminEmail.trim(),
      });

      ref.invalidateSelf(); // Refresh the list
    } catch (e) {
      throw "Onboarding Failed via Cloud Function: $e";
    }
  }
}

final tenantMasterProvider =
    AsyncNotifierProvider<TenantMasterNotifier, List<TenantModel>>(() {
      return TenantMasterNotifier();
    });
