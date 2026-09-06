import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

import 'parse.dart';

/// A home-screen promo banner (`banners/{id}`).
///
/// [gradientColors] lets an admin publish a banner with no artwork at all,
/// which is why [imageUrl] is allowed to be empty.
class HomeBanner extends Equatable {
  const HomeBanner({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl = '',
    this.gradientColors = const [],
    this.deeplink,
    this.isActive = true,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
  });

  factory HomeBanner.fromMap(String id, Map<String, dynamic> map) => HomeBanner(
        id: id,
        title: Parse.toStr(map['title']),
        subtitle: Parse.toStr(map['subtitle']),
        imageUrl: Parse.toStr(map['imageUrl']),
        gradientColors: Parse.toStringList(map['gradientColors']),
        deeplink: map['deeplink'] as String?,
        isActive: Parse.toBool(map['isActive'], true),
        sortOrder: Parse.toInt(map['sortOrder']),
        startsAt: Parse.toDate(map['startsAt']),
        endsAt: Parse.toDate(map['endsAt']),
      );

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;

  /// Hex strings like `#6C5CE7`. Parsed defensively — a typo in the admin
  /// dashboard must not crash the home screen.
  final List<String> gradientColors;
  final String? deeplink;
  final bool isActive;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Scheduling is enforced here rather than in the query, because Firestore
  /// can't range-filter two different fields in one query.
  bool get isLive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  List<Color> get colors {
    final parsed = gradientColors.map(_parseHex).nonNulls.toList();
    return parsed.length >= 2 ? parsed : const [];
  }

  static Color? _parseHex(String raw) {
    var s = raw.trim().replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }

  @override
  List<Object?> get props => [id, title, imageUrl, isActive, sortOrder];
}
