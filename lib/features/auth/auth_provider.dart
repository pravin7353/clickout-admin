// lib/features/auth/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import '../../../core/providers/access_control_provider.dart';

// 1. Firebase Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 2. 🛡️ ENTERPRISE SESSION & ROLE MANAGER (The Vault)
final adminRoleProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.email == null) return Stream.value(null);

  // 🚀 FIXED: Search by Email instead of UID
  return FirebaseFirestore.instance
      .collection('staff')
      .where('email', isEqualTo: user.email)
      .where('isDeleted', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return snapshot.docs.first.data();
      });
});

// 3. The Auth Controller
class AuthController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> setupAdminSession() async {
    state = true;
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw "Authentication failed. No active user found.";
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('email', isEqualTo: currentUser.email)
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        await FirebaseAuth.instance.signOut();
        throw "SECURITY ALERT: Access Denied! You are not registered as an Admin.";
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final role = (data['role'] ?? '').toString().toLowerCase();

      // 🚀 ALL SAAS ROLES ALLOWED
      final allowedWebRoles = [
        'super_admin',
        'tenant_admin',
        'delegated_admin',
        'admin',
        'owner',
        'manager', // 🍖 Gomu Gomu no Entry Allowed!
      ];

      if (!allowedWebRoles.contains(role)) {
        await FirebaseAuth.instance.signOut();
        throw "SECURITY ALERT: Invalid Privilege Level. You need Command Center access.";
      }

      final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

      await doc.reference.update({
        'activeSessionId': newSessionId,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'deviceInfo': kIsWeb ? 'Web Browser' : 'Unknown',
        'suspiciousLoginFlag': false,
      });
    } catch (e) {
      throw e.toString();
    } finally {
      state = false;
    }
  }

  Future<void> logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // Find the document by email to delete session ID
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
