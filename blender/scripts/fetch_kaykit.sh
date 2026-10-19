#!/usr/bin/env bash
# Fetch the KayKit (CC0, Kay Lousberg) packs used by the FL-0135 style comparison into a GITIGNORED cache (blender/exports/.cache).
# Pinned by commit; the sha256 of every file the comparison reads is checked. NOTHING from these packs is committed (D-057 (13)).
#   bash blender/scripts/fetch_kaykit.sh            -> prints the two pack roots to pass as --kaykit / --building
# Sources: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (LICENSE.txt: Creative Commons Zero, CC0)
#          https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0     (same author, same licence)
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
cache="${FORGE_KAYKIT_CACHE:-$here/exports/.cache/kaykit}"
mkdir -p "$cache"

fetch() { # name url sha
	local dir="$cache/$1"
	if [[ ! -d "$dir/.git" ]]; then
		git init -q "$dir"
		git -C "$dir" remote add origin "$2"
	fi
	if [[ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" != "$3" ]]; then
		git -C "$dir" fetch -q --depth 1 origin "$3"
		git -C "$dir" checkout -q FETCH_HEAD
	fi
	[[ "$(git -C "$dir" rev-parse HEAD)" == "$3" ]] || { echo "FAIL: $1 is not at $3"; exit 1; }
}
verify() { # dir "sha  relpath" ...
	local dir="$1"; shift
	for line in "$@"; do
		local want="${line%% *}" rel="${line##* }"
		local got; got="$(sha256sum "$dir/$rel" | cut -d' ' -f1)"
		[[ "$got" == "$want" ]] || { echo "FAIL: sha256 of $rel is $got, expected $want"; exit 1; }
	done
}

CH=addons/kaykit_character_pack_adventures/Characters/gltf
fetch adventurers https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0.git 672074b73ba276876a19e8816ecdc5241817ab47
verify "$cache/adventurers" \
	"ae322141814056dda0deea7540d74c41d87aee1da319977cd1bd84ee5a923629  LICENSE.txt" \
	"60428e3abc09ba83e595d256e3af8c5c976b46cdae599f0802fc82b4a3445168  $CH/Knight.glb" \
	"e825437cd4d2ee9c1960b517a74a69101e33eb409ae7fa8cedc7134a998fbb7d  $CH/Rogue.glb" \
	"5d250ccc5da020e6126bfa3839f83bd9a465a951ed223e4d13c08b1925e154d4  $CH/knight_texture.png" \
	"a4032e877c3b91939f5cdbb630349c1998fdbc3211bbd587c111125500fe4cc5  $CH/rogue_texture.png"

BD=addons/kaykit_medieval_hexagon_pack/Assets/gltf/buildings/red
fetch hexagon https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0.git 84fa4e91af6a88989be7c99e0891cede11f2ca38
verify "$cache/hexagon" \
	"881e50d3629fba90629bedc65e9e6f47cfab3609598c296dcb7f70ea83174360  LICENSE.txt" \
	"158bcb4149f4d6db461774d7bd67d264262f30145762eddd0a8def8be292286c  $BD/building_home_A_red.gltf" \
	"5d527ca5908c1bbbe80ffbd9443135e9387654bf2187a94796d018d00c6c5726  $BD/building_home_A_red.bin" \
	"5301a06866ba3be68dcc14cc429bd6d0f69004b72884283715d7e233f2e9782e  $BD/hexagons_medieval.png"

echo "kaykit adventurers: $cache/adventurers   (use: charkit_compare.py --kaykit \$that)"
echo "kaykit hexagon building: $cache/hexagon/$BD/building_home_A_red.gltf   (use: --building \$that)"
