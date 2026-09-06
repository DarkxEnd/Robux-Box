import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// A catalogue achievement (`achievements/{id}`), seeded by
/// `scripts/seed.js`. `metric` names a field on the wallet document that the
/// `syncAchievementsOnWalletWrite` trigger compares against [threshold], so a
/// new achievement can be added without deploying functions.
class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.threshold,
    this.rewardCoins = 0,
    this.iconUrl = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Achievement.fromMap(String id, Map<String, dynamic> map) =>
      Achievement(
        id: id,
        title: Parse.toStr(map['title']),
        description: Parse.toStr(map['description']),
        metric: Parse.toStr(map['metric'], 'lifetimeEarned'),
        threshold: Parse.toInt(map['threshold']),
        rewardCoins: Parse.toInt(map['rewardCoins']),
        iconUrl: Parse.toStr(map['iconUrl']),
        isActive: Parse.toBool(map['isActive'], true),
        sortOrder: Parse.toInt(map['sortOrder']),
      );

  final String id;
  final String title;
  final String description;

  /// Wallet field to measure — `lifetimeEarned` or `lifetimeSpent`.
  final String metric;
  final int threshold;
  final int rewardCoins;
  final String iconUrl;
  final bool isActive;
  final int sortOrder;

  @override
  List<Object?> get props => [id, title, metric, threshold, rewardCoins];
}

/// Per-user unlock state (`users/{uid}/achievements/{achievementId}`).
///
/// Unlocking and paying are two steps: the trigger writes [unlockedAt] as soon
/// as the threshold is crossed, and [claimedAt] is set only when the user taps
/// to collect. That split is what stops a coin grant from happening inside a
/// Firestore trigger that could re-fire.
class UserAchievement extends Equatable {
  const UserAchievement({
    required this.achievementId,
    this.unlockedAt,
    this.claimedAt,
    this.progress = 0,
  });

  factory UserAchievement.fromMap(String id, Map<String, dynamic> map) =>
      UserAchievement(
        achievementId: id,
        unlockedAt: Parse.toDate(map['unlockedAt']),
        claimedAt: Parse.toDate(map['claimedAt']),
        progress: Parse.toInt(map['progress']),
      );

  final String achievementId;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;

  /// The metric's value the last time the trigger ran — used for the progress
  /// bar on locked achievements.
  final int progress;

  bool get isUnlocked => unlockedAt != null;
  bool get isClaimed => claimedAt != null;
  bool get isClaimable => isUnlocked && !isClaimed;

  double progressFraction(int threshold) =>
      threshold <= 0 ? 1 : (progress / threshold).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [achievementId, unlockedAt, claimedAt, progress];
}

/// An achievement paired with the current user's state for it. [state] is null
/// when the user has never touched the metric.
class AchievementView extends Equatable {
  const AchievementView(this.achievement, this.state);

  final Achievement achievement;
  final UserAchievement? state;

  bool get isUnlocked => state?.isUnlocked ?? false;
  bool get isClaimable => state?.isClaimable ?? false;

  double get progressFraction =>
      state?.progressFraction(achievement.threshold) ?? 0;

  @override
  List<Object?> get props => [achievement, state];
}
