# Translation audit: Korean (ko)

Method: every key was read with its key name and the English beside the Korean, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Polite style: 합니다 for messages, 하세요 for instructions; button labels use the short noun form (저장, 공유, 삭제).

## Result
| Verdict | Count |
|---|---|
| Matches the English | 163 |
| Corrected | 3 (4 strings) |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| settingsDisclaimer | `{appName}은(는)` ... | "{appName} (topic marker, either form)" | The hedged particle "은(는)" shows literally to the reader ("StatusSozo은(는)"). Korean picks the particle by the last sound of the name; "StatusSozo" ends in a vowel sound, so it is "는" | `{appName}는` |
| shareAppMessage | `{appName}으로` ... | "with {appName}" | "으로" is the form after a consonant; after a vowel it is "로" | `{appName}로` |
| sourceSheetTitle, semSwitchSource | 소스 선택, 소스 전환 | "Choose / switch sauce" (or source) | "소스" most often means the food sauce to everyday readers | 출처 선택, 출처 전환 ("origin") |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Korean text (emulator check, API 33 and 34).
- Korean has no singular and plural, so counts use "other" with the counter 개; toastSavedPartial needs no grammar fix.
- "상태" is the WhatsApp-style word for a status and is used throughout.
- "지원" is used for both the Support section and the Support row.

## Known limit of the particle fix
The particles are chosen for the current app name, StatusSozo. If the display name were ever changed to one that ends in a consonant sound, "는" and "로" in settingsDisclaimer and shareAppMessage would need to become "은" and "으로". Korean ICU messages cannot choose the particle from a placeholder.
