# Architecture

## The trust boundary

Everything of value is decided on the server. The app is a client to a wallet
it cannot write to.

```
┌──────────────┐   callable    ┌──────────────────┐   Admin SDK   ┌───────────┐
│  Flutter app │ ────────────► │  Cloud Functions │ ────────────► │ Firestore │
│              │               │  (us-central1)   │               │           │
│  reads only  │ ◄──────────── │  requireAuth     │               │           │
└──────────────┘   snapshots   │  requireAdmin    │               └───────────┘
       ▲                       │  rateLimit       │                     ▲
       │                       │  App Check       │                     │
       │                       └──────────────────┘                     │
       │                              ▲                                 │
       └──────── firestore.rules ─────┴─── deny all client writes ───────┘
                 (read-only for wallets, transactions, redemptions)
```

Clients read their own documents through snapshots — that part is direct and
fast. Every *write* that matters goes through a callable.

## Layers

**`models/`** — plain Dart mirrors of Firestore documents. All parsing goes
through `Parse`, which coerces rather than throws, so one malformed document
cannot take a list screen down.

**`features/<name>/data/`** — repositories. They own the Firestore queries and
the callable names, and return `Result<T>` rather than throwing.

**`features/<name>/domain/`** — controllers, where a feature needs orchestration
across more than one call. Most features do not need one.

**`features/<name>/presentation/`** — screens and their widgets.

**`core/services/`** — cross-cutting concerns: ads, offerwall, security,
notifications, geo, preferences, sound.

State is Riverpod throughout. Providers live next to what they provide, not in
a central file.

## The rewarded-ad flow

This is the only place in the app where ordering genuinely matters.

```
app                     server                    AdMob
 │                        │                         │
 │── beginRewardedAd ────►│                         │
 │                        │ issue single-use nonce  │
 │◄──── nonce ────────────│                         │
 │                        │                         │
 │──────── show ad, nonce as SSV custom_data ──────►│
 │                        │                         │
 │                        │◄─ signed SSV callback ──│
 │                        │  verify ECDSA, record   │
 │                        │  verified impression    │
 │                        │                         │
 │── confirmRewardedAd ──►│                         │
 │                        │ consume nonce, pay      │
 │◄───── coins ───────────│                         │
```

The client never learns what an ad is worth until the server tells it. In
strict SSV mode, `confirmRewardedAd` refuses to pay unless AdMob's signed
callback has already recorded a verified impression against that nonce — so
calling it without watching an ad earns nothing.

A dismissed ad is deliberately **not** confirmed. The nonce simply expires.

## Offerwalls

Three providers behind one interface: CPX Research, CPAlead and Lootwalls.

`getOfferwallUrl` returns a signed URL carrying the uid the postback will
credit. The app never builds one — doing so would let anyone point a
completion at any account.

All three postbacks land in one shared `recordOfferCompletion()`, so payout
maths, idempotency and reversal cannot drift between providers. What differs:

| | Auth | Reversal |
| --- | --- | --- |
| CPX | `md5(trans_id + secret)` | `status=2` |
| CPAlead | shared secret in URL | **none** — manual clawback only |
| Lootwalls | shared secret in URL | `status=0`, or a word like `declined` |

Lootwalls documents a numeric status but sends words in practice. That was
found from a live log, not from their docs, and the handler matches both.

## The economy

`lib/core/constants/app_constants.dart` and `functions/src/lib/economy.ts`
hold the same numbers. `test/economy_parity_test.dart` enforces that they
agree, by parsing the TypeScript.

Payout is `base × geo tier × VIP multiplier`. Geo tier comes from the country
of record, which is pinned on first resolve and only an admin can change —
otherwise a VPN would multiply every payout.

## Localisation

Eight locales: English, Arabic, Spanish, Portuguese, French, Hindi, Indonesian,
Turkish. Arabic is RTL, so direction-aware layout is not optional — anything
hard-coding `left`/`right` will look wrong.
