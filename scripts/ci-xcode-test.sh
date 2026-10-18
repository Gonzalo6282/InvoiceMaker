#!/bin/bash
# Usage: ci-xcode-test.sh <family: iPhone|iPad> <preferred simulator name>
# Runs the InvoiceMaker scheme's tests on a simulator, falling back to any
# available device of that family if the preferred one isn't installed.
set -euo pipefail
FAMILY="$1"
PREFERRED="$2"

AVAILABLE=$(xcrun simctl list devices available | grep -E "^\s+${FAMILY}" | sed -E 's/^ +//; s/ \([0-9A-F-]{36}\).*//' | sort -u)
if grep -qxF "$PREFERRED" <<<"$AVAILABLE"; then
  DEVICE="$PREFERRED"
else
  DEVICE=$(head -1 <<<"$AVAILABLE")
  echo "::warning::$PREFERRED not available, using $DEVICE"
fi
echo "Testing on: $DEVICE"

mkdir -p build
xcodebuild test \
  -project InvoiceMaker.xcodeproj \
  -scheme InvoiceMaker \
  -destination "platform=iOS Simulator,name=${DEVICE}" \
  -resultBundlePath "build/${FAMILY}.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  | if command -v xcbeautify >/dev/null; then xcbeautify; else cat; fi
