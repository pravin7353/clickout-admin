import 'package:flutter_riverpod/flutter_riverpod.dart';

// 📦 1. STATE MODEL (Holds the active context)
class ActiveStoreState {
  final String tenantId;
  final String branchCode;
  final String storeName;
  final String managerEmail;
  final String managerEmpId;
  final String managerName;
  final String managerPhone;

  ActiveStoreState({
    required this.tenantId,
    required this.branchCode,
    required this.storeName,
    required this.managerEmail,
    required this.managerEmpId,
    required this.managerName,
    required this.managerPhone,
  });

  bool get isValid => tenantId.isNotEmpty && branchCode.isNotEmpty;
}

// 🧠 2. THE ENGINE (Manages the lock)
class ActiveStoreNotifier extends Notifier<ActiveStoreState?> {
  @override
  ActiveStoreState? build() {
    return null; // By default, no store is selected (Global View)
  }

  // 🔒 CALL THIS WHEN USER CLICKS "ENTER PORTAL"
  void setStore({
    required String tenantId,
    required String branchCode,
    required String storeName,
    required String managerEmail,
    required String managerEmpId,
    required String managerName,
    required String managerPhone,
  }) {
    state = ActiveStoreState(
      tenantId: tenantId,
      branchCode: branchCode,
      storeName: storeName,
      managerEmail: managerEmail,
      managerEmpId: managerEmpId,
      managerName: managerName,
      managerPhone: managerPhone,
    );
  }

  // 🔓 CALL THIS ON LOGOUT OR GOING BACK TO HQ
  void clearStore() {
    state = null;
  }
}

// 🌐 3. THE PROVIDER (To be used across the app)
final activeStoreProvider =
    NotifierProvider<ActiveStoreNotifier, ActiveStoreState?>(() {
      return ActiveStoreNotifier();
    });
