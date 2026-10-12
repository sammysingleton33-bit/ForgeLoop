#!/usr/bin/env bash
# Writes roblox/src/shared/BuildInfo.json = { sha, branch, builtAt, dirty } (interfaces §11).
# Rojo turns it into ReplicatedStorage.Forge.BuildInfo; Main.server/Main.client log it at start.
# The file is gitignored; code tolerates its absence (logs sha=unstamped).
#   bash roblox/scripts/stamp_build.sh        (from any directory; run before rojo build / rojo serve)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

sha="$(git rev-parse HEAD)"
# CI checks out a detached HEAD: prefer the branch name GitHub provides.
branch="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}}"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
dirty=false
# Untracked/ignored build outputs do not count; tracked or new source changes do.
if [[ -n "$(git status --porcelain --untracked-files=normal -- . ':!roblox/build' ':!roblox/src/shared/BuildInfo.json')" ]]; then
	dirty=true
fi

# Branch names cannot contain '"' or '\' (git check-ref-format), so plain quoting is safe.
out="roblox/src/shared/BuildInfo.json"
printf '{\n\t"sha": "%s",\n\t"branch": "%s",\n\t"builtAt": "%s",\n\t"dirty": %s\n}\n' \
	"$sha" "$branch" "$built_at" "$dirty" > "$out"
echo "stamped $out: sha=$sha branch=$branch builtAt=$built_at dirty=$dirty"
