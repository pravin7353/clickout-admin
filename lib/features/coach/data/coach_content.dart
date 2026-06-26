// lib/features/coach/data/coach_content.dart

class CoachContent {
  static const Map<String, Map<String, String>> screens = {
    '/manager': {
      'title': 'Super Manager',
      'mission': 'Add, remove, reassign staff across stores from one place.',
      'impact': 'Wrong role assignment = security risk + operational chaos.',
      'tip':
          'Review inactive staff monthly — dormant accounts are a fraud risk.',
    },
    '/dashboard': {
      'title': 'Revenue Command Center',
      'mission': 'Real-time financial health of your store.',
      'impact': '1% leakage on ₹5L/month = ₹5,000 loss. Catch it here.',
      'tip': 'Settlement pending > 2 hrs = investigate immediately.',
    },
    '/growth': {
      'title': 'Growth Radar',
      'mission': 'Predict churn before customer disappears.',
      'impact': 'Retaining 1 VIP customer = ₹500-2000 avg revenue saved.',
      'tip': 'Ghost visitors = visited but never bought. Target them first.',
    },
    '/fraud': {
      'title': 'Fraud Control',
      'mission': 'Detect financial leakage before it drains profit.',
      'impact': '2% staff fraud on ₹10L/month = ₹20,000 silent loss.',
      'tip': 'Red alerts older than 24hrs need immediate investigation.',
    },
    '/procurement': {
      'title': 'Procurement & Supply Chain',
      'mission': 'Optimize stock flow, eliminate dead inventory.',
      'impact': 'Dead stock = blocked capital. Every unsold item costs money.',
      'tip': 'Reorder when stock hits 20% — not when its zero.',
    },
    '/refunds': {
      'title': 'Refund Engine',
      'mission': 'Monitor refund patterns to catch abuse early.',
      'impact': '3 refunds by same cashier in 1 hour = high fraud risk.',
      'tip': 'Healthy refund rate < 2% of daily transactions.',
    },
    '/auditor': {
      'title': 'Super Auditor',
      'mission': 'Complete financial audit trail of every rupee.',
      'impact': 'Cash variance > ₹500/day = process breakdown.',
      'tip': 'Reconcile daily — not weekly. Weekly is too late.',
    },

    '/guard': {
      'title': 'Super Guard',
      'mission': 'Zero unauthorized exits. Every cart accounted for.',
      'impact': 'Unverified exit = potential shoplifting or billing fraud.',
      'tip': 'Gate rejection rate > 5% = cashier workflow problem.',
    },
    '/risk': {
      'title': 'Risk Engine',
      'mission': 'AI-level pattern detection before losses occur.',
      'impact': 'Early risk detection saves 3-8x more than post-loss recovery.',
      'tip': 'Yellow alerts = monitor. Red alerts = act within 1 hour.',
    },
    '/inventory': {
      'title': 'Product Control',
      'mission': 'Live inventory intelligence — know before stockout.',
      'impact': 'Stockout during peak = direct revenue loss + customer churn.',
      'tip': 'Fast-moving SKUs need weekly review minimum.',
    },
    '/service-control': {
      'title': 'Service Control',
      'mission': 'Track service performance and labor efficiency.',
      'impact': 'Delayed service = repeat customer loss.',
      'tip': 'Services with zero bookings in 30 days = review or remove.',
    },
  };

  static Map<String, String>? get(String route) => screens[route];
}
