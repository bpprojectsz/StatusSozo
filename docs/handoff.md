# Handoff for the next agent

Read this first, then `docs/decisions.md`, then `docs/blueprint.md`. **Update this file at the end of every batch** (state, next step), append every decision to `docs/decisions.md`, and keep `docs/blueprint.md` true to the code.

## 1. State in one paragraph

Stage 1 and Stage 2 of the specification are built and green: `main` passes `flutter analyze` (0 issues), the forbidden-pattern gate, and **1168 tests** (at 2947663). Android 13 and 14 emulators ran the app (launch, folder picker, 12 photos and 2 videos listed, viewer, save into `Pictures/StatusSozo`, relaunch persistence, ads banner, seven languages). **Done: A1 to A6, B1 to B3, C1 to C3, D1 to D5 (last green 2947663, 1168 tests). A7 (back-translation audit of all 11 languages, by hand, records in docs/audit/) is done; the picker check passed 45 of 45 on API 33 and 34 at a7e4133. A8 was folded into the same pass (instruction strings read for clarity). Only the owner's test build and device checks remain.** A4 and A6 are proven on emulators (API 33 and 34, Google DocumentsUI): the App languages screen lists all 11 languages, and every Access-screen step matches Android's own picker wording in all 11 languages. Not proven on a device: system-language resolution (adb system-locale switching drops the connection; it is covered by widget tests only), and other makers' pickers (Samsung, Xiaomi and others word things differently). No test APK has been built since test-5, so nothing from b15 onward has run on the owner's phone. The owner has said: **no APK until he writes "build".**

## 2. Access and identities (no secrets in this file, the repository is public)

| Item | Value |
|---|---|
| Repository | https://github.com/bpprojectsz/StatusSozo (branch `main`, public) |
| GitHub access token | **Not stored here and never to be committed.** The owner gives it in the conversation or the project instructions. It is a personal access token with Contents, Workflows, Actions and Secrets read and write. If you do not have it, ask for it. |
| Commit identity | `bpprojectsz` / `314406686+bpprojectsz@users.noreply.github.com` |
| Actions secrets already set | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`StatusSozo`), `ANDROID_KEY_PASSWORD`. Passwords are held by the owner. The keystore file and its base64 were given to him on 1 Nov 2026 |
| Secrets not yet created | `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID` (after the AdMob account exists) |
| Website | https://statussozo.bpprojectsz.workers.dev (Cloudflare builds from `website/` on each push to `main`) |
| Support e-mail | stmakarios@gmail.com |
| Owner | Works only from an Android phone (Termux with Flutter 3.29.2). Writes tersely. Sends screenshots and asks for tables |

## 3. How the owner wants you to work

1. **Blunt, short, tables.** No padding, no premature claims of completeness, no placeholders. Ask for any missing detail instead of assuming.
2. **Discuss before coding** when he sends an observation or a small remark. Do not rewrite code on a remark.
3. **Never build or dispatch an APK** (`build_android` with `test`, `debug` or `release`) until he writes "build". The emulator workflow builds a CI-only debug APK and is allowed (he approved it).
4. **Do not lecture** about the token or security. Do keep it out of files.
5. **Language audit rules (A7):** no sub-agents; do it yourself one language at a time; read every string in full with the English and the key name beside it; do not rely on machine output. Report flagged strings, correct, re-check.
6. After every batch: push only when the local gate is green, run `verify`, read the log, report in a table with the Termux command block, and say what was **not** verified.
7. Be honest about limits: the translations are agent-written, ads and consent have not run against the real SDK, emulator frame times mean nothing.

## 4. Operating the environment

| Fact | Detail |
|---|---|
| Sandbox | Has bash, python3, git, `apt` (ImageMagick, `librsvg2-bin`, JDK work), pip. Can reach github.com and api.github.com. **Cannot run Flutter, reach pub.dev, Google Maven or the Android SDK.** Each command is limited to 300 seconds: poll in separate calls with loops under about 250 s |
| The working copy can vanish | The sandbox has been reset before. Re-clone with the token: `git clone https://x-access-token:$GH@github.com/bpprojectsz/StatusSozo.git`, then set the commit identity |
| Local gate | `cd app && sh tool/check_forbidden.sh` (the only check that runs locally) |
| Verify | Dispatch `verify.yml`, wait about 3.5 minutes, read `ci-logs` |
| Push order | `verify.yml` commits `pubspec.lock` back, so run `git pull --rebase origin main` before every push or it is rejected |
| Chain with `&&` | A past push went out with a failing gate because commands were joined with `;`. Always `sh tool/check_forbidden.sh && git add -A && git commit ... && git push` |

