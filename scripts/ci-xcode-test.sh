#!/bin/bash
# Usage: ci-xcode-test.sh <family: iPhone|iPad> <preferred simulator name>
# Runs the InvoiceMaker scheme's tests on a simulator that the selected Xcode
# supports, preferring the named one. Errors are echoed as GitHub annotations
# so they can be read through the API without downloading the full log.
set -uo pipefail
FAMILY="$1"
PREFERRED="$2"
mkdir -p build

DESTS=$(xcodebuild -showdestinations -project InvoiceMaker.xcodeproj -scheme InvoiceMaker 2>/dev/null \
  | grep "platform:iOS Simulator" | grep "name:${FAMILY}" || true)
echo "::notice title=${FAMILY} simulators::$(sed -E 's/.*OS:([^,]+), name:([^ }]+( [^,}]+)*).*/\2 (\1)/' <<<"$DESTS" | sort -u | tr '\n' ';')"

LINE=$(grep "name:${PREFERRED} }" <<<"$DESTS" | tail -1)
if [ -z "$LINE" ]; then
  LINE=$(tail -1 <<<"$DESTS")
  echo "::warning::${PREFERRED} not available for this Xcode, using: ${LINE}"
fi
ID=$(sed -E 's/.*id:([^,]+),.*/\1/' <<<"$LINE")
if [ -z "$ID" ]; then
  echo "::error::No ${FAMILY} simulator available for this Xcode"
  xcrun simctl list runtimes | while read -r l; do echo "::notice title=runtime::$l"; done
  exit 1
fi
echo "Testing on: $LINE"

xcodebuild test \
  -project InvoiceMaker.xcodeproj \
  -scheme InvoiceMaker \
  -destination "id=${ID}" \
  -resultBundlePath "build/${FAMILY}.xcresult" \
  CODE_SIGNING_ALLOWED=NO > "build/${FAMILY}.log" 2>&1
STATUS=$?

if command -v xcbeautify >/dev/null; then xcbeautify < "build/${FAMILY}.log"; else cat "build/${FAMILY}.log"; fi

if [ $STATUS -ne 0 ]; then
  grep -E "error:|\*\* .* FAILED \*\*|failed|Test Case .* failed|✘|xcodebuild: error" "build/${FAMILY}.log" \
    | grep -v "^\s*$" | sort -u | head -9 \
    | while IFS= read -r l; do echo "::error title=${FAMILY}::${l}"; done
  tail -8 "build/${FAMILY}.log" | while IFS= read -r l; do echo "::notice title=${FAMILY} tail::${l}"; done
fi
exit $STATUS
