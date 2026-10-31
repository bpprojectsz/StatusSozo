#!/bin/sh
# Renders the SVG sources in app/brand/ to PNG, then runs the icon and splash
# generators when the Dart SDK is available. Run from anywhere.
# Usage: sh tool/build_brand_assets.sh [--render-only]
set -eu

cd "$(dirname "$0")/.."

for svg in brand/*.svg; do
  if grep -q '<filter' "$svg"; then
    echo "build_brand_assets: $svg contains <filter>, which renderers drop silently" >&2
    exit 1
  fi
done

render() {
  svg="$1"
  out="$2"
  width="$3"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$width" "$svg" -o "$out"
  elif command -v magick >/dev/null 2>&1; then
    magick -background none -density 384 "$svg" -resize "${width}x" "$out"
  elif command -v convert >/dev/null 2>&1; then
    convert -background none -density 384 "$svg" -resize "${width}x" "$out"
  else
    echo "build_brand_assets: need rsvg-convert or ImageMagick" >&2
    exit 1
  fi
  size=$(wc -c < "$out")
  if [ "$size" -lt 1000 ]; then
    echo "build_brand_assets: $out is only $size bytes, the render failed" >&2
    exit 1
  fi
  echo "  $out ($size bytes)"
}

mkdir -p assets/brand ../store_submission/graphics ../website/images

echo "Rendering"
render brand/icon_master.svg      assets/brand/icon_1024.png       1024
render brand/icon_background.svg  assets/brand/icon_background.png 1024
render brand/icon_foreground.svg  assets/brand/icon_foreground.png 1024
render brand/icon_mono.svg        assets/brand/icon_mono.png       1024
render brand/splash_logo.svg      assets/brand/splash_logo.png     1152
render brand/icon_master.svg      ../store_submission/graphics/play_icon_512.png 512
render brand/feature_graphic.svg  ../store_submission/graphics/feature_graphic_1024x500.png 1024
render brand/icon_master.svg      ../website/images/icon.png       512

if [ "${1:-}" = "--render-only" ] || ! command -v dart >/dev/null 2>&1; then
  echo "Skipping the icon and splash generators (render only, or no Dart SDK here)"
  exit 0
fi

dart run flutter_launcher_icons -f flutter_launcher_icons.yaml
dart run flutter_native_splash:create --path=flutter_native_splash.yaml
echo "Done. Check that AndroidManifest.xml still has no <uses-permission>."
