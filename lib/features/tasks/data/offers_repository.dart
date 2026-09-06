import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../models/offer.dart';
import '../../profile/data/user_repository.dart';

/// Featured offers (`offers/{id}`).
///
/// A shop window only — real offers live inside each provider's wall, and
/// completion is credited by their postback. Nothing here can grant coins.
class OffersRepository {
  const OffersRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<Offer>> watch() => _db
      .collection(FsPaths.offers)
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .limit(60)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Offer.fromMap(d.id, d.data())).toList());
}

final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  return OffersRepository(ref.watch(firestoreProvider));
});

/// Offers filtered to the user's country.
///
/// Filtered client-side because the alternative — an `array-contains` on
/// country plus an ordered range — needs a composite index per country, and
/// the collection is small enough that it is not worth it.
final offersProvider = StreamProvider<List<Offer>>((ref) {
  final country = ref.watch(currentUserProvider).valueOrNull?.countryCode;
  return ref
      .watch(offersRepositoryProvider)
      .watch()
      .map((offers) => offers.where((o) => o.isAvailableIn(country)).toList());
});
