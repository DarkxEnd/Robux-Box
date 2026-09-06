import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import 'auth_controller.dart';

/// Which half of the phone flow the screen is showing.
enum PhoneAuthStep { enterNumber, enterCode }

class PhoneAuthState {
  const PhoneAuthState({
    this.step = PhoneAuthStep.enterNumber,
    this.busy = false,
    this.failure,
    this.verificationId,
    this.resendToken,
    this.phoneNumber = '',
  });

  final PhoneAuthStep step;
  final bool busy;
  final Failure? failure;
  final String? verificationId;
  final int? resendToken;
  final String phoneNumber;

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
    String? verificationId,
    int? resendToken,
    String? phoneNumber,
  }) =>
      PhoneAuthState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        phoneNumber: phoneNumber ?? this.phoneNumber,
      );
}

/// Phone sign-in, which is two screens' worth of state and therefore gets its
/// own controller rather than overloading [AuthController].
class PhoneAuthController extends AutoDisposeNotifier<PhoneAuthState> {
  /// Firebase's phone callbacks fire from the platform channel and can land
  /// after the user has left the screen and this provider was disposed;
  /// writing `state` then throws.
  bool _disposed = false;

  @override
  PhoneAuthState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const PhoneAuthState();
  }

  Future<void> sendCode(String phoneNumber, {bool resend = false}) async {
    state = state.copyWith(
      busy: true,
      clearFailure: true,
      phoneNumber: phoneNumber,
    );

    await ref.read(authRepositoryProvider).startPhoneVerification(
          phoneNumber: phoneNumber,
          resendToken: resend ? state.resendToken : null,
          onCodeSent: (verificationId, resendToken) {
            // The provider can be disposed if the user left the screen while
            // the SMS was in flight; writing state then throws.
            if (_disposed) return;
            state = state.copyWith(
              busy: false,
              step: PhoneAuthStep.enterCode,
              verificationId: verificationId,
              resendToken: resendToken,
            );
          },
          onFailed: (failure) {
            if (_disposed) return;
            state = state.copyWith(busy: false, failure: failure);
          },
          onAutoVerified: (_) {
            // Android auto-retrieved the code and signed in already. The
            // router reacts to the auth change; nothing to do here but stop
            // the spinner.
            if (_disposed) return;
            state = state.copyWith(busy: false);
          },
        );
  }

  Future<bool> confirmCode(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(
        failure: const OperationFailure(
          'Request a new code and try again.',
          code: 'no-verification-id',
        ),
      );
      return false;
    }

    state = state.copyWith(busy: true, clearFailure: true);
    final result = await ref.read(authRepositoryProvider).confirmSmsCode(
          verificationId: verificationId,
          smsCode: smsCode,
        );

    return result.when(
      success: (_) {
        state = state.copyWith(busy: false);
        return true;
      },
      failure: (f) {
        state = state.copyWith(busy: false, failure: f);
        return false;
      },
    );
  }

  void backToNumber() => state = state.copyWith(
        step: PhoneAuthStep.enterNumber,
        clearFailure: true,
      );
}

final phoneAuthControllerProvider =
    AutoDisposeNotifierProvider<PhoneAuthController, PhoneAuthState>(
  PhoneAuthController.new,
);
