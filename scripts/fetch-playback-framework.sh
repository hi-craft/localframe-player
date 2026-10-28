#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if test -f Vendor/MobileVLCKit.xcframework/Info.plist; then
  echo 'Using cached MobileVLCKit 3.7.4 framework.'
  exit 0
fi
mkdir -p Vendor build/downloads
archive=build/downloads/MobileVLCKit-3.7.4.tar.xz
curl -fL --retry 2 --retry-delay 3 --connect-timeout 15 --max-time 180 \
  --output "$archive" \
  'https://download.videolan.org/pub/cocoapods/prod/MobileVLCKit-3.0-20260922-1512.tar.xz'
echo "c649c4c47bd065b3a5511746361b5a9066a34033f2df9cbc9454409c0f363b52  $archive" | shasum -a 256 -c -
tar -xf "$archive" --strip-components=1 -C Vendor
test -f Vendor/MobileVLCKit.xcframework/Info.plist
echo 'Verified and extracted official MobileVLCKit 3.7.4.'
