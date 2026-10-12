#!/usr/bin/env bash
# CI only (.github/workflows/ci.yml): download the pinned Linux x86_64 release binaries named in
# rokit.toml into <bin-dir>. No compiling: Actions minutes are metered on private repos (D-015).
#   bash roblox/scripts/ci_install_tools.sh "$RUNNER_TEMP/forge-bin"
# Asset names (checked 2026-10-12 against each tag's release workflow on raw.githubusercontent.com):
#   rojo    rojo-<v>-linux-x86_64.zip   (rojo .github/workflows/release.yml: $BIN-${TAG#v}-linux-x86_64.zip)
#   stylua  stylua-linux-x86_64.zip     (StyLua release.yml: asset_name <artifact-name>.zip; built with luau)
#   lune    lune-<v>-linux-x86_64.zip   (lune release.yaml + scripts/unpack-releases.sh)
#   selene  selene-<v>-linux.zip        (selene .github/workflows/build.yml at tag 0.31.0: the
#           `release` job runs on a "[release]" commit — the tag commit is "0.31.0 [release]" — and
#           uploads asset_name selene-${VERSION}-linux.zip, built on ubuntu-latest x86_64)
# The release pages themselves were not reachable from the cloud sandbox (unverified there).
# Tags: rojo v<v>, StyLua v<v>, lune v<v>, selene <v> (no "v"), verified with git ls-remote.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="${1:?usage: ci_install_tools.sh <bin-dir>}"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

version() { sed -n "s/^$1 *= *\"[^@]*@\([0-9.]*\)\".*/\1/p" "$ROOT/rokit.toml"; }

install_zip() { # repo tag asset binary
	local repo="$1" tag="$2" asset="$3" binary="$4"
	echo "download $repo $tag $asset"
	curl -fsSL --retry 3 --retry-delay 3 -o "$TMP/$asset" "https://github.com/$repo/releases/download/$tag/$asset"
	mkdir -p "$TMP/unzip-$binary"
	unzip -o -q "$TMP/$asset" -d "$TMP/unzip-$binary"
	local found
	found="$(find "$TMP/unzip-$binary" -type f -name "$binary" | head -1)"
	if [[ -z "$found" ]]; then
		echo "error: $asset does not contain '$binary'" >&2
		exit 1
	fi
	install -m 0755 "$found" "$BIN/$binary"
}

ROJO="$(version rojo)"
SELENE="$(version selene)"
STYLUA="$(version stylua)"
LUNE="$(version lune)"

install_zip rojo-rbx/rojo "v$ROJO" "rojo-$ROJO-linux-x86_64.zip" rojo
install_zip JohnnyMorganz/StyLua "v$STYLUA" "stylua-linux-x86_64.zip" stylua
install_zip lune-org/lune "v$LUNE" "lune-$LUNE-linux-x86_64.zip" lune
install_zip Kampfkarren/selene "$SELENE" "selene-$SELENE-linux.zip" selene

for tool in rojo selene stylua lune; do
	"$BIN/$tool" --version
done
