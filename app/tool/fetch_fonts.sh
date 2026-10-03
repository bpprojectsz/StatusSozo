#!/bin/sh
# Downloads the two bundled variable fonts and their SIL OFL licences into
# assets/fonts/. Run from app/. Fonts are already committed; use this only to
# refresh them.
set -eu
DEST="assets/fonts"
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"
mkdir -p "$DEST"

fetch() {
  url=$1; out=$2; min=$3
  curl -fL --retry 3 -s -o "$DEST/$out" "$url" || { echo "FAIL: download $url"; exit 1; }
  size=$(wc -c < "$DEST/$out" | tr -d ' ')
  if [ "$size" -lt "$min" ]; then
    echo "FAIL: $out is $size bytes (expected more than $min)"; exit 1
  fi
  echo "ok  $out  $size bytes"
}

fetch "$BASE/inter/Inter%5Bopsz%2Cwght%5D.ttf" "Inter-Variable.ttf" 100000
fetch "$BASE/manrope/Manrope%5Bwght%5D.ttf" "Manrope-Variable.ttf" 100000
fetch "$BASE/inter/OFL.txt" "OFL-Inter.txt" 1000
fetch "$BASE/manrope/OFL.txt" "OFL-Manrope.txt" 1000
echo "fonts ready"
