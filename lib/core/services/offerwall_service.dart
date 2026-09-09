import '../../models/offerwall.dart';
import '../error/result.dart';
import 'callable_service.dart';

/// Fetches signed offerwall URLs.
///
/// The app never builds a wall URL itself. Each provider signs its URL with a
/// secret that only Cloud Functions holds, and the URL carries the uid the
/// postback will credit — building it client-side would let anyone point a
/// completion at any account.
class OfferwallService {
  const OfferwallService(this._callables);

  final CallableService _callables;

  /// Always fetched fresh, never cached: the URL is short-lived and carries
  /// the identity the payout is bound to.
  Future<Result<OfferwallSession>> urlFor(OfferwallProvider provider) async {
    final res = await _callables.call('getOfferwallUrl', {
      'provider': provider.wire,
    });
    return res.map(OfferwallSession.fromMap);
  }

  /// The providers to offer, in the order they should appear.
  ///
  /// Only Lootwalls is live: CPX and CPAlead have not approved this publisher,
  /// so their walls would open on an error page. The integration code for all
  /// three is intact — re-enabling one is adding it back here and to
  /// `ENABLED_PROVIDERS` in `functions/src/handlers/offerwall.ts`, then
  /// setting its secret.
  ///
  /// This list only decides what is *offered*. The server keeps its own list
  /// and refuses to sign a URL for anything absent from it, so a stale build
  /// cannot reach a disabled provider.
  static const List<OfferwallProvider> ordered = [OfferwallProvider.lootwalls];
}
