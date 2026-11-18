# Translation audit: French (fr)

Method: every key was read with its key name and the English beside the French, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Register is "vous" throughout.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 163 |
| Corrected | 3 (one of them touches 5 strings) |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} enregistrés, {failed} n'ont pas pu l'être` | "{n} saved, {n} could not be" | Wrong grammar at 1: "1 enregistrés", "1 n'ont pas pu" | plural forms for both numbers (`1 enregistré`, `1 n'a pas pu l'être`) |
| settingsReviewTap | Touchez pour noter sur le store | "Tap to rate on the store" | "store" is an English word and sounds casual | Touchez pour noter dans la boutique d'applications |
| deleteTitle, debugLogsClearTitle, savedFooter, shareAppMessage and every other string with " ?" or " :" | plain space before ? and : | n/a | French typography needs a non-breaking space so "?" or ":" never starts a new line | non-breaking space (U+00A0) |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own French text (emulator check, API 33 and 34).
- "Business" and "Standard" stay as they are (product names).
- One-form plurals use French's rule: 0 and 1 are singular ("one"), and "=0" is used where the English has a zero case.
- "Mentions légales" for the Legal section, "Assistance" for Support, "Réglages" for Settings: standard French app wording.
