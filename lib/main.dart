import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("🔥 Firebase Init Error: $e");
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint("🚨 FLUTTER CAUGHT ERROR: ${details.exception}");
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("🚨 PLATFORM CAUGHT ERROR: $error");
    return true;
  };

  runApp(const ProviderScope(child: ClickOutAdminApp()));
}

class ClickOutAdminApp extends ConsumerWidget {
  const ClickOutAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeProvider).currentTheme; // 🚀 NAYA FIX

    return MaterialApp.router(
      title: 'ClickOut Command Center',
      debugShowCheckedModeBanner: false,
      routerConfig: router,

      // 🎨 Dual Theme Integration
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    );
  }
}
