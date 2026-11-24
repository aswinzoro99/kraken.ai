#!/bin/sh
# Regenerates every app icon from the vector glyph in lib/ui_kit.
# Usage (from app/): sh tool/icons/make_icons.sh
set -e
cd "$(dirname "$0")/../.."
OUT=tool/icons/out
flutter test --update-goldens tool/icons/render_icons_test.dart >/dev/null

# iOS: every size in the asset catalogue. App Store icons must not have an
# alpha channel, so each one is flattened through JPEG (the art is opaque).
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
python3 - "$IOS/Contents.json" <<'PY' | while read -r px name; do
import json, sys
for i in json.load(open(sys.argv[1]))["images"]:
    size = float(i["size"].split("x")[0]); scale = int(i["scale"][0])
    print(round(size * scale), i["filename"])
PY
  sips -s format jpeg -s formatOptions best -z "$px" "$px" "$OUT/ios_1024.png" --out "/tmp/kraken_icon.jpg" >/dev/null
  sips -s format png "/tmp/kraken_icon.jpg" --out "$IOS/$name" >/dev/null
done
rm -f /tmp/kraken_icon.jpg

# Android: legacy icon (pre-8.0) and adaptive foreground (8.0+).
RES=android/app/src/main/res
for pair in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  d=${pair%%:*}; rest=${pair#*:}; legacy=${rest%%:*}; fg=${rest#*:}
  sips -z "$legacy" "$legacy" "$OUT/android_legacy_1024.png" --out "$RES/mipmap-$d/ic_launcher.png" >/dev/null
  sips -z "$fg" "$fg" "$OUT/android_foreground_1024.png" --out "$RES/mipmap-$d/ic_launcher_foreground.png" >/dev/null
done
echo "Icons updated."
