// lib/core/subscription/engine/subscription_access_engine.dart

import 'feature_flag_matrix.dart';
import 'subscription_plan.dart';

class SubscriptionAccessEngine {
  // ─────────────────────────────────────────────
  // 1. CORE ACCESS CHECK
  // ─────────────────────────────────────────────

  /// Is this route accessible for the given plan + trial state?
  static bool isRouteAllowed({
    required String route,
    required SubscriptionPlan plan,
    required bool isTrialActive,
  }) {
    // Trial = full access to everything
    if (isTrialActive) return true;
    // Enterprise = full access
    if (plan == SubscriptionPlan.enterprise) return true;

    final minPlan = kRouteMinPlan[route];
    // Route not in matrix = open for all
    if (minPlan == null) return true;

    final userIndex = kPlanHierarchy.indexOf(plan.id);
    final requiredIndex = kPlanHierarchy.indexOf(minPlan);

    if (userIndex == -1 || requiredIndex == -1) return false;
    return userIndex >= requiredIndex;
  }

  // ─────────────────────────────────────────────
  // 2. TRIAL ENGINE
  // ─────────────────────────────────────────────

  static bool isTrialActive(DateTime? trialEndsAt) {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt);
  }

  static int trialDaysRemaining(DateTime? trialEndsAt) {
    if (trialEndsAt == null) return -1;
    final remaining = trialEndsAt.difference(DateTime.now()).inDays;
    return remaining >= 0 ? remaining : -1;
  }

  // ─────────────────────────────────────────────
  // 3. SUBSCRIPTION EXPIRY
  // ─────────────────────────────────────────────

  static bool isExpired(String billingStatus) {
    return billingStatus == 'expired' || billingStatus == 'suspended';
  }

  // ─────────────────────────────────────────────
  // 4. USAGE LIMITS
  // ─────────────────────────────────────────────

  static bool isTransactionLimitReached({
    required SubscriptionPlan plan,
    required int currentCount,
  }) {
    return currentCount >= plan.maxTransactions;
  }

  static bool isTransactionWarning({
    required SubscriptionPlan plan,
    required int currentCount,
  }) {
    if (plan.maxTransactions == 999999) return false;
    final percent = currentCount / plan.maxTransactions;
    return percent >= 0.9;
  }

  static bool isCampaignLimitReached({
    required SubscriptionPlan plan,
    required int currentCount,
  }) {
    if (plan.maxCampaigns == 999999) return false;
    return currentCount >= plan.maxCampaigns;
  }

  static bool isStaffLimitReached({
    required SubscriptionPlan plan,
    required int currentCount,
  }) {
    return currentCount >= plan.maxStaff;
  }

  // ─────────────────────────────────────────────
  // 5. UPGRADE MESSAGE HELPERS
  // ─────────────────────────────────────────────

  static String getUpgradeMessage(String route) {
    return kRouteUpgradeMessage[route] ??
        'Upgrade your plan to unlock this feature';
  }

  static List<String> getFeatureBullets(String route) {
    return kRouteFeatureBullets[route] ?? [];
  }

  static String getRequiredPlanName(String route) {
    final minPlan = kRouteMinPlan[route];
    if (minPlan == null) return '';
    return subscriptionPlanFromString(minPlan).displayName;
  }
}
