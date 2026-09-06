import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/providers.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    googleSignIn: GoogleSignIn(scopes: const ['email']),
  );
});

/// Drives the auth screens.
///
/// The state is only about *this form's* progress — whether the user is signed
/// in is `authStateProvider`, which comes from Firebase itself. Keeping the two
/// apart avoids the classic bug where a stale local flag says "signed in" after
/// the token was revoked.
class AuthState {
  const AuthState({this.busy = false, this.failure});

  final bool busy;
  final Failure? failure;

  AuthState copyWith({bool? busy, Failure? failure, bool clearFailure = false}) =>
      AuthState(
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class AuthController extends AutoDisposeNotifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signInWithGoogle() =>
      _run(() => _repo.signInWithGoogle());

  Future<bool> signInWithEmail(String email, String password) =>
      _run(() => _repo.signInWithEmail(email, password));

  Future<bool> register(String email, String password) =>
      _run(() => _repo.registerWithEmail(email, password));

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(busy: true, clearFailure: true);
    final result = await _repo.sendPasswordReset(email);
    return _finish(result);
  }

  Future<void> signOut() async {
    state = state.copyWith(busy: true);
    await _repo.signOut();
    // No need to clear busy: the auth change tears this provider down.
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(busy: true, clearFailure: true);
    final result = await _repo.deleteAccount();
    return _finish(result);
  }

  void clearError() => state = state.copyWith(clearFailure: true);

  Future<bool> _run(Future<Result<User>> Function() action) async {
    state = state.copyWith(busy: true, clearFailure: true);
    return _finish(await action());
  }

  bool _finish(Result<Object?> result) {
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
}

final authControllerProvider =
    AutoDisposeNotifierProvider<AuthController, AuthState>(AuthController.new);
