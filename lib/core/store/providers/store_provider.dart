import 'package:flutter_riverpod/flutter_riverpod.dart';

// 📦 1. STATE MODEL (Holds the active context)
class ActiveStoreState {
  final String tenantId;
  final String branchCode;
  final String storeName; // 🚀 NAYA: Store ka naam yaad rakhne ke liye

  ActiveStoreState({
    required this.tenantId,
    required this.branchCode,
    required this.storeName,
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
  void setStore(String tenantId, String branchCode, String storeName) {
    // 🚀 NAYA PARAMETER
    state = ActiveStoreState(
      tenantId: tenantId,
      branchCode: branchCode,
      storeName: storeName,
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
