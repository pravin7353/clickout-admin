// lib/features/coach/widgets/guidance_toggle.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/coach_provider.dart';
import '../../auth/auth_provider.dart';

class GuidanceToggle extends ConsumerWidget {
  const GuidanceToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminData = ref.watch(adminRoleProvider).value;
    final role = adminData?['role']?.toString().toUpperCase() ?? '';
    if (role == 'SUPER_ADMIN') return const SizedBox.shrink();

    final tenantId = adminData?['tenantId']?.toString() ?? '';
    final mode = ref.watch(guidanceModeProvider);
    final isOn = mode != GuidanceMode.expert;

    return GestureDetector(
      onTap: () {
        if (tenantId.isEmpty) return;
        final next = isOn ? GuidanceMode.expert : GuidanceMode.smart;
        updateGuidanceMode(tenantId, next);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isOn
              ? const Color(0xFF00C853).withOpacity(0.12)
              : Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOn
                ? const Color(0xFF00C853).withOpacity(0.4)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOn ? Icons.school_rounded : Icons.school_outlined,
              color: isOn ? const Color(0xFF00C853) : Colors.white38,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              isOn ? 'Guidance ON' : 'Guidance OFF',
              style: TextStyle(
                color: isOn ? const Color(0xFF00C853) : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
