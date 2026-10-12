#!/usr/bin/env bash
# FORGELOOP Roblox gates (G1 static + G2 unit). Works from any directory.
#   bash roblox/scripts/check.sh                   # all gates
#   bash roblox/scripts/check.sh --require-stamp   # also require a BuildInfo stamp (CI on main)
# Steps: toolchain versions · Lune tests · Selene (0 errors) · StyLua --check · Rojo build · place check.
# Prints a PASS/FAIL table and exits non-zero if any step fails. Nothing is skipped silently:
# a missing tool is a FAIL, and a step that records no result (e.g. aborted by a shell error) fails
# the run. Portable to bash 3.2 (macOS /bin/bash): no mapfile, no empty-array expansions.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
export PATH="$PATH:$HOME/.rokit/bin:$HOME/.cargo/bin" # tools already on PATH (CI) take precedence

REQUIRE_STAMP=""
for arg in "$@"; do
	case "$arg" in
		--require-stamp) REQUIRE_STAMP="--require-stamp" ;;
		*) echo "unknown argument: $arg" >&2; exit 2 ;;
	esac
done

PLACE="roblox/build/sandbox.rbxl"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT
LUAU_DIRS=(roblox/src roblox/tests roblox/scripts games)
EXPECTED_STEPS=6 # toolchain, lune tests, selene, stylua, rojo build, place check
STEP_TIMEOUT=600 # seconds per Lune step (coreutils `timeout`, when installed): a hung spec cannot stall CI

NAMES=()
RESULTS=()
DETAILS=()
record() { NAMES+=("$1"); RESULTS+=("$2"); DETAILS+=("$3"); }

# run_step <name> <log-file> <command...>: streams output, returns the command's exit code
run_step() {
	local name="$1" log="$2"
	shift 2
	echo
	echo "==> $name: $*"
	"$@" 2>&1 | tee "$log"
	return "${PIPESTATUS[0]}"
}

# with_timeout <command...>: runs the command under `timeout` when available (exit 124 on expiry)
with_timeout() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "$STEP_TIMEOUT" "$@"
	else
		"$@"
	fi
}

# ---------------------------------------------------------------- toolchain
want_version() { # tool -> version pinned in rokit.toml
	sed -n "s/^$1 *= *\"[^@]*@\([0-9.]*\)\".*/\1/p" rokit.toml
}
tool_detail=""
tool_ok=1
for tool in rojo selene stylua lune; do
	want="$(want_version "$tool")"
	if ! command -v "$tool" >/dev/null 2>&1; then
		tool_ok=0
		tool_detail+="$tool missing; "
		continue
	fi
	have="$("$tool" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
	if [[ "$have" != "$want" ]]; then
		tool_ok=0
		tool_detail+="$tool $have (want $want); "
	else
		tool_detail+="$tool $have; "
	fi
done
echo "==> toolchain: ${tool_detail%; }"
if [[ $tool_ok == 1 ]]; then record "toolchain" "PASS" "${tool_detail%; }"; else record "toolchain" "FAIL" "${tool_detail%; }"; fi

# ---------------------------------------------------------------- Lune tests
if command -v lune >/dev/null 2>&1; then
	run_step "lune tests" "$LOG_DIR/lune.log" with_timeout lune run roblox/tests/harness/run.luau
	code=$?
	summary="$(grep -E '^Lune tests:' "$LOG_DIR/lune.log" | tail -1 | sed 's/^Lune tests: //')"
	if [[ $code == 0 ]] && grep -q '^RESULT: PASS' "$LOG_DIR/lune.log"; then
		record "lune tests" "PASS" "$summary"
	elif [[ $code == 124 ]]; then
		record "lune tests" "FAIL" "timed out after ${STEP_TIMEOUT}s (a spec that never finishes?)"
	else
		record "lune tests" "FAIL" "${summary:-runner exited $code}"
	fi
else
	record "lune tests" "FAIL" "lune not found"
fi

