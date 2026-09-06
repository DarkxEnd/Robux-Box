import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/utils/logger.dart';
import '../data/earn_repository.dart';

/// What the earn screen is currently doing.
enum EarnStatus { idle, preparing, showingAd, crediting }

class EarnState {
  const EarnState({this.status = EarnStatus.idle, this.adsLeft});

  final EarnStatus status;
  final int? adsLeft;

  bool get busy => status != EarnStatus.idle;

  EarnState copyWith({EarnStatus? status, int? adsLeft}) => EarnState(
        status: status ?? this.status,
        adsLeft: adsLeft ?? this.adsLeft,
      );
}

/// Orchestrates the earning actions.
///
/// The rewarded-ad flow is three server-coordinated steps and is the only
/// place in the app where ordering really matters:
///
///  1. `beginRewardedAd` issues a single-use nonce bound to this user.
///  2. The nonce goes to AdMob as SSV `custom_data`; AdMob's signed callback
///     posts back to `admobSsv`, which records a verified impression.
///  3. `confirmRewardedAd` consumes the nonce and pays out.
///
/// Step 3 is called even when the ad was dismissed early — the server decides
/// whether that earns anything, and asking is how the nonce gets cleaned up.
class EarnController extends AutoDisposeNotifier<EarnState> {
  @override
  EarnState build() => const EarnState();

  EarnRepository get _repo => ref.read(earnRepositoryProvider);

  Future<Result<int>> watchAd({AdFormat format = AdFormat.rewarded}) async {
    if (state.busy) {
      return const Result.failure(
        OperationFailure('Already in progress.', code: 'busy'),
      );
    }

    state = state.copyWith(status: EarnStatus.preparing);
    try {
      final device = await ref.read(securityServiceProvider).deviceContext();

      final begin = await _repo.beginRewardedAd(
        format: format.wire,
        device: device,
      );
      if (begin case Err(:final failure)) return Result.failure(failure);
      final session = (begin as Ok<AdSession>).value;
      state = state.copyWith(adsLeft: session.adsLeft);

      state = state.copyWith(status: EarnStatus.showingAd);
      final uid = ref.read(currentUidProvider) ?? '';
      final shown = await ref.read(adsServiceProvider).show(
            format: format,
            nonce: session.nonce,
            uid: uid,
          );
      if (shown case Err(:final failure)) {
        // The nonce is left to expire on its own; confirming a dismissed ad
        // would ask the server to pay for an impression that never completed.
        return Result.failure(failure);
      }

      state = state.copyWith(status: EarnStatus.crediting);
      final confirmed = await _repo.confirmRewardedAd(session.nonce);
      return confirmed.map((r) {
        state = state.copyWith(adsLeft: r.adsLeft);
        return r.coins;
      });
    } catch (e, s) {
      log.e('watchAd failed', e, s);
      return const Result.failure(UnexpectedFailure());
    } finally {
      state = state.copyWith(status: EarnStatus.idle);
      // Preload the next ad so the following tap is instant.
      ref.read(adsServiceProvider).preload(format);
    }
  }

  Future<Result<int>> claimDailyReward() =>
      _guard(() => _repo.claimDailyReward());

  Future<Result<int>> redeemPromocode(String code) =>
      _guard(() => _repo.redeemPromocode(code));

  Future<Result<int>> claimRateAppReward() =>
      _guard(() => _repo.claimRateAppReward());

  Future<Result<int>> claimVipDailyBonus() =>
      _guard(() => _repo.claimVipDailyBonus());

  /// Plays a daily game. Returns the full result, because the wheel needs the
  /// winning segment index to animate onto it.
  Future<Result<EarnResult>> playGame(String game) async {
    if (state.busy) {
      return const Result.failure(
        OperationFailure('Already in progress.', code: 'busy'),
      );
    }
    state = state.copyWith(status: EarnStatus.crediting);
    try {
      return await _repo.playDailyGame(game);
    } finally {
      state = state.copyWith(status: EarnStatus.idle);
    }
  }

  Future<Result<int>> _guard(Future<Result<EarnResult>> Function() action) async {
    if (state.busy) {
      return const Result.failure(
        OperationFailure('Already in progress.', code: 'busy'),
      );
    }
    state = state.copyWith(status: EarnStatus.crediting);
    try {
      final res = await action();
      return res.map((r) => r.coins);
    } finally {
      state = state.copyWith(status: EarnStatus.idle);
    }
  }
}

final earnControllerProvider =
    AutoDisposeNotifierProvider<EarnController, EarnState>(EarnController.new);
