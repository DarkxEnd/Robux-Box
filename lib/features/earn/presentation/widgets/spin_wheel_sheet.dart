import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../domain/earn_controller.dart';
import 'earn_reward_dialog.dart';
import 'spin_wheel.dart';

Future<void> showSpinWheelSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const SpinWheelSheet(),
);

/// The spin game.
///
/// Flow: ask the server, get the winning index back, *then* animate the wheel
/// onto it. The animation is presentation of a decision already made — this is
/// what stops the wheel and the credited coins ever disagreeing.
class SpinWheelSheet extends ConsumerStatefulWidget {
  const SpinWheelSheet({super.key});

  @override
  ConsumerState<SpinWheelSheet> createState() => _SpinWheelSheetState();
}

class _SpinWheelSheetState extends ConsumerState<SpinWheelSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  bool _spinning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() => _spinning = true);

    final result = await ref
        .read(earnControllerProvider.notifier)
        .playGame('spin');
    if (!mounted) return;

    await result.when(
      success: (earn) async {
        final segments = AppConstants.spinWheelPrizes.length;
        // Fall back to segment 0 only if the server omitted the index; the
        // coins are still whatever it granted.
        final index = (earn.index ?? 0).clamp(0, segments - 1);

        _rotation =
            Tween<double>(
              begin: 0,
              end: SpinWheel.rotationFor(index, segments),
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
            );
        await _controller.forward(from: 0);

        if (!mounted) return;
        await ref.read(soundServiceProvider).celebrate();
        if (!mounted) return;
        Navigator.of(context).pop();
        await showEarnRewardDialog(context, coins: earn.coins);
      },
      failure: (f) async {
        AppToast.failure(context, f);
        if (mounted) Navigator.of(context).pop();
      },
    );

    if (mounted) setState(() => _spinning = false);
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
          Text(l.earnSpinWheel, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.xl),
          AnimatedBuilder(
            animation: _rotation,
            builder: (_, __) => SpinWheel(rotation: _rotation.value),
          ),
          const SizedBox(height: AppDimens.xxl),
          GradientButton(
            label: l.earnSpinWheel,
            enabled: !_spinning,
            onPressed: _spin,
          ),
        ],
      ),
    );
  }
}
