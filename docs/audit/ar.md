# Translation audit: Arabic (ar)

Method: every key was read with its key name and the English beside the Arabic, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Imperative masculine singular throughout (the usual app convention). Plural forms use all six Arabic categories where a count is shown.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 163 |
| Corrected | 3 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| accessStep2 | إذا لم يعرضه المحدد ... | "If the determiner/specifier doesn't show it" | "المحدد" ("the specified one") is not a clear word for the folder picker | إذا لم تعرضه أداة الاختيار ... ("the selection tool") |
| settingsDisclaimer | ... غير تابع لأي خدمة مراسلة ولا تدعمه | "...not affiliated with any messaging service and does not support it" | The subject of "does not endorse" is unclear: it reads as if the app does not support the service | ... وليس تابعًا لأي خدمة مراسلة ولا تؤيده أي منها ("...and none of them endorses it") |
| settingsSectionLegal | قانوني | "Legal" (adjective only) | A bare adjective as a section title | معلومات قانونية ("Legal information") |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Arabic text (emulator check, API 33 and 34); the only change to step 2 is the picker's name, not the words the person must tap.
- Plurals use zero case, one, two, few (3 to 10), many (11 to 99) and other, with the correct noun form for each (for example عناصر, عنصرًا, عنصر).
- toastSavedPartial ("تم حفظ {saved} وتعذّر حفظ {failed}") needs no plural: Arabic leaves out the noun after the number, so there is no agreement problem at 1.
- Digits: Flutter shows numbers in the style of the locale, so counts appear as Arabic-Indic digits on Arabic phones; no change made.
- The folder names Pictures/{folder} and Movies/{folder} stay in Latin letters inside the right-to-left text, as they are real folder names.
