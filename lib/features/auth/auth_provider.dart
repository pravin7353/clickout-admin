import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Firebase Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 2. 🛡️ ENTERPRISE SESSION & ROLE MANAGER (The Vault)
// 🛡️ SECURITY FIX: Role/tenantId resolution ab sirf email-matched Firestore doc
// pe blindly depend nahi karta. Cloud Function `assignCustomClaims` har staff
// doc write pe token me role/tenantId/branchCode custom claims set karta hai —
// wahi actual server-enforced source of truth hai (Firestore Rules bhi ussi pe
// depend karti hain). Ab hum ID token force-refresh karke us claim ko doc ke
// data se cross-verify karte hain, aur mismatch pe warning log karte hain taaki
// silent drift (galat role/tenant UI me dikhna) pakda ja sake.
// Note: naye user ke pehle login pe claims propagate hone me kuch second lag
// sakte hain (trigger + token refresh delay), isliye hard-block nahi kiya —
// sirf visibility di gayi hai. Agar aapko strict enforcement chahiye, mismatch
// hone par `return null;` bhi kiya ja sakta hai.
final adminRoleProvider = StreamProvider<Map<String, dynamic>?>((ref) async* {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.email == null) {
    yield null;
    return;
  }

  // Latest custom claims fetch karo (server-enforced source of truth).
  Map<String, dynamic> tokenClaims = {};
  try {
    final idTokenResult = await user.getIdTokenResult(true);
    tokenClaims = idTokenResult.claims ?? {};
  } catch (e) {
    debugPrint('⚠️ Could not fetch ID token claims: $e');
  }

  yield* FirebaseFirestore.instance
      .collection('staff')
      .where('email', isEqualTo: user.email)
      .where('isActive', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final data = snapshot.docs.first.data();

        final claimRole = (tokenClaims['role'] ?? '').toString().toLowerCase();
        final docRole = (data['role'] ?? '').toString().toLowerCase();
        final claimTenantId = tokenClaims['tenantId']?.toString();
        final docTenantId = data['tenantId']?.toString();

        if (claimRole.isNotEmpty &&
            (claimRole != docRole || claimTenantId != docTenantId)) {
          debugPrint(
            '⚠️ SECURITY: staff doc role/tenantId ($docRole/$docTenantId) '
            'does not match token custom claims ($claimRole/$claimTenantId). '
            'Firestore Rules enforce access using the token claims, not this doc.',
          );
        }

        return data;
      });
});

// 3. The Auth Controller
class AuthController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> setupAdminSession() async {
    state = true;
    bool isFirstTimeLogin = false;
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw "Authentication failed. No active user found.";
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: currentUser.email)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      DocumentReference staffRef;
      Map<String, dynamic> data;

      if (querySnapshot.docs.isEmpty) {
        isFirstTimeLogin = true;
        final String rawName = currentUser.email!.split('@')[0].toUpperCase();
        final String prefix = rawName.length >= 3
            ? rawName.substring(0, 3)
            : rawName;
        final String newTenantId =
            '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

        staffRef = FirebaseFirestore.instance
            .collection('staff')
            .doc(currentUser.uid);
        final batch = FirebaseFirestore.instance.batch();

        batch.set(
          FirebaseFirestore.instance.collection('tenants').doc(newTenantId),
          {
            'tenantId': newTenantId,
            'companyName':
                '${currentUser.email!.split('@')[0].toUpperCase()} ENTERPRISES',
            'ownerName': currentUser.email!.split('@')[0],
            'establishedYear': DateTime.now().year,
            'isOnboardingComplete': false,
            'status': 'ACTIVE',
            'subscriptionPlan': 'trial',
            'billingStatus': 'active',
            'trialStartAt': FieldValue.serverTimestamp(),
            'activeStores': 0,
            'industries': [],
            'goods_or_services': [],
            'licenses': [],
            'contact': {
              'email': currentUser.email,
              'phone': '',
              'recoveryEmail': '',
              'recoveryPhone': '',
            },
            'location': {'address': '', 'city': '', 'state': '', 'pincode': ''},
            'bankDetails': {
              'accountName': '',
              'accountNo': '',
              'ifsc': '',
              'upi': '',
              'bankName': '',
              'isCustom': false,
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        data = {
          'uid': currentUser.uid,
          'email': currentUser.email,
          'role': 'TENANT_ADMIN',
          'tenantId': newTenantId,
          'name': currentUser.email!.split('@')[0],
          'isActive': true,
          'isDeleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(staffRef, data);

        await batch.commit();
      } else {
        staffRef = querySnapshot.docs.first.reference;
        data = querySnapshot.docs.first.data();

        final String currentRole = (data['role'] ?? '')
            .toString()
            .toUpperCase();

        if (currentRole != 'SUPER_ADMIN' && data['tenantId'] != null) {
          final tenantDoc = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(data['tenantId'])
              .get();
          if (!tenantDoc.exists) {
            await FirebaseAuth.instance.signOut();
            throw Exception(
              'DATA INTEGRITY FAILURE: Tenant document missing or corrupted.',
            );
          }
        }
      }

      final role =
          (data['role'] ??
                  (currentUser.email == 'dev@clickout.local'
                      ? 'SUPER_ADMIN'
                      : ''))
              .toString()
              .toLowerCase();

      final allowedWebRoles = [
        'super_admin',
        'tenant_admin',
        'delegated_admin',
        'admin',
        'owner',
        'store_manager',
        'manager',
      ];

      if (!allowedWebRoles.contains(role)) {
        await FirebaseAuth.instance.signOut();
        throw "SECURITY ALERT: Invalid Privilege Level. You need Command Center access.";
      }

      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

      await staffRef.update({
        'activeSessionId': newSessionId,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'deviceInfo': kIsWeb ? 'Web Browser' : 'Unknown',
        'suspiciousLoginFlag': false,
      });

      return isFirstTimeLogin;
    } catch (e) {
      throw e.toString();
    } finally {
      state = false;
    }
  }

  Future<void> logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final query = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference
            .update({'activeSessionId': FieldValue.delete()})
            .catchError((_) {});
      }
    }
    await FirebaseAuth.instance.signOut();
  }
}

final authControllerProvider = NotifierProvider<AuthController, bool>(() {
  return AuthController();
});
