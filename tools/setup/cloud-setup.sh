#!/usr/bin/env bash
# FORGELOOP-01 cloud/Linux toolchain setup. Idempotent: skips tools already at the pinned version.
#   bash tools/setup/cloud-setup.sh            # Roblox CLI tools + pytest
#   bash tools/setup/cloud-setup.sh --blender  # also headless Blender (bpy wheel) + Mesa for Eevee
#   bash tools/setup/cloud-setup.sh --blender-only  # only Blender (FORGE-02; ready in ~1 min)
# Background use (keeps working while it compiles, ~10 min first time):
#   nohup bash tools/setup/cloud-setup.sh > /tmp/forge-setup.log 2>&1 &
#   ...later: tail -3 /tmp/forge-setup.log   (ends with "FORGE SETUP DONE" or "FORGE SETUP FAILED")
# Versions must match rokit.toml and DECISIONS.md D-005.
set -uo pipefail
export PATH="$HOME/.cargo/bin:$PATH"
want_blender=0
want_roblox=1
[[ "${1:-}" == "--blender" ]] && want_blender=1
[[ "${1:-}" == "--blender-only" ]] && { want_blender=1; want_roblox=0; }
fail=0

need() { # name crate version
	local have
	have="$("$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
	if [[ "$have" == "$3" ]]; then
		echo "ok   $1 $have"
	else
		echo "inst $1 $3 (have: ${have:-none})"
		cargo install --locked "$2@$3" || { echo "FAIL $1"; fail=1; }
	fi
}

if [[ $want_roblox == 0 ]]; then
	echo "skip Roblox tools (--blender-only)"
elif ! command -v cargo >/dev/null; then
	echo "cargo not found: install Rust (https://rustup.rs) or use rokit on a desktop machine"
	fail=1
else
	need rojo rojo 7.7.1
	need selene selene 0.31.0
	need stylua stylua 2.6.0
	need lune lune 0.11.0
fi

python3 -c "import pytest" 2>/dev/null || pip install -q pytest || fail=1

if [[ $want_blender == 1 ]]; then
	venv="${FORGE_BPY_VENV:-$HOME/forge-bpy}"
	pyv="$(python3 -c 'import sys;print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
	[[ "$pyv" == "3.13" ]] || echo "warn: bpy 5.2.2 needs Python 3.13 (found $pyv)"
	if ! "$venv/bin/python" -c "import bpy" 2>/dev/null; then
		python3 -m venv "$venv" && "$venv/bin/pip" install -q bpy==5.2.2 || { echo "FAIL bpy"; fail=1; }
	fi
	# Eevee/Workbench need EGL; Cycles CPU works without it.
	if ! ldconfig -p | grep -q libEGL.so.1; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q libegl1 libegl-mesa0 libgl1-mesa-dri libgbm1 >/dev/null 2>&1 \
			|| (apt-get update -q >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y -q libegl1 libegl-mesa0 libgl1-mesa-dri libgbm1 >/dev/null 2>&1) \
			|| echo "warn: could not install EGL (Cycles still works)"
	fi
	"$venv/bin/python" -c "import bpy; print('ok   blender', bpy.app.version_string)" && echo "BLENDER READY" || fail=1
	echo "Blender python: $venv/bin/python"
fi

if [[ $fail == 0 ]]; then echo "FORGE SETUP DONE"; else echo "FORGE SETUP FAILED"; exit 1; fi
