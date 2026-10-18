#!/usr/bin/env bash
# FORGE-02 asset gate. Exit 0 = PASS, 1 = FAIL. Prints SKIP (exit 0) when bpy is unavailable.
#   bash blender/scripts/check.sh
# Steps: committed image sizes -> manifest schema/cross-checks -> pytest -> rebuild every committed
# generator from its recorded seed/variant count and compare geometry hashes + validation (build.py --verify).
# Python with bpy: $FORGE_BPY_PYTHON, else $FORGE_BPY_VENV/bin/python, else ~/forge-bpy/bin/python.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1   # blender/
fail=0
step() { printf '\n== %s\n' "$*"; }

PY="${FORGE_BPY_PYTHON:-${FORGE_BPY_VENV:-$HOME/forge-bpy}/bin/python}"
if [[ ! -x "$PY" ]] || ! "$PY" -c "import bpy" >/dev/null 2>&1; then
	echo "SKIP: no Python with bpy at $PY (set FORGE_BPY_PYTHON or run tools/setup/cloud-setup.sh --blender-only)"
	echo "blender check: SKIP (not PASS)"
	exit 0
fi

step "committed images <= 250 KB"
big=$(find previews reviews -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -size +250000c 2>/dev/null)
if [[ -n "$big" ]]; then echo "FAIL: images over 250 KB:"; echo "$big"; fail=1; else echo "ok"; fi

step "manifest schema + cross-checks"
if "$PY" -c "
import sys; sys.path.insert(0, '.')
from lib import manifest
errs = manifest.check()
warns = manifest.warnings()
print('\n'.join(errs) if errs else 'ok')
if warns:
    print(f'WARN: {len(warns)} preview path(s) named in the manifest are not committed (not a failure; first: {warns[0]})')
sys.exit(1 if errs else 0)"; then :; else fail=1; fi

step "pytest"
pt=$("$PY" -m pytest -q -p no:warnings tests 2>&1); rc=$?
echo "$pt" | tail -3
[[ $rc == 0 ]] || fail=1

step "rebuild + verify every committed generator (no render)"
out=$("$PY" build.py --verify --out "${TMPDIR:-/tmp}/forge-check-exports" 2>&1)
echo "$out" | grep -E "verify|VERIFY|MISMATCH|FAIL|Error|Traceback" | grep -vE "^\s*$"
echo "$out" | grep -q "^VERIFY PASS" || fail=1

echo
if [[ $fail == 0 ]]; then echo "blender check: PASS"; else echo "blender check: FAIL"; fi
exit $fail
