#!/bin/sh
# StatusSozo mechanical gate: forbidden patterns, RTL safety and layering.
# POSIX sh + grep + find only (works in Termux and CI). Run from app/.
# Comment-only lines are ignored. lib/spike/ and lib/l10n/gen/ are skipped.
set -u

if [ ! -d lib ]; then echo "check_forbidden: run from app/ (no lib/ here)"; exit 2; fi

TMP=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/sz_check.$$")
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT INT TERM
: > "$TMP/hits"

find lib -type f -name '*.dart' ! -path 'lib/spike/*' ! -path 'lib/l10n/gen/*' | sort > "$TMP/all"
grep -v '^lib/design/' "$TMP/all" > "$TMP/nondesign"
grep -v '^lib/screens/error_fallback_screen\.dart$' "$TMP/all" > "$TMP/nofallback"
grep -v '^lib/widgets/icons/' "$TMP/all" > "$TMP/noicons"

# B = "start of line or a non-identifier character": makes Card( not match AppCard(
B='(^|[^A-Za-z0-9_])'

# scan LISTFILE REGEX LABEL [LINE_EXCLUDE_REGEX] [keep-comments]
scan() {
  list=$1; pat=$2; label=$3; excl=${4:-}; keepc=${5:-}
  [ -s "$list" ] || return 0
  out=$(xargs grep -nHE -- "$pat" < "$list" 2>/dev/null)
  if [ -z "$keepc" ] && [ -n "$out" ]; then
    out=$(printf '%s\n' "$out" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
  fi
  if [ -n "$excl" ] && [ -n "$out" ]; then
    out=$(printf '%s\n' "$out" | grep -vE -- "$excl")
  fi
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r l; do echo "FAIL [$label] $l"; done
    printf '%s\n' "$out" >> "$TMP/hits"
  fi
  return 0
}

# layer DIR ALLOW_REGEX LABEL : every import/export under lib/DIR must match ALLOW
layer() {
  dir=$1; allow=$2; label=$3
  grep "^lib/$dir/" "$TMP/all" > "$TMP/layer" || true
  [ -s "$TMP/layer" ] || return 0
  out=$(xargs grep -nHE '^[[:space:]]*(import|export)[[:space:]]' < "$TMP/layer" | grep -vE -- "$allow")
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r l; do echo "FAIL [layer:$label] $l"; done
    printf '%s\n' "$out" >> "$TMP/hits"
  fi
  return 0
}

# layer_deny DIR DENY_REGEX LABEL : no import/export under lib/DIR may match DENY
layer_deny() {
  dir=$1; deny=$2; label=$3
  grep "^lib/$dir/" "$TMP/all" > "$TMP/layer" || true
  [ -s "$TMP/layer" ] || return 0
  out=$(xargs grep -nHE '^[[:space:]]*(import|export)[[:space:]]' < "$TMP/layer" | grep -E -- "$deny")
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r l; do echo "FAIL [layer:$label] $l"; done
    printf '%s\n' "$out" >> "$TMP/hits"
  fi
  return 0
}

# ---- Forbidden list -------------------------------------------------------
scan "$TMP/all" "${B}Icons\\." "icons-material"
scan "$TMP/all" "CupertinoIcons" "icons-cupertino"
if [ -s "$TMP/all" ]; then
  out=$(xargs grep -nHE -- "${B}Colors\\." < "$TMP/all" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' | sed 's/Colors\.transparent//g' | grep -E "${B}Colors\\.")
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r l; do echo "FAIL [colors-material] $l"; done
    printf '%s\n' "$out" >> "$TMP/hits"
  fi
fi
scan "$TMP/nondesign" "Color\\(0x|Color\\.from(ARGB|RGBO)|${B}Color\\([0-9]" "colour-literal"
scan "$TMP/all" "${B}(Card|AppBar|Switch|IconButton|CircularProgressIndicator|RefreshIndicator)\\(" "forbidden-widget"
scan "$TMP/all" "${B}(ListTile|ElevatedButton|TextButton|OutlinedButton|SnackBar|InkWell)" "forbidden-widget"
scan "$TMP/all" "[Rr]ipple" "ripple"
scan "$TMP/nofallback" "${B}Text\\(\\s*['\"]" "hardcoded-string"
scan "$TMP/nondesign" "${B}TextStyle\\(|fontSize:" "text-style-outside-design"
scan "$TMP/nondesign" "Duration\\(milliseconds" "duration-outside-design"
scan "$TMP/nondesign" "BorderRadius\\.circular\\([0-9]|EdgeInsets\\.all\\([0-9]" "raw-size-outside-design"
scan "$TMP/all" "TODO|FIXME|UnimplementedError" "todo" "" keep-comments
scan "$TMP/all" "setState\\(" "set-state" "ui-local"

# ---- RTL safety ---------------------------------------------------------------
scan "$TMP/all" "TextAlign\\.(left|right)([^A-Za-z]|$)" "rtl"
scan "$TMP/all" "EdgeInsets\\.only\\(.*(left|right):" "rtl"
scan "$TMP/all" "${B}Alignment\\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)" "rtl"
scan "$TMP/all" "${B}Positioned\\(.*(left|right):" "rtl"

# ---- Icon source: hugeicons only inside lib/widgets/icons/ --------------------
scan "$TMP/noicons" "hugeicons|HugeIcon" "icon-source"

# ---- Layering (architecture section 1.2) ---------------------------------------
layer core "['\"](dart:|package:statussozo/(core|utils)/|package:flutter/(foundation|widgets)\\.dart)" "core"
layer_deny core "['\"]dart:io['\"]" "core-no-dart-io"
layer utils "['\"](dart:|package:intl/|package:flutter/foundation\\.dart|package:statussozo/utils/)" "utils"
layer design "['\"](dart:|package:flutter/|package:statussozo/design/)" "design"
layer_deny platform "package:statussozo/(widgets|screens|app|design|l10n)/" "platform"
layer widgets "['\"](dart:|package:flutter/|package:statussozo/(core|design|utils|l10n/gen|widgets)/|package:(hugeicons|flutter_svg)/)" "widgets"
layer screens "['\"](dart:|package:flutter/|package:statussozo/(core|design|utils|l10n/gen|widgets|screens)/|package:statussozo/app/app_scope\\.dart)" "screens"

# ---- SVG renderers silently drop filters --------------------------------------
find brand ../website -type f -name '*.svg' 2>/dev/null > "$TMP/svg"
scan "$TMP/svg" "<filter" "svg-filter"

# ---- Summary --------------------------------------------------------------------
n=$(wc -l < "$TMP/hits" | tr -d ' ')
files=$(wc -l < "$TMP/all" | tr -d ' ')
if [ "$n" -gt 0 ]; then
  echo "check_forbidden: $n violation(s) in $files dart file(s)"
  exit 1
fi
echo "check_forbidden: clean ($files dart file(s) scanned)"
exit 0
