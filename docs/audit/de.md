# Translation audit: German (de)

Method: every key was read with its key name and the English beside the German, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Register is "du" throughout.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 164 |
| Corrected | 2 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} gespeichert, {failed} konnten nicht gespeichert werden` | "{n} saved, {n} could not be saved" | Wrong grammar when 1 failed: "1 konnten" | `1 konnte nicht gespeichert werden` for one, `konnten` for more |
| semCloseViewer (screen-reader label) | Anzeige schließen | "Close ad" | "Anzeige" also means advertisement, and the app shows ads; a screen reader would announce "close ad" for the viewer's close button | Ansicht schließen |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own German text (emulator check, API 33 and 34).
- "Status" is both singular and plural in German, so "deine Status" is correct.
- "Store" in settingsReviewTap is common German app wording; left as is.
- "Support", "Info" and "Design" (for Theme) are normal German app wording. "Werbung" is used for ads everywhere.
