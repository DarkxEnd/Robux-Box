import 'package:equatable/equatable.dart';

import 'parse.dart';

/// An in-app notification (`users/{uid}/notifications/{id}`).
///
/// Written server-side by `functions/src/lib/notify.ts`. A push message and
/// this document are created together, so the inbox stays complete even when
/// the push was dropped (permission denied, token expired, app uninstalled).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.deeplink,
    this.imageUrl,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        title: Parse.toStr(map['title']),
        body: Parse.toStr(map['body']),
        type: Parse.toStr(map['type'], 'general'),
        deeplink: map['deeplink'] as String?,
        imageUrl: map['imageUrl'] as String?,
        isRead: Parse.toBool(map['isRead']),
        createdAt: Parse.toDate(map['createdAt']),
      );

  final String id;
  final String title;
  final String body;

  /// Groups notifications for the icon shown in the list: `redemption`,
  /// `offerwall`, `vip`, `support`, `achievement`, `general`.
  final String type;

  /// In-app route to open on tap, e.g. `/wallet` or `/redeem/history`.
  /// Validated against the router before navigating — never passed through as
  /// an arbitrary URL.
  final String? deeplink;
  final String? imageUrl;
  final bool isRead;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, isRead, createdAt];
}
