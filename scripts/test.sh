#!/usr/bin/env bash
#
# Offline checks: unit tests plus the generated settings file.
# ROOT is the repository root, independent of the caller's working directory.
#
# Usage:
#   scripts/test.sh            # pytest -m "not network", settings.xml check
#   NETWORK=1 scripts/test.sh  # also call DailyVerses.net once

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 -m pip install -q -r "$ROOT/requirements-dev.txt"
python3 -m pytest -m "not network"
python3 "$ROOT/tools/gen_settings.py" --check

if [ "${NETWORK:-0}" = "1" ]; then
    python3 -m pytest -m network
fi
