import 'package:flutter/material.dart';
import 'dart:async';

// ==========================================
// 🚀 1. ACTION DEBOUNCER (Prevents spam clicks/API calls)
// ==========================================
class ActionDebouncer {
  final int milliseconds;
  Timer? _timer;

  ActionDebouncer({this.milliseconds = 500});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

// ==========================================
// 🚀 2. BACKEND ERROR PARSER (Standardizes error messages)
// ==========================================
String parseBackendError(dynamic error) {
  if (error == null) return "An unknown error occurred.";
  
  String errorStr = error.toString();
  // Remove common Dart/Firebase exception prefixes to keep it clean for UI
  errorStr = errorStr.replaceAll('Exception:', '').replaceAll('FirebaseException:', '').trim();
  
  return errorStr;
}

// ==========================================
// 🚀 3. SKELETON LOADER (For consistent loading states)
// ==========================================
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}