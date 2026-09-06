import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/callable_service.dart';

/// Real-money VIP purchases.
///
/// The store is never the source of truth for VIP status. A purchase here only
/// produces a receipt, which `verifyVipPurchase` checks against the Play
/// Developer API server-side before granting anything — a client that claims
/// "purchased" gets nothing. Consequently the UI must wait for the callable,
/// not for the store callback.
class VipIapService {
  VipIapService(this._callables, {InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final CallableService _callables;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _results = StreamController<Result<String>>.broadcast();

  /// Emits the granted tier on success, or a [Failure]. One event per
  /// completed purchase attempt.
  Stream<Result<String>> get results => _results.stream;

  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => _products;

  bool _available = false;
  bool get isAvailable => _available;

  Future<void> initialise() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        log.i('in-app purchases unavailable on this device');
        return;
      }

      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e, StackTrace s) => log.e('purchase stream', e, s),
      );

      final ids = AppConstants.vipIapProductIds.values.toSet();
      final response = await _iap.queryProductDetails(ids);
      if (response.error != null) {
        log.w('product query failed: ${response.error!.message}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        // Almost always a Play Console configuration gap rather than a bug.
        log.w('products not configured in the store: ${response.notFoundIDs}');
      }
      _products = response.productDetails;
    } catch (e, s) {
      log.e('IAP init failed', e, s);
      _available = false;
    }
  }

  ProductDetails? productFor(String tier) {
    final id = AppConstants.vipIapProductIds[tier];
    if (id == null) return null;
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Starts a purchase. The outcome arrives on [results], not from this call —
  /// the store flow outlives the method.
  Future<Result<void>> buy(String tier) async {
    if (!_available) {
      return const Result.failure(
        OperationFailure(
          'Purchases are not available on this device.',
          code: 'iap-unavailable',
        ),
      );
    }
    final product = productFor(tier);
    if (product == null) {
      return const Result.failure(
        OperationFailure(
          'That subscription is not available right now.',
          code: 'product-missing',
        ),
      );
    }

    try {
      // Non-consumable: VIP is a time-limited entitlement the server tracks by
      // expiry date, not something the user can buy repeatedly and stockpile.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return const Result.success(null);
    } catch (e, s) {
      log.e('buy failed', e, s);
      return const Result.failure(UnexpectedFailure());
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          continue;

        case PurchaseStatus.error:
          log.w('purchase error: ${p.error?.message}');
          _results.add(
            const Result.failure(
              OperationFailure('The purchase did not complete.',
                  code: 'iap-error'),
            ),
          );

        case PurchaseStatus.canceled:
          _results.add(
            const Result.failure(
              OperationFailure('Purchase cancelled.', code: 'iap-cancelled'),
            ),
          );

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _results.add(await _verify(p));
      }

      // Must always be called, including for errors — an uncompleted purchase
      // is re-delivered on every launch and, on Android, is refunded after
      // three days.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<Result<String>> _verify(PurchaseDetails p) async {
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty) {
      return const Result.failure(
        OperationFailure('Could not verify that purchase.', code: 'no-receipt'),
      );
    }

    final res = await _callables.call('verifyVipPurchase', {
      'productId': p.productID,
      'purchaseToken': token,
    });

    return res.map((data) => (data['tier'] as String?) ?? 'none');
  }

  /// Buying VIP with coins instead of money. Entirely server-side; there is no
  /// store involved.
  Future<Result<Map<String, dynamic>>> buyWithCoins(String tier) =>
      _callables.call('purchaseVipWithCoins', {'tier': tier});

  /// Re-delivers past purchases. Needed after a reinstall or a device change,
  /// and required by App Store review.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      log.w('restore failed', e);
    }
  }

  void dispose() {
    _sub?.cancel();
    _results.close();
  }
}
