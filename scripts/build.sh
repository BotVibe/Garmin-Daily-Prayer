#!/usr/bin/env bash
#
# Compile the app for one device, a list of devices, or every product in the
# manifest. Intended for local development and CI smoke builds.
#
# Usage:
#   scripts/build.sh                      # build every product in manifest.xml
#   scripts/build.sh fenix7 venu3         # build only the named devices
#   DEVICE=fenix7 scripts/build.sh        # same as passing fenix7
#
# Environment:
#   CIQ_SDK_HOME      Connect IQ SDK root (its bin/ holds monkeyc). Optional when
#                     monkeyc is already on PATH.
#   CIQ_DEVELOPER_KEY Path to the developer key in DER format.
#                     Default: $HOME/.Garmin/ConnectIQ/developer_key.der
#   TYPECHECK         monkeyc -l level (0=off, 1=gradual, 2=informative, 3=strict).
#                     Default: 1
#   RELEASE           Set to 1 to strip debug info (monkeyc -r).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

ciq_require_monkeyc
KEY="$(ciq_require_key)"

OUT_DIR="$ROOT/bin"
mkdir -p "$OUT_DIR"

mapfile -t DEVICES < <(ciq_target_devices "$@")

TYPECHECK="${TYPECHECK:-1}"
EXTRA_ARGS=()
if [ "${RELEASE:-0}" = "1" ]; then
    EXTRA_ARGS+=(-r)
fi

echo "Connect IQ compiler: $(monkeyc --version 2>&1 | head -1)"
echo "Devices to build:    ${#DEVICES[@]}"
echo

failed=()
for device in "${DEVICES[@]}"; do
    printf '%-20s ' "$device"
    log="$OUT_DIR/$device.build.log"
    if monkeyc \
        -f "$ROOT/monkey.jungle" \
        -d "$device" \
        -o "$OUT_DIR/DailyVerse-$device.prg" \
        -y "$KEY" \
        -l "$TYPECHECK" \
        -w \
        "${EXTRA_ARGS[@]}" \
        >"$log" 2>&1
    then
        if grep -q "Invalid device id" "$log"; then
            echo "FAIL (unknown device id - see $log)"
            failed+=("$device")
        else
            echo "ok"
        fi
    else
        echo "FAIL (see $log)"
        sed 's/^/    /' "$log" | grep -E "ERROR|error" | head -10 || true
        failed+=("$device")
    fi
done

echo
if [ ${#failed[@]} -gt 0 ]; then
    echo "FAILED (${#failed[@]}/${#DEVICES[@]}): ${failed[*]}"
    exit 1
fi
echo "BUILD OK for all ${#DEVICES[@]} device(s). Artifacts in bin/"
