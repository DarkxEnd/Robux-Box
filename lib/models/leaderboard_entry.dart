import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// One row of `leaderboards/{period}/entries/{uid}`, rebuilt by the scheduled
/// `rebuildLeaderboards` job.
///
/// A denormalised snapshot on purpose: the leaderboard shows a name and photo
/// for users the viewer has no permission to read, so those fields are copied
/// in by the job rather than joined at read time. They can therefore be stale
/// by up to one rebuild interval.
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.uid,
    required this.rank,
    required this.coins,
    this.displayName,
    this.photoUrl,
    this.countryCode,
    this.vipLevel = 'none',
  });

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> map) =>
      LeaderboardEntry(
        uid: uid,
        rank: Parse.toInt(map['rank']),
        coins: Parse.toInt(map['coins']),
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        countryCode: map['countryCode'] as String?,
        vipLevel: Parse.toStr(map['vipLevel'], 'none'),
      );

  final String uid;
  final int rank;

  /// Coins earned within the period, not the current balance — spending must
  /// not drop someone down the board.
  final int coins;
  final String? displayName;
  final String? photoUrl;
  final String? countryCode;
  final String vipLevel;

  bool get isPodium => rank >= 1 && rank <= 3;

  /// Never show a raw uid or email to other users.
  String get safeName {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Player ${uid.substring(0, uid.length.clamp(0, 4))}';
  }

  @override
  List<Object?> get props => [uid, rank, coins, displayName, vipLevel];
}

/// Leaderboard periods. The wire values are the document ids under
/// `leaderboards/`, written by the scheduled job.
enum LeaderboardPeriod {
  daily('daily'),
  weekly('weekly'),
  allTime('all_time');

  const LeaderboardPeriod(this.wire);

  final String wire;
}
