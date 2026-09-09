import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robux_box/core/services/offerwall_service.dart';
import 'package:robux_box/models/offerwall.dart';

/// Guards the client and server lists of live offerwall providers against
/// drift.
///
/// `OfferwallService.ordered` decides which walls the app offers;
/// `ENABLED_PROVIDERS` in `functions/src/handlers/offerwall.ts` decides which
/// ones the server will sign a URL for. If the app offers one the server has
/// dropped, the tile is there and tapping it silently lands the user on the
/// default provider's wall instead — no error, just the wrong wall. Rather
/// than trusting a comment in each file that points at the other, this reads
/// the TypeScript and checks.
void main() {
  late final String offerwallTs;

  setUpAll(() {
    final file = File('functions/src/handlers/offerwall.ts');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'offerwall.ts must exist for this parity check to mean anything',
    );
    offerwallTs = file.readAsStringSync();
  });

  /// Pulls the string literals out of `NAME ... = [ "a", "b" ];`.
  List<String> tsStringList(String source, String name) {
    final block = RegExp(
      '$name[^=]*=\\s*\\[([^\\]]*)\\]',
      dotAll: true,
    ).firstMatch(source)?.group(1);
    if (block == null) return const [];
    return RegExp(
      '"([^"]+)"',
    ).allMatches(block).map((m) => m.group(1)!).toList();
  }

  /// Pulls `NAME ... = "value";`.
  String? tsString(String source, String name) =>
      RegExp('$name[^=]*=\\s*"([^"]+)"').firstMatch(source)?.group(1);

  group('client and server agree on which offerwalls are live', () {
    test('the offered providers are exactly the ones the server serves', () {
      final server = tsStringList(offerwallTs, 'ENABLED_PROVIDERS');
      expect(
        server,
        isNotEmpty,
        reason: 'could not parse ENABLED_PROVIDERS out of offerwall.ts',
      );
      expect(
        OfferwallService.ordered.map((p) => p.wire).toList(),
        server,
        reason:
            'OfferwallService.ordered and ENABLED_PROVIDERS have drifted; the '
            'app would offer a wall the server refuses to sign',
      );
    });

    test('every enabled wire value is a provider the app knows', () {
      final known = OfferwallProvider.values.map((p) => p.wire).toSet();
      for (final wire in tsStringList(offerwallTs, 'ENABLED_PROVIDERS')) {
        expect(
          known,
          contains(wire),
          reason: '$wire is enabled on the server but absent from the enum',
        );
      }
    });

    test('the server default is itself enabled', () {
      // The fallback for an unrecognised request. If it were a disabled
      // provider, every such request would be handed a dead wall.
      final fallback = tsString(offerwallTs, 'DEFAULT_PROVIDER');
      expect(fallback, isNotNull);
      expect(
        tsStringList(offerwallTs, 'ENABLED_PROVIDERS'),
        contains(fallback),
      );
    });
  });
}
