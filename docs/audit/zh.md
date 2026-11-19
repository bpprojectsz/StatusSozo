# Translation audit: Chinese, Simplified (zh)

Method: every key was read with its key name and the English beside the Chinese, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Polite "您" throughout; Mainland wording (点按, 分享, 视频, 文件夹, 设置). Spaces between Latin text and Chinese are used as in current Chinese Android apps.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 166 |
| Corrected | 0 |

## Checked
- The Android picker words in accessStep2 and accessStep3 match Android's own Chinese text (emulator check, API 33 and 34).
- Chinese has no singular and plural, so counts use "other" with the counter 项; toastSavedPartial needs no grammar fix.
- "跟随系统" is used for both the System theme and System default language, which is the usual Chinese wording.
- Only Simplified Chinese is shipped. A phone set to Traditional Chinese (Taiwan, Hong Kong) opens the app in Simplified Chinese.

## Style notes (not mistakes, nothing changed)
- "支持" for Support is understood; "帮助与反馈" or "获取支持" would be more explicit.
- "商业版" for Business; "商务版" is also common.

## Finding that affects every language (now checked against sources, 19 Nov 2026)
homeEmptyMessage tells people to "Open its Status tab".
- WhatsApp's own Updates Tab terms (effective 14 July 2025, whatsapp.com/legal/updatestab-terms-of-service) call it the "Updates Tab", the home of Channels and Status.
- Android Authority's current how-to tells Android users to tap the Updates tab to see statuses.
- WABetaInfo (beta 2.26.17.x, 2026) reports a limited test that also shows statuses at the top of the Chats tab; the full overview stays in the Updates tab. Notebookcheck (17 Feb 2026) describes the same.
- Older articles still say "Status tab", so the name has changed over time and is still changing.
- Not verified: whether WhatsApp Business uses the same names.
Conclusion: "Status tab" is out of date, and naming "Updates" could also go stale. Recommendation: no tab name at all (option A). Decision pending with the owner.
