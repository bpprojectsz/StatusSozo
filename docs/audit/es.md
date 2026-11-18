# Translation audit: Spanish (es)

Method: every key was read with its key name and the English beside the Spanish, then back-translated by hand into English. Done by the assistant who also wrote the translation, so shared blind spots remain; a native speaker should still read the store-facing text. 166 keys read.

## Result
| Verdict | Count |
|---|---|
| Matches the English | 163 |
| Corrected | 3 (plus the 25 regional changes below) |

## Corrections
| Key | Before | Back-translation of the old text | Problem | After |
|---|---|---|---|---|
| toastSavedPartial | `{saved} guardados, {failed} no se pudieron guardar` | "{n} saved, {n} could not be saved" | Wrong grammar at 1: "1 guardados", "1 no se pudieron guardar" | plural forms for both numbers (`1 guardado`, `1 no se pudo guardar`) |
| semSwitchSource | Cambiar de fuente | "Change font/typeface" | "fuente" also means typeface, and this label is read aloud by screen readers | Cambiar de origen |
| sourceSheetTitle | Elige una fuente | "Choose a font/source" | Same ambiguity | Elige un origen |

## Checked and left alone (for the record)
- The Android picker words in accessStep2 and accessStep3 match Android's own Spanish text (emulator check, API 33 and 34).
- "Business" is left in English on purpose: it is the product's name.
- Register is "tú" throughout.
- "Eliminar" (delete) and "Borrar" (clear) are used for different actions on purpose.

## Decision by the owner: Latin American Spanish
Applied to 25 strings. Changes: Ajustes to Configuración; Valorar to Calificar; Vídeo(s) to Video(s); Informar de un problema to Reportar un problema; informe to reporte; "ha pasado / ha ocurrido / ha tenido" to the simple past (pasó / ocurrió / tuvo); Comprueba to Verifica; "encima de esta línea" to "arriba de esta línea". A scan of all 166 values found no Spain-only wording left. The Android picker wording in the Access steps is unchanged and is re-checked on the emulator.
