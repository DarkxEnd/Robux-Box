import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device believes it has a network.
///
/// Only ever used to *explain* a failure, never to prevent an attempt: this
/// reports the radio's state, not whether Firebase is reachable, and a captive
/// portal or a blocked domain looks perfectly "connected" here. Requests are
/// always made and their real errors surfaced.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map(_isOnline)
      .distinct();

  Future<bool> get isOnline async => _isOnline(
        await _connectivity.checkConnectivity(),
      );

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
