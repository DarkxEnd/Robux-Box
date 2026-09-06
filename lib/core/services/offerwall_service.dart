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

  /// Providers in the order they should appear. CPX first — it has the widest
  /// survey inventory and the fastest crediting of the three.
  static const List<OfferwallProvider> ordered = [
    OfferwallProvider.cpx,
    OfferwallProvider.cpalead,
    OfferwallProvider.lootwalls,
  ];
}
