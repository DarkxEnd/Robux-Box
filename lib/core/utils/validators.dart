/// Form validation. Every one of these returns null when the value is fine and
/// a message when it is not, matching Flutter's `FormFieldValidator` contract.
///
/// These are a courtesy to the user, not a security control — the server
/// validates everything again. Nothing here may be relied on for correctness.
abstract final class Validators {
  const Validators._();

  /// Deliberately permissive. The only way to truly validate an email is to
  /// send one, and an over-strict pattern rejects real addresses (plus-tags,
  /// new TLDs, unicode domains) far more often than it catches typos.
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'That does not look like an email address.';
    }
    return null;
  }

  /// Six is Firebase Auth's own floor; rejecting shorter here just saves a
  /// round trip.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password.';
    if (v.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'The passwords do not match.';
    return null;
  }

  /// Roblox usernames: 3–20 characters, letters/digits/underscore, and at most
  /// one underscore which may not be at either end. Getting this wrong means a
  /// redemption is delivered to nobody, so it is worth checking properly.
  static String? robloxUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your Roblox username.';
    if (v.length < 3 || v.length > 20) return 'Between 3 and 20 characters.';
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(v)) {
      return 'Letters, numbers and underscore only.';
    }
    if (v.startsWith('_') || v.endsWith('_')) {
      return 'Cannot start or end with an underscore.';
    }
    if ('_'.allMatches(v).length > 1) return 'Only one underscore allowed.';
    return null;
  }

  /// E.164, which is what Firebase phone auth requires.
  static String? phone(String? value) {
    final v = value?.replaceAll(RegExp(r'[\s()-]'), '') ?? '';
    if (v.isEmpty) return 'Enter your phone number.';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v)) {
      return 'Include the country code, e.g. +201234567890.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a display name.';
    if (v.length < 2) return 'A little longer, please.';
    if (v.length > 30) return 'Keep it under 30 characters.';
    return null;
  }

  static String? promoCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a code.';
    if (!RegExp(r'^[A-Za-z0-9_-]{3,32}$').hasMatch(v)) {
      return 'That is not a valid code.';
    }
    return null;
  }

  static String? notEmpty(String? value, {String field = 'This field'}) {
    if ((value?.trim() ?? '').isEmpty) return '$field is required.';
    return null;
  }

  static String? minLength(String? value, int min, {String? message}) {
    if ((value?.trim().length ?? 0) < min) {
      return message ?? 'Use at least $min characters.';
    }
    return null;
  }
}
