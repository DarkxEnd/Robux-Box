import 'package:flutter_test/flutter_test.dart';
import 'package:robux_box/core/router/app_router.dart';
import 'package:robux_box/core/utils/validators.dart';
import 'package:robux_box/models/offerwall.dart';

void main() {
  group('Validators.robloxUsername', () {
    // Getting this wrong means a redemption is delivered to nobody.
    test('accepts real usernames', () {
      for (final name in ['Builderman', 'abc', 'a_b', 'Player123', 'A' * 20]) {
        expect(Validators.robloxUsername(name), isNull, reason: name);
      }
    });

    test('rejects the shapes Roblox does not allow', () {
      expect(Validators.robloxUsername(''), isNotNull);
      expect(Validators.robloxUsername('ab'), isNotNull);
      expect(Validators.robloxUsername('A' * 21), isNotNull);
      expect(Validators.robloxUsername('_leading'), isNotNull);
      expect(Validators.robloxUsername('trailing_'), isNotNull);
      expect(Validators.robloxUsername('two_under_scores'), isNotNull);
      expect(Validators.robloxUsername('has space'), isNotNull);
      expect(Validators.robloxUsername('has-dash'), isNotNull);
    });
  });

  group('Validators.email', () {
    test('accepts addresses an over-strict pattern would reject', () {
      // Plus-tags and long TLDs are real; rejecting them loses redemptions.
      for (final email in [
        'a@b.co',
        'user+tag@example.com',
        'first.last@sub.domain.technology',
      ]) {
        expect(Validators.email(email), isNull, reason: email);
      }
    });

    test('rejects obvious typos', () {
      for (final email in ['', 'no-at-sign', 'a@b', 'a b@c.com', '@b.com']) {
        expect(Validators.email(email), isNotNull, reason: email);
      }
    });
  });

  group('Validators.phone', () {
    test('requires E.164, which is what Firebase phone auth needs', () {
      expect(Validators.phone('+201234567890'), isNull);
      expect(Validators.phone('+1 (555) 123-4567'), isNull);

      expect(Validators.phone('01234567890'), isNotNull);
      expect(Validators.phone('+0123456789'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });
  });

  group('Validators.password', () {
    test('matches Firebase Auth\'s own six-character floor', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password(''), isNotNull);
    });

    test('confirmation must match exactly', () {
      expect(Validators.confirmPassword('abc123', 'abc123'), isNull);
      expect(Validators.confirmPassword('abc123', 'abc124'), isNotNull);
    });
  });

  group('OfferwallProvider', () {
    test('wire values match the server union exactly', () {
      // getOfferwallUrl switches on these strings; a rename here routes the
      // user to the wrong wall or none at all.
      expect(OfferwallProvider.values.map((p) => p.wire).toList(), [
        'cpx',
        'cpalead',
        'lootwalls',
      ]);
    });

    test('an unknown provider falls back to cpx rather than throwing', () {
      expect(OfferwallProvider.fromWire('unknown'), OfferwallProvider.cpx);
      expect(OfferwallProvider.fromWire(null), OfferwallProvider.cpx);
    });

    test('CPAlead is the one provider with no reversal macro', () {
      expect(OfferwallProvider.cpalead.supportsReversal, isFalse);
      expect(OfferwallProvider.cpx.supportsReversal, isTrue);
      expect(OfferwallProvider.lootwalls.supportsReversal, isTrue);
    });

    test('a session URL must be https', () {
      expect(
        OfferwallSession.fromMap({'url': 'https://x.test/wall'}).isValid,
        isTrue,
      );
      expect(
        OfferwallSession.fromMap({'url': 'http://x.test/wall'}).isValid,
        isFalse,
      );
      expect(OfferwallSession.fromMap({}).isValid, isFalse);
    });
  });

  group('Routes.isKnown', () {
    // Push payloads are attacker-influenced in principle; anything not
    // recognised must be dropped rather than navigated to.
    test('accepts declared routes and their children', () {
      expect(Routes.isKnown('/home'), isTrue);
      expect(Routes.isKnown('/earn/offerwall'), isTrue);
      expect(Routes.isKnown('/admin/users'), isTrue);
      expect(Routes.isKnown('/wallet'), isTrue);
    });

    test('rejects anything else', () {
      expect(Routes.isKnown('/not-a-route'), isFalse);
      expect(Routes.isKnown('https://evil.test'), isFalse);
      expect(Routes.isKnown('javascript:alert(1)'), isFalse);
      expect(Routes.isKnown(''), isFalse);
    });

    test('every shell tab is a declared route', () {
      for (final tab in Routes.shellTabs) {
        expect(Routes.isKnown(tab), isTrue, reason: tab);
      }
    });
  });
}
