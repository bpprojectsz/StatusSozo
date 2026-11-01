# Play Console submission checklist

Play changes its Console and policy wording often. Treat every "verify" below as a real step on the day.

## Before you start

| # | Item | State |
|---|---|---|
| 1 | Play developer account created and identity-verified | Yours to do. The account type (personal or organisation) and creation date decide the closed-test rule in `CLOSED_TESTING_PLAN.md`. |
| 2 | Release build (AAB) produced with the upload keystore | Needs your four signing secrets in the repository settings (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). The release workflow refuses to build without them. |
| 3 | Keystore file backed up off the phone | Losing the upload key means a key-reset request to Google |
| 4 | Website pages live | https://statussozo.bpprojectsz.workers.dev, /privacy and /support. Open all three on the phone first. |
| 5 | Official Play badge on the home page | Replace `website/images/google-play-badge.svg` with Google's own file. The current one is a third-party copy. |

## Create the app

| Step | Value |
|---|---|
| App name | See `ASO_METADATA.md` |
| Default language | English |
| App or game | App |
| Free or paid | Free |
| Declarations | Developer Program Policies and US export laws, ticked by you |

## Policy forms (App content)

| Form | Answer |
|---|---|
| Privacy policy | https://statussozo.bpprojectsz.workers.dev/privacy |
| App access | All functionality is available without login. Paste the reviewer instructions below. |
| Ads | No ads (Stage 1) |
| Content rating | Answer the questionnaire literally (`ASO_METADATA.md`) |
| Target audience | 13 and over, not directed at children |
| Data safety | `DATA_BACKING.md`, including the Share decision |
| Government, news, health, financial features | No |
| Advertising ID | Not used in Stage 1. Declare "No". Stage 2 changes this. |

### Reviewer instructions (paste into App access)

```
StatusSozo lists photos and videos from a folder the user chooses. It needs no login.

If the test phone does not have the messaging app, create a folder named .Statuses
(for example inside Documents) and copy a few photos and videos into it. Open
StatusSozo, tap Choose folder, open the folder that contains .Statuses (or .Statuses
itself; if the picker hides it, open the picker menu and turn on Show hidden files)
and tap Use this folder, then Allow.

The app then shows the Photos and Videos tabs. Long-press an item to select, tap Save
to copy it to Pictures/StatusSozo or Movies/StatusSozo, and open Saved to see it.
```

**Before you submit this text:** confirm on a real phone that picking the parent folder works and that a hand-made `.Statuses` folder is accepted. The parent-folder pick was added after the last device test and has not been confirmed yet.

## Store listing

| Item | Source |
|---|---|
| Title, short and full description | `ASO_METADATA.md` |
| App icon, 512 x 512 | `store_submission/graphics/play_icon_512.png` |
| Feature graphic, 1024 x 500, no alpha | `store_submission/graphics/feature_graphic_1024x500.png` |
| Phone screenshots, at least 2 | `SCREENSHOT_STRATEGY.md` |
| Category | Tools |
| Contact email, website | stmakarios@gmail.com and https://statussozo.bpprojectsz.workers.dev |

## Upload and release

| Step | Detail |
|---|---|
| Play App Signing | Accept it. Your keystore becomes the upload key. |
| Track | Closed testing first (`CLOSED_TESTING_PLAN.md`), then production |
| Target API | The app targets 36. Check Play's current minimum target level on the day. |
| Release notes | "First release." |
| Pre-launch report | Read it after the first upload. Fix any crash it finds. |
| Staged rollout | Start production at a low percentage and raise it |

## After release

| Step | Detail |
|---|---|
| First week | Check Android vitals for crashes and ANRs daily |
| Updates | Any change to ads, permissions or data handling means updating Data safety and the privacy page first |
| Maintenance | The messaging service's folder layout is not a public API. If it changes, the fix is one file (`status_source.dart`), shipped as an update. |
