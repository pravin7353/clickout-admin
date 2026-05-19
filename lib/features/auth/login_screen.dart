// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // 🚀 IMPORT GOOGLE FONTS
import 'package:shared_preferences/shared_preferences.dart';
// 🚀 ADDED
import 'package:go_router/go_router.dart'; // 🚀 ADDED
import '../../core/auth/unified_auth_service.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _linkSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catchIncomingMagicLink();
    });
  }

  Future<void> _catchIncomingMagicLink() async {
    String currentUrl = Uri.base.toString();

    if (FirebaseAuth.instance.isSignInWithEmailLink(currentUrl)) {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      String? savedEmail = prefs.getString('emailForSignIn');

      if ((savedEmail == null || savedEmail.isEmpty) &&
          _emailController.text.trim().isEmpty) {
        setState(() => _isLoading = false);
        _askForEmailDialog(currentUrl);
        return;
      }

      _executeMagicLogin(
        currentUrl,
        savedEmail ?? _emailController.text.trim(),
      );
    }
  }

  void _askForEmailDialog(String url) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111811),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text(
          "Confirm Email",
          style: GoogleFonts.syne(
            color: const Color(0xFFF0F0F0),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "For security, please confirm your email to board the ship.",
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: confirmCtrl,
              style: GoogleFonts.dmSans(color: const Color(0xFFF0F0F0)),
              decoration: InputDecoration(
                labelText: "Work Email",
                labelStyle: GoogleFonts.dmSans(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF00FF88)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isLoading = false);
            },
            child: Text(
              "CANCEL",
              style: GoogleFonts.dmSans(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeMagicLogin(url, confirmCtrl.text.trim());
            },
            child: Text(
              "LOGIN",
              style: GoogleFonts.dmSans(
                color: const Color(0xFF080B08),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeMagicLogin(String url, String email) async {
    setState(() => _isLoading = true);
    try {
      await UnifiedAuthService.verifyMagicLink(url, fallbackEmail: email);
      final isFirstTime = await ref
          .read(authControllerProvider.notifier)
          .setupAdminSession();

      // 🚀 SECURE ROUTING: Smart Interception
      if (mounted) {
        if (isFirstTime) {
          context.go('/simulator'); // 🚀 New Users get the AI Coach
        } else {
          context.go(
            '/dashboard',
          ); // Existing Users go straight to Command Center
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMagicLink() async {
    if (_emailController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await UnifiedAuthService.sendAdminMagicLink(
        _emailController.text.trim(),
        'com.clickout.admin',
      );
      if (mounted) {
        setState(() => _linkSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Magic Link sent! Please check your Email Inbox."),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDevBypass() async {
    setState(() => _isLoading = true);
    try {
      await UnifiedAuthService.devBypassLogin();
      final isFirstTime = await ref
          .read(authControllerProvider.notifier)
          .setupAdminSession();
      if (mounted) {
        if (isFirstTime) {
          context.go('/simulator');
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Dev Login Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF080B08,
      ), // 🚀 Web Landing Page Background
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04), // 🚀 Glassmorphism Card
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚀 CLAUDE'S TYPOGRAPHY LOGO
              RichText(
                text: TextSpan(
                  style: GoogleFonts.syne(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Click',
                      style: TextStyle(color: Color(0xFFF0F0F0)),
                    ),
                    TextSpan(
                      text: 'Out',
                      style: TextStyle(color: Color(0xFF00FF88)),
                    ), // Neon Green
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Command Center Gateway",
                style: GoogleFonts.dmSans(
                  color: Colors.white54,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              if (!_linkSent) ...[
                // 🚀 CLAUDE'S INPUT FIELD STYLE
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EMAIL ADDRESS",
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFF0F0F0),
                        fontSize: 15,
                      ),
                      cursorColor: const Color(0xFF00FF88),
                      decoration: InputDecoration(
                        hintText: "you@yourstore.com",
                        hintStyle: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.35),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF00FF88),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 🚀 CLAUDE'S GREEN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF080B08),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleMagicLink,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFF080B08),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Send Magic Link →",
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "We will send a secure password-less login link.",
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                  textAlign: TextAlign.center,
                ),

                // 🛠️ DEV BYPASS BUTTON (Match React btn-outline style)
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF0F0F0),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleDevBypass,
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: Text(
                        "DEV BYPASS",
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF00FF88))
                    : const Icon(
                        Icons.mark_email_read,
                        size: 60,
                        color: Color(0xFF00FF88),
                      ),
                const SizedBox(height: 24),
                Text(
                  _isLoading ? "Verifying Magic Link..." : "Check your Email!",
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF0F0F0),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isLoading)
                  Text(
                    "Click the secure link we just sent you to access the Command Center.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 32),
                if (!_isLoading)
                  TextButton(
                    onPressed: () => setState(() => _linkSent = false),
                    child: Text(
                      "Use a different email",
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF00FF88),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
