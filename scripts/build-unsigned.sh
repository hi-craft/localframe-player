#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ipa/Payload
xcodebuild -workspace LocalFrame.xcworkspace -scheme LocalFrame -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  build 2>&1 | tee build/device-build.log
app='build/device/Build/Products/Release-iphoneos/LocalFrame.app'
test -d "$app"
ditto "$app" build/ipa/Payload/LocalFrame.app
(
  cd build/ipa
  zip -qry ../LocalFrame-unsigned.ipa Payload
)
echo 'Created build/LocalFrame-unsigned.ipa (must be signed before device installation).'
