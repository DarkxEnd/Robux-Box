import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Presentation for the five VIP tiers.
///
/// The tier is a plain `String` on the wire (`none`/`bronze`/…) rather than an
/// enum, because the server can introduce a tier without the app needing an
/// update — so every lookup here has to tolerate an unknown value.
extension VipLevelPresentation on String {
  int get vipRank => AppConstants.vipRank[this] ?? 0;

  double get vipMultiplier => AppConstants.vipMultipliers[this] ?? 1.0;

  bool get isVipTier => vipRank > 0;

  String get vipLabel => switch (this) {
        'bronze' => 'Bronze',
        'silver' => 'Silver',
        'gold' => 'Gold',
        'diamond' => 'Diamond',
        _ => 'Free',
      };

  /// The tier's accent colour. Used for badges and card borders.
  Color get vipColor => switch (this) {
        'bronze' => const Color(0xFFCD7F32),
        'silver' => const Color(0xFFB0BEC5),
        'gold' => const Color(0xFFFFC107),
        'diamond' => const Color(0xFF4FC3F7),
        _ => const Color(0xFF9E9E9E),
      };

  /// Two-stop gradient for the VIP card.
  List<Color> get vipGradient => switch (this) {
        'bronze' => const [Color(0xFFCD7F32), Color(0xFF8D5524)],
        'silver' => const [Color(0xFFCFD8DC), Color(0xFF78909C)],
        'gold' => const [Color(0xFFFFD54F), Color(0xFFFF8F00)],
        'diamond' => const [Color(0xFF80D8FF), Color(0xFF0091EA)],
        _ => const [Color(0xFF757575), Color(0xFF424242)],
      };

  IconData get vipIcon => switch (this) {
        'bronze' => Icons.workspace_premium_outlined,
        'silver' => Icons.workspace_premium,
        'gold' => Icons.military_tech,
        'diamond' => Icons.diamond,
        _ => Icons.person_outline,
      };

  /// The next tier up, or null at the top. Drives the "upgrade" prompt.
  String? get nextVipTier => switch (this) {
        'none' => 'bronze',
        'bronze' => 'silver',
        'silver' => 'gold',
        'gold' => 'diamond',
        _ => null,
      };
}
