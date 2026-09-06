import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../../core/config/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/game_feature_card.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../profile/data/user_repository.dart';
import '../domain/earn_controller.dart';
import 'widgets/earn_reward_dialog.dart';
import 'widgets/lucky_chest_sheet.dart';
import 'widgets/spin_wheel_sheet.dart';

/// Every way to earn, on one screen.
class EarnScreen extends ConsumerStatefulWidget {
  const EarnScreen({super.key});

  @override
  ConsumerState<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends ConsumerState<EarnScreen> {
  @override
  void initState() {
    super.initState();
    // Preload immediately so the first tap on "watch an ad" does not wait for
    // a fill — that delay is where users assume the app is broken.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adsServiceProvider).preload(AdFormat.rewarded);
    });
  }

  Future<void> _watchAd(AdFormat format) async {
    final result = await ref
        .read(earnControllerProvider.notifier)
        .watchAd(format: format);
    if (!mounted) return;
    result.when(
      success: (coins) async {
        await ref.read(soundServiceProvider).reward();
        if (mounted) await showEarnRewardDialog(context, coins: coins);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final earn = ref.watch(earnControllerProvider);

    final adsLeft = earn.adsLeft ?? user?.adsLeftToday ?? 0;
    final canWatch = adsLeft > 0 && !earn.busy;

    return ListView(
      padding: AppDimens.listBottomPadding,
      children: [
        SectionHeader(
          title: l.earnTitle,
          subtitle: adsLeft > 0 ? l.earnAdsLeft(adsLeft) : l.earnNoAdsLeft,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: Column(
            children: [
              GameFeatureCard(
                title: l.earnWatchAd,
                subtitle: l.earnWatchAdSubtitle,
                icon: Icons.play_circle_fill_rounded,
                gradient: AppTheme.brandGradient,
                locked: !canWatch,
                lockedReason: earn.busy ? l.earnLoadingAd : l.earnNoAdsLeft,
                onTap: () => _watchAd(AdFormat.rewarded),
                trailing: earn.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppDimens.md),
              GameFeatureCard(
                title: l.earnOfferwall,
                subtitle: l.tasksSubtitle,
                icon: Icons.task_alt_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D1FF), Color(0xFF2FD07A)],
                ),
                onTap: () => context.push(Routes.tasks),
              ),
              const SizedBox(height: AppDimens.md),
              Row(
                children: [
                  Expanded(
                    child: GameFeatureCard(
                      title: l.earnSpinWheel,
                      subtitle: '',
                      icon: Icons.casino_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B7BFF), Color(0xFF6C5CE7)],
                      ),
                      locked: !(user?.canSpin ?? true),
                      lockedReason: l.homeDailyClaimed,
                      onTap: () => showSpinWheelSheet(context),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: GameFeatureCard(
                      title: l.earnLuckyChest,
                      subtitle: '',
                      icon: Icons.card_giftcard_rounded,
                      gradient: AppTheme.coinGradient,
                      locked: !(user?.canOpenChest ?? true),
                      lockedReason: l.homeDailyClaimed,
                      onTap: () => showLuckyChestSheet(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(title: l.earnPromoCode),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: _PromoCodeField(),
        ),
        const SizedBox(height: AppDimens.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
          child: _RateAppTile(claimed: user?.rateAppRewardClaimed ?? false),
        ),
      ],
    );
  }
}

class _PromoCodeField extends ConsumerStatefulWidget {
  const _PromoCodeField();

  @override
  ConsumerState<_PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends ConsumerState<_PromoCodeField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final error = Validators.promoCode(_controller.text);
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    setState(() => _busy = true);
    final result = await ref
        .read(earnControllerProvider.notifier)
        .redeemPromocode(_controller.text);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (coins) async {
        _controller.clear();
        await showEarnRewardDialog(context, coins: coins);
      },
      failure: (f) => AppToast.failure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: l.earnPromoHint,
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _redeem(),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _redeem,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
            ),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.rewardsRedeem),
          ),
        ],
      ),
    );
  }
}

class _RateAppTile extends ConsumerWidget {
  const _RateAppTile({required this.claimed});

  final bool claimed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return GlassCard(
      onTap: claimed
          ? null
          : () async {
              final review = InAppReview.instance;
              if (await review.isAvailable()) {
                await review.requestReview();
              }
              // The reward is for *opening* the flow, never for the rating
              // given — the API never reports it back, and paying for positive
              // ratings violates Play Store policy.
              final result = await ref
                  .read(earnControllerProvider.notifier)
                  .claimRateAppReward();
              if (!context.mounted) return;
              result.when(
                success: (coins) => showEarnRewardDialog(context, coins: coins),
                failure: (f) => AppToast.failure(context, f),
              );
            },
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.coin),
          const SizedBox(width: AppDimens.md),
          Expanded(child: Text(l.earnRateApp)),
          if (claimed)
            const Icon(Icons.check_circle, color: AppTheme.success, size: 18)
          else
            const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
