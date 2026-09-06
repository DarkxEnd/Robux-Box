import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/providers.dart';
import '../../../core/error/result.dart';
import '../../../core/services/callable_service.dart';
import 'vip_iap_service.dart';

/// VIP purchases and the daily bonus.
///
/// Two independent paths to the same entitlement:
///  - coins, entirely server-side (`purchaseVipWithCoins`);
///  - real money, where the store only produces a receipt and
///    `verifyVipPurchase` checks it against the Play Developer API before
///    granting anything.
///
/// Neither lets the client assert a tier.
class VipRepository {
  const VipRepository(this._callables);

  final CallableService _callables;

  Future<Result<Map<String, dynamic>>> purchaseWithCoins(String tier) =>
      _callables.call('purchaseVipWithCoins', {'tier': tier});

  Future<Result<int>> claimDailyBonus() async {
    final res = await _callables.call('claimVipDailyBonus');
    return res.map((data) => (data['coins'] as num?)?.toInt() ?? 0);
  }
}

final vipRepositoryProvider = Provider<VipRepository>((ref) {
  return VipRepository(ref.watch(callableServiceProvider));
});

final vipIapServiceProvider = Provider<VipIapService>((ref) {
  final service = VipIapService(ref.watch(callableServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});
