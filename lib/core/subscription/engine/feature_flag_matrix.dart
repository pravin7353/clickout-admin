// lib/core/subscription/engine/feature_flag_matrix.dart

// Route → Minimum plan required to access
// Routes NOT in this map = open for all plans
const Map<String, String> kRouteMinPlan = {
  '/manager': 'pro',
  '/auditor': 'mini',
  '/refunds': 'pro',
  '/growth': 'pro',
  '/procurement': 'pro',
  '/fraud': 'pro',
  '/campaign-manager': 'pro',
  '/guard': 'growth',
  '/risk': 'growth',
  '/qr-reactivation': 'growth',
};

// Plan hierarchy — order matters
const List<String> kPlanHierarchy = [
  'trial',
  'mini',
  'pro',
  'growth',
  'enterprise',
];

// Upgrade message shown in lock widget
const Map<String, String> kRouteUpgradeMessage = {
  '/manager': 'Upgrade to PRO to manage your staff',
  '/auditor': 'Upgrade to PRO for Super Auditor suite',
  '/refunds': 'Upgrade to PRO for Refund Engine',
  '/growth': 'Upgrade to PRO for Growth Radar & churn intelligence',
  '/procurement': 'Upgrade to PRO for Procurement module',
  '/fraud': 'Upgrade to PRO for Fraud Detection',
  '/campaign-manager': 'Upgrade to PRO to run offer campaigns',
  '/guard': 'Upgrade to GROWTH for Super Guard',
  '/risk': 'Upgrade to GROWTH for Risk Engine AI',
  '/qr-reactivation': 'Upgrade to GROWTH for QR Bailout',
};

// Features shown inside lock widget (curiosity bullets)
const Map<String, List<String>> kRouteFeatureBullets = {
  '/manager': [
    'Staff onboarding & command management',
    'Role-based performance monitoring',
    'Shift scheduling & attendance',
  ],
  '/auditor': [
    'Cash reconciliation dashboard',
    'Time intelligence reports',
    'Vault audit trail',
  ],
  '/refunds': [
    'Automated refund decision engine',
    'Financial leakage detection',
    'Refund fraud scoring',
  ],
  '/growth': [
    'VIP customer tracking',
    'Ghost visitor detection',
    'Churn prediction & offers',
  ],
  '/procurement': [
    'Purchase order management',
    'Distributor intelligence',
    'Stock alert automation',
  ],
  '/fraud': [
    'Real-time anomaly detection',
    'Leakage kanban board',
    'Staff fraud scoring',
  ],
  '/guard': [
    'AI-powered entry control',
    'Gate pass intelligence',
    'Exit scan analytics',
  ],
  '/risk': [
    'Risk Engine AI scoring',
    'Operational intelligence layer',
    'Threat pattern recognition',
  ],
  '/qr-reactivation': [
    'QR bailout for blocked carts',
    'Emergency checkout recovery',
    'Session reactivation logs',
  ],
};
