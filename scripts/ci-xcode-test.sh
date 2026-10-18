#!/bin/bash
# Usage: ci-xcode-test.sh <family: iPhone|iPad> <preferred simulator name>
# Runs the InvoiceMaker scheme's tests on a simulator that the selected Xcode
# supports, preferring the named one. Errors are echoed as GitHub annotations
# so they can be read through the API without downloading the full log.
set -uo pipefail
FAMILY="$1"
PREFERRED="$2"
mkdir -p build

# -showdestinations sometimes comes back empty while CoreSimulator starts; retry.
for attempt in 1 2 3 4; do
  DESTS=$(xcodebuild -showdestinations -project InvoiceMaker.xcodeproj -scheme InvoiceMaker 2>/dev/null \
    | grep "platform:iOS Simulator" | grep "name:${FAMILY}" || true)
  [ -n "$DESTS" ] && break
  echo "No ${FAMILY} destinations yet (attempt $attempt), retrying"
  xcrun simctl list devices >/dev/null 2>&1 || true
  sleep 15
done
echo "::notice title=${FAMILY} simulators::$(sed -E 's/.*OS:([^,]+), name:([^ }]+( [^,}]+)*).*/\2 (\1)/' <<<"$DESTS" | sort -u | tr '\n' ';')"

LINE=$(grep "name:${PREFERRED} }" <<<"$DESTS" | tail -1)
if [ -z "$LINE" ]; then
  LINE=$(tail -1 <<<"$DESTS")
  echo "::warning::${PREFERRED} not available for this Xcode, using: ${LINE}"
fi
ID=$(sed -E 's/.*id:([^,]+),.*/\1/' <<<"$LINE")
if [ -z "$ID" ]; then
  echo "::error::No ${FAMILY} simulator available for this Xcode"
  xcrun simctl list devices available | head -30
  exit 1
fi
echo "Testing on: $LINE"

xcodebuild test \
  -project InvoiceMaker.xcodeproj \
  -scheme InvoiceMaker \
  -destination "id=${ID}" \
  -resultBundlePath "build/${FAMILY}.xcresult" \
  CODE_SIGNING_ALLOWED=NO > "build/${FAMILY}.log" 2>&1
# (TEST_RUNNER_SNAPSHOT_DIR, if set, reaches the tests as SNAPSHOT_DIR.)
STATUS=$?

if command -v xcbeautify >/dev/null; then xcbeautify < "build/${FAMILY}.log"; else cat "build/${FAMILY}.log"; fi

if [ $STATUS -ne 0 ]; then
  # Most useful first: compiler errors and test issue details (file:line + message).
  grep -E "error:|Caught error|Expectation failed|recorded an issue|Issue recorded|XCTAssert|failed -|Fatal error|fatal error|crashed|signal|Incorrect actor|precondition|Thread [0-9]+ Crashed" "build/${FAMILY}.log" \
    | grep -v -E "^\s*$|Test case '.*' failed on" | awk '!seen[$0]++' | head -9 \
    | while IFS= read -r l; do echo "::error title=${FAMILY}::${l:0:900}"; done
  tail -4 "build/${FAMILY}.log" | while IFS= read -r l; do echo "::notice title=${FAMILY} tail::${l}"; done
fi
exit $STATUS
