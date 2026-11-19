# Translation audit: Portuguese (pt, Brazilian wording)

Method: every key was read with its key name and the English beside the Portuguese, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read. Register is "você" throughout. The wording is Brazilian (Salvar, Compartilhar, Excluir, Carregando, Arquivos), not European.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 164 |
| Corrected | 2 |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} salvos, {failed} não puderam ser salvos` | "{n} saved, {n} could not be saved" | Wrong grammar at 1: "1 salvos", "1 não puderam" | plural forms for both numbers (`1 salvo`, `1 não pôde ser salvo`) |
| settingsSectionLegal | Legal | "Cool" | In Brazilian Portuguese "Legal" on its own is everyday slang for "cool"; as a bare section title it reads wrongly | Informações legais |

## Checked and left alone
- The Android picker words in accessStep2 and accessStep3 match Android's own Portuguese text (emulator check, API 33 and 34).
- "Business" and "Padrão" (Standard) stay as they are.
- `one` plural form covers 0 and 1, which is the Brazilian rule; "=0" is used where English has a zero case.
- European Portuguese would use different words (Guardar, Partilhar, A carregar, Ficheiros). The app is Brazilian by choice; a European set is not built.
