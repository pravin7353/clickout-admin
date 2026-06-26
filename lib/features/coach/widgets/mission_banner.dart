// lib/features/coach/widgets/mission_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissionBanner extends ConsumerWidget {
  final String route;
  const MissionBanner({super.key, required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
