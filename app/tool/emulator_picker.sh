#!/bin/bash
# A6 and A4 on a real engine. For each language it changes the SYSTEM language
# (the system folder picker follows it; the per-app language does not), opens
# Android's own folder picker at the status folder, and records what the picker
# and its confirmation dialog really say, as screenshots, uiautomator dumps and
# a table. It then opens the app (no folder connected, so the Access screen,
# which has no ad and can be read) and checks that the three steps shown are
# the app's own strings for that language. Also records the Android 13+
# "App languages" screen for the app (A4).
# Run by the emulator workflow after the smoke script. Needs adb and python3.
set +e
PKG=com.zdmgold.statussozo
APK=app/build/app/outputs/flutter-apk/app-debug.apk
OUT=/tmp/emu/picker
STAT=/sdcard/Android/media/com.whatsapp/WhatsApp/Media/.Statuses
INIT='content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses'
mkdir -p "$OUT"
: > "$OUT/summary.txt"
note() { echo "$1" | tee -a "$OUT/summary.txt"; }
shot() { adb exec-out screencap -p > "$OUT/$1.png"; }

dump_to() {
  for i in 1 2 3 4; do
    adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 \
      && adb pull /sdcard/ui.xml "$OUT/$1.xml" > /dev/null 2>&1 \
      && [ -s "$OUT/$1.xml" ] && return 0
    sleep 2
  done
  note "dump failed: $1"
  return 1
}

# tap_id SUBSTRING XML: taps the node whose resource-id contains SUBSTRING.
tap_id() {
  xy=$(python3 - "$1" "$2" <<'PY'
import re, sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[2]).getroot()
except Exception:
    sys.exit(0)
for n in root.iter('node'):
    if sys.argv[1] in (n.get('resource-id') or '') and n.get('bounds'):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)
  if [ -n "$xy" ]; then adb shell input tap $xy; return 0; fi
  return 1
}

