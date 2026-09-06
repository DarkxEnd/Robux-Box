import 'package:flutter/material.dart';

import '../../../models/reward.dart';

/// Groups the catalogue into the brand tiles shown on the rewards screen.
///
/// Derived from the reward id rather than stored on the document, so adding a
/// card to an existing brand needs only a seed entry — no schema change and no
/// admin field to get wrong.
enum RewardBrand {
  roblox('Roblox', Color(0xFFE2231A), Icons.sports_esports),
  amazon('Amazon', Color(0xFFFF9900), Icons.shopping_cart_outlined),
  googlePlay('Google Play', Color(0xFF34A853), Icons.play_arrow_rounded),
  appStore('App Store', Color(0xFF0D96F6), Icons.apple),
  other('More', Color(0xFF6C5CE7), Icons.card_giftcard);

  const RewardBrand(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static RewardBrand of(Reward reward) {
    final id = reward.id.toLowerCase();
    if (reward.kind == RewardKind.robux || id.startsWith('robux')) {
      return RewardBrand.roblox;
    }
    if (id.contains('amazon')) return RewardBrand.amazon;
    if (id.contains('gplay') || id.contains('google')) {
      return RewardBrand.googlePlay;
    }
    if (id.contains('itunes') || id.contains('apple')) {
      return RewardBrand.appStore;
    }
    return RewardBrand.other;
  }

  /// Brands present in the catalogue, in display order, each with its rewards.
  static Map<RewardBrand, List<Reward>> group(List<Reward> rewards) {
    final map = <RewardBrand, List<Reward>>{};
    for (final reward in rewards) {
      map.putIfAbsent(of(reward), () => []).add(reward);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    // Fixed enum order, so the grid does not reshuffle when the catalogue
    // changes.
    return {
      for (final brand in RewardBrand.values)
        if (map.containsKey(brand)) brand: map[brand]!,
    };
  }
}
