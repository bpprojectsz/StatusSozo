# Translation audit: Japanese (ja)

Method: every key was read with its key name and the English beside the Japanese, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Polite です・ます style throughout; button labels use the short noun or verb form (保存, 共有, 削除) as Android does. Full-width brackets ［ ］ and punctuation are used.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 164 |
| Corrected | 2 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| languageSystemDefault | システムの設定 | "System settings" | Reads as "System settings", which is also what the Settings screen is called, not "system default" | システムのデフォルト ("System default") |
| proComingSoonSubtitle | 広告を削除する買い切りの購入です。 | "A buy-out purchase that removes ads" | Clumsy: "purchase" is said twice in one phrase | 一度の購入で広告を削除できます。 ("One purchase removes ads.") |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Japanese text (emulator check, API 33 and 34), including the corrected step 2 ("非表示のファイルを表示").
- Japanese has no singular and plural, so every count uses the "other" form with the counter 件; the English zero case is "0件", which is correct. toastSavedPartial needs no grammar fix.
- "情報" for the About section is short but understood; "このアプリについて" would be more explicit. Left as is.
- Latin text such as {appName}, Pictures/{folder} and Android keeps its own spacing, as in Japanese Android UI.
