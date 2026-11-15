# StatusSozo master blueprint

**What this is:** the as-built description of the whole project: product, architecture, rules, native protocol, build pipeline, batches in dependency order, and a generated inventory of every file. It describes the code that is in `main` today. When a batch changes any of this, update the matching section in the same commit.

**What this is not:** the original four-part build specification the project started from (Product and Design System, Architecture and Batches B0 to B6, Batches B7 to B14, Stage 2 and Gates). That text lives with the project owner and in the project instructions, not in this repository. Where the build deliberately departed from it, `docs/decisions.md` says so. Read `docs/handoff.md` first, then `docs/decisions.md`, then this file.

---

## 1. Product

| Field | Value |
|---|---|
| Name | StatusSozo (spec codename StatusVault) |
| Application ID / Dart package | `com.zdmgold.statussozo` / `statussozo` |
| What it does | Browse, save and share status photos and videos from a folder the user picks (Storage Access Framework), from two sources: Standard and Business |
| Platform | Android 10+ (minSdk 29, targetSdk 36, compileSdk 36). No iOS, no backend, no accounts, no analytics SDK, no crash SDK |
| Stack | Flutter 3.29.2 / Dart 3.7.2 (pinned in every workflow and on the owner's Termux), Kotlin 2.2.0, AGP 8.9.1, Gradle 8.11.1, NDK 27.0.12077973, Java 17 |
| Money | Free, supported by Google AdMob banners and interstitials. A paid "Remove ads" row shows "Coming soon" (billing is Stage 3, needs a Play merchant profile) |
| Languages | 11: en es fr de pt ar hi ja ko zh he. Follows the system language; the user can override it in Settings. Arabic and Hebrew are right to left |
| Website | https://statussozo.bpprojectsz.workers.dev (Cloudflare, build output directory `website`): `/`, `/privacy`, `/support`, `/terms` |
| Support email | stmakarios@gmail.com |
| Repository | https://github.com/bpprojectsz/StatusSozo (public) |

## 2. Screens (9) and where ads appear

| Screen | Notes | Bottom banner |
|---|---|---|
| Access | Modes: first run, renewal, reconnect, help ("How to connect a folder") | No |
| Home | Photos/Videos tabs, source switch (selector when both sources are connected, chip otherwise), grid, selection bar, auto refresh every 4 s while visible, pull-down refresh | Yes |
| Viewer | Status mode and Saved mode. Banner sits under Save with a 24 px gap | Yes |
| Saved | Saved library, selection, delete | Yes |
| Settings | Appearance, Folders, Language, Pro (Coming soon), Support, Legal, Diagnostics, About | Yes |
| Debug logs | Local log, Send report, Clear | No |
| Open-source licenses | List of packages (includes the two bundled fonts) | No |
| License detail | One package's text | No |
| Crash fallback | Shown by the global error handler. English only by design | No |

Bottom sheets (not screens): source picker, folder actions, language picker, three confirmations (delete in Saved, delete in Saved viewer, clear log).

## 3. Architecture

### 3.1 Layers and import rules (enforced by `app/tool/check_forbidden.sh`)

| Layer (`app/lib/`) | May import | Must not import |
|---|---|---|
| `core/` (models, contracts, providers, services, config) | `core/`, `utils/`, Dart SDK (not `dart:io`), `flutter/foundation`, `flutter/widgets` (contracts only) | `platform/ widgets/ screens/ app/ design/ l10n/`, any plugin |
| `utils/` | Dart SDK, `intl`, `flutter/foundation` | the rest of `lib/` |
| `design/` | Flutter | the rest of `lib/` |
| `platform/` | `core/ utils/`, plugins, `flutter/services` | `widgets/ screens/ app/ design/` |
| `widgets/` | `core/` (models, contracts, errors), `design/ utils/ l10n/gen`, `hugeicons`, `flutter_svg` | `platform/ screens/ app/`, other plugins |
| `screens/` | `widgets/ core/ design/ utils/ l10n/gen`, `app/app_scope.dart` | `platform/`, plugins |
| `app/` | everything | nothing |

Only `app/app_services.dart` constructs platform classes. Everything else receives contracts. All imports are `package:statussozo/...`.

### 3.2 Banned in `lib/` (the gate fails on any hit)

`Icons.`, `CupertinoIcons`, `Colors.` (except `Colors.transparent`), raw `Color(0x` outside `design/`, Material widgets (`Card(`, `ListTile`, `AppBar(`, `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton(`, `SnackBar`, `CircularProgressIndicator`, `RefreshIndicator`, `Switch(`, `InkWell`, ripple), hardcoded strings (`Text('...')`), `TextStyle(` and `fontSize:` outside `design/`, `Duration(milliseconds` outside `design/`, hard-coded radii and paddings outside `design/`, left/right layout APIs (`TextAlign.left/right`, `EdgeInsets.only(left/right`, `Alignment.centerLeft/Right`, `Positioned(left/right`), `setState(` without `// ui-local`, `TODO`, `FIXME`, `UnimplementedError`, layering violations, `<filter` in any SVG.

### 3.3 State (all `ValueNotifier` based, no Provider package)

| Provider | Owns |
|---|---|
| `SettingsProvider` | The persisted `AppSettings` (theme, language, last source, grants, review counters), persistence warning flag |
| `ThemeProvider`, `SourceProvider`, `LocaleProvider` | Views over settings |
| `FolderAccessProvider` | Per-source connection state, connect and disconnect |
| `StatusListProvider` | The current source's list. Request ids discard stale responses. Silent refresh keeps the old list |
| `SavedLibraryProvider` | Saved items (MediaStore is the store) |
| `SelectionProvider` x2 | Home and Saved multi-select |
| `SaveProvider` | Batch save progress and summary |
| `ToastProvider` | Message queue (codes, never English text) |
| `AdProvider` | Consent, SDK start, interstitial rules, `isEnabled` for ad slots |
| `ReviewProvider` | Counts saves and days, asks for a store review |

### 3.4 Navigation

Cold start goes to `AppGate`: no grants means Access (first run); stored grants mean Home straight away (verification runs after the first frame); all grants verified lost means Access (renewal). Home pushes Viewer, Saved, Settings and Access. Saved pushes Viewer. Settings pushes Access (reconnect and help), Licenses (then License detail), Debug logs. Android back leaves selection mode first, then pops.

### 3.5 Start-up and resume

`main()`: `runGuarded` > ensureInitialized > register font licenses > `AppServices.create()` > `settings.load()` > install global error handling > `runApp`. After the first frame `bootstrap()` starts consent and ads (`ads.start()`), verifies grants, loads the list and the saved library, and prunes the share cache. On every resume `refreshAll()` re-verifies grants, refreshes lists and tops up the interstitial.

### 3.6 Native channel `statussozo/saf` (Dart `platform/saf_channel.dart` and Kotlin `SafChannelHandler.kt` must match; error codes in `core/errors/error_codes.dart` and `ErrorCodes.kt`)

| Method | Arguments | Returns | Errors |
|---|---|---|---|
| `pickFolder` | `initialUri?` | `{uri,name}` or null if cancelled | none |
| `hasAccess` | `uri` | bool | none |
| `releaseFolder` | `uri` | null | none |
| `listFolder` | `uri` | rows `{uri,name,mime,size,modified}` | `ACCESS_LOST NOT_FOUND IO` |
| `thumbnail` | `uri,mime,px` | JPEG bytes or null | none |
| `readBytes` | `uri,maxBytes` | bytes | `TOO_LARGE NOT_FOUND IO ACCESS_LOST` |
| `saveToGallery` | `uri,name,mime,subfolder` | `{uri,name,mime,size,added}` | `IO ACCESS_LOST` |
| `listSaved` | `subfolder` | rows | `IO` |
| `deleteSaved` | `uri` | bool | `PERMISSION_LOST NOT_FOUND` |
| `copyToCache` | `uri,name` | path | `IO NOT_FOUND ACCESS_LOST` |
| `pruneShareCache` | `olderThanMs` | count | none |

Status folder rules: the picked folder must be named `.Statuses`, or contain one within 3 levels (the Kotlin lister searches, caches the result). Source paths live only in `core/models/status_source.dart`: `Android/media/com.whatsapp/WhatsApp/Media/.Statuses` and `.../com.whatsapp.w4b/WhatsApp Business/Media/.Statuses`. Saves go to `Pictures/StatusSozo` and `Movies/StatusSozo` through MediaStore (`IS_PENDING`, half-written rows are deleted on failure).

### 3.7 Errors

`AppErrorKind`: accessLost, wrongFolder, pickerCancelled, notFound, io, permissionLost, unsupported, persistence, unexpected. `treatmentFor(error, scope)` decides screen, toast or fallback. User-facing text is localisation keys only.

## 4. Design system (authoritative values are in `app/lib/design/`)

Custom widgets only (no Material visuals). One accent: indigo `#4F46E5` light, `#8B93FF` dark; 18 colour tokens in `app_colors.dart`, contrast tested at 4.5:1. Fonts bundled: Inter (UI and body) and Manrope (display, wordmark), variable files. Spacing 2/4/8/16/24/32/48/64. 48 px touch targets. Hairline 0.5. One shadow only (floating selection bar, light mode). No spring or bounce; 150 to 400 ms ease curves; reduce-motion makes all animation instant. Icons: `hugeicons` stroke rounded, only through `AppIcons` (names) and `AppIcon` (drawing, stroke 2.0). The wordmark is two colours: "Status" in the text colour, "Sozo" in the accent.

App icon and splash: teal gradient rounded square, faint outer ring, bold open ring with a mint dot in the gap, white download arrow on a tray line. Sources in `app/brand/*.svg`; `app/tool/build_brand_assets.sh` renders PNGs; the `brand` workflow ran the launcher-icon and splash generators and committed the Android resources.

## 5. Ads, consent, review

| Topic | Rule as built |
|---|---|
| Test IDs | Google's sample IDs in every build. Live IDs only through the `live_ads` input of `build_android` (release only, needs secrets `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID`) |
| Consent | Google UMP. Runs after the first frame, before any ad request. The SDK's own `canRequestAds` decides. After a decline Google may serve limited ads or none. If the consent step fails, ads are still requested (Google's advice). Privacy choices row appears only where required |
| Banners | Home, Viewer, Saved, Settings. Zero height with no gap, border or placeholder until an ad is ready, while ads are off, while the keyboard is open, and while another screen covers it. One retry after 60 s, then on resume |
| Interstitials | Five moments: batch save of 2+ items on Home; saving a photo in the Viewer; deleting from Saved; deleting a photo in the Saved viewer when a photo follows; every 5th Viewer close. One shared clock: at least 7 minutes apart, no daily cap. Never before consent, at launch, on exit or during a video (video saves and deletes followed by a video show none) |
| Review prompt | Google in-app review (`in_app_review`). Counts saved items and days; asks after 10 saved items on 3 different days; never while an interstitial shows or within 2 minutes after one. The Settings row "Rate the app" (chip "Review this app now", line "Tap to review on store") opens the Play listing. **Planned changes are in `docs/handoff.md` section 6.** |

