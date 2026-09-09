import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart' show CombineLatestStream;

import '../../../core/config/providers.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../models/achievement.dart';

/// The achievement catalogue and the user's progress against it.
class AchievementRepository {
  const AchievementRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<Achievement>> watchCatalogue() => _db
      .collection(FsPaths.achievements)
      .where('isActive', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => Achievement.fromMap(d.id, d.data())).toList(),
      );

  Stream<Map<String, UserAchievement>> watchProgress(String uid) => _db
      .collection(FsPaths.users)
      .doc(uid)
      .collection(FsPaths.userAchievements)
      .snapshots()
      .map(
        (snap) => {
          for (final d in snap.docs)
            d.id: UserAchievement.fromMap(d.id, d.data()),
        },
      );
}

final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  return AchievementRepository(ref.watch(firestoreProvider));
});

/// Catalogue joined with the user's state.
///
/// Two streams rather than one denormalised collection: the catalogue is
/// shared by every user and the progress is private, so they cannot live in
/// the same document without either duplicating the catalogue per user or
/// making progress world-readable.
final achievementsProvider = StreamProvider<List<AchievementView>>((ref) {
  final repo = ref.watch(achievementRepositoryProvider);
  final uid = ref.watch(currentUidProvider);

  if (uid == null) {
    return repo.watchCatalogue().map(
      (list) => list.map((a) => AchievementView(a, null)).toList(),
    );
  }

  return CombineLatestStream.combine2(
    repo.watchCatalogue(),
    repo.watchProgress(uid),
    (List<Achievement> catalogue, Map<String, UserAchievement> progress) =>
        catalogue.map((a) => AchievementView(a, progress[a.id])).toList(),
  );
});
