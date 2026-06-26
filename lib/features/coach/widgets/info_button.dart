// lib/features/coach/widgets/info_button.dart

import 'package:flutter/material.dart';

class InfoButton extends StatelessWidget {
  final String title;
  final String en;
  final String hi;
  final Color? iconColor;

  const InfoButton({
    super.key,
    required this.title,
    required this.en,
    required this.hi,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: '$en\n\n🇮🇳 $hi',
      preferBelow: true,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        height: 1.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A221A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(
        Icons.info_outline_rounded,
        size: 13,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }
}