## 6. Localisation

`app/l10n.yaml` + `lib/l10n/app_en.arb` (template, with metadata) + 10 other ARB files (key and value only, plus `@@locale`). `flutter gen-l10n` writes `lib/l10n/gen/` (not committed). `test/l10n/arb_parity_test.dart` enforces the same keys, placeholders, valid plural branches, no empty values and the `.Statuses` folder name. The 10 translations were machine-written by the build agent and checked mechanically only; a native-speaker review is recommended before production, and a full back-translation audit is planned (handoff section 6).

## 7. Build, CI and verification

All workflows are `workflow_dispatch` only. **Never add a `push:` trigger.**

| Workflow | Does | Log branch |
|---|---|---|
| `verify.yml` | `flutter pub get`, `gen-l10n`, `analyze --no-fatal-infos`, `tool/check_forbidden.sh`, `flutter test`. Commits `pubspec.lock` back | `ci-logs` (`verify.log`, `meta.txt`) |
| `build_android.yml` | Input `build_type`: `test` (small signed arm64 APK, temporary key, published as a GitHub Release `test-N`), `debug`, `release` (signed AAB and APK, needs the four signing secrets). Inputs `perf_overlay`, `live_ads` | `ci-logs-build` |
| `emulator.yml` | Boots Android 13 and 14 emulators, installs a debug build with sample statuses, drives the picker, saves, switches languages, publishes screenshots and logs. Input `api` (all, 33, 34) | `ci-emulator-33`, `ci-emulator-34` |
| `bootstrap.yml`, `brand.yml` | One-off, already run | `ci-logs-brand` |

