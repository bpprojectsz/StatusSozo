# StatusSozo

Browse, save and share status photos and videos from the folders you choose. Android 10+ (API 29+), Flutter, no accounts, no analytics, no network access in Stage 1.

StatusSozo is an independent app and is not affiliated with or endorsed by any messaging service.

## Layout

| Path | Purpose |
|---|---|
| `app/` | Flutter application: `lib/`, `test/`, `android/`, `brand/` (SVG sources), `assets/`, `tool/` |
| `website/` | Static site: home, privacy, support. Deployed by Cloudflare from this folder. |
| `store_submission/` | Listing copy, Data safety evidence, screenshot plan, Play Console checklist, closed-testing plan, store graphics |
| `.github/workflows/` | `verify.yml`, `build_android.yml`, `bootstrap.yml` (one-off, done), `brand.yml` (one-off generator) |

Identity: display name StatusSozo, application ID `com.zdmgold.statussozo`, Dart package `statussozo`. Toolchain: Flutter 3.29.2 (Dart 3.7.2), pinned in every workflow.

## Architecture

Layers under `app/lib/`: `core/` (pure Dart: models, contracts, providers, services), `platform/` (plugins and the native channel `statussozo/saf`), `design/` (tokens, theme, motion), `widgets/`, `screens/`, `app/` (wiring), `utils/`, `l10n/`. Imports between layers are restricted and enforced by `app/tool/check_forbidden.sh`, which also bans raw colours, hardcoded strings, Material visuals and left/right layout APIs. All imports use `package:statussozo/...`.

Status folders are read through the Android Storage Access Framework. Native Kotlin lives in `app/android/app/src/main/kotlin/com/zdmgold/statussozo/`.

## Checks

From `app/`:

```
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos     # zero errors and zero warnings
sh tool/check_forbidden.sh           # layering and forbidden-pattern gate
flutter test
```

The same steps run in GitHub Actions through the manual `verify` workflow, which publishes its log to the `ci-logs` branch.

## Workflows

All workflows are `workflow_dispatch` only. **Never add a `push:` trigger.**

| Workflow | Purpose |
|---|---|
| `verify` | Analyze, gate and tests. No build, no signing. |
| `build_android` | `build_type` test: a small signed arm64 APK published on the Releases page. `release`: signed AAB and APK, which needs the four signing secrets. Optional performance overlay and `live_ads`. |
| `brand` | One-off: runs the launcher icon and splash generators and commits the generated Android files |
| `bootstrap` | One-off, already run: generated the Android scaffold |

## Ads

Banners (Home, Viewer, Saved, Settings) and rule-limited interstitials through the Google Mobile Ads SDK, after Google's consent form. Every build uses Google's test ad IDs. A release build compiles live IDs in only when the `live_ads` input is ticked and the `ADMOB_APP_ID`, `ADMOB_BANNER_ID` and `ADMOB_INTERSTITIAL_ID` secrets exist. See `store_submission/ADMOB_SETUP.md`.

## Brand assets

SVG sources are in `app/brand/`. `sh app/tool/build_brand_assets.sh` renders the PNGs (needs `rsvg-convert` or ImageMagick) and, when the Dart SDK is present, runs the generators. Rules: no `<filter>` in any SVG, and no text in the icon or feature graphic.

## Fonts

Inter and Manrope variable fonts are bundled in `app/assets/fonts/` with their SIL Open Font Licence texts. Both are free for commercial use and embedding.

## Release

Signing secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Back the keystore file up off the phone. The submission steps are in `store_submission/PLAY_CONSOLE_CHECKLIST.md`.
