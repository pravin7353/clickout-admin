// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/unified_auth_service.dart';
import '../../core/theme/app_theme.dart';
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
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          title: Text(
            "Confirm Email",
            style: GoogleFonts.syne(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "For security, please confirm your email to board the ship.",
                style: GoogleFonts.dmSans(
                  color: tt.labelLarge?.color,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: confirmCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: const InputDecoration(labelText: "Work Email"),
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
                style: TextStyle(color: tt.labelLarge?.color),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeMagicLogin(url, confirmCtrl.text.trim());
              },
              child: const Text("LOGIN"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeMagicLogin(String url, String email) async {
    setState(() => _isLoading = true);
    try {
      await UnifiedAuthService.verifyMagicLink(url, fallbackEmail: email);
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
            content: Text("Login Error: $e"),
            backgroundColor: AppColors.error,
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
            content: Text(
              "Magic Link sent! Please check your Email Inbox. Check Spam if you don't see it.",
            ),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.syne(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                  children: [
                    TextSpan(
                      text: 'Click',
                      style: TextStyle(color: cs.onSurface),
                    ),
                    const TextSpan(
                      text: 'Out',
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Command Center Gateway",
                style: GoogleFonts.dmSans(
                  color: tt.labelLarge?.color,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              if (!_linkSent) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EMAIL ADDRESS",
                      style: GoogleFonts.dmSans(
                        color: tt.labelLarge?.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                      cursorColor: AppColors.accent,
                      decoration: const InputDecoration(
                        hintText: "you@yourstore.com",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _handleMagicLink,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
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
                    color: tt.labelLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
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
                    ? const CircularProgressIndicator(color: AppColors.accent)
                    : const Icon(
                        Icons.mark_email_read,
                        size: 60,
                        color: AppColors.accent,
                      ),
                const SizedBox(height: 24),
                Text(
                  _isLoading ? "Verifying Magic Link..." : "Check your Email!",
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isLoading)
                  Text(
                    "Click the secure link we just sent you to access the Command Center.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: tt.labelLarge?.color,
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
                        color: AppColors.accent,
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
