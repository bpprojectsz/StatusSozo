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

## Finding that affects every language
homeEmptyMessage tells people to "Open its Status tab". As far as I know, current WhatsApp shows statuses under a tab called Updates, not Status. If so, the instruction is outdated in all 11 languages. This is a wording decision for the owner, not a translation fault. See the report.
