# Translation audit: Hebrew (he)

Method: every key was read with its key name and the English beside the Hebrew, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Masculine singular imperative throughout (the usual app convention); nouns in nominal form for buttons (שמירה, מחיקה, ניקוי). Plurals use one, two and other.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 161 |
| Corrected | 5 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} נשמרו, ...` | "{n} were saved (plural)" | Wrong form at 1: "1 נשמרו" | `1 נשמר` for one, `נשמרו` for more |
| semCloseViewer (screen-reader label) | סגירת הצופה | "Closing the spectator" | "הצופה" is a person who watches, not a screen | סגירת התצוגה ("closing the view") |
| toastWrongFolder, errorWrongFolderMessage | ... בחר את .Statuses ... | n/a | In right-to-left text the leading dot of ".Statuses" is drawn after the name ("Statuses."), because a dot between Hebrew and Latin text takes the right-to-left direction | the name is wrapped in a left-to-right isolate (U+2066 ... U+2069) |
| settingsSectionLegal | משפטי | "Legal" (adjective only) | A bare adjective as a section title | מידע משפטי ("Legal information") |
| settingsStorageClear | נקה | "Clean (imperative)" | Inconsistent with debugLogsClear, which is the noun form ניקוי | ניקוי |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Hebrew text (emulator check, API 33 and 34). Step 3 uses Android's Hebrew "Allow" text, "כן, זה בסדר", taken from the picker's resource file; the Hebrew dialog was never seen on screen.
- Plural forms use "=1", "=2" and other with the right noun forms (פריט אחד, שני פריטים).
- The same ".Statuses" display flaw was found in Arabic and fixed there too.
- Folder names Pictures/{folder} and Movies/{folder} stay together as Latin text inside the right-to-left sentence.