Signing secrets (names only; values are held by the owner): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`StatusSozo`), `ANDROID_KEY_PASSWORD`. The upload keystore was generated on 1 Nov 2026 (PKCS12, RSA 2048, valid to 2054). SHA-1 `90:E8:D7:AB:7F:AF:79:8F:AE:AC:44:5E:C0:DA:3E:B5:FF:24:4D:12`, SHA-256 `BE:29:EA:DD:3A:05:B9:31:97:84:6F:2C:58:3A:A4:6F:0E:0C:5E:A9:49:CE:91:D7:1B:2D:76:B6:26:35:D4:EB`.

Local check (owner's Termux, Flutter 3.29.2), from `app/`: `flutter pub get && flutter gen-l10n && flutter analyze --no-fatal-infos && sh tool/check_forbidden.sh && flutter test`.

## 8. Batches in dependency order (what was built, commit prefix in git history)

| Batch | Content |
|---|---|
| b1 | Repo, pubspec, lints, l10n config, English strings, gate script, fonts, Android scaffold (via `bootstrap.yml`), verify workflow |
| b2 | Design tokens, theme, motion, route, scroll behaviour, token tests |
| b3 | Config, models, error taxonomy, Result, log, formatters |
| b4 | Contracts, settings codec, organizer, save coordinator, test fakes |
| b5 | Platform Dart implementations (channel, repositories, share, prefs, links, haptics, video) |
| b6 | Kotlin native layer, Gradle, manifest, workflows, throwaway spike. E1 passed on the owner's phone |
| b7 | Nine providers |
| b8 | Icons and primitives |
| b9 | Layout, feedback, sheets, services container, scope |
| b10 | Media and viewer widgets |
| b11 | Screens |
| b12 | Shell: error handling, lifecycle, gate, app widget, real `main.dart` |
| fix-1, fix-2 | Chip truncation, parent-folder pick, auto and pull refresh, honest copy; Standard/Business selector |
| b13 | Brand SVGs, rendered PNGs, generated icon and splash, two-colour wordmark |
| b14 | Website and store documents |
| b15 | Settings completion: share, support, how to connect, terms page, licenses, debug logs |
| b16 | 10 languages, override, language sheet, parity and per-language tests |
| b17a/b | Ads and consent: contracts, policy, provider, SDK services, banners, interstitial triggers, Pro row, privacy choices |
| b18 | Review prompt, merged Rate row |
| b19 | Dependency upgrade within Flutter 3.29.2; Kotlin 2.2.0, NDK 27 |
| b20 | Emulator workflow and smoke script |
| ads updates | 7-minute spacing, no daily cap, viewer save and viewer delete moments |

Work approved but not started (the next batches) is listed in `docs/handoff.md` section 6.

## 9. Known limits and unverified items

| Item | State |
|---|---|
| Release-mode build with R8 and the current plugins | Never built. The first test APK will be the first release-mode build since the b17 to b19 changes |
| Interstitials, the consent form, consent errors | Unit-tested with fakes only. Never run against the real SDK or an EEA phone |
| Translations | Mechanically checked only. Not natively reviewed. Not yet back-translated |
| Android's own picker wording per language | Not verified (planned A6) |
| Speed on a low-end phone | Never measured. The emulator renders in software and says nothing about speed |
| After a reinstall | Earlier saves stay in the gallery but are not listed in Saved (Android ownership rule) |
| Store folder layout | Not a public API. If it changes, the fix is one file, `core/models/status_source.dart` |

---

## 10. Generated file inventory

Auto-extracted from the first documentation line of each file (it can describe the first type in the file, not always the whole file). Regenerate when many files change.

### App code (Dart) (`app/lib`, 128 files)

| File | Purpose |
|---|---|
| `app/app_gate.dart` | Chooses the first screen. |
| `app/app_scope.dart` | Gives the widget tree access to the services container. The container |
| `app/app_services.dart` | The dependency container and wiring. This file (and the temporary spike) is |
| `app/error_handling.dart` | Rebuilds the whole app tree. The crash fallback's "Try again" uses it. |
| `app/font_licenses.dart` | Adds the licenses of the two bundled fonts to Flutter's license registry, |
| `app/lifecycle_refresher.dart` | Re-verifies grants and silently refreshes lists every time the app returns |
| `app/statussozo_app.dart` | The application widget. |
| `core/app_config.dart` | Every constant that is not a design token. |
| `core/contracts/ad_service.dart` | Where one banner is in its life. |
| `core/contracts/consent_service.dart` | What the consent step decided. |
| `core/contracts/haptics_service.dart` | Port for touch feedback. Fire-and-forget. |
| `core/contracts/link_launcher.dart` | Port for leaving the app. Every method returns whether it succeeded. |
| `core/contracts/review_service.dart` | Port for the store's in-app review prompt. **No method may throw.** |
| `core/contracts/saved_repository.dart` | Port for the gallery folders the app saves into. |
| `core/contracts/settings_store.dart` | What a store returns on load. |
| `core/contracts/share_service.dart` | Port for the system share sheet. |
| `core/contracts/status_repository.dart` | Port for the status source folders. |
| `core/contracts/thumbnail_source.dart` | Port for pixels. |
| `core/contracts/video_playback.dart` | A snapshot of a video session. |
| `core/errors/app_error.dart` | Every failure the app distinguishes. |
| `core/errors/error_codes.dart` | Error code strings sent by the native layer. Mirrors `ErrorCodes.kt`. |
| `core/models/app_language.dart` | A language the app is translated into. The name is written in the language |
| `core/models/app_settings.dart` | The user's theme choice. |
| `core/models/folder_grant.dart` | A persisted folder permission for one source. |
| `core/models/json_fields.dart` | Returns [json] [key] as a string, or throws [FormatException]. |
| `core/models/media_kind.dart` | The two kinds of media the app handles. |
| `core/models/save_summary.dart` | The result of a batch save. |
| `core/models/saved_item.dart` | An item saved to the gallery. |
| `core/models/status_item.dart` | An item in a status folder. |
| `core/models/status_source.dart` | The two supported sources. All path knowledge lives only in this file, so a |
| `core/models/viewable_media.dart` | The shape shared by anything the grid, thumbnails and viewer can show. |
| `core/providers/ad_provider.dart` | Where ads stand for the whole app. |
| `core/providers/folder_access_provider.dart` | Connection state of one source. |
| `core/providers/locale_provider.dart` | The language the person chose, as a language code. Null means follow the |
| `core/providers/review_provider.dart` | Decides when to ask for a store review, and counts toward it. |
| `core/providers/save_provider.dart` | The summary of the most recent batch. |
| `core/providers/saved_library_provider.dart` | Newest first. |
| `core/providers/selection_provider.dart` | Multi-select. Two instances exist, one for Home and one for Saved. |
| `core/providers/settings_provider.dart` | What the settings provider publishes. |
| `core/providers/source_provider.dart` | Which source is showing. |
| `core/providers/status_list_provider.dart` | Loading phase of a list. |
| `core/providers/theme_provider.dart` | The theme preference. Mapping to Flutter's `ThemeMode` happens in the app |
| `core/providers/toast_provider.dart` | Every message the app can toast. The UI turns a code into localised text; |
| `core/result.dart` | Explicit success or failure instead of thrown exceptions. |
| `core/services/consent_rules.dart` | Decides whether ads may be requested after the consent step. |
| `core/services/disabled_ads.dart` | An ad service that never shows anything. Used in tests and wherever ads are |
| `core/services/disabled_review.dart` | A review service that never shows anything. Used in tests. |
| `core/services/interstitial_policy.dart` | The moments at which an interstitial may be considered. |
| `core/services/save_coordinator.dart` | Batch save orchestration. |
| `core/services/settings_codec.dart` | Upgrades stored JSON from one schema version to the next. |
| `core/services/status_organizer.dart` | Pure list logic. |
| `design/app_colors.dart` | The only place colour literals exist. Every other file reads these tokens. |
| `design/app_motion.dart` | Durations and curves. There are no spring or bounce curves in this app. |
| `design/app_page_route.dart` | The one route type. Push 350 ms, pop 280 ms, ease-in-out, fade plus a 20 px |
| `design/app_radii.dart` | Corner radii, as doubles and as ready-made [BorderRadius] values. |
| `design/app_scroll_behavior.dart` | Clamping physics, no overscroll glow, no scrollbar: no bounce anywhere. |
| `design/app_shadows.dart` | The single permitted shadow in the app: the floating selection bar. |
| `design/app_sizes.dart` | Fixed dimensions shared across the app. |
| `design/app_spacing.dart` | Spacing scale. Screen gutter is [md]; grid gap is [sm]. |
| `design/app_theme.dart` | Builds [ThemeData] from tokens. Material is only the invisible scaffolding |
| `design/app_typography.dart` | The only place text styles exist. |
| `design/design.dart` |  |
| `l10n/app_ar.arb` |  |
| `l10n/app_de.arb` |  |
| `l10n/app_en.arb` |  |
| `l10n/app_es.arb` |  |
| `l10n/app_fr.arb` |  |
| `l10n/app_he.arb` |  |
| `l10n/app_hi.arb` |  |
| `l10n/app_ja.arb` |  |
| `l10n/app_ko.arb` |  |
| `l10n/app_pt.arb` |  |
| `l10n/app_zh.arb` |  |
| `main.dart` |  |
| `platform/google_ad_service.dart` | Ads through the Google Mobile Ads SDK. Nothing here throws: a failure is |
| `platform/in_app_review_service.dart` | The Google Play in-app review prompt. Nothing here throws. |
| `platform/media_store_saved_repository.dart` | [SavedRepository] over MediaStore. |
| `platform/native_thumbnail_source.dart` | [ThumbnailSource] with a least-recently-used cache of futures keyed by |
| `platform/plus_share_service.dart` | Opens the system share sheet with a list of files. |
| `platform/prefs_settings_store.dart` | [SettingsStore] over `shared_preferences`: one JSON string under one key. |
| `platform/saf_channel.dart` | The folder the person picked in the system picker. |
| `platform/saf_status_repository.dart` | [StatusRepository] over the storage access framework. |
| `platform/system_haptics.dart` | [HapticsService] over `HapticFeedback`. Fire-and-forget; failures are ignored. |
| `platform/ump_consent_service.dart` | Consent through Google's User Messaging Platform. A request that fails never |
| `platform/url_link_launcher.dart` | Opens a URI in another app. Returns whether it was handled. |
| `platform/video_player_session.dart` | [VideoSession] over `video_player`, playing straight from a content URI |
| `screens/access_screen.dart` | Why the access screen is showing. |
| `screens/debug_logs_screen.dart` | The on-device debug log: newest first, with Send report and Clear. The log |
| `screens/error_fallback_screen.dart` | The full-screen crash fallback. It depends on neither `AppScope` nor any |
| `screens/home_screen.dart` | The main screen: Photos and Videos tabs, the source chip, the grid, and a |
| `screens/licenses_screen.dart` | The open-source licenses: every package that ships with the app. |
| `screens/saved_screen.dart` | The saved library: the same grid and selection mechanics as Home, with Share |
| `screens/screen_text.dart` | The display name of a source. |
| `screens/settings_screen.dart` | Settings: inset grouped cards with uppercase section headers. |
| `screens/viewer_screen.dart` | Whether the viewer shows statuses (with a Save button) or saved items (with |
| `utils/app_log.dart` | Local-only diagnostics: a ring buffer of the last 50 lines. Nothing leaves |
| `utils/formatters.dart` | Formats a byte count: `0 B`, `512 B`, `1 KB`, `1.5 MB`. Binary units, at |
| `utils/license_collector.dart` | One package and the license text that applies to it. |
| `widgets/ads/ad_slot.dart` | The bottom embed that holds a banner ad. |
| `widgets/feedback/empty_state.dart` | The centred layout shared by empty and error views: a 72 px `bgTertiary` |
| `widgets/feedback/error_state.dart` | Localised title for an error kind. Kinds that only ever appear as toasts |
| `widgets/feedback/toast_host.dart` | The localised text of a toast message. |
| `widgets/icons/app_icon.dart` | The only widget that draws icons. Every icon uses the same stroke width so |
| `widgets/icons/app_icons.dart` | Icon data as the icon package represents it. |
| `widgets/layout/app_nav_bar.dart` | The nav bar: at least 56 px tall, brand or back chip on the start edge, the |
| `widgets/layout/screen_scaffold.dart` | The standard shape of every screen: nav bar, primary content, optional |
| `widgets/media/media_grid.dart` | The grid delegate used everywhere: tiles of at most 140 px with an 8 px gap. |
| `widgets/media/media_thumbnail.dart` | One thumbnail. It asks the [ThumbnailSource] once (the source caches), shows |
| `widgets/media/selection_bar.dart` | The floating action pill shown in selection mode: one compact |
| `widgets/media/status_tile.dart` | The accessibility label of a tile: kind, saved and selected. |
| `widgets/primitives/app_card.dart` | The one card: `bgSecondary` fill, hairline border, radius 16, no elevation. |
| `widgets/primitives/app_chip.dart` | Visual tone of a chip. Tones also carry an icon, so colour is never the |
| `widgets/primitives/app_group.dart` | Inset grouped list: one card shell with hairline dividers between rows, |
| `widgets/primitives/app_row.dart` | The one list row: leading icon, label, optional second line, trailing value |
| `widgets/primitives/button_base.dart` | Shared geometry of the two button types: filled, height 52, radius 12, |
| `widgets/primitives/loading_indicator.dart` | The one spinner: a `CupertinoActivityIndicator` tinted with a token. |
| `widgets/primitives/nav_icon_button.dart` | A toolbar action: a 40 x 40 chip with a 22 px icon and a 48 px hit area. |
| `widgets/primitives/pressable.dart` | The touch primitive everything tappable is built on. |
| `widgets/primitives/primary_button.dart` | The one primary action: filled `accent`, `accentOn` label, never outlined. |
| `widgets/primitives/secondary_button.dart` | The one secondary action: same geometry, `accentSoft` fill, `accent` label. |
| `widgets/primitives/section_header.dart` | A group header: uppercase `sectionHeader` text in the tertiary colour, |
| `widgets/primitives/segmented_tabs.dart` | One segment of [SegmentedTabs]. |
| `widgets/sheets/app_sheet.dart` | One row of an action sheet. |
| `widgets/sheets/language_sheet.dart` | Lets the person choose the app language: System default first, then every |
| `widgets/viewer/video_controls.dart` | Custom video controls: a 64 px circle that plays, pauses or replays, a |
| `widgets/viewer/video_surface.dart` | Builds the controls for a live session. It is rebuilt whenever the session |
| `widgets/viewer/viewer_overlay.dart` | Top and bottom chrome for the viewer: gradient scrims (scrim to transparent) |
| `widgets/viewer/zoomable_image.dart` | Pinch and double-tap zoom for an image: 1x to 4x, with a double tap that |

### Tests (`app/test`, 53 files)

| File | Purpose |
|---|---|
| `analysis_options.yaml` | Tests share doubles from test/fakes/, which cannot be reached through a |
| `app/app_services_test.dart` | Records the order in which the bootstrap steps touch their dependencies. |
| `app/app_smoke_test.dart` |  |
| `app/font_licenses_test.dart` |  |
| `app/review_wiring_test.dart` |  |
| `core/app_error_test.dart` |  |
| `core/consent_rules_test.dart` |  |
| `core/interstitial_policy_test.dart` |  |
| `core/models_test.dart` |  |
| `core/providers/ad_provider_test.dart` |  |
| `core/providers/folder_access_provider_test.dart` |  |
| `core/providers/locale_provider_test.dart` |  |
| `core/providers/review_provider_test.dart` |  |
| `core/providers/saved_save_provider_test.dart` |  |
| `core/providers/selection_provider_test.dart` |  |
| `core/providers/settings_theme_source_test.dart` |  |
| `core/providers/status_list_provider_test.dart` |  |
| `core/providers/toast_provider_test.dart` |  |
| `core/result_test.dart` |  |
| `core/save_coordinator_test.dart` |  |
| `core/settings_codec_test.dart` |  |
| `core/status_organizer_test.dart` |  |
| `core/video_state_test.dart` |  |
| `design/contrast_test.dart` | WCAG 2.x contrast ratio between two opaque colours. |
| `design/theme_test.dart` |  |
| `design/tokens_test.dart` |  |
| `fakes/fakes.dart` | A controllable clock. |
| `l10n/arb_parity_test.dart` | Placeholder names: ASCII identifiers directly inside braces. |
| `platform/mock_saf.dart` | Every call received, in order. |
| `platform/native_thumbnail_source_test.dart` |  |
| `platform/platform_services_test.dart` |  |
| `platform/prefs_settings_store_test.dart` |  |
| `platform/saf_channel_test.dart` |  |
| `platform/saf_repositories_test.dart` |  |
| `platform/video_player_session_test.dart` |  |
| `screens/access_screen_test.dart` |  |
| `screens/ads_screens_test.dart` |  |
| `screens/debug_licenses_test.dart` |  |
| `screens/home_screen_test.dart` |  |
| `screens/languages_test.dart` |  |
| `screens/screen_harness.dart` | Everything a screen test needs: the fakes and the container built on them. |
| `screens/settings_screen_test.dart` |  |
| `screens/viewer_saved_test.dart` |  |
| `utils/app_log_test.dart` |  |
| `utils/formatters_test.dart` |  |
| `utils/license_collector_test.dart` |  |
| `widgets/ad_slot_test.dart` |  |
| `widgets/harness.dart` | Sets a phone-sized surface for the test. |
| `widgets/layout_feedback_test.dart` |  |
| `widgets/media_widgets_test.dart` |  |
| `widgets/primitives_test.dart` |  |
| `widgets/viewer_widgets_test.dart` |  |
| `widgets/wordmark_test.dart` |  |

### Native Android (Kotlin) (`app/android/app/src/main/kotlin`, 8 files)

| File | Purpose |
|---|---|
| `com/zdmgold/statussozo/ErrorCodes.kt` | Error code strings sent to Dart. Must match lib/core/errors/error_codes.dart. |
| `com/zdmgold/statussozo/FolderAccess.kt` | The system folder picker and the persisted permissions it produces. |
| `com/zdmgold/statussozo/FolderLister.kt` | Lists a granted folder with a single content-resolver query, which is much |
| `com/zdmgold/statussozo/GallerySaver.kt` | Saves into MediaStore so items appear in the gallery, lists what this app |
| `com/zdmgold/statussozo/MainActivity.kt` |  |
| `com/zdmgold/statussozo/SafChannelHandler.kt` | Routes every method of the statussozo/saf channel to its helper. Everything |
| `com/zdmgold/statussozo/ShareCache.kt` | Stages files in the cache folder so the share sheet reads plain files, and |
| `com/zdmgold/statussozo/ThumbnailLoader.kt` | Decodes small JPEG thumbnails on a fixed pool of three threads, with a 16 MB |

### Tooling scripts (`app/tool`, 4 files)

| File | Purpose |
|---|---|
| `build_brand_assets.sh` | Renders the SVG sources in app/brand/ to PNG, then runs the icon and splash |
| `check_forbidden.sh` | StatusSozo mechanical gate: forbidden patterns, RTL safety and layering. |
| `emulator_smoke.sh` | Drives the debug build on a running emulator: connects a sample status folder |
| `fetch_fonts.sh` | Downloads the two bundled variable fonts and their SIL OFL licences into |

### Brand SVG sources (`app/brand`, 6 files)

| File | Purpose |
|---|---|
| `feature_graphic.svg` |  |
| `icon_background.svg` |  |
| `icon_foreground.svg` |  |
| `icon_master.svg` |  |
| `icon_mono.svg` |  |
| `splash_logo.svg` |  |

### CI workflows (`.github/workflows`, 5 files)

| File | Purpose |
|---|---|
| `bootstrap.yml` | One-time: generates the Android project scaffold with the pinned Flutter |
| `brand.yml` | One-off: runs the launcher icon and splash generators on the committed PNGs |
| `build_android.yml` | Manual only. Never add a push: trigger. |
| `emulator.yml` | Boots Android 13 and 14 emulators, installs a debug build with sample |
| `verify.yml` | Manual only. Never add a push: trigger. |

### Website (`website`, 7 files)

| File | Purpose |
|---|---|
| `index.html` |  |
| `privacy.html` |  |
| `robots.txt` |  |
| `sitemap.xml` |  |
| `style.css` |  |
| `support.html` |  |
| `terms.html` |  |

### Store submission documents (`store_submission`, 6 files)

| File | Purpose |
|---|---|
| `ADMOB_SETUP.md` | AdMob setup |
| `ASO_METADATA.md` | Store listing: copy and answers |
| `CLOSED_TESTING_PLAN.md` | Closed testing plan |
| `DATA_BACKING.md` | Evidence behind the Data safety form |
| `PLAY_CONSOLE_CHECKLIST.md` | Play Console submission checklist |
| `SCREENSHOT_STRATEGY.md` | Screenshot plan |
