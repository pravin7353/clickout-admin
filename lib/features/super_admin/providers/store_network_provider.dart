import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreTenantFilter extends Notifier<String> {
  @override
  String build() => 'ALL';

  void updateFilter(String val) {
    state = val;
  }
}

final storeTenantFilterProvider = NotifierProvider<StoreTenantFilter, String>(
  () {
    return StoreTenantFilter();
  },
);

final storesStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) {
  ref.keepAlive();
  return FirebaseFirestore.instance
      .collection('stores')
      // 🚀 COST FIX: Ye pehle poore platform ke saare stores (sab tenants) real-time
      // stream karta tha bina kisi limit ke — jaise-jaise tenants/stores badhenge
      // billing/perf risk badhta jayega. Abhi ke liye ek safety cap laga diya hai.
      // TODO: Isse proper pagination (startAfterDocument + "Load More") me convert
      // karna chahiye jab store count consistently 500 se zyada rehne lage.
      .limit(500)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            // ⚡ FIX: isEqualTo bhi un docs ko exclude karta hai jinme
            // field hi missing hai. Client-side filter guarantee karta
            // hai purane docs bhi list mein aayein.
            .where((s) => s['isDeleted'] != true)
            .toList(),
      );
});