# tap_overflow XML: the right-most clickable control in the top toolbar.
tap_overflow() {
  xy=$(python3 - "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    sys.exit(0)
best = None
for n in root.iter('node'):
    if n.get('clickable') != 'true' or not n.get('bounds'):
        continue
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
    if y1 < 420 and (best is None or x2 > best[0]):
        best = (x2, (x1 + x2) // 2, (y1 + y2) // 2)
if best:
    print(best[1], best[2])
PY
)
  if [ -n "$xy" ]; then adb shell input tap $xy; return 0; fi
  return 1
}

set_system_locale() {
  adb root > /dev/null 2>&1
  sleep 2
  adb wait-for-device
  adb shell "setprop persist.sys.locale $1; setprop ctl.restart zygote" > /dev/null 2>&1
  sleep 20
  adb wait-for-device
  for i in $(seq 1 60); do
    [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ] \
      && adb shell pm path android > /dev/null 2>&1 && break
    sleep 2
  done
  sleep 25
  adb shell settings put global hide_error_dialogs 1
  adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS > /dev/null 2>&1
  adb shell input keyevent KEYCODE_HOME
  sleep 3
  note "system locale now: persist=$(adb shell getprop persist.sys.locale | tr -d '\r') current=$(adb shell getprop ro.product.locale | tr -d '\r')"
}

adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
adb shell settings put global hide_error_dialogs 1
adb root > /dev/null 2>&1; sleep 2
note "adb root: $(adb shell id | tr -d '\r')"
note "device: $(adb shell getprop ro.build.version.release | tr -d '\r') (API $(adb shell getprop ro.build.version.sdk | tr -d '\r'))"

# The status folder must exist for the picker to open inside it.
if [ -z "$(adb shell ls "$STAT" 2>/dev/null)" ]; then
  adb shell mkdir -p "$STAT"
  for f in /tmp/media/*; do adb push "$f" "$STAT/" > /dev/null 2>&1; done
fi
note "files in the status folder: $(adb shell ls "$STAT" 2>/dev/null | wc -l)"
adb install -r "$APK" 2>&1 | tail -1 | tee -a "$OUT/summary.txt"
# No folder connected, so the app opens on its Access screen.
adb shell pm clear "$PKG" > /dev/null 2>&1

# A4: the Android 13+ "App languages" screen must list the app's languages.
set_system_locale en-US
adb shell am start -a android.settings.APP_LOCALE_SETTINGS -d "package:$PKG" > /dev/null 2>&1
sleep 6
shot applang_screen
dump_to applang_screen
python3 - "$OUT/applang_screen.xml" <<'PY' | tee -a "$OUT/summary.txt"
import sys, xml.etree.ElementTree as ET
want = ['English', 'Spanish', 'French', 'German', 'Portuguese', 'Arabic',
        'Hindi', 'Japanese', 'Korean', 'Chinese', 'Hebrew']
try:
    texts = ' | '.join((n.get('text') or '') for n in ET.parse(sys.argv[1]).getroot().iter('node'))
except Exception:
    print('APP LANGUAGES SCREEN: could not read'); sys.exit(0)
found = [w for w in want if w in texts]
print('APP LANGUAGES SCREEN lists:', ', '.join(found) or 'none')
print('APP LANGUAGES SCREEN missing:', ', '.join(w for w in want if w not in found) or 'none')
PY
adb shell input keyevent KEYCODE_BACK
sleep 1

for entry in en-US:en es-ES:es fr-FR:fr de-DE:de pt-BR:pt ar-EG:ar he-IL:he hi-IN:hi ja-JP:ja ko-KR:ko zh-CN:zh; do
  TAG=${entry%%:*}
  L=${entry##*:}
  note "===== $TAG"
  set_system_locale "$TAG"

  # The system picker, opened at the status folder like the app does it.
  adb shell am force-stop com.android.documentsui
  adb shell am start -a android.intent.action.OPEN_DOCUMENT_TREE --eu android.provider.extra.INITIAL_URI "$INIT" > /dev/null 2>&1
  sleep 8
  shot "picker_$L"
  dump_to "picker_$L"
  tap_overflow "$OUT/picker_$L.xml"
  sleep 2
  shot "menu_$L"
  dump_to "menu_$L"
  adb shell input keyevent KEYCODE_BACK
  sleep 1
  tap_id "button_pick" "$OUT/picker_$L.xml"
  sleep 3
  shot "dialog_$L"
  dump_to "dialog_$L"
  adb shell input keyevent KEYCODE_BACK
  adb shell am force-stop com.android.documentsui
  sleep 1

  # The app's own Access screen in the same system language.
  adb shell am force-stop "$PKG"
  adb shell am start -W -n "$PKG/.MainActivity" > /dev/null 2>&1
  sleep 9
  shot "app_$L"
  dump_to "app_$L"
done

python3 - "$OUT" app/lib/l10n <<'PY' | tee -a "$OUT/summary.txt"
import json, os, re, sys, xml.etree.ElementTree as ET
out, arbdir = sys.argv[1], sys.argv[2]

def nodes(name):
    try:
        return list(ET.parse(os.path.join(out, name + '.xml')).getroot().iter('node'))
    except Exception:
        return None

def texts(ns):
    return [(n.get('text') or '').strip() for n in ns if (n.get('text') or '').strip()]

print()
print('SYSTEM PICKER, WHAT ANDROID REALLY SAYS (per system language)')
for L in 'en es fr de pt ar he hi ja ko zh'.split():
    p = nodes('picker_' + L)
    m = nodes('menu_' + L)
    d = nodes('dialog_' + L)
    pick = [n.get('text') for n in (p or []) if 'button_pick' in (n.get('resource-id') or '')]
    dlg = [(n.get('resource-id') or '').split('/')[-1] + '=' + (n.get('text') or '')
           for n in (d or []) if (n.get('resource-id') or '').split('/')[-1] in ('button1', 'button2', 'alertTitle', 'message')]
    menu = texts(m) if m else None
    print(f'[{L}] use-this-folder button: {pick or "NOT FOUND"}')
    print(f'[{L}] confirm dialog: {dlg or "NOT FOUND"}')
    print(f'[{L}] menu items: {menu if menu is not None else "NOT READ"}')

print()
print('APP ACCESS SCREEN VS THE APP STRINGS (per system language)')
for L in 'en es fr de pt ar he hi ja ko zh'.split():
    arb = json.load(open(os.path.join(arbdir, f'app_{L}.arb'), encoding='utf-8'))
    a = nodes('app_' + L)
    if a is None:
        print(f'[{L}] APP SCREEN NOT READ'); continue
    shown = ' | '.join(texts(a)) + ' | ' + ' | '.join((n.get('content-desc') or '') for n in a)
    missing = [k for k in ('accessTitleFirst', 'accessStep1', 'accessStep2', 'accessStep3')
               if arb[k] not in shown]
    print(f'[{L}]', 'PASS: title and all three steps are the app strings' if not missing else 'FAIL missing: ' + ', '.join(missing))
PY

set_system_locale en-US
adb logcat -d -v time > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  note "CRASH FOUND"
  grep -n -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -40 | tee -a "$OUT/summary.txt"
fi
exit 0
