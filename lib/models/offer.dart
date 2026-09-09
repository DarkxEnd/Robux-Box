import 'package:equatable/equatable.dart';

import 'model_utils.dart';
import 'offerwall.dart';

/// A featured offer (`offers/{id}`).
///
/// Only a *shop window*. Real offers live inside each provider's wall, and
/// completion is credited by their postback — nothing here can grant coins.
/// These documents exist so the tasks screen has something to show before the
/// user opens a wall, and so an admin can promote a specific campaign.
class Offer extends Equatable {
  const Offer({
    required this.id,
    required this.title,
    required this.provider,
    this.description = '',
    this.imageUrl = '',
    this.estimatedCoins = 0,
    this.category = 'other',
    this.difficulty = 1,
    this.isActive = true,
    this.sortOrder = 0,
    this.countries = const [],
    this.deeplink,
  });

  factory Offer.fromMap(String id, Map<String, dynamic> map) => Offer(
    id: id,
    title: Parse.toStr(map['title']),
    provider: OfferwallProvider.fromWire(map['provider'] as String?),
    description: Parse.toStr(map['description']),
    imageUrl: Parse.toStr(map['imageUrl']),
    estimatedCoins: Parse.toInt(map['estimatedCoins']),
    category: Parse.toStr(map['category'], 'other'),
    difficulty: Parse.toInt(map['difficulty'], 1).clamp(1, 3),
    isActive: Parse.toBool(map['isActive'], true),
    sortOrder: Parse.toInt(map['sortOrder']),
    countries: Parse.toStringList(map['countries']),
    deeplink: map['deeplink'] as String?,
  );

  final String id;
  final String title;
  final OfferwallProvider provider;
  final String description;
  final String imageUrl;

  /// What the user would earn at the T1 rate. Shown with an "up to" qualifier,
  /// because the actual credit depends on their geo tier and VIP multiplier,
  /// and on what the provider ultimately reports.
  final int estimatedCoins;

  /// `survey`, `app_install`, `signup`, `game`, `other`.
  final String category;

  /// 1–3. Drives the effort indicator, not the payout.
  final int difficulty;
  final bool isActive;
  final int sortOrder;

  /// Empty means available everywhere.
  final List<String> countries;
  final String? deeplink;

  bool isAvailableIn(String? countryCode) =>
      countries.isEmpty ||
      (countryCode != null && countries.contains(countryCode));

  @override
  List<Object?> get props => [id, title, provider, estimatedCoins, isActive];
}
