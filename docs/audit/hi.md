# Translation audit: Hindi (hi)

Method: every key was read with its key name and the English beside the Hindi, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Register is the polite "आप" imperative (…करें) throughout. Common English tech words (ऐप, फ़ोटो, वीडियो, एक्सेस, स्टोरेज, रीफ़्रेश) are written in Devanagari, as Hindi Android does.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 164 |
| Corrected | 2 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} सहेजे गए, {failed} नहीं सहेजे जा सके` | "{n} saved (plural), {n} could not be saved (plural)" | Wrong verb form at 1 (plural verb with the number 1) | `one` and `other` forms for both numbers (`1 सहेजा गया`, `1 नहीं सहेजा जा सका`) |
| settingsSectionLegal | कानूनी | "Legal" (adjective only) | A bare adjective as a section title | कानूनी जानकारी ("Legal information") |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Hindi text (emulator check, API 33 and 34), including the corrected step 3 ("यह फ़ोल्डर इस्तेमाल करें").
- Hindi's `one` plural form covers 0 and 1, so zero cases are written with "=0" where the English has one.
- Number order for "x of y" is reversed ("{total} में से {current}"), which is correct Hindi word order.
- Folder names Pictures/{folder} and Movies/{folder} stay in Latin letters.
