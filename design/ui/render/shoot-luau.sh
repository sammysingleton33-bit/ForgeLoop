#!/usr/bin/env bash
# Snapshot + screenshot Luau UI scenes at phone, tablet and desktop (FORGE-03 headless renderer).
#
#   bash design/ui/render/shoot-luau.sh                         # every scenes/*.luau except selftest
#   bash design/ui/render/shoot-luau.sh selftest                # the renderer self-test
#   bash design/ui/render/shoot-luau.sh scenes/hud.luau build   # paths or bare scene names
#   DEVICES="phone" bash design/ui/render/shoot-luau.sh hud     # only some devices
#   RENDER_FLAGS="--guides --dpr=2" bash design/ui/render/shoot-luau.sh hud
#
# Writes design/ui/render/out/<scene>-<device>.json (+ .html, .layout.json) and
# design/ui/screenshots/luau/<scene>-<device>.png. Exit code 1 if any snapshot or render failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
export PATH="$HOME/.cargo/bin:$PATH"
command -v lune >/dev/null || { echo "shoot-luau: lune not found (bash tools/setup/cloud-setup.sh)" >&2; exit 1; }

DEVICES="${DEVICES:-phone tablet desktop}"
read -r -a FLAGS <<< "${RENDER_FLAGS:-}"

scenes=()
if [ "$#" -eq 0 ]; then
	for f in "$HERE"/scenes/*.luau; do
		[ -e "$f" ] || continue
		[ "$(basename "$f")" = "selftest.luau" ] && continue
		scenes+=("$f")
	done
	if [ "${#scenes[@]}" -eq 0 ]; then
		echo "shoot-luau: no scenes in $HERE/scenes besides selftest (run: bash $0 selftest)" >&2
		exit 1
	fi
else
	for s in "$@"; do
		if [ -f "$s" ]; then scenes+=("$(cd "$(dirname "$s")" && pwd)/$(basename "$s")")
		elif [ -f "$HERE/$s" ]; then scenes+=("$HERE/$s")
		elif [ -f "$HERE/scenes/$s.luau" ]; then scenes+=("$HERE/scenes/$s.luau")
		else echo "shoot-luau: no scene '$s'" >&2; exit 1
		fi
	done
fi

status=0
jsons=()
for scene in "${scenes[@]}"; do
	name="$(basename "$scene" .luau)"
	for device in $DEVICES; do
		out="$HERE/out/$name-$device.json"
		rm -f "$out"
		(cd "$ROOT" && lune run design/ui/render/snapshot.luau "$scene" "$device" "$out") || status=1
		[ -f "$out" ] && jsons+=("$out")
	done
done
if [ "${#jsons[@]}" -gt 0 ]; then
	(cd "$ROOT" && node design/ui/render/render.js "${jsons[@]}" "${FLAGS[@]}") || status=1
fi
exit $status
