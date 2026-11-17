#!/bin/bash
# A6 and A4 on a real engine.
#  1. Reads Android's own folder-picker translations out of the picker app's
#     resource file (every language at once, nothing to switch) and checks each
#     of the app's Access-screen steps against them automatically (A6).
#  2. Records the picker, its menu and its confirmation in English.
#  3. Scrolls the system "App languages" screen for the app and lists every
#     language it offers (A4).
# Run by the emulator workflow. Needs adb, python3 and the SDK's aapt2.
set +e
PKG=com.zdmgold.statussozo
APK=app/build/app/outputs/flutter-apk/app-debug.apk
OUT=/tmp/emu/picker
STAT=/sdcard/Android/media/com.whatsapp/WhatsApp/Media/.Statuses
INIT='content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses'
A="timeout 40 adb"
mkdir -p "$OUT"
: > "$OUT/summary.txt"
note() { echo "$1" | tee -a "$OUT/summary.txt"; }
shot() { timeout 40 adb exec-out screencap -p > "$OUT/$1.png"; }

dump_to() {
  for i in 1 2 3 4; do
    $A shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 \
      && $A pull /sdcard/ui.xml "$OUT/$1.xml" > /dev/null 2>&1 \
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
  if [ -n "$xy" ]; then $A shell input tap $xy; return 0; fi
  return 1
}

tap_overflow() {
  xy=$(python3 - "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception:
    sys.exit(0)
for n in root.iter('node'):
    if (n.get('content-desc') or '') and n.get('bounds') and 'More options' in n.get('content-desc'):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)
  if [ -n "$xy" ]; then $A shell input tap $xy; return 0; fi
  return 1
}

