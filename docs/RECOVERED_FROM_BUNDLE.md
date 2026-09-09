# What was recovered from the shipped AAB

The original source tree was lost. This rebuild is not a guess: most of the
externally-observable surface was recovered from the shipped `v2.0.0+6` app
bundle, and this file records **which facts are evidence-backed and which are
reconstruction**, so a future reader knows how much to trust each part.

Dart AOT code cannot be decompiled back to source. Everything in `lib/` is
rewritten from scratch — but it is pinned to the recovered identifiers below,
so it talks to the same Firestore documents, the same callables and the same
ad units as the version already in the Play Store.

## Evidence-backed (do not "fix" these without new evidence)

| Fact | Source in the bundle |
| --- | --- |
| Application id `com.robuxbox.app` | `AndroidManifest.xml` |
| Only one app-owned Android class: `com.robuxbox.app.MainActivity` | `proguard.map` |
| AdMob app id `ca-app-pub-2788515829400980~2420412642` | `AndroidManifest.xml` meta-data |
| Ad unit ids `2360557102`, `3354788588`, `9337028990` | `libapp.so` strings |
| `9337028990` is the **Rewarded** unit ("Video R", نوع: بمكافأة) | AdMob console, confirmed by the owner |
| Asset directory layout (`assets/images/robux_packages/`, …) | `flutter_assets/` |
| Launcher icons, all densities | `res.zip` |
| Route paths, callable function names, collection and field names | `libapp.so` strings |
| `supportTickets` / `ticketCategories` are camelCase, unlike every other multi-word collection | `libapp.so` strings |
| Android Gradle Plugin 8.11.1 | `appmetadata.properties` |
| Kotlin 2.2.20, Play Billing 8.0.0, AdMob SDK 23.6.0, Firebase BoM 33.16.0 | `dependencies.pb` |
| Flutter engine `cafcda5721a78a7884db92f13c5e89f7643d52dd` | `dependencies.pb` |

### The plugin set

`dependencies.pb` lists the Maven graph and `proguard.map` lists every class
before obfuscation, so between them the Android plugin set is exact rather than
inferred:

```
firebase_core  firebase_auth  cloud_firestore  cloud_functions
firebase_messaging  firebase_storage  firebase_analytics
firebase_crashlytics  firebase_app_check
google_sign_in  google_mobile_ads  in_app_purchase  in_app_review
webview_flutter  url_launcher  image_picker  path_provider
shared_preferences  flutter_secure_storage  flutter_local_notifications
geolocator  geocoding  permission_handler
connectivity_plus  device_info_plus  package_info_plus  share_plus
```

Three of these — `geocoding`, `permission_handler`, `path_provider` — were
missing from the first reconstruction of `pubspec.yaml` and were added only
after `proguard.map` proved them present.

`sqflite` also appears in the map but is **not** a direct dependency: it
arrives through `cached_network_image` → `flutter_cache_manager`. Its presence
is what confirms `cached_network_image` was in the original, since pure-Dart
packages leave no trace in the Android artifacts.

## Reconstruction (evidence-shaped, not evidence-proven)

- **All Dart source.** Structure, naming and behaviour are rebuilt to match the
  recovered identifiers, but the original implementation is unrecoverable.
- **The point economy.** Values in `functions/src/lib/economy.ts` and
  `lib/core/constants/app_constants.dart` come from the working session that
  set them, not from the bundle.
- **Cloud Functions.** The deployed functions still exist in `robux-box1`; the
  names match the callables found in `libapp.so`, but the bodies are rewritten.
- **Firestore rules and indexes.** Rewritten from the collection names, then
  tightened; they are stricter than whatever shipped.

## Deliberately not recovered

`BundleConfig.pb`, `MANIFEST.MF`, `UPLOAD.RSA`, `UPLOAD.SF`, `baseline.prof`
and `r8.json` are signing and build-tooling metadata. They contain no source
and nothing that changes how the app is built. `libflutter.so` and its debug
symbols are the stock Flutter engine, identical for every app built on that
engine revision.
