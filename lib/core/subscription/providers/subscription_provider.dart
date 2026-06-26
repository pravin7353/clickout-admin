// lib/core/subscription/providers/subscription_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../engine/subscription_plan.dart';
import '../engine/subscription_access_engine.dart';
import '../../providers/access_control_provider.dart';
import '../../../features/auth/auth_provider.dart';

// ─────────────────────────────────────────────
// Service instance
// ─────────────────────────────────────────────

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

// ─────────────────────────────────────────────
// Current tenant's parsed plan enum
// ─────────────────────────────────────────────

final subscriptionPlanProvider = Provider<SubscriptionPlan>((ref) {
  final planString = ref.watch(currentPlanProvider);
  return subscriptionPlanFromString(planString);
});

// ─────────────────────────────────────────────
// Trial state
// ─────────────────────────────────────────────

final isTrialActiveProvider = Provider<bool>((ref) {
  // Agar paid plan hai to trial override — lock dikhega as per plan
  final plan = ref.watch(currentPlanProvider);
  if (plan != 'trial' && plan != 'mini') return false;
  // mini pe bhi trial benefits nahi — sirf trial plan pe
  if (plan == 'mini') return false;
  final days = ref.watch(trialDaysRemainingProvider);
  return days >= 0;
});

// ─────────────────────────────────────────────
// Usage ledger stream for current month
// ─────────────────────────────────────────────

final usageLedgerProvider = StreamProvider<SubscriptionUsage>((ref) {
  final adminData = ref.read(adminRoleProvider).value;
  if (adminData == null) return Stream.value(SubscriptionUsage.empty());
  final tenantId = adminData['tenantId']?.toString() ?? '';
  if (tenantId.isEmpty) return Stream.value(SubscriptionUsage.empty());
  return ref.read(subscriptionServiceProvider).watchUsage(tenantId);
});

// ─────────────────────────────────────────────
// Transaction warning (90% threshold)
// ─────────────────────────────────────────────

final isTransactionWarningProvider = Provider<bool>((ref) {
  final plan = ref.watch(subscriptionPlanProvider);
  final usageAsync = ref.watch(usageLedgerProvider);
  return usageAsync.maybeWhen(
    data: (usage) => SubscriptionAccessEngine.isTransactionWarning(
      plan: plan,
      currentCount: usage.transactionCount,
    ),
    orElse: () => false,
  );
});

// ─────────────────────────────────────────────
// Campaign limit check (PRO = max 10)
// ─────────────────────────────────────────────

final isCampaignLimitReachedProvider = Provider<bool>((ref) {
  final plan = ref.watch(subscriptionPlanProvider);
  if (plan.maxCampaigns == 999999) return false;
  if (plan.maxCampaigns == 0)
    return false; // MINI — procurement locked, no banner
  final usageAsync = ref.watch(usageLedgerProvider);
  return usageAsync.maybeWhen(
    data: (usage) {
      if (usage.campaignCount == 0) return false; // No campaigns yet
      return SubscriptionAccessEngine.isCampaignLimitReached(
        plan: plan,
        currentCount: usage.campaignCount,
      );
    },
    orElse: () => false,
  );
});

// ─────────────────────────────────────────────
// Staff limit check
// ─────────────────────────────────────────────

final isStaffLimitReachedProvider = Provider<bool>((ref) {
  final plan = ref.watch(subscriptionPlanProvider);
  final usageAsync = ref.watch(usageLedgerProvider);
  return usageAsync.maybeWhen(
    data: (usage) => SubscriptionAccessEngine.isStaffLimitReached(
      plan: plan,
      currentCount: usage.staffCount,
    ),
    orElse: () => false,
  );
});
