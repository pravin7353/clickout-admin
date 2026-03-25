import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📊 FETCH TODAY'S AGGREGATED STATS (O(1) Query)
  Stream<DocumentSnapshot> getTodayStoreStats(String storeId) {
    // Date format wahi same nikalna hai jo backend me tha: YYYY-MM-DD
    String todayDate = DateTime.now().toIso8601String().split('T')[0];
    String docId = '${storeId}_$todayDate';

    return _db.collection('daily_store_stats').doc(docId).snapshots();
  }
}
