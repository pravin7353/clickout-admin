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

final storesStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.keepAlive();
      return FirebaseFirestore.instance
          .collection('stores')
          .where(
            'isDeleted',
            isEqualTo: false,
          ) // ⚡ FIX: Prevents silent exclusion of documents missing this field. Ensure all your DB docs have isDeleted: false.
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
          );
    });