# ---------------------------------------------------------------- Selene
if command -v selene >/dev/null 2>&1; then
	run_step "selene" "$LOG_DIR/selene.log" selene "${LUAU_DIRS[@]}"
	code=$?
	errors="$(sed -n 's/^\([0-9][0-9]*\) errors$/\1/p' "$LOG_DIR/selene.log" | tail -1)"
	warnings="$(sed -n 's/^\([0-9][0-9]*\) warnings$/\1/p' "$LOG_DIR/selene.log" | tail -1)"
	parse_errors="$(sed -n 's/^\([0-9][0-9]*\) parse errors$/\1/p' "$LOG_DIR/selene.log" | tail -1)"
	detail="${errors:-?} errors, ${warnings:-?} warnings, ${parse_errors:-?} parse errors"
	if [[ $code == 0 && "$errors" == "0" && "$parse_errors" == "0" ]]; then
		record "selene" "PASS" "$detail"
	else
		record "selene" "FAIL" "$detail (exit $code)"
	fi
else
	record "selene" "FAIL" "selene not found"
fi

# ---------------------------------------------------------------- StyLua
# Explicit file list: a StyLua build without Luau support would otherwise skip .luau files when
# given directories and report success without checking anything.
if command -v stylua >/dev/null 2>&1; then
	luau_files=()
	while IFS= read -r f; do
		luau_files+=("$f")
	done < <(find "${LUAU_DIRS[@]}" -type f \( -name '*.luau' -o -name '*.lua' \) 2>/dev/null | sort)
	if [[ ${#luau_files[@]} == 0 ]]; then
		record "stylua" "FAIL" "no Luau files found"
	else
		run_step "stylua" "$LOG_DIR/stylua.log" stylua --check "${luau_files[@]}"
		code=$?
		if [[ $code == 0 ]]; then
			record "stylua" "PASS" "${#luau_files[@]} files formatted"
		else
			unformatted="$(grep -c '^Diff in' "$LOG_DIR/stylua.log")"
			record "stylua" "FAIL" "$unformatted file(s) need formatting (stylua <file>), exit $code"
		fi
	fi
else
	record "stylua" "FAIL" "stylua not found"
fi

# ---------------------------------------------------------------- Rojo build
rm -f "$PLACE" # never let a stale place pass the place check
mkdir -p "$(dirname "$PLACE")"
if command -v rojo >/dev/null 2>&1; then
	run_step "rojo build" "$LOG_DIR/rojo.log" rojo build roblox/default.project.json -o "$PLACE"
	code=$?
	if [[ $code == 0 && -f "$PLACE" ]]; then
		record "rojo build" "PASS" "$PLACE ($(wc -c < "$PLACE" | tr -d ' ') bytes)"
	else
		record "rojo build" "FAIL" "exit $code"
	fi
else
	record "rojo build" "FAIL" "rojo not found"
fi

# ---------------------------------------------------------------- place check
if command -v lune >/dev/null 2>&1; then
	run_step "place check" "$LOG_DIR/place.log" with_timeout lune run roblox/scripts/check_place.luau "$PLACE" $REQUIRE_STAMP
	code=$?
	summary="$(grep -E '^place check:' "$LOG_DIR/place.log" | tail -1 | sed -E 's/^place check: ((PASS|FAIL) — )?//')"
	if [[ $code == 0 ]]; then record "place check" "PASS" "$summary"; else record "place check" "FAIL" "$summary"; fi
else
	record "place check" "FAIL" "lune not found"
fi

# ---------------------------------------------------------------- summary
overall="PASS"
echo
echo "FORGELOOP Roblox gates — $(git rev-parse --short HEAD 2>/dev/null || echo 'no git')$( [[ -n "$(git status --porcelain 2>/dev/null)" ]] && echo ' (uncommitted changes)')"
printf '%-12s %-6s %s\n' "STEP" "RESULT" "DETAIL"
recorded=${#NAMES[@]}
i=0
while [[ $i -lt $recorded ]]; do
	printf '%-12s %-6s %s\n' "${NAMES[$i]}" "${RESULTS[$i]}" "${DETAILS[$i]}"
	[[ "${RESULTS[$i]}" == "PASS" ]] || overall="FAIL"
	i=$((i + 1))
done
if [[ $recorded -ne $EXPECTED_STEPS ]]; then
	printf '%-12s %-6s %s\n' "steps" "FAIL" "$recorded of $EXPECTED_STEPS steps recorded a result (a step aborted; see the log above)"
	overall="FAIL"
fi
printf '%-12s %-6s\n' "OVERALL" "$overall"
[[ "$overall" == "PASS" ]]
