// lib/features/coach/providers/coach_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/auth_provider.dart';
import '../../../features/tenant_admin/providers/tenant_dashboard_provider.dart';

// 3 modes
enum GuidanceMode { beginner, smart, expert }

extension GuidanceModeX on GuidanceMode {
  String get id {
    switch (this) {
      case GuidanceMode.beginner:
        return 'beginner';
      case GuidanceMode.smart:
        return 'smart';
      case GuidanceMode.expert:
        return 'expert';
    }
  }

  String get label {
    switch (this) {
      case GuidanceMode.beginner:
        return '🟢 Beginner';
      case GuidanceMode.smart:
        return '🟡 Smart Assist';
      case GuidanceMode.expert:
        return '🔴 Expert Mode';
    }
  }

  static GuidanceMode fromString(String? v) {
    switch (v) {
      case 'beginner':
        return GuidanceMode.beginner;
      case 'expert':
        return GuidanceMode.expert;
      default:
        return GuidanceMode.smart;
    }
  }
}

// Read current mode from Firestore
final guidanceModeProvider = Provider<GuidanceMode>((ref) {
  final adminData = ref.watch(adminRoleProvider).value;
  if (adminData == null) return GuidanceMode.smart;
  final tenantId = adminData['tenantId']?.toString() ?? '';
  if (tenantId.isEmpty) return GuidanceMode.smart;
  final tenantData = ref.watch(tenantProfileProvider(tenantId)).value;
  final mode = tenantData?['guidanceMode']?.toString();
  return GuidanceModeX.fromString(mode);
});

// Should mission banner show?
final showMissionBannerProvider = Provider<bool>((ref) {
  final mode = ref.watch(guidanceModeProvider);
  return mode != GuidanceMode.expert;
});

// Update mode in Firestore
Future<void> updateGuidanceMode(String tenantId, GuidanceMode mode) async {
  await FirebaseFirestore.instance.collection('tenants').doc(tenantId).update({
    'guidanceMode': mode.id,
  });
}
