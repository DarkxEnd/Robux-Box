# Robux Box

A Flutter + Firebase rewards app. Users watch rewarded ads and complete
offerwall tasks to earn coins, then exchange them for Roblox gift cards and
other digital rewards.

- **Package:** `com.robuxbox.app`
- **Firebase project:** `robux-box1`
- **Version:** 3.0.0+7

## The one thing to understand first

**Coins can only be created by the server.** `firestore.rules` makes
`wallets`, `transactions`, `redemptions` and the VIP and fraud collections
unwritable by any client. Every coin that exists was created by a Cloud
Function running with the Admin SDK.

This is not defensive style — it is the whole design. The app is a wallet whose
balance is decided elsewhere, and every screen is written on that assumption.
If you find yourself adding a client-side write that changes a balance, the
logic belongs in `functions/` instead.

## Layout

```
lib/
  core/          config, services, theme, router, l10n, shared widgets
  models/        Firestore document models
  features/      one directory per feature: data / domain / presentation
functions/       Cloud Functions (TypeScript, Node 20, us-central1)
scripts/seed.js  seeds the catalogue, achievements and config
web_public/      privacy policy and terms, published to GitHub Pages
test/            53 tests, including a client/server economy parity check
```

## Running it

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=FLAVOR=dev
```

Ad unit ids default to Google's public test ids, so a dev build always serves
something. A real build must override them — see `docs/DEPLOYMENT.md`.

## Checks

```bash
flutter analyze --fatal-infos     # clean
flutter test                      # 53 tests
cd functions && npm run build     # clean
```

`test/economy_parity_test.dart` reads `functions/src/lib/economy.ts` and
checks every shared number against `lib/core/constants/app_constants.dart`.
The two files hold the same economy in two languages, and a comment saying
"keep these in sync" is not a mechanism.

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the pieces fit, and why
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — building, signing, releasing
- [`docs/SECURITY.md`](docs/SECURITY.md) — the trust boundary and its gaps
- [`docs/RECOVERED_FROM_BUNDLE.md`](docs/RECOVERED_FROM_BUNDLE.md) — what is
  evidence-backed and what is reconstruction

## Not affiliated with Roblox

Robux Box is independent. "Roblox" and "Robux" are trademarks of Roblox
Corporation.
