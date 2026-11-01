# Closed testing plan

## Do you need it?

Google requires a closed test for some new developer accounts before they can apply for production access. I could not confirm your account details, so decide from this table once you know them:

| Your account | Closed test before production |
|---|---|
| Personal account created on or after 13 November 2023 | **Required: at least 12 testers opted in, for 14 consecutive days.** Verify the current numbers in the Console. |
| Personal account created before 13 November 2023 | Not required by that rule. Still recommended for one round of real-device feedback. |
| Organisation account | Not required by that rule. Same recommendation. |

If the test is required, **start recruiting the day you upload the first build**. The 14 days start when the opted-in count reaches the minimum.

## Recruiting

| Rule | Detail |
|---|---|
| Real people only | Never use paid, bought or fake testers. Google treats that as a policy violation and it can end the account. |
| How many | Aim for 15 to 20 so a few drop-outs do not reset the count |
| Who | People with Android 10 or later phones, ideally a spread of phone brands and Android versions. At least some should have the messaging app and its business version installed. |
| How they join | You add their Google account emails to a tester list in the Console, or share the opt-in link. Each tester must accept the invitation. |

## Tester brief (send this to every tester)

```
Thank you for testing StatusSozo, an app that lets you browse, save and share status
photos and videos from a folder you choose.

1. Install it from the link I sent and open it.
2. Tap Choose folder and pick the status folder (or the folder that contains it).
3. Try: browsing Photos and Videos, selecting several items and saving them, opening
   the viewer (swipe, zoom, play a video), sharing an item, opening Saved and deleting
   one, and changing the theme in Settings.
4. If you use both the standard and the business messaging app, connect both and switch
   between them.
5. Keep the app installed for the full 14 days and open it a few times.

Please report anything that crashes, looks wrong, or confuses you: Settings, then
Send feedback. Tell me your phone model and Android version.
```

## Tracking

| Day | Opted-in testers | Builds uploaded | Crashes in vitals | Feedback received | Notes |
|---|---|---|---|---|---|
| 1 | | | | | |
| 7 | | | | | |
| 14 | | | | | |

Fill this in as you go. Check after every new upload that the opted-in count and the day count have not changed.

## Applying for production

When the 14 days are complete, the Console asks you to apply for production access. It asks how you tested, what feedback you received and how you acted on it. Answer with the real numbers and real changes from your tracking table. Do not copy generic text. Reviewers read these answers.

## While the test runs

| Item | Detail |
|---|---|
| Updates | Upload fixes to the same track. Keep the same testers. |
| Stage 2 | Ads and languages are built during this period. Do not ship ads to testers with live IDs. Test IDs only. |
