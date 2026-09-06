import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive Firestore parsing.
///
/// Documents in a live database are never as clean as the model expects — a
/// field can be missing, an int can arrive as a double, a timestamp can be a
/// String. These helpers coerce instead of throwing, so one malformed document
/// can't take a whole list screen down.
abstract final class Parse {
  const Parse._();

  static int toInt(Object? v, [int fallback = 0]) => switch (v) {
        final int i => i,
        final double d => d.round(),
        final String s => int.tryParse(s) ?? fallback,
        _ => fallback,
      };

  static double toDouble(Object? v, [double fallback = 0]) => switch (v) {
        final double d => d,
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? fallback,
        _ => fallback,
      };

  static String toStr(Object? v, [String fallback = '']) => switch (v) {
        final String s => s,
        null => fallback,
        _ => v.toString(),
      };

  static bool toBool(Object? v, [bool fallback = false]) => switch (v) {
        final bool b => b,
        final num n => n != 0,
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  static DateTime? toDate(Object? v) => switch (v) {
        final Timestamp t => t.toDate(),
        final DateTime d => d,
        final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        final String s => DateTime.tryParse(s),
        _ => null,
      };

  static List<String> toStringList(Object? v) => switch (v) {
        final List<dynamic> l => l.map((e) => toStr(e)).toList(),
        _ => const <String>[],
      };

  static Map<String, dynamic> toMap(Object? v) => switch (v) {
        final Map<String, dynamic> m => m,
        final Map<dynamic, dynamic> m =>
          m.map((k, val) => MapEntry(k.toString(), val)),
        _ => const <String, dynamic>{},
      };
}
