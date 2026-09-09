import '../../../models/reward.dart';

/// Maps a reward to its bundled card artwork.
///
/// Paths match the directory layout recovered from the shipped bundle, so ids
/// that already had art keep it. A missing file is expected and handled by the
/// caller with a gradient fallback — the catalogue is edited from the admin
/// dashboard and can contain ids with no bundled image.
abstract final class RobuxCardArt {
  const RobuxCardArt._();

  static const _robuxDir = 'assets/images/robux_packages';
  static const _brandDir = 'assets/images/redeem_brand_cards';

  /// Ids known to have bundled artwork. Anything outside this set goes
  /// straight to the fallback rather than triggering an asset-load exception
  /// on every rebuild.
  static const _known = {
    'robux_100',
    'robux_200',
    'robux_400',
    'robux_800',
    'robux_1000',
    'robux_2500',
    'robux_usd_5',
    'robux_usd_10',
    'robux_usd_20',
    'gc_amazon_10',
    'gc_gplay_10',
  };

  static String? assetFor(Reward reward) {
    if (!_known.contains(reward.id)) return null;
    final dir = reward.kind == RewardKind.robux ? _robuxDir : _brandDir;
    return '$dir/${reward.id}.png';
  }
}
