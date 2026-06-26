import 'package:cloud_firestore/cloud_firestore.dart';

class Tenant {
  final String? id;
  final String companyName;
  final String subscriptionPlan;
  final String billingStatus;
  final int maxStores;
  final int maxUsers;
  final bool fraudDetectionEnabled;
  final int analyticsRetentionDays;
  final DateTime createdAt;
  final bool isActive;
  final DateTime? trialStartAt;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String billingCycle;

  Tenant({
    this.id,
    required this.companyName,
    required this.subscriptionPlan,
    required this.billingStatus,
    required this.maxStores,
    required this.maxUsers,
    required this.fraudDetectionEnabled,
    required this.analyticsRetentionDays,
    required this.createdAt,
    required this.isActive,
    this.trialStartAt,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.billingCycle = 'monthly',
  });

  // Firestore se data read karne ke liye
  factory Tenant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Tenant(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      subscriptionPlan: data['subscriptionPlan'] ?? 'basic',
      billingStatus: data['billingStatus'] ?? 'suspended',
      maxStores: data['limits']?['maxStores'] ?? 0,
      maxUsers: data['limits']?['maxUsers'] ?? 0,
      fraudDetectionEnabled:
          data['features']?['fraudDetectionEnabled'] ?? false,
      analyticsRetentionDays: data['features']?['analyticsRetentionDays'] ?? 30,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      trialStartAt: data['trialStartAt'] != null
          ? (data['trialStartAt'] as Timestamp).toDate()
          : null,
      trialEndsAt: data['trialEndsAt'] != null
          ? (data['trialEndsAt'] as Timestamp).toDate()
          : null,
      currentPeriodEnd: data['currentPeriodEnd'] != null
          ? (data['currentPeriodEnd'] as Timestamp).toDate()
          : null,
      billingCycle: data['billingCycle'] ?? 'monthly',
    );
  }

  // Firestore me data write karne ke liye
  Map<String, dynamic> toFirestore() {
    return {
      'companyName': companyName,
      'subscriptionPlan': subscriptionPlan,
      'billingStatus': billingStatus,
      'limits': {'maxStores': maxStores, 'maxUsers': maxUsers},
      'features': {
        'fraudDetectionEnabled': fraudDetectionEnabled,
        'analyticsRetentionDays': analyticsRetentionDays,
      },
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      if (trialStartAt != null)
        'trialStartAt': Timestamp.fromDate(trialStartAt!),
      if (trialEndsAt != null) 'trialEndsAt': Timestamp.fromDate(trialEndsAt!),
      if (currentPeriodEnd != null)
        'currentPeriodEnd': Timestamp.fromDate(currentPeriodEnd!),
      'billingCycle': billingCycle,
    };
  }
}
