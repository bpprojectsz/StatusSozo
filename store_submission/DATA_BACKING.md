# Evidence behind the Data safety form

Google's rules, as read from its Data safety help page on 1 November 2026:

| Rule | Source wording, in short |
|---|---|
| "Collect" means transmitting data from the app off the user's device | Data safety help page |
| Data only accessed or processed on the device and not sent off it does not need to be disclosed as collected | Same page |
| Every developer must complete the form and link a privacy policy | Same page |
| Transferring user data to another app directly on the device must be disclosed as sharing, even if nothing leaves the device | Same page |
| Data that a third-party SDK in your app collects counts as collected by your app | Google's published Data safety guidance. **Re-read it on the day.** |

**Re-read the live page on the day of submission.** Google changes the wording. The "Verified" column says what was and was not confirmed.

## What the app itself does

| Fact | Evidence |
|---|---|
| No account, no sign-in, no analytics SDK, no crash-reporting SDK | `pubspec.yaml` lists none |
| The developer receives and stores nothing | There is no backend |
| Photos and videos are read from one folder the user picks, and copied into the gallery. They are never uploaded. | Code and privacy page |
| The only network use is the Google ad SDK and Google's consent form | Manifest declares `INTERNET` and `AD_ID` for that |

## Answers for this build (with ads)

| Form question | Answer | Why | Verified |
|---|---|---|---|
| Does the app collect or share any of the required user data types? | **Yes, through the Google Mobile Ads SDK** | The SDK sends device and usage data to Google to show and measure ads | Not verified. Read Google's AdMob data disclosure page on the day and declare exactly what it lists for banner ads, interstitial ads and the consent form. |
| Data types | Declare what that page lists. Expect device or other IDs (the advertising ID), app interactions, diagnostics and approximate location from the IP address. | Do not declare more or less than Google lists. | Not verified |
| Purpose of collection | Advertising or marketing; analytics and fraud prevention as Google lists | | Not verified |
| Shared with third parties | Yes: Google, as the ad network | | Not verified |
| Collected by the app itself, outside the SDK | **None** | No other code sends data | Confirmed in code |
| Is all user data encrypted in transit? | Yes for ad traffic, as Google's SDK documents | Confirm in Google's SDK documentation on the day | Not verified |
| Can users request deletion of their data? | Not applicable to the developer, who holds none. Users can reset the advertising ID in Android settings. | | n/a |
| Account creation | None | | Confirmed in code |
| Independent security review | No | | n/a |
| Privacy policy URL | https://statussozo.bpprojectsz.workers.dev/privacy | Updated 5 November 2026 to describe ads and consent | Page checked in the repo |
| Advertising ID (Play Console declaration) | Yes, used for advertising | The manifest declares `AD_ID` | Confirmed in code |

## One decision that is yours: the Share action

When the user taps Share, the app hands a copy of the chosen file to the Android share sheet, and the user picks the destination app. Google's page says transfers to another app on the device must be disclosed as sharing. I could not confirm from the text I retrieved whether Google exempts a transfer the user starts themselves. Read the form's own "sharing" exemptions on the day, then choose one:

| Choice | Form answer | Trade-off |
|---|---|---|
| Treat Share as user-initiated and exempt, if the exemption text covers it | Share is not declared | Cleanest label. Risk: if the exemption does not apply, the declaration is inaccurate. |
| Declare it | Photos and videos shared, purpose App functionality, user-initiated | Always accurate |

My recommendation is to declare it unless the exemption wording clearly covers it. An inaccurate declaration is the larger risk.

## Keeping it true

| Change | Do first |
|---|---|
| Adding or removing an SDK | Update this file, the privacy page and the Data safety form before the release |
| Adding the paid "remove ads" option | Update the form for Play Billing data, and the privacy page |
