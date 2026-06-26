// lib/core/subscription/engine/subscription_plan.dart

enum SubscriptionPlan { trial, mini, pro, growth, enterprise }

extension SubscriptionPlanX on SubscriptionPlan {
  String get id {
    switch (this) {
      case SubscriptionPlan.trial:
        return 'trial';
      case SubscriptionPlan.mini:
        return 'mini';
      case SubscriptionPlan.pro:
        return 'pro';
      case SubscriptionPlan.growth:
        return 'growth';
      case SubscriptionPlan.enterprise:
        return 'enterprise';
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionPlan.trial:
        return 'Free Trial';
      case SubscriptionPlan.mini:
        return 'Mini';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.growth:
        return 'Growth';
      case SubscriptionPlan.enterprise:
        return 'Enterprise';
    }
  }

  int get monthlyPrice {
    switch (this) {
      case SubscriptionPlan.trial:
        return 0;
      case SubscriptionPlan.mini:
        return 99;
      case SubscriptionPlan.pro:
        return 299;
      case SubscriptionPlan.growth:
        return 699;
      case SubscriptionPlan.enterprise:
        return 0; // Custom
    }
  }

  int get yearlyPrice {
    switch (this) {
      case SubscriptionPlan.trial:
        return 0;
      case SubscriptionPlan.mini:
        return 79;
      case SubscriptionPlan.pro:
        return 239;
      case SubscriptionPlan.growth:
        return 599;
      case SubscriptionPlan.enterprise:
        return 0;
    }
  }

  int get maxTransactions {
    switch (this) {
      case SubscriptionPlan.trial:
        return 999999;
      case SubscriptionPlan.mini:
        return 100;
      case SubscriptionPlan.pro:
        return 1000;
      case SubscriptionPlan.growth:
        return 999999;
      case SubscriptionPlan.enterprise:
        return 999999;
    }
  }

  int get maxStaff {
    switch (this) {
      case SubscriptionPlan.trial:
        return 999999;
      case SubscriptionPlan.mini:
        return 2;
      case SubscriptionPlan.pro:
        return 4;
      case SubscriptionPlan.growth:
        return 999999;
      case SubscriptionPlan.enterprise:
        return 999999;
    }
  }

  int get maxTerminals {
    switch (this) {
      case SubscriptionPlan.trial:
        return 999999;
      case SubscriptionPlan.mini:
        return 1;
      case SubscriptionPlan.pro:
        return 3;
      case SubscriptionPlan.growth:
        return 5;
      case SubscriptionPlan.enterprise:
        return 999999;
    }
  }

  int get maxCampaigns {
    switch (this) {
      case SubscriptionPlan.trial:
        return 999999;
      case SubscriptionPlan.mini:
        return 0; // Procurement locked
      case SubscriptionPlan.pro:
        return 10; // Hard limit
      case SubscriptionPlan.growth:
        return 999999;
      case SubscriptionPlan.enterprise:
        return 999999;
    }
  }
}

SubscriptionPlan subscriptionPlanFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'trial':
      return SubscriptionPlan.trial;
    case 'mini':
      return SubscriptionPlan.mini;
    case 'pro':
      return SubscriptionPlan.pro;
    case 'growth':
      return SubscriptionPlan.growth;
    case 'enterprise':
      return SubscriptionPlan.enterprise;
    default:
      return SubscriptionPlan.mini;
  }
}
