#!/usr/bin/env bash
#
# Shared helpers for scripts/build.sh, scripts/export.sh and scripts/test.sh.
# shellcheck shell=bash

ciq_require_monkeyc() {
    if [ -n "${CIQ_SDK_HOME:-}" ]; then
        PATH="$CIQ_SDK_HOME/bin:$PATH"
        export PATH
    fi
    if ! command -v monkeyc >/dev/null 2>&1; then
        cat >&2 <<'EOF'
error: monkeyc not found.

Install the Connect IQ SDK (https://developer.garmin.com/connect-iq/sdk/) and
either add its bin/ directory to PATH or point CIQ_SDK_HOME at the SDK root:

    CIQ_SDK_HOME=~/connectiq-sdk scripts/build.sh

Device definitions are downloaded separately with the Connect IQ SDK Manager
and land in ~/.Garmin/ConnectIQ/Devices.
EOF
        return 1
    fi
}

ciq_require_key() {
    local key="${CIQ_DEVELOPER_KEY:-$HOME/.Garmin/ConnectIQ/developer_key.der}"
    if [ ! -f "$key" ]; then
        cat >&2 <<EOF
error: developer key not found at $key

Generate one (never commit it) and point CIQ_DEVELOPER_KEY at the DER file:

    openssl genrsa -out developer_key.pem 4096
    openssl pkcs8 -topk8 -inform PEM -outform DER \\
        -in developer_key.pem -out developer_key.der -nocrypt
EOF
        return 1
    fi
    printf '%s\n' "$key"
}

#! Products declared in manifest.xml, in document order.
ciq_manifest_devices() {
    python3 - "$ROOT/manifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
NS = {"iq": "http://www.garmin.com/xml/connectiq"}
root = ET.parse(sys.argv[1]).getroot()
for product in root.findall("iq:application/iq:products/iq:product", NS):
    print(product.attrib["id"])
PY
}

#! Devices named on the command line, else $DEVICE, else every manifest product.
ciq_target_devices() {
    if [ "$#" -gt 0 ]; then
        printf '%s\n' "$@"
    elif [ -n "${DEVICE:-}" ]; then
        printf '%s\n' "$DEVICE"
    else
        ciq_manifest_devices
    fi
}
