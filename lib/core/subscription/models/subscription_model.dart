// lib/core/subscription/models/subscription_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionUsage {
  final int transactionCount;
  final int staffCount;
  final int terminalCount;
  final int campaignCount;
  final DateTime? lastUpdatedAt;

  const SubscriptionUsage({
    this.transactionCount = 0,
    this.staffCount = 0,
    this.terminalCount = 0,
    this.campaignCount = 0,
    this.lastUpdatedAt,
  });

  factory SubscriptionUsage.fromFirestore(Map<String, dynamic> data) {
    return SubscriptionUsage(
      transactionCount: data['transactionCount'] ?? 0,
      staffCount: data['staffCount'] ?? 0,
      terminalCount: data['terminalCount'] ?? 0,
      campaignCount: data['campaignCount'] ?? 0,
      lastUpdatedAt: data['lastUpdatedAt'] != null
          ? (data['lastUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory SubscriptionUsage.empty() => const SubscriptionUsage();
}
