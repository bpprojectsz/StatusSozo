#!/bin/bash
# Drives the debug build on a running emulator: connects a sample status folder
# through the system picker, scrolls, opens the viewer and Settings, and saves
# screenshots, a frame-timing reading and the crash log to /tmp/emu.
# Run by the emulator workflow. Needs adb and python3.
set +e
PKG=com.zdmgold.statussozo
APK=app/build/app/outputs/flutter-apk/app-debug.apk
OUT=/tmp/emu
STAT=/sdcard/Android/media/com.whatsapp/WhatsApp/Media/.Statuses
mkdir -p "$OUT"
: > "$OUT/summary.txt"
note() { echo "$1" | tee -a "$OUT/summary.txt"; }

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }

dump() {
  for i in 1 2 3; do
    adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 \
      && adb pull /sdcard/ui.xml "$OUT/ui.xml" > /dev/null 2>&1 \
      && [ -s "$OUT/ui.xml" ] && return 0
    sleep 1
  done
  return 1
}

# tap_text REGEX: taps the first node whose text or content description matches.
tap_text() {
  for attempt in 1 2 3 4 5 6; do
    dump
    xy=$(python3 - "$1" "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
pat = re.compile(sys.argv[1], re.I)
try:
    root = ET.parse(sys.argv[2]).getroot()
except Exception:
    sys.exit(0)
for n in root.iter('node'):
    text, desc = n.get('text') or '', n.get('content-desc') or ''
    if (pat.search(text) or pat.search(desc)) and n.get('bounds'):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)
    if [ -n "$xy" ]; then
      adb shell input tap $xy
      note "tapped '$1' at $xy"
      return 0
    fi
    sleep 2
  done
  note "NOT FOUND: $1"
  return 1
}

has_text() {
  dump
  grep -qiE "$1" "$OUT/ui.xml"
}

# A slow software emulator can show "isn't responding" dialogs for system apps,
# which stop uiautomator. Hide them and let the system settle first.
adb wait-for-device
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell settings put global hide_error_dialogs 1
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 2; done
sleep 45
adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS > /dev/null 2>&1
adb shell input keyevent KEYCODE_HOME
sleep 3

note "device: $(adb shell getprop ro.build.version.release) (API $(adb shell getprop ro.build.version.sdk)), $(adb shell wm size | tr -d '\r')"

# Sample statuses in the folder the app expects.
note "media on the runner: $(ls /tmp/media | wc -l) files"
adb shell mkdir -p "$STAT" 2>&1 | tee -a "$OUT/summary.txt"
for f in /tmp/media/*; do adb push "$f" "$STAT/" 2>&1 | tail -1 >> "$OUT/push.txt"; done
head -3 "$OUT/push.txt" | tee -a "$OUT/summary.txt"
adb shell ls -la "$STAT" 2>&1 | head -6 | tee -a "$OUT/summary.txt"
note "files in the status folder: $(adb shell ls "$STAT" 2>/dev/null | wc -l)"

adb install -r "$APK" 2>&1 | tail -1 | tee -a "$OUT/summary.txt"
adb logcat -c
adb shell am start -W -n "$PKG/.MainActivity" > /dev/null
sleep 6
shot 01_launch

tap_text '^Choose folder$'
sleep 4
shot 02_picker

tap_text 'use this folder'
sleep 3
shot 03_after_use_folder
tap_text '^allow$'
sleep 5
shot 04_after_allow

if has_text 'Photos|Videos'; then note "HOME REACHED"; else note "HOME NOT REACHED"; fi
shot 05_home

adb shell dumpsys gfxinfo "$PKG" reset > /dev/null
for i in 1 2 3 4 5 6; do adb shell input swipe 540 1700 540 600 250; sleep 0.4; done
for i in 1 2 3 4 5 6; do adb shell input swipe 540 600 540 1700 250; sleep 0.4; done
adb shell dumpsys gfxinfo "$PKG" | grep -E "Total frames rendered|Janky frames|50th percentile|90th percentile|95th percentile|99th percentile" > "$OUT/perf.txt"
note "frame timing:"; cat "$OUT/perf.txt" | tee -a "$OUT/summary.txt"
shot 06_after_scroll

# Home is covered by an animated ad, which stops uiautomator from reading it,
# so Home is driven by coordinates (1080 x 2340 screen).
adb shell input tap 200 640
sleep 4
shot 07_viewer
# Android shows a one-time "Viewing full screen" tip. Back dismisses it.
adb shell input keyevent KEYCODE_BACK
sleep 15
shot 07b_viewer_with_ad
adb shell input tap 540 1986
sleep 4
shot 07c_after_save
note "saved pictures: $(adb shell ls /sdcard/Pictures/StatusSozo 2>/dev/null | tr '\n' ' ')"
adb shell input keyevent KEYCODE_BACK
sleep 2
shot 07d_after_back
adb shell input keyevent KEYCODE_BACK
sleep 2

adb shell input tap 817 206
sleep 4
shot 08_saved
adb shell input keyevent KEYCODE_BACK
sleep 2

adb shell input tap 970 206
sleep 4
shot 09_settings
for i in 1 2 3; do adb shell input swipe 540 1800 540 700 300; sleep 0.5; done
shot 10_settings_scrolled
for i in 1 2 3; do adb shell input swipe 540 1800 540 700 300; sleep 0.5; done
shot 11_settings_bottom
adb shell input keyevent KEYCODE_BACK
sleep 2

adb shell am force-stop "$PKG"
adb shell am start -W -n "$PKG/.MainActivity" > /dev/null
sleep 6
shot 12_relaunch
if has_text 'Photos|Videos'; then note "RELAUNCH GOES STRAIGHT TO HOME"; else note "RELAUNCH DID NOT REACH HOME"; fi

# Other languages on a real engine: Home in each, and Settings in Arabic (right
# to left, so the chips move to the left edge) and Japanese.
for L in ar he hi ja ko zh de; do
  adb shell cmd locale set-app-locales "$PKG" --locales "$L" > /dev/null 2>&1
  adb shell am force-stop "$PKG"
  adb shell am start -W -n "$PKG/.MainActivity" > /dev/null
  sleep 9
  shot "lang_${L}_home"
  if [ "$L" = "ar" ]; then
    adb shell input tap 110 206; sleep 4
    shot "lang_ar_settings"
    for i in 1 2 3; do adb shell input swipe 540 1800 540 700 300; sleep 0.5; done
    shot "lang_ar_settings_scrolled"
  fi
  if [ "$L" = "ja" ]; then
    adb shell input tap 970 206; sleep 4
    shot "lang_ja_settings"
    for i in 1 2 3; do adb shell input swipe 540 1800 540 700 300; sleep 0.5; done
    shot "lang_ja_settings_scrolled"
  fi
done
adb shell cmd locale set-app-locales "$PKG" --locales "" > /dev/null 2>&1

adb logcat -d -v time > "$OUT/logcat.txt"
if grep -q "FATAL EXCEPTION" "$OUT/logcat.txt"; then
  note "CRASH FOUND"
  grep -n -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -60 | tee -a "$OUT/summary.txt"
  exit 1
fi
grep -iE "flutter.*(error|exception)|E/flutter|AndroidRuntime" "$OUT/logcat.txt" | head -20 > "$OUT/flutter_errors.txt"
note "no crash"
exit 0