$A wait-for-device
until [ "$($A shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
$A shell settings put global hide_error_dialogs 1
note "device: $($A shell getprop ro.build.version.release | tr -d '\r') (API $($A shell getprop ro.build.version.sdk | tr -d '\r'))"

# ---- 1. Android's own picker translations, straight from its resource file.
PICKER_PKG=$($A shell cmd package resolve-activity --brief -a android.intent.action.OPEN_DOCUMENT_TREE | tail -1 | cut -d/ -f1 | tr -d '\r')
note "picker package: $PICKER_PKG"
PICKER_APK=$($A shell pm path "$PICKER_PKG" | head -1 | sed 's/^package://' | tr -d '\r')
note "picker apk: $PICKER_APK"
$A pull "$PICKER_APK" "$OUT/picker_app.apk" > /dev/null 2>&1
AAPT2=$(ls "${ANDROID_HOME:-/usr/local/lib/android/sdk}"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)
note "aapt2: $AAPT2"
if [ -n "$AAPT2" ] && [ -s "$OUT/picker_app.apk" ]; then
  "$AAPT2" dump resources "$OUT/picker_app.apk" > "$OUT/picker_resources_full.txt" 2>&1
  grep -ciE "use this folder|hidden files" "$OUT/picker_resources_full.txt" | sed 's/^/matching lines: /' | tee -a "$OUT/summary.txt"
  # Keep the file small enough to publish: strings only.
  python3 - "$OUT/picker_resources_full.txt" "$OUT/picker_strings.json" <<'PY'
import json, re, sys
res, cur = {}, None
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.match(r'\s+resource 0x[0-9a-f]+ string/(\S+)', line)
    if m:
        cur = m.group(1); res[cur] = {}; continue
    if re.match(r'\s+resource ', line):
        cur = None; continue
    m = re.match(r'\s+\(([^)]*)\)\s+(?:\(string\d*\)\s+)?"(.*)"\s*$', line)
    if m and cur is not None:
        res[cur][m.group(1)] = m.group(2).replace('\\"', '"').replace("\\'", "'")
json.dump(res, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False)
print('picker string resources parsed:', len(res))
PY
  rm -f "$OUT/picker_resources_full.txt"
fi

python3 - "$OUT" app/lib/l10n <<'PY' | tee -a "$OUT/summary.txt"
import json, os, sys
out, arbdir = sys.argv[1], sys.argv[2]
try:
    res = json.load(open(os.path.join(out, 'picker_strings.json'), encoding='utf-8'))
except Exception:
    print('PICKER TRANSLATIONS: could not be read'); sys.exit(0)

def names_for(pred):
    return [n for n, v in res.items() if pred((v.get('') or '').strip())]

# What Android calls each thing the app tells people to tap.
targets = {
    'use this folder': names_for(lambda t: t.lower() == 'use this folder'),
    'show hidden files': names_for(lambda t: t.lower() == 'show hidden files'),
    'allow': names_for(lambda t: t.lower() == 'allow'),
}
print('PICKER RESOURCES FOUND:', {k: v for k, v in targets.items()})

def configs(L):
    keys = {L}
    if L == 'he': keys.add('iw')
    return keys

def variants(phrase, L):
    out = set()
    for n in targets[phrase]:
        for cfg, val in res[n].items():
            base = cfg.split('-')[0]
            if base in configs(L) and val:
                out.add(val)
    return out

checks = [('accessStep3', 'use this folder'), ('accessStep2', 'show hidden files'), ('accessStep3', 'allow')]
print()
print('APP STEPS VS ANDROID PICKER WORDS (per language)')
for L in 'en es fr de pt ar he hi ja ko zh'.split():
    arb = json.load(open(os.path.join(arbdir, f'app_{L}.arb'), encoding='utf-8'))
    choose = arb['accessChooseFolder']
    step1_ok = choose.lower() in arb['accessStep1'].lower()
    print(f'[{L}] step 1 names our own button "{choose}":', 'PASS' if step1_ok else 'FAIL')
    for key, phrase in checks:
        vs = variants(phrase, L) if L != 'en' else {phrase if phrase != 'allow' else 'Allow'}
        if L == 'en':
            vs = {v for n in targets[phrase] for v in [res[n].get('', '')] if v}
        text = arb[key].lower()
        hit = [v for v in vs if v.lower().strip(' …').rstrip('.') in text]
        status = 'PASS' if hit else ('NO ANDROID TEXT FOUND' if not vs else 'FAIL')
        print(f'[{L}] {key} contains Android\'s "{phrase}":', status,
              '| Android says:', sorted(vs), '| app says:', arb[key])
PY

# ---- 2. English picker, menu and confirmation on the real picker.
$A shell pm clear "$PKG" > /dev/null 2>&1
if [ -z "$($A shell ls "$STAT" 2>/dev/null)" ]; then
  $A shell mkdir -p "$STAT"
  for f in /tmp/media/*; do $A push "$f" "$STAT/" > /dev/null 2>&1; done
fi
$A shell am force-stop "$PICKER_PKG"
$A shell am start -a android.intent.action.OPEN_DOCUMENT_TREE --eu android.provider.extra.INITIAL_URI "$INIT" > /dev/null 2>&1
sleep 8
shot picker_en
dump_to picker_en
tap_overflow "$OUT/picker_en.xml"
sleep 2
shot menu_en
dump_to menu_en
$A shell input keyevent KEYCODE_BACK
sleep 1
tap_id "button1" "$OUT/picker_en.xml"
sleep 3
shot dialog_en
dump_to dialog_en
$A shell input keyevent KEYCODE_BACK
$A shell am force-stop "$PICKER_PKG"

# ---- 3. The "App languages" screen, scrolled to the end.
$A install -r "$APK" 2>&1 | tail -1 | tee -a "$OUT/summary.txt"
$A shell am start -a android.settings.APP_LOCALE_SETTINGS -d "package:$PKG" > /dev/null 2>&1
sleep 6
shot applang_0
for i in 0 1 2 3 4 5; do
  dump_to "applang_$i"
  $A shell input swipe 540 1900 540 600 300
  sleep 1.5
done
shot applang_end
python3 - "$OUT" <<'PY' | tee -a "$OUT/summary.txt"
import glob, os, sys, xml.etree.ElementTree as ET
want = ['English', 'Spanish', 'French', 'German', 'Portuguese', 'Arabic',
        'Hindi', 'Japanese', 'Korean', 'Chinese', 'Hebrew']
seen = set()
for f in sorted(glob.glob(os.path.join(sys.argv[1], 'applang_*.xml'))):
    try:
        for n in ET.parse(f).getroot().iter('node'):
            if (n.get('resource-id') or '').endswith('/locale'):
                seen.add((n.get('content-desc') or n.get('text') or '').strip())
    except Exception:
        pass
print('APP LANGUAGES SCREEN offers:', sorted(seen))
hit = [w for w in want if any(w in s for s in seen)]
print('APP LANGUAGES SCREEN has all 11 app languages:', 'PASS' if len(hit) == len(want) else 'FAIL, missing ' + ', '.join(w for w in want if w not in hit))
PY
$A shell input keyevent KEYCODE_BACK

# The system-language switch (adb root plus a zygote restart) drops the adb
# connection on these images, so it is not attempted. System-language
# resolution is covered by the widget tests (language_system_test.dart).
$A logcat -d -v time > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  note "CRASH FOUND"
  grep -n -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -40 | tee -a "$OUT/summary.txt"
fi
exit 0
