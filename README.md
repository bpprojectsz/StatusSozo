# StatusSozo

Browse, save and share status photos and videos you have already viewed, from folders you choose. Android 10+ (API 29+), Flutter, offline-only in Stage 1.

StatusSozo is an independent app and is not affiliated with or endorsed by any messaging service.

## Layout

| Path | Purpose |
|---|---|
| `app/` | Flutter application (`app/lib`, `app/test`, `app/android`, `app/tool`) |
| `website/` | Static marketing, privacy and support pages |
| `store_submission/` | Store listing copy and submission documents |
| `.github/workflows/` | `verify.yml`, `bootstrap.yml`, later `build_android.yml` |

Identity: display name StatusSozo, application ID `com.zdmgold.statussozo`, Dart package `statussozo`.
Toolchain pin: Flutter 3.29.2 (Dart 3.7.2), used identically in CI and on the maintainer's phone.

## Architecture rules

Layers under `app/lib/`: `core/` (pure Dart: models, contracts, providers, services), `platform/` (plugins and the native channel), `design/` (tokens, theme, motion), `widgets/`, `screens/`, `app/` (wiring), `utils/`, `l10n/`.
Imports between layers are restricted and enforced by `app/tool/check_forbidden.sh`, which also bans raw colours, hardcoded strings, Material visuals and left/right layout APIs.
All imports use `package:statussozo/...`.

## Checks

From `app/`:

```
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos     # zero errors and zero warnings
sh tool/check_forbidden.sh           # layering and forbidden-pattern gate
flutter test
```

The same steps run in GitHub Actions through the manually triggered `verify` workflow.

## Workflows

All workflows are `workflow_dispatch` only. **Never add a `push:` trigger.**

## Fonts

Inter and Manrope variable fonts are bundled under `app/assets/fonts/` with their SIL Open Font Licence texts (`OFL-Inter.txt`, `OFL-Manrope.txt`). Both are free for commercial use and embedding.
