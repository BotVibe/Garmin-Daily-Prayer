#!/usr/bin/env bash
#
# Produce the signed Connect IQ Store package (.iq) and verify that it contains a
# build for every product declared in manifest.xml.
#
# Usage:
#   scripts/export.sh                 # writes export/DailyVerse.iq
#   scripts/export.sh path/to/out.iq
#
# Environment:
#   CIQ_SDK_HOME      Connect IQ SDK root (its bin/ holds monkeyc). Optional when
#                     monkeyc is already on PATH.
#   CIQ_DEVELOPER_KEY Path to the developer key in DER format. The key used for the
#                     store upload must stay the same for all future updates.
#                     Default: $HOME/.Garmin/ConnectIQ/developer_key.der

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

ciq_require_monkeyc
KEY="$(ciq_require_key)"

OUT="${1:-$ROOT/export/DailyVerse.iq}"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

echo "Connect IQ compiler: $(monkeyc --version 2>&1 | head -1)"
echo "Output:              $OUT"
echo

LOG="$(dirname "$OUT")/export.log"
set +e
monkeyc -e -f "$ROOT/monkey.jungle" -o "$OUT" -y "$KEY" -w -r 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ] || [ ! -f "$OUT" ]; then
    echo "error: monkeyc -e failed (exit $status); see $LOG" >&2
    exit 1
fi

echo
echo "Verifying device coverage..."

# An unresolvable product id is only a warning, but it silently drops the device
# from the package, so treat it as a release blocker.
if grep -q "Invalid device id" "$LOG"; then
    echo "error: manifest.xml lists device ids this SDK cannot resolve:" >&2
    grep "Invalid device id" "$LOG" | sed 's/^/    /' >&2
    echo "hint: install the missing device in the Connect IQ SDK Manager, or drop the product." >&2
    exit 1
fi

# monkeyc reports coverage as "<built> OUT OF <total> DEVICES BUILT" per part number.
coverage="$(grep -oE '[0-9]+ OUT OF [0-9]+ DEVICES BUILT' "$LOG" | tail -1)"
if [ -z "$coverage" ]; then
    echo "error: could not find the device coverage line in $LOG" >&2
    exit 1
fi
built="$(echo "$coverage" | awk '{print $1}')"
total="$(echo "$coverage" | awk '{print $4}')"
if [ "$built" != "$total" ]; then
    echo "error: only $built of $total device targets were built" >&2
    exit 1
fi

echo "  manifest products:  $(ciq_manifest_devices | wc -l | tr -d ' ')"
echo "  device targets:     $built/$total"
echo

echo "EXPORT OK: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Upload this file at https://apps.garmin.com/developer/dashboard"
