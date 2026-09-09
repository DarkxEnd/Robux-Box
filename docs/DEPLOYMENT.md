# Deployment

## Before anything else: the signing key

`android/app/upload-keystore.jks` is **irreplaceable**. Lose it and the app on
Google Play can never be updated again — you would have to publish a new
listing under a new package name and lose every install and review.

- It is in `.gitignore`. Keep it that way.
- Keep an offline copy somewhere you will still have in five years.
- The key password should be long and random. If it is currently something
  memorable, change it — this is the single highest-value secret in the
  project.

CI reads it from the `KEYSTORE_BASE64` secret and deletes it from the runner
afterwards.

## Required GitHub secrets

| Secret | Used by | What it is |
| --- | --- | --- |
| `KEYSTORE_BASE64` | ci.yml | `base64 -w0 upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | ci.yml | keystore password |
| `KEY_PASSWORD` | ci.yml | key password |
| `KEY_ALIAS` | ci.yml | key alias |
| `GOOGLE_SERVICES_JSON` | ci.yml | contents of `android/app/google-services.json` |
| `ADMOB_REWARDED_ANDROID` | ci.yml | `ca-app-pub-2788515829400980/9337028990` |
| `ADMOB_REWARDED_INTERSTITIAL_ANDROID` | ci.yml | rewarded interstitial unit |
| `ADMOB_APP_OPEN_ANDROID` | ci.yml | app-open unit |
| `ADMOB_BANNER_ANDROID` | ci.yml | banner unit |
| `FIREBASE_SERVICE_ACCOUNT` | deploy, seed, logs | service-account JSON |
| `LOOTWALLS_API_KEY` | deploy | Lootwalls API key, from their dashboard |
| `LOOTWALLS_SECRET` | deploy | Lootwalls "Secret (for postback)" |

Only Lootwalls is live. CPX and CPAlead have not approved this publisher, so
they are absent from `ENABLED_PROVIDERS` in `functions/src/handlers/offerwall.ts`
and from `OfferwallService.ordered`, and their secrets are deliberately left
unset:

| Secret | Used by | What it is |
| --- | --- | --- |
| `CPX_SECURE_HASH` | deploy | CPX secure hash — leave unset while disabled |
| `CPALEAD_SECRET` | deploy | CPAlead postback secret — leave unset while disabled |
| `CPALEAD_WALL_URL` | deploy | CPAlead wall URL — leave unset while disabled |
| `OFFERWALL_APP_ID` | deploy | CPX app id — leave unset while disabled |

**Never put a placeholder in a disabled provider's secret.** Every postback
refuses with 503 when its secret is empty, and that is the only thing keeping
a disabled endpoint shut. Any value at all — even `disabled` or `x` — turns
the guard off and reopens the endpoint behind a guessable secret.

The name on the left of each line in the workflow's `Set function secrets`
step is what the code reads from `process.env`; the secret it is assigned from
may be named differently. `test/env_wiring_test.dart` fails if the two drift,
because a mismatch there is silent — it once left every Lootwalls postback
answering 503 with nobody credited.

Generate any new shared secret with `openssl rand -hex 32`. Never a personal
password: these secrets are the only thing standing between an attacker and
crediting coins to any account they choose.

## Building locally

```bash
flutter build appbundle --release \
  --dart-define=FLAVOR=prod \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-2788515829400980/9337028990 \
  --obfuscate --split-debug-info=build/symbols
```

Without the `--dart-define`s the build uses Google's public **test** ad units
and earns nothing. `AppConfig.hasRealAdUnits` detects this and switches App
Check to the debug provider, so a test build can still reach the backend.

Keep `build/symbols` — a release stack trace is unreadable without it.

## The version number

`pubspec.yaml` currently reads `3.0.0+7`.

Play Console rejects any upload whose build number is not **higher** than
every previous upload. The last published build was `+6`, so `+7` is the floor.
Bump the `+N` on every upload, even for an identical version name.

## Releasing

1. Merge to `main`. CI analyzes, tests, builds the functions, then builds and
   signs the AAB and APK, and attaches them to the rolling `android-latest`
   pre-release.
2. Download the `.aab` and upload it to Play Console.
3. Upload `debug-symbols` to Play Console as well, so crash reports
   de-obfuscate.

The APK is for sideloading and testing only. **A sideloaded APK cannot pass
Play Integrity**, so if App Check enforcement is on, it will be rejected by
every callable — and the error will read "please sign in", not "attestation
failed". See `docs/SECURITY.md`.

## Firebase

`deploy-firebase.yml` runs on any push to `main` that touches `functions/`,
the rules or the indexes. It runs in the `production` environment, so you can
require a manual approval there.

To deploy by hand:

```bash
cd functions && npm ci && npm run build
npx firebase-tools deploy --project robux-box1 --only functions,firestore,storage
```

Seeding is manual only (`seed-firestore.yml`, type `seed` to confirm). It
overwrites catalogue prices, so running it after an admin has tuned them from
the dashboard would undo their work.

## Play Console configuration

- **In-app products:** `vip_bronze_30d`, `vip_silver_30d`, `vip_gold_30d`,
  `vip_diamond_30d`. These ids must match `AppConstants.vipIapProductIds`
  exactly or the store returns them as "not found".
- **Privacy policy URL:** the GitHub Pages URL for `web_public/privacy.html`.
  Required, and AdMob requires it too.
- **App access:** the reviewer needs a working account. Provide test
  credentials, or the review stalls on "cannot access the app".
- **Data safety:** declare device identifiers, approximate location and email,
  matching what the privacy policy says.

## AdMob

Ad unit ids are injected at build time, never committed. The app id **is**
committed, in `AndroidManifest.xml` — it is not a secret and is visible in any
copy of the APK.

If a policy strike appears under Site behavior → Navigation, read
`lib/core/widgets/ad_banner.dart` first. That strike came from ads placed too
close to interactive controls, and the fix is placement, not the ad unit.