```
export GH=<token>
# dispatch verify
curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Authorization: Bearer $GH" -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/bpprojectsz/StatusSozo/actions/workflows/verify.yml/dispatches -d '{"ref":"main"}'
# status
curl -s -H "Authorization: Bearer $GH" "https://api.github.com/repos/bpprojectsz/StatusSozo/actions/workflows/verify.yml/runs?per_page=1" \
  | python3 -c "import sys,json;r=json.load(sys.stdin)['workflow_runs'][0];print(r['head_sha'][:7],r['status'],r['conclusion'])"
# read the result
git fetch -q origin ci-logs && git show origin/ci-logs:meta.txt
git show origin/ci-logs:verify.log | tr -cd '\11\12\15\40-\176' | grep -E "^ *(error|warning|info)  |No issues|issues? found|All tests passed|Some tests failed|\[E\]"
# emulator (api = all, 33 or 34), then: git fetch origin ci-emulator-34; git show origin/ci-emulator-34:summary.txt; PNGs are in the same branch
curl -s -X POST ... .../workflows/emulator.yml/dispatches -d '{"ref":"main","inputs":{"api":"34"}}'
```

Known traps: a job-level `if` cannot read `matrix` (build the matrix from the input); `uiautomator dump` fails on screens with an animated ad (use coordinates on Home); the emulator can show "Pixel Launcher isn't responding" (the script now hides those); GitHub sometimes returns 504 while downloading Gradle (just re-run); an ICU apostrophe directly before `{` or after `}` in an ARB string breaks `gen-l10n`.

## 5. What exists (full detail in `docs/blueprint.md`)

Screens: Access, Home, Viewer, Saved, Settings, Debug logs, Licenses, License detail, Crash fallback (9; banners on 4). Providers: settings, theme, source, locale, folder access, status list, saved library, selection x2, save, toast, ad, review. Native: Kotlin channel `statussozo/saf` (11 methods). Languages: 11. Tests: 1168 across 60 files. Workflows: `verify`, `build_android`, `emulator`, plus the finished one-offs `bootstrap`, `brand`. Pinned: Flutter 3.29.2, Kotlin 2.2.0, AGP 8.9.1, Gradle 8.11.1, NDK 27.0.12077973. `google_mobile_ads` 6.0.0, `hugeicons` 4.4.0, `share_plus` 12.0.2, `package_info_plus` 9.0.1, `in_app_review` 2.0.12.

Last shipped test APK: **test-5** (Releases page), built before b15. Everything since is untested on the phone: icon, splash, wordmark, source selector, refresh, Terms and licenses, Debug logs, languages, ads, review row, new packages.

## 6. The approved plan, not started (the owner ticked every item)

Suggested batch names continue the sequence: b21, b22, and so on. Report after each. The owner asked to **report after A5, A1, A2, A3, A4 before touching A6 and A7**. He did not fix the order of B, C and D: propose it at that report.

### A. Languages

| ID | Work | Detail and acceptance |
|---|---|---|
| A5 (DONE) | CI string check | Move the apostrophe-next-to-brace check (`'{` or `}'`) into `test/l10n/arb_parity_test.dart` so CI enforces it |
| A1 (DONE) | System language on first install | Tests that set the phone's language list (`tester.platformDispatcher.localesTestValue`) with `languageCode` null: each of the 11; variants pt-BR, es-MX, zh-TW, en-GB, he-IL; an unsupported language; a list whose first entry is unsupported and second supported. Assert and document what Flutter's default resolution does. If the second preference is ignored, add a `localeListResolutionCallback` so the first supported language in the list wins, and test it |
| A2 (DONE) | Manual choice survives restart | Start-up test: choose a language, build a new `AppServices` from the same stored settings, assert the language and direction. Also "System default" after restart |
| A3 (DONE) | Everything in every language | Extend `test/screens/languages_test.dart` to Viewer (both modes), Licenses, License detail, all 6 sheets, every `ToastCode`, every error kind, at 1x and 2x text: no overflow, locale applied |
| A4 (DONE) | Android 13+ App language screen | (Files and manifest done; emulator proof still open.) Add `res/xml/locales_config.xml` listing en, es, fr, de, pt, ar, hi, ja, ko, zh, he, and `android:localeConfig="@xml/locales_config"` in the manifest. Rule: the in-app choice wins; "System default" follows the system or per-app setting. Prove on the emulator (API 33 and 34) |
| A6 (DONE) | Picker wording | Extend the emulator job to switch the **system** language and screenshot Android's own folder picker in each language. Compare "Use this folder", "Allow", "Show hidden files" with `accessStep2` and `accessStep3` in every language and fix mismatches (biggest comprehension risk) |
| A7 | Back-translation audit | Per language, one at a time, by you, no agents: a table of key, English, translation, back-translation, verdict for **all 156 strings**, key name and English beside every row. Output a short flagged list with corrections, apply, re-check, next language. Store reports as `docs/i18n-audit/<code>.md` and a final `SUMMARY.md` listing every change. The audit shares the author's blind spots: say so, and keep recommending a native review |
| A8 | Comprehension pass | Same reading, rating each **instruction** string (Access steps, errors, empty states, toasts): does a first-time user know what to do? Propose and apply rewrites |

