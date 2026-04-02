// lib/core/auth/unified_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnifiedAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================================
  // 📱 1. PHONE OTP ENGINE (Customers, Guards, Cashiers)
  // ==========================================================

  static Future<void> sendPhoneOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getInt('last_otp_$phone') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastSent < 60000) {
        throw "Please wait 60 seconds before requesting another OTP.";
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification failed.");
        },
        codeSent: (String verificationId, int? resendToken) async {
          await prefs.setInt(
            'last_otp_$phone',
            DateTime.now().millisecondsSinceEpoch,
          );
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  static Future<UserCredential?> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
    required String roleCollection,
    required Map<String, dynamic> initialData,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        final docRef = _db.collection(roleCollection).doc(userCred.user!.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          bool isAutoActive = (roleCollection == 'users');
          await docRef.set({
            ...initialData,
            'uid': userCred.user!.uid,
            'phone': userCred.user!.phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': isAutoActive,
          });
        }

        await docRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'activeSessionId': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      }
      return userCred;
    } catch (e) {
      throw "Invalid OTP. Please try again.";
    }
  }

  // ==========================================================
  // 📧 2. ADMIN MAGIC LINK (Passwordless - Ultra Secure)
  // ==========================================================

  static Future<void> sendAdminMagicLink(String email, String bundleId) async {
    try {
      // 🚀 SAAS UPDATE: Allow link delivery for both new (Signup) and existing (Login) users
      final query = await _db
          .collection('staff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data();
        if (userData['isActive'] == false || userData['isDeleted'] == true) {
          throw "Account Suspended: Please contact support.";
        }

        final role = (userData['role'] ?? '').toString().toLowerCase();
        final allowedWebRoles = [
          'super_admin',
          'tenant_admin',
          'delegated_admin',
          'admin',
          'owner',
          'manager',
        ];

        if (!allowedWebRoles.contains(role)) {
          throw "Access Denied: You do not have Command Center privileges.";
        }
      }
      // If query is empty, it's a new signup! They bypass the role check to receive the magic link.

      // final String redirectUrl = kDebugMode
      //     ? 'http://localhost:50000/'
      //     : 'https://clickout-cfa95.web.app/';

      // var acs = ActionCodeSettings(
      //   url: redirectUrl,
      // 🚀 YOSH! Ab yeh browser ka current port khud dhundh lega!
      final String currentDomain = kIsWeb
          ? Uri.base.origin
          : 'https://clickout-cfa95.web.app';
      final String redirectUrl = '$currentDomain/#/login';

      var acs = ActionCodeSettings(
        url: redirectUrl,
        handleCodeInApp: true,
        iOSBundleId: bundleId,
        androidPackageName: bundleId,
        androidInstallApp: false,
        androidMinimumVersion: '12',
      );

      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', email);
    } catch (e) {
      throw e.toString();
    }
  }

  // 🛡️ Added fallbackEmail parameter
  static Future<void> verifyMagicLink(
    String emailLink, {
    String? fallbackEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('emailForSignIn');

    // Agar LocalStorage khali hai (port mismatch), toh UI se email utha lo
    if (email == null || email.isEmpty) {
      email = fallbackEmail;
    }

    if (email == null || email.isEmpty) {
      throw "Memory lost! Please type your email in the box before clicking the link, or send a new one.";
    }

    if (_auth.isSignInWithEmailLink(emailLink)) {
      try {
        await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
        await prefs.remove('emailForSignIn');
      } catch (e) {
        throw "Error signing in with link: $e";
      }
    }
  }

  // ==========================================================
  // 🚪 3. GLOBAL LOGOUT
  // ==========================================================
  static Future<void> logout(String roleCollection) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db
          .collection(roleCollection)
          .doc(user.uid)
          .update({'activeSessionId': FieldValue.delete()})
          .catchError((_) {});
    }
    await _auth.signOut();
  }

  // ==========================================================
  // 🛠️ 4. DEV BYPASS LOGIN (Localhost Only)
  // ==========================================================
  static Future<void> devBypassLogin() async {
    if (!kDebugMode) return;

    const devEmail = 'dev@clickout.local';
    const devPassword = 'password123';

    try {
      await _auth.signInWithEmailAndPassword(
        email: devEmail,
        password: devPassword,
      );
    } catch (e) {
      // User doesn't exist, create on the fly
      final cred = await _auth.createUserWithEmailAndPassword(
        email: devEmail,
        password: devPassword,
      );

      await _db.collection('staff').doc(cred.user!.uid).set({
        'email': devEmail,
        'role': 'SUPER_ADMIN',
        'isActive': true,
        'isDeleted':
            false, // IMPORTANT: Without this, auth_provider query fails!
        'name': 'Dev Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
