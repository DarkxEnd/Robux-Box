# Security

## The model in one sentence

The app is untrusted; the server decides everything that has value.

Every coin in existence was created by a Cloud Function running with the Admin
SDK. `firestore.rules` denies client writes to `wallets`, `transactions`,
`redemptions`, `vip_purchases` and the fraud collections outright — not
"validates" them, denies them. There is no code path in the app that can
increase a balance.

## Read this before debugging an auth bug

**Cloud Functions returns `unauthenticated` both for a genuinely signed-out
caller and for a request App Check rejected before the handler ran.**

`FirebaseErrorMapper` renders both as "please sign in". This has twice sent
this project chasing a phantom authentication bug when the real cause was Play
Integrity failing — an unsigned build, a sideloaded APK, or a device that
could not attest.

If users report being asked to sign in while already signed in:

1. Check App Check enforcement before touching any auth code.
2. Check whether they installed the APK from outside the Play Store.
3. `ENFORCE_APP_CHECK` defaults to **false** server-side, deliberately: a
   missing or misconfigured secret should degrade security, not take the app
   down.

## Layers

**App Check / Play Integrity.** Attests that the caller is a genuine install
of this app. Release builds use Play Integrity; builds with test ad units fall
back to the debug provider, because a debug build cannot attest and would
otherwise be locked out of its own backend.

**Auth.** `requireAuth` on every callable; `requireAdmin` on every privileged
one. Admin status is a custom claim on the ID token, which is what the rules
check too — never a Firestore field, which a client could read but the server
would not honour.

**Rate limiting.** Per-user, per-action, in `security.ts`. The limits are
sized for a real user, not for a bot.

**Device fingerprinting.** A device id we generate ourselves — Play policy
forbids using a hardware identifier here, and a reinstall *should* look like a
new device. It survives app updates, which is what the per-account device cap
needs. Emulators and debug builds are scored down. All of it is a *hint*: a
rooted device can forge every field, and the server treats a low score as a
reason to flag for review, not to hard-block. A false positive here stops a
paying user from earning.

**Velocity checks.** Coins per minute per user. Crossing the threshold raises a
fraud flag rather than blocking, for the same reason.

## Rewarded-ad verification

Three steps, and the middle one is the point:

1. `beginRewardedAd` issues a single-use nonce bound to the user.
2. The nonce goes to AdMob as SSV `custom_data`. AdMob calls `admobSsv`, which
   verifies an ECDSA/SHA-256 signature against Google's published verifier
   keys and records a verified impression.
3. `confirmRewardedAd` consumes the nonce and pays.

In strict mode, step 3 refuses without a verified impression from step 2. So
calling `confirmRewardedAd` directly — the obvious attack — earns nothing.

The client never learns an ad's value until the server tells it.

## Offerwall postbacks

These endpoints are the most attractive target in the system: a successful
forgery mints coins.

- **CPX** verifies `md5(trans_id + secret)`.
- **CPAlead** and **Lootwalls** compare a shared secret with
  `crypto.timingSafeEqual`, not `===`, so the comparison does not leak the
  secret through timing.
- Every completion is idempotent on a provider-namespaced document id
  (`transId`, `cpalead_${transId}`, `lootwalls_${transId}`), so a replayed
  postback credits nothing.
- Secrets are never logged, even at debug level.

Reversal coverage genuinely differs between providers, and the app says so
rather than pretending otherwise: CPAlead has no reversal macro, so a
chargeback there is a manual clawback from the admin dashboard.

## Known gaps

Worth writing down, because a security document that claims completeness is
not useful:

- **A determined user on a rooted device can forge the device fingerprint.**
  Accepted: the fingerprint is a fraud *signal*, and App Check is the real
  barrier.
- **CPAlead reversals are manual.** Nothing to be done until they add a macro.
- **Geo tier is pinned on first resolve**, so a user who first opens the app
  through a VPN keeps the wrong tier until an admin changes it.
- **Achievements are granted by a Firestore trigger.** Triggers can re-fire, so
  unlock and payment are deliberately separate steps.
- **The admin dashboard trusts the claim.** Anyone who can grant themselves the
  claim owns the economy. `setAdminClaim` is the most dangerous callable in the
  project and self-revoke is blocked, so the last admin cannot lock themselves
  out.

## Secret handling

- Nothing sensitive is committed. `.gitignore` blocks `*.jks`, `key.properties`,
  service-account JSON and `functions/.env`.
- `google-services.json` and the AdMob app id **are** committed. They ship
  inside every APK and are not secrets; security comes from the rules and App
  Check, not from hiding them.
- Shared secrets are generated with `openssl rand -hex 32`. Never a personal
  password.
- CI writes credentials to the runner and deletes them in an `always()` step.
