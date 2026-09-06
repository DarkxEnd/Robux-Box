import 'package:flutter/material.dart';

import '../extensions/format_extensions.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// A number that counts up when it changes.
///
/// The count-up is the reward feedback for earning coins, so it only animates
/// on an *increase*: watching a balance tick down after a redemption feels
/// like a loss being rubbed in.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final effective = (style ?? Theme.of(context).textTheme.displaySmall)
        ?.merge(AppTypography.tabular);

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('$prefix${v.grouped}$suffix', style: effective, maxLines: 1),
    );
  }
}

/// A coin pill: the icon and the amount, used in lists and dialogs.
class CoinAmount extends StatelessWidget {
  const CoinAmount({
    super.key,
    required this.coins,
    this.size = 16,
    this.signed = false,
    this.color,
  });

  final int coins;
  final double size;

  /// Shows an explicit `+`/`-`. Used in the transaction list, where the
  /// direction matters more than the number.
  final bool signed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final positive = coins >= 0;
    final tint =
        color ??
        (signed
            ? (positive ? const Color(0xFF2FD07A) : const Color(0xFFFF5A5F))
            : const Color(0xFFFFC94A));

    final text = signed
        ? '${positive ? '+' : '-'}${coins.abs().grouped}'
        : coins.abs().grouped;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.monetization_on, size: size, color: tint),
        const SizedBox(width: AppDimens.xs + 2),
        Text(
          text,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w700,
            fontSize: size - 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