A1 outcome: a deterministic resolver `AppLanguages.resolve` (first supported language in the phone's list, else English; regions ignored) is wired through `localeListResolutionCallback`. It only runs while no language is chosen in the app. zh-TW opens Simplified Chinese (the only Chinese shipped).

Order approved: A5, A1, A2, A3, A4, report; then A6; then A7 and A8 language by language.

### B. Consent resilience

| ID | Work |
|---|---|
| B1 | `ConsentOutcome` gains `needsRetry`, set when the consent step errored. On the next foreground, run the consent step once more; ads keep running meanwhile; never loop |
| B2 | A throw from `canRequestAds()` (inside `UmpConsentService._current`) counts as an error: still ask for ads, log it, retry per B1 |
| B3 | Tests: throwing case, retry-once, retry-does-not-loop (extend `test/core/consent_rules_test.dart` and `ad_provider_test.dart`) |

### C. Review prompt (the owner's final wording)

| ID | Work |
|---|---|
| C1 | Tapping **Rate the app** only opens the Play listing. It must **not** mark the prompt as done (remove `markAsked()` from `_reviewNow` in `settings_screen.dart`) |
| C2 | Ask again later, never a permanent stop. After each ask reset the counters; the next ask needs another 10 saved items on 3 different days **and** a cooldown of up to 30 days (assumed exactly 30: constant `reviewCooldown`). Replace `reviewAsked` with a timestamp field. Google's own quota still decides whether anything appears |
| C3 | The quiet period around interstitials becomes **up to 10 minutes** (`reviewQuietAfterInterstitial`, now 2) |

Update `review_provider_test.dart`, `models_test.dart`, `settings_screen_test.dart`, `docs/blueprint.md` section 5 and `docs/decisions.md`.

### D. Storage and memory

| ID | Work |
|---|---|
| D1 | Cap Flutter's image cache at 50 MB at start-up (`PaintingBinding.instance.imageCache.maximumSizeBytes`) |
| D2 | Owner ticked it without choosing. Assume: `AppLog` keeps **500** lines, the Debug logs screen shows all, the e-mailed report carries only the last 50. Confirm in the batch report |
| D3 | Storage row in Settings: size of the share cache plus a Clear button. New native calls `shareCacheSize` and `clearShareCache`, a `ShareService` method pair, a row, about 4 strings in 11 languages |
| D4 | The start-up sweep also deletes the oldest share copies when the folder passes **200 MB**, on top of the 24-hour rule (`ShareCache.kt`) |
| D5 | Low-storage check before a batch save or a share copies files: needed size plus a 50 MB margin against free space (new native `freeSpace`). New `AppErrorKind.lowStorage`, a toast, an error state, the taxonomy tests, and translations in 11 languages |

Every new string needs the 10 translations and passes the parity test. Not applicable from the owner's pasted cleanup notes: document rows, search index, overlay images, PDF or conversion memory, Undo.

## 7. After the plan

1. Wait for the owner's **"build"**, then run `build_android` with `build_type: test`. Result: a release-mode arm64 APK on the Releases page (`test-6`). It is the first release-mode build with the current plugins and ads SDK, so read the build log branch `ci-logs-build` for R8 problems. Tell him to uninstall the previous test build first (new temporary key each time).
2. He tests on his phone (checklists were given in earlier reports). Fix findings as `fix-N` batches.
3. Release: he adds or confirms the four signing secrets, then `build_type: release` for the AAB.
4. Play: follow `store_submission/PLAY_CONSOLE_CHECKLIST.md`, `DATA_BACKING.md` (read Google's AdMob data disclosure on the day), `SCREENSHOT_STRATEGY.md` (crop to at most 2:1), `CLOSED_TESTING_PLAN.md`.
5. AdMob: after the listing exists, follow `ADMOB_SETUP.md`, create the three secrets, build a release with `live_ads`, write `website/app-ads.txt` (needs his publisher ID).
6. Stage 3 (paid "Remove ads"): only if a Play merchant profile exists.

## 8. Needed from the owner

Play account type and creation date; AdMob publisher ID; his "build" go-ahead; results from his phone; a native-speaker review of the translations and a lawyer's read of the Terms before launch; whether he wants the official Google Play badge file swapped in.

## 9. Small known stale items

| Item | Fix |
|---|---|
| `app/pubspec.yaml` description still says "you have already viewed" | Reword |
| Play badge on the website is a crop from a screenshot (about 240 px wide) | Replace with Google's official file when available |
| `docs/blueprint.md` file inventory (section 10) is generated | Regenerate when many files change |
| The original four-part specification is not in the repository | Ask the owner to add it as `docs/spec/` if it is not in the project instructions |


## Decisions added after the plan (from the owner)
- C2 cooldowns: 30 days after the first ask, 90 after the second, 180 after every later one. A new ask needs only the wait to pass.
- C3: exactly 10 minutes after an interstitial.
- D2: the 500-line email was rejected as far too long; the owner has not yet given the new number.


## Built after the plan (B, C, D), with the rules as built
- Consent (B): a failed consent step (or a throwing canRequestAds) still asks for ads and is retried once on the next foreground; never more than once per launch.
- Review (C): tapping Rate never touches the automatic prompt. First request after 10 saves on 3 days; then only time counts: 30 days after the first request, 90 after the second, 180 after every later one. Never within 10 minutes of an interstitial. Old "asked" settings become one request, and the wait starts at the next save.
- Storage (D): Flutter image cache capped at 50 MB; debug log 50 lines on screen and in the email; Settings row "Temporary files" with size and Clear; share cache capped at 200 MB (oldest first) plus the 24 hour rule; a save or share that would leave under 50 MB free is stopped before anything is copied and says so (lowStorage error, toast and error state in 11 languages); native out-of-space errors map to lowStorage.
- Native code from D3, D4 and D5 was compiled and smoke-tested on the Android 13 and 14 emulators (save works, relaunch goes straight to Home). The low-storage stop and the 200 MB cap themselves were not exercised on a device.


## Owner decisions after the audit
- Spanish uses the Latin American set. Portuguese stays Brazilian wording (a European set was offered, no answer yet).
- homeEmptyMessage keeps "Open its Status tab" (option C). Checked 19 Nov 2026: current WhatsApp calls the tab Updates and is still changing it; the wording may be out of date for some users. Same phrase is in website/index.html, website/support.html and store_submission/ASO_METADATA.md.
- Japanese keeps ソース for "source" (Korean uses 출처); offered 取得元, no answer yet.


## b21 (owner's three requests after the first phone test)
- Viewer: only the status bar is hidden, the navigation bar stays, so the banner sits above the buttons like Home (`SystemUiMode.manual`, overlays: bottom).
- First run: the app asks Android which of the two apps are installed (package names in the manifest `<queries>`, no permission). The access screen lists them with a Not connected / Connected chip; Choose folder (or tapping a row) connects one and opens the next picker straight away (`FolderAccessProvider.connectInOrder`, `holdSetup` keeps the access screen up). If nothing is detected, or detection fails, both are offered. Cancelling the second picker keeps the first, with no message.
- Home: an All view is the default when two sources are connected. The selector reads All / Standard / Business with a count on each. `StatusListProvider` now lists every connected source at once and merges them newest first (`StatusItem.source`); a failing source is recorded in `errors` and the other still shows; the whole list is an error only when every source fails. Each tile shows the first letter of its source name in the All view, and its accessibility label names the source. A source that needs access again while the other shows gets a warning chip.
- New strings: sourceAll, tileLabelWithSource (11 languages).
- Emulator (API 33 and 34, commit 25ca3cd): the second picker opened by itself, both sources connected, Home opened on All (All 19, Standard 14, Business 5), the viewer banner sits above the gesture bar, a test interstitial showed after a photo save in the viewer.
- Known limit, not changed: duplicate detection (the Saved badge and the "already saved" skip) still goes by file name only. Two different files with the same name from the two apps would be treated as one.
