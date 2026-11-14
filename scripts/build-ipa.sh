#!/bin/bash
# Build an unsigned iDesk.ipa (Release, device) for signing with ESign, Feather, Scarlet, …
# Usage: scripts/build-ipa.sh            → build/iDesk.ipa
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null && xcodegen -q
xcodebuild -project iDesk.xcodeproj -scheme iDesk -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" || true
APP=build/DerivedData/Build/Products/Release-iphoneos/iDesk.app
[ -d "$APP" ] || { echo "Build failed"; exit 1; }
rm -rf build/ipa && mkdir -p build/ipa/Payload && cp -R "$APP" build/ipa/Payload/
(cd build/ipa && rm -f ../iDesk.ipa && zip -qry ../iDesk.ipa Payload)
rm -rf build/ipa
echo "→ build/iDesk.ipa"
