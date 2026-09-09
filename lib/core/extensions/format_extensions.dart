import 'package:intl/intl.dart';

/// Number and date formatting used across the app.
///
/// All of it is locale-aware through `intl`, which matters here: the app ships
/// in Arabic, Hindi and six other locales, and hard-coded `toString()` on a
/// number renders Western digits in locales that expect their own.
extension IntFormatting on int {
  /// `12345` → `12,345` (or the locale's equivalent grouping).
  String get grouped => NumberFormat.decimalPattern().format(this);

  /// Compact form for tight spaces: `12345` → `12K`.
  String get compact => NumberFormat.compact().format(this);

  /// Coins are always shown grouped — a six-digit balance is unreadable
  /// otherwise, and this is the number users care most about.
  String get coins => grouped;
}

extension DoubleFormatting on double {
  String asCurrency(String code) {
    // RBX is not an ISO currency, so NumberFormat.simpleCurrency would throw.
    if (code == 'RBX') return '${round().grouped} R\$';
    return NumberFormat.simpleCurrency(name: code).format(this);
  }
}

extension DateFormatting on DateTime {
  String get shortDate => DateFormat.yMMMd().format(toLocal());
  String get dateTime => DateFormat.yMMMd().add_jm().format(toLocal());

  /// "3 hours ago". Intentionally coarse — to the minute is noise in a
  /// transaction list, and exact times are available on the detail view.
  String get relative {
    final diff = DateTime.now().difference(toLocal());
    if (diff.isNegative) return shortDate;
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate;
  }
}

extension DurationFormatting on Duration {
  /// `mm:ss` for the ad cooldown timer.
  String get clock {
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    return inHours > 0 ? '$inHours:$m:$s' : '$m:$s';
  }
}
