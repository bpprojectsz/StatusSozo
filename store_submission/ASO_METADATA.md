# Store listing: copy and answers

Everything here matches the app as built in Stage 1 (no ads, no network access). Stage 2 changes are listed at the end.

## Identity

| Field | Value |
|---|---|
| App name (30 max) | `StatusSozo: Status Saver` (24 characters) |
| Application ID | `com.zdmgold.statussozo` (cannot be changed after the first upload) |
| Category | Tools |
| Contact email | stmakarios@gmail.com |
| Website | https://statussozo.bpprojectsz.workers.dev |
| Privacy policy URL | https://statussozo.bpprojectsz.workers.dev/privacy |
| Support URL | https://statussozo.bpprojectsz.workers.dev/support |
| Price | Free |

## Short description (80 max, 76 characters)

```
Browse, save and share status photos and videos from the folders you choose.
```

## Full description (4,000 max, 2178 characters)

```
StatusSozo is a simple, private way to browse, save and share the status photos and videos stored on your phone.

You choose the folder. StatusSozo reads only that folder, and nothing else on your phone.

WHAT YOU CAN DO

• Browse: Photos and Videos in two tabs, newest first, with live counts.
• Save: save one item, or select many and save them together. Photos go to Pictures/StatusSozo and videos to Movies/StatusSozo, so they also appear in your gallery.
• Share: send one or several items through the standard Android share sheet.
• View: swipe between items, pinch or double-tap to zoom photos, and play videos with clear controls.
• Saved library: see everything you saved, share it again, or delete it with a confirmation.
• Both apps: connect the standard and the business messaging app, then switch between them with one tap.
• Always current: the list refreshes by itself while it is open, and you can pull it down to refresh at once.
• Your look: follow the system theme, or choose light or dark.

PRIVATE BY DESIGN

• No account and no sign-in.
• No analytics and no tracking.
• No internet access. The app works entirely on your device.
• No access to your chats, contacts or messages. You grant access to one folder through the system folder picker, and you can remove it any time in Settings.

HOW IT WORKS

1. Open StatusSozo and tap Choose folder.
2. In the system file picker, open the status folder (or the folder that contains it) and tap Use this folder.
3. Browse, select and save. Everything you save stays in your gallery.

GOOD TO KNOW

• A status appears in StatusSozo once the messaging app has loaded it on your phone. If a list is empty, open the messaging app's Status tab and come back.
• The status folder is hidden by Android. If the picker does not show it, open the picker's menu and turn on Show hidden files.
• StatusSozo needs Android 10 or later.
• Only save and share content you have the right to use.

StatusSozo is an independent app. It is not affiliated with, endorsed by or sponsored by any messaging service.

Questions or feedback? Open Settings and tap Send feedback, or visit https://statussozo.bpprojectsz.workers.dev/support
```

## What's new (first release)

```
First release.
```

## Why the listing reads this way

| Choice | Reason |
|---|---|
| No messaging-service name, colour or logo anywhere | Play's impersonation and trademark policies. The cost is some search ranking, which is accepted to avoid a takedown. |
| No "without being seen" or "secretly" claims | Play's metadata policy rejects misleading or unverifiable claims. |
| "A status appears once the messaging app has loaded it" | This is what the app actually depends on, and it sets the right expectation for an empty list. |
| "No internet access" | True for Stage 1: the manifest has no permissions at all. **Remove this line when Stage 2 adds ads.** |
| Disclaimer in the description | The app is independent, and the text says so plainly. |

## Questionnaire answers (the developer must answer these in the Console; these are the answers that match the app)

| Question | Answer |
|---|---|
| Target audience | Not directed at children. Select 13 to 15, 16 to 17 and 18 and over. Do not select any age group below 13. |
| Ads | No, the app contains no ads (Stage 1) |
| App access | All functionality is available without login or special access. Add the reviewer instructions in `PLAY_CONSOLE_CHECKLIST.md`. |
| Content rating | The app contains no violence, sexual content, gambling, drugs or profanity of its own. It displays files from a folder the user chooses, and it does not host or distribute user content. Answer the questionnaire literally for the app itself. Re-read each question on the day, because the wording changes. |
| Government, news, health, financial features | No to all |
| Data safety | See `DATA_BACKING.md` |

## Stage 2 changes

| Item | Change |
|---|---|
| Ads declaration | Yes |
| Description | Remove "No internet access" and the ad-free implication, and add the ad and consent disclosure |
| Data safety | Update first, then ship (`DATA_BACKING.md`) |
| Listing languages | 10 more, in `LISTING_TRANSLATIONS.md` (Stage 2, S3) |
