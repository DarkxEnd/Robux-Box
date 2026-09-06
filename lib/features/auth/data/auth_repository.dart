import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/network/firebase_error_mapper.dart';
import '../../../core/utils/logger.dart';

/// All authentication routes into the app.
///
/// Creating the user profile document is *not* done here — the
/// `onUserCreate` auth trigger does it server-side. Doing it from the client
/// would let a caller choose their own starting balance, VIP tier and referral
/// credit before the rules could stop them.
class AuthRepository {
  AuthRepository(this._auth, {GoogleSignIn? googleSignIn})
    : _google = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<Result<User>> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      // A null account means the user backed out of the picker. That is not an
      // error and must not surface as one.
      if (account == null) {
        return const Result.failure(
          OperationFailure('Sign-in cancelled.', code: 'cancelled'),
        );
      }

      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      return _requireUser(cred);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<Result<User>> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(cred);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<Result<User>> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Best effort: a failure here must not block a successful sign-up.
      unawaitedVerification(cred.user);
      return _requireUser(cred);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  void unawaitedVerification(User? user) {
    user?.sendEmailVerification().catchError(
      (Object e) => log.w('verification email failed', e),
    );
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  /// Starts phone verification. [onCodeSent] receives the verification id
  /// needed by [confirmSmsCode].
  ///
  /// On Android the SMS can be auto-retrieved, in which case
  /// [onAutoVerified] fires and no code entry is needed at all.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(Failure failure) onFailed,
    required void Function(User user) onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final cred = await _auth.signInWithCredential(credential);
          final user = cred.user;
          if (user != null) onAutoVerified(user);
        } on Object catch (e, s) {
          onFailed(FirebaseErrorMapper.map(e, s));
        }
      },
      verificationFailed: (e) => onFailed(FirebaseErrorMapper.map(e)),
      codeSent: onCodeSent,
      // Fires when auto-retrieval gives up. Nothing to do: the user is already
      // on the code-entry screen and can type it in.
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<Result<User>> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final cred = await _auth.signInWithCredential(credential);
      return _requireUser(cred);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Future<void> signOut() async {
    // Google's session survives Firebase sign-out, so the next sign-in would
    // silently reuse the same account with no picker shown.
    try {
      await _google.signOut();
    } catch (e) {
      log.w('google sign-out failed', e);
    }
    await _auth.signOut();
  }

  /// Deletes the Firebase Auth user. Firestore cleanup is handled by the
  /// `onUserDelete` trigger, which also anonymises the audit trail rather than
  /// erasing it — the transaction history has to survive for accounting.
  Future<Result<void>> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FirebaseErrorMapper.map(e, s));
    }
  }

  Result<User> _requireUser(UserCredential cred) {
    final user = cred.user;
    if (user == null) {
      return const Result.failure(
        AuthFailure('Sign-in failed. Please try again.'),
      );
    }
    return Result.success(user);
  }
}
