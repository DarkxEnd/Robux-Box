import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/providers.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../domain/earn_controller.dart';
import 'earn_reward_dialog.dart';

Future<void> showLuckyChestSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const LuckyChestSheet(),
);

/// The daily chest. Same contract as the wheel: the server picks, the
/// animation reports.
class LuckyChestSheet extends ConsumerStatefulWidget {
  const LuckyChestSheet({super.key});

  @override
  ConsumerState<LuckyChestSheet> createState() => _LuckyChestSheetState();
}

class _LuckyChestSheetState extends ConsumerState<LuckyChestSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  bool _opening = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);

    // Three shakes of anticipation while the call is in flight, so the wait
    // is part of the moment rather than a frozen screen.
    unawaited(_shake.repeat(reverse: true));

    final result = await ref
        .read(earnControllerProvider.notifier)
        .playGame('chest');
    _shake
      ..stop()
      ..reset();
    if (!mounted) return;

    unawaited(
      result.when(
        success: (earn) async {
          await ref.read(soundServiceProvider).celebrate();
          if (!mounted) return;
          Navigator.of(context).pop();
          await showEarnRewardDialog(context, coins: earn.coins);
        },
        failure: (f) async {
          AppToast.failure(context, f);
          Navigator.of(context).pop();
        },
      ),
    );

    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.xl,
        AppDimens.sm,
        AppDimens.xl,
        AppDimens.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.earnLuckyChest, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.xxl),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.rotate(
              angle: (_shake.value - 0.5) * 0.24,
              child: child,
            ),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: AppTheme.coinGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 74,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xxl),
          GradientButton(
            label: l.earnLuckyChest,
            gradient: AppTheme.coinGradient,
            enabled: !_opening,
            onPressed: _open,
          ),
        ],
      ),
    );
  }
}
