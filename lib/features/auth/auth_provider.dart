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

      DocumentReference staffRef;
      Map<String, dynamic> data;

      if (querySnapshot.docs.isEmpty) {
        // 🚀 ENTERPRISE PROVISIONING ENGINE: Perfect Schema Generator
        final String rawName = currentUser.email!.split('@')[0].toUpperCase();
        final String prefix = rawName.length >= 3
            ? rawName.substring(0, 3)
            : rawName;
        final String newTenantId =
            '${prefix}_${DateTime.now().millisecondsSinceEpoch}'; // Format: JYO_173...

        staffRef = FirebaseFirestore.instance
            .collection('staff')
            .doc(currentUser.uid);
        final batch = FirebaseFirestore.instance.batch();

        // 1. Create Enterprise-Grade Tenant Doc (Matches your Exact Database Structure!)
        batch.set(
          FirebaseFirestore.instance.collection('tenants').doc(newTenantId),
          {
            'tenantId': newTenantId,
            'companyName':
                '${currentUser.email!.split('@')[0].toUpperCase()} ENTERPRISES',
            'ownerName': currentUser.email!.split('@')[0],
            'businessType': 'Super Mart', // Default fallback
            'establishedYear': DateTime.now().year,
            'isOnboardingComplete':
                true, // 🚀 FIX: Skip that old deleted screen forever!
            'status': 'ACTIVE',
            'plan': 'PRO PLAN',
            'activeStores': 0,
            'contact': {'email': currentUser.email, 'phone': ''},
            'location': {'address': '', 'city': '', 'state': '', 'pincode': ''},
            'kyc': {'pan': '', 'gstin': ''},
            'bankDetails': {
              'accountName': '',
              'accountNo': '',
              'ifsc': '',
              'upi': '',
            },
            'config': {
              'openTime': '09:00 AM',
              'closeTime': '10:00 PM',
              'expectedEmployees': 0,
              'monthlyVolume': 'Under 1,000',
            },
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // 2. Create Staff Record as TENANT_ADMIN
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
      }
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

      // 🚀 FIX: Used 'staffRef' instead of 'doc.reference'
      await staffRef.update({
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
