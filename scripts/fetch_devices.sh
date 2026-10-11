#!/usr/bin/env bash
#
# Install compiler device definitions for every product in manifest.xml.
#
# The Connect IQ SDK Manager is the normal source and needs a Garmin login.
# This script is the CI path: it copies the same device folders from public
# mirrors pinned to a commit. Nothing here is committed back into the repo.
#
#   scripts/fetch_devices.sh
#   CIQ_DEVICES_DIR=/path scripts/fetch_devices.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${CIQ_DEVICES_DIR:-$HOME/.Garmin/ConnectIQ/Devices}"
mkdir -p "$DEST"

# mgallesio/granbike-face-builder backend/devices — covers the manifest except
# fenix8pro47mm, which is taken from AzzureSkyy/Garmin-Sdk.
GRANBIKE_SHA="4dff743377cde3c09c9204d3c948d8076129b433"
AZZURE_SHA="afdfa3abb4f1628f4cc241f87729560bab0e7a89"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading device definitions (${GRANBIKE_SHA:0:7})..."
curl -fsSL -o "$TMP/devices.tar.gz" \
    "https://github.com/mgallesio/granbike-face-builder/archive/${GRANBIKE_SHA}.tar.gz"
tar -xzf "$TMP/devices.tar.gz" -C "$TMP"
GB="$(echo "$TMP"/granbike-face-builder-*/backend/devices)"
if [ ! -d "$GB" ]; then
    echo "error: device mirror archive has no backend/devices ($GB)" >&2
    exit 1
fi

missing=()
while IFS= read -r device; do
    if [ -d "$GB/$device" ]; then
        rm -rf "$DEST/$device"
        cp -a "$GB/$device" "$DEST/$device"
    else
        missing+=("$device")
    fi
done < <(python3 - "$ROOT/manifest.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
NS = {"iq": "http://www.garmin.com/xml/connectiq"}
root = ET.parse(sys.argv[1]).getroot()
for product in root.findall("iq:application/iq:products/iq:product", NS):
    print(product.attrib["id"])
PY
)

if [ "${#missing[@]}" -gt 0 ]; then
    echo "Fetching ${missing[*]} from Garmin-Sdk (${AZZURE_SHA:0:7})..."
    python3 - "$DEST" "$AZZURE_SHA" "${missing[@]}" <<'PY'
import json, os, sys, urllib.error, urllib.request

dest, sha, *devices = sys.argv[1:]
api = "https://api.github.com/repos/AzzureSkyy/Garmin-Sdk/contents"

def listing(path):
    url = f"{api}/{path}?ref={sha}"
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)

def download(path, target):
    entries = listing(path)
    if isinstance(entries, dict):
        entries = [entries]
    os.makedirs(target, exist_ok=True)
    for entry in entries:
        out = os.path.join(target, entry["name"])
        if entry["type"] == "dir":
            download(entry["path"], out)
        elif entry["type"] == "file":
            with urllib.request.urlopen(entry["download_url"], timeout=60) as response:
                open(out, "wb").write(response.read())

for device in devices:
    folder = f"ConnectIQ/Devices/{device}"
    try:
        download(folder, os.path.join(dest, device))
    except urllib.error.HTTPError as error:
        print(f"error: no device definition for {device} ({error.code})", file=sys.stderr)
        raise SystemExit(1)
    print(f"  {device}")
PY
fi

echo "Device definitions in $DEST:"
find "$DEST" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort
