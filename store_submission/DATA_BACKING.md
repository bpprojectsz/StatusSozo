# Evidence behind the Data safety form

Google's rules, as read from its Data safety help page on 1 November 2026:

| Rule | Source wording, in short |
|---|---|
| "Collect" means transmitting data from the app off the user's device | Data safety help page |
| Data only accessed or processed on the device and not sent off it does not need to be disclosed as collected | Same page |
| Every developer must complete the form and link a privacy policy, even if the app collects nothing | Same page |
| Transferring user data to another app directly on the device must be disclosed as sharing, even if nothing leaves the device | Same page |

**Re-read the live page on the day of submission.** Google changes the wording. The "Verified" column below says what was and was not confirmed.

## Stage 1 answers

| Form question | Answer | Why it is true | Verified |
|---|---|---|---|
| Does the app collect or share any of the required user data types? | **No collection.** Sharing: see the decision below. | The app has no network permission. Nothing is transmitted off the device. | Rule read 1 Nov 2026 |
| Is all user data encrypted in transit? | Not applicable | Nothing is transmitted | n/a |
| Can users request that data is deleted? | Not applicable | No data is held by the developer | n/a |
| Account creation | None | No accounts, no sign-in | Confirmed in code |
| Photos and videos, files and docs | Accessed on the device only, never transmitted | The app reads the one folder the user picks and copies items into the gallery | Confirmed in code |
| Device identifiers, location, contacts, messages, financial, health | Not accessed | No such permission or API is used | Confirmed in code (manifest has no `uses-permission`) |
| Analytics or crash SDK | None | None is included | Confirmed in `pubspec.yaml` |
| Independent security review | No | | n/a |
| Privacy policy URL | https://statussozo.bpprojectsz.workers.dev/privacy | Live, and it matches the app | Page checked in the repo 1 Nov 2026 |

## One decision that is yours: the Share action

When the user taps Share, the app hands a copy of the chosen file to the Android share sheet, and the user picks the destination app. Google's page says transfers to another app on the device must be disclosed as sharing. I could not confirm from the text I retrieved whether Google exempts a transfer the user starts themselves. Read the form's own "sharing" exemptions on the day, then choose one:

| Choice | Form answer | Trade-off |
|---|---|---|
| Treat Share as user-initiated and exempt, if the exemption text covers it | "No data shared" | Cleanest label. Risk: if the exemption does not apply, the declaration is inaccurate. |
| Declare it | Photos and videos shared, purpose App functionality, user-initiated | Always accurate. The listing then shows that the app shares photos and videos. |

My recommendation is to declare it unless the exemption wording clearly covers it. An inaccurate declaration is the larger risk.

## Stage 2 answers (ads, S1 to S3)

Do this **before** the first ads build is uploaded.

| Item | Change |
|---|---|
| Collection | Yes: device or other IDs (advertising ID) and the other categories Google's AdMob disclosure page lists, for advertising |
| Sharing | Yes: with the ad network |
| Encryption in transit | Yes for ad traffic, as the SDK documents |
| Manifest | `INTERNET` and `com.google.android.gms.permission.AD_ID` |
| Privacy page | Replace the "no ads" section with the real ad and consent disclosure |
| Verified | Against Google's AdMob data disclosure page on the submission day |
