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
import '../../core/utils/standard_utils.dart'; // 🚀 5 Standard Rules
import 'auth_provider.dart';
import '../../core/providers/theme_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _linkSent = false;
  final ActionDebouncer _authDebouncer = ActionDebouncer(
    milliseconds: 1500,
  ); // 🚀 Debouncing Rule

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
        return AlertDialog(
          backgroundColor: context.colors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.colors.border),
          ),
          title: Text(
            "Confirm Email",
            style: GoogleFonts.syne(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "For security, please confirm your email to board the ship.",
                style: GoogleFonts.dmSans(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: confirmCtrl,
                style: TextStyle(color: context.colors.textPrimary),
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
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.ctaBackground,
                foregroundColor: context.colors.ctaText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeMagicLogin(url, confirmCtrl.text.trim());
              },
              child: Text(
                "LOGIN",
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.bold,
                  color: context.colors.ctaText,
                ),
              ),
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
            content: Text(
              "Login Error: ${parseBackendError(e)}",
            ), // 🚀 Backend Validation Rule
            backgroundColor: context.colors.danger,
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
          SnackBar(
            content: const Text(
              "Magic Link sent! Please check your Email Inbox. Check Spam if you don't see it.",
            ),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.colors.danger,
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
            backgroundColor: context.colors.danger,
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

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: Stack(
        children: [
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: context.colors.textPrimary,
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            ),
          ),
          Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: context.colors.cardBg,
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.syne(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Click',
                          style: TextStyle(color: context.colors.textPrimary),
                        ),
                        TextSpan(
                          text: 'Out',
                          style: TextStyle(color: context.colors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Command Center Gateway",
                    style: GoogleFonts.dmSans(
                      color: context.colors.textSecondary,
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
                            color: context.colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          style: GoogleFonts.dmSans(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: context.colors.ctaBackground,
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
                          backgroundColor: context.colors.ctaBackground,
                          foregroundColor: context.colors.ctaText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleMagicLink,
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: context.colors.ctaText,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Send Magic Link →",
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.ctaText,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "We will send a secure password-less login link.",
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: context.colors.textSecondary,
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
                        ? CircularProgressIndicator(
                            color: context.colors.ctaBackground,
                          )
                        : Icon(
                            Icons.mark_email_read,
                            size: 60,
                            color: context.colors.success,
                          ),
                    const SizedBox(height: 24),
                    Text(
                      _isLoading
                          ? "Verifying Magic Link..."
                          : "Check your Email!",
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_isLoading)
                      Text(
                        "Click the secure link we just sent you to access the Command Center.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: context.colors.textSecondary,
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
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
