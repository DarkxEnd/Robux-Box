import 'package:equatable/equatable.dart';

/// The three offerwall networks. The wire values must match the
/// `OfferwallProvider` union in `functions/src/handlers/offerwall.ts` — the
/// `getOfferwallUrl` callable switches on exactly these strings.
enum OfferwallProvider {
  cpx('cpx', 'CPX Research'),
  cpalead('cpalead', 'CPAlead'),
  lootwalls('lootwalls', 'Lootwalls');

  const OfferwallProvider(this.wire, this.displayName);

  final String wire;
  final String displayName;

  static OfferwallProvider fromWire(String? v) =>
      OfferwallProvider.values.firstWhere(
        (p) => p.wire == v,
        orElse: () => OfferwallProvider.cpx,
      );

  /// Bundled logo. Falls back to a generic tile if the asset is missing.
  String get logoAsset => 'assets/icons/brands/$wire.png';

  /// Whether the network reverses a credited offer when it later turns out to
  /// be fraudulent.
  ///
  /// CPAlead has no reversal macro at all, so a chargeback there can only be
  /// clawed back by hand from the admin dashboard. Surfaced in the UI as a
  /// difference in how long a credit takes to become final.
  bool get supportsReversal => this != OfferwallProvider.cpalead;
}

/// The signed wall URL returned by `getOfferwallUrl`, loaded into a WebView.
///
/// Short-lived by design: it carries the user id the postback will credit, so
/// it is fetched fresh on every open rather than cached.
class OfferwallSession extends Equatable {
  const OfferwallSession({required this.url, required this.provider});

  factory OfferwallSession.fromMap(Map<String, dynamic> map) =>
      OfferwallSession(
        url: (map['url'] as String?) ?? '',
        provider: OfferwallProvider.fromWire(map['provider'] as String?),
      );

  final String url;
  final OfferwallProvider provider;

  bool get isValid => url.startsWith('https://');

  @override
  List<Object?> get props => [url, provider];
}
