# AdMob setup

Until this is done the app runs on Google's **test** ad IDs, which is what you want for testing. Never click your own live ads, and never put live IDs in a test build.

## Order

| Step | What to do |
|---|---|
| 1 | Publish the app to a Play track first. AdMob links an app to its store listing. |
| 2 | Create an AdMob account. Complete the payments profile and tax information so earnings can be paid. |
| 3 | In AdMob, add the app as an Android app and link it to the Play listing (`com.zdmgold.statussozo`). |
| 4 | Create two ad units: an **Adaptive banner** and an **Interstitial**. |
| 5 | Copy the three values: the app ID (`ca-app-pub-...~...`), the banner unit ID and the interstitial unit ID (`ca-app-pub-.../...`). |
| 6 | Create the consent message under Privacy and messaging for the EEA and UK, and publish it. The app's consent step needs it to show a form. |
| 7 | Add your phone as a test device in AdMob, so you can see live-ID ads without counting as a real user. |

## Compiling live IDs into a release

| Step | What to do |
|---|---|
| 1 | In the repository settings add three secrets: `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID` |
| 2 | Run the **build_android** workflow with `build_type` = release and `live_ads` ticked |
| 3 | The workflow refuses `live_ads` on any other build type, and refuses it when a secret is missing |
| 4 | Upload that AAB to the track. Every other build keeps Google's test IDs. |

## app-ads.txt

AdMob asks you to publish an `app-ads.txt` file at the root of the developer website named in the Play listing. It holds one line with your AdMob publisher ID, in the format AdMob shows you. It cannot be written until the AdMob account exists. Put it in the `website/` folder so it is served at `https://statussozo.bpprojectsz.workers.dev/app-ads.txt`, then check in AdMob that it shows as verified.

## Rules the app follows

| Rule | Detail |
|---|---|
| Consent first | No ad is requested until Google's consent step reports that ads may be requested. After a person declines, Google may still serve non-personalised (limited) ads or none, and that is Google's decision. |
| Banners | Home, Viewer, Saved and Settings. Not on the access screen or the crash screen. Each is released when another screen covers it. |
| Interstitials | After a batch save of two or more items, after every fifth viewer close, and after deleting from Saved. At least 3 minutes apart and at most 6 a day. Never at launch, on exit or during video playback. |
| Content rating | The app asks the network for general-audience ads |

## Before you update the store forms

| Form | Change |
|---|---|
| Data safety | See `DATA_BACKING.md` |
| Ads declaration | Yes |
| Privacy policy | Already describes ads and consent |
