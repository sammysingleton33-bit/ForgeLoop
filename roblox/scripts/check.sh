#!/usr/bin/env bash
# FORGELOOP Roblox gates (G1 static + G2 unit). Works from any directory.
#   bash roblox/scripts/check.sh                   # all gates
#   bash roblox/scripts/check.sh --require-stamp   # also require a BuildInfo stamp (CI on main)
# Steps: toolchain versions · Lune tests · Selene (0 errors) · StyLua --check · Rojo build · place check,
# then the same for every game project in GAME_PROJECTS (D-022): game specs over the game project,
# Rojo build of the game place, place check of it.
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
# game projects: "<id>:<project file>:<spec dir>"; each builds roblox/build/<id>.rbxl
GAME_PROJECTS=("game-001:games/game-001/default.project.json:games/game-001/tests")
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT
LUAU_DIRS=(roblox/src roblox/tests roblox/scripts games)
EXPECTED_STEPS=$((9 + 3 * ${#GAME_PROJECTS[@]})) # 9 framework steps + (specs, build, place check) per game
STEP_TIMEOUT=600 # seconds per Lune step (coreutils `timeout`, when installed): a hung spec cannot stall CI
# spec folders that run as several Lune steps (run.luau --shard i/n), each under STEP_TIMEOUT:
# "<game id>/<folder>:<n>". game-001's sim/ took 572 s alone locally on 2026-10-15 (limit 600); its 49 files
# summed 584 s one by one on 2026-10-18 (ConversationService 138 s, ConsequenceService 113 s, MatchKingdomServices
# 79 s), which the every-n-th split puts at 424 + 160 s with 2 shards and 253 + 109 + 221 s with 3. game-001's
# world/ took 565 s of 600 on 2026-10-19 (gate 7: #217 arena venue, #226 citizen mesh kit), so it runs as 2 shards too;
# with FORGE-02's war kit (#260: KitWarKit, KitCeiling, KitDamage) world shard 1/2 took 678 s run alone, so 3 shards;
# gate 8n (+#268) put world#2/3 at 496 s, past FORGE-00's 480 s split line (KitEmblems alone ~176 s), so 4.
SHARDS=("game-001/sim:3" "game-001/world:6") # world 4 -> 6 on 2026-10-22: world#1/4 reached 358 s locally (split line 480)
# sub-folders that run as their own Lune step and are left out of their parent folder's step(s) (run.luau
# --exclude): "<game id>/<folder>/<sub>". game-001's sim/long holds the real-length full-match spec (FL-0125).
SPLITS=("game-001/sim/long")

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

# ---------------------------------------------------------------- plugin-only property writes
# Game code may not write Plugin-security properties (MeshPart.CollisionFidelity, MeshId, ...): Roblox refuses
# the write in a live game, a pcall hides it, and Lune lets it through, so no spec can see it (2026-10-19).
if command -v lune >/dev/null 2>&1; then
	run_step "plugin props" "$LOG_DIR/plugin-props.log" with_timeout lune run roblox/scripts/check_plugin_props.luau
	code=$?
	summary="$(grep -E '^plugin props:' "$LOG_DIR/plugin-props.log" | tail -1 | sed -E 's/^plugin props: ((PASS|FAIL) — )?//')"
	if [[ $code == 0 ]]; then record "plugin props" "PASS" "$summary"; else record "plugin props" "FAIL" "$summary"; fi
else
	record "plugin props" "FAIL" "lune not found"
fi

# ---------------------------------------------------------------- engine members a live client refuses
# Writes to read-only / not-scriptable GUI properties, GetPropertyChangedSignal of a property no class has, Enum items
# that do not exist: Lune lets them through, a real client errors (B22 HUD P0, 2026-10-22; roblox/scripts/UiMembers).
if command -v lune >/dev/null 2>&1; then
	run_step "ui members" "$LOG_DIR/ui-members.log" with_timeout lune run roblox/scripts/check_ui_members.luau
	code=$?
	summary="$(grep -E '^ui members:' "$LOG_DIR/ui-members.log" | tail -1 | sed -E 's/^ui members: ((PASS|FAIL) — )?//')"
	if [[ $code == 0 ]]; then record "ui members" "PASS" "$summary"; else record "ui members" "FAIL" "$summary"; fi
else
	record "ui members" "FAIL" "lune not found"
fi

# ---------------------------------------------------------------- world measurements (blender/scripts/lune)
# FORGE-02's measurement specs pin the placed world (props, parts, dressing) at the shipped density and at 1.0. They ran
# only under blender/tests (pytest + lune), never in check.sh or CI, so #303 changed the world and passed CI with three
# stale pins; only FORGE-05's gate saw it (2026-10-22). Now every check.sh run and CI run them (about a minute).
if command -v lune >/dev/null 2>&1; then
	if [[ -d blender/scripts/lune ]]; then
		run_step "world measurements" "$LOG_DIR/world-measurements.log" with_timeout lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune
		code=$?
		summary="$(grep -E '^Lune tests:' "$LOG_DIR/world-measurements.log" | tail -1 | sed -E 's/^Lune tests: //')"
		if [[ $code == 0 ]]; then record "world measurements" "PASS" "$summary"; else record "world measurements" "FAIL" "$summary"; fi
	else
		record "world measurements" "FAIL" "no blender/scripts/lune folder (the measurement specs must exist; see docs/lessons-learned/integration.md)"
	fi
else
	record "world measurements" "FAIL" "lune not found"
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

# ---------------------------------------------------------------- game projects (D-022)
for entry in "${GAME_PROJECTS[@]}"; do
	IFS=: read -r game_id game_project game_specs <<<"$entry"
	game_place="roblox/build/$game_id.rbxl"
	if command -v lune >/dev/null 2>&1; then
		# One Lune run per top-level spec folder (or per shard, SHARDS), each under STEP_TIMEOUT, summed into
		# one row in the usual "N passed, …" form. Spec files directly in the spec root run as one more chunk.
		chunks=()
		while IFS= read -r dir; do chunks+=("$dir"); done < <(find "$game_specs" -mindepth 1 -maxdepth 1 -type d | sort)
		if compgen -G "$game_specs/*.spec.luau" >/dev/null || [[ ${#chunks[@]} == 0 ]]; then
			chunks=("$game_specs") # specs at the root (or no folders): the whole tree in one run, as before
		fi
		# a sub-folder listed in SPLITS (when it exists) is one more chunk, and its parent's runs exclude it
		excludes=()
		for split in "${SPLITS[@]}"; do
			[[ ${split%%/*} == "$game_id" ]] || continue
			sub="$game_specs/${split#*/}"
			if [[ -d $sub ]]; then
				chunks+=("$sub")
				excludes+=("$(dirname "$sub")|$sub")
			fi
		done
		# a folder listed in SHARDS runs as n steps: "<dir>|<i>/<n>"
		runs=()
		for chunk in "${chunks[@]}"; do
			folder="${chunk#"$game_specs"}"
			folder="${folder#/}"
			n=1
			for shard in "${SHARDS[@]}"; do
				[[ ${shard%%:*} == "$game_id/$folder" ]] && n="${shard##*:}"
			done
			if [[ $n -gt 1 ]]; then
				for ((k = 1; k <= n; k++)); do runs+=("$chunk|$k/$n"); done
			else
				runs+=("$chunk|")
			fi
		done
		passed=0 failed=0 broken=0 files=0 skipped=0 ok=1 why="" times=()
		for run in "${runs[@]}"; do
			chunk="${run%%|*}"
			shard="${run#*|}"
			label="${chunk#"$game_specs"}"
			label="${label#/}"
			label="${label:-all}${shard:+#$shard}" # e.g. "sim#1/2": no space, the slowest list sorts on field 2
			log="$LOG_DIR/$game_id-lune-${label//[\/#]/_}.log"
			started=$SECONDS
			exclude_args=()
			for pair in ${excludes[@]+"${excludes[@]}"}; do
				[[ ${pair%%|*} == "$chunk" ]] && exclude_args+=(--exclude "${pair#*|}")
			done
			run_step "$game_id specs ($label)" "$log" with_timeout lune run roblox/tests/harness/run.luau \
				--project "$game_project" --specs "$chunk" ${shard:+--shard "$shard"} ${exclude_args[@]+"${exclude_args[@]}"}
			code=$?
			times+=("$label $((SECONDS - started))s")
			line="$(grep -E '^Lune tests:' "$log" | tail -1)"
			if [[ $line =~ ([0-9]+)\ passed,\ ([0-9]+)\ failed,\ ([0-9]+)\ broken\ file\(s\),\ ([0-9]+)\ spec\ file\(s\),\ ([0-9]+)\ skipped ]]; then
				passed=$((passed + BASH_REMATCH[1])) failed=$((failed + BASH_REMATCH[2])) broken=$((broken + BASH_REMATCH[3]))
				files=$((files + BASH_REMATCH[4])) skipped=$((skipped + BASH_REMATCH[5]))
			fi
			if [[ $code != 0 ]] || ! grep -q '^RESULT: PASS' "$log"; then
				ok=0
				if [[ $code == 124 ]]; then
					why="${why}${why:+; }$label timed out after ${STEP_TIMEOUT}s"
				else
					why="${why}${why:+; }$label failed (exit $code)"
				fi
			fi
		done
		# every spec file on disk ran exactly once across the shards and splits (a too-broad --exclude, a SPLITS
		# entry without its own chunk, or a shard bug would otherwise still read PASS); same names as run.luau
		expected=$(find "$game_specs" \( -name '*.spec.luau' -o -name '*.spec.lua' \) | wc -l | tr -d ' ')
		if [[ $files -ne $expected ]]; then
			ok=0
			why="${why}${why:+; }$files of $expected spec files ran"
		fi
		summary="$passed passed, $failed failed, $broken broken file(s), $files spec file(s), $skipped skipped"
		slowest="$(printf '%s\n' "${times[@]}" | sort -k2 -t' ' -rn | head -3 | paste -sd, - | sed 's/,/, /g')"
		if [[ $ok == 1 ]]; then
			record "$game_id specs" "PASS" "$summary (slowest: $slowest)"
		else
			record "$game_id specs" "FAIL" "$summary; $why"
		fi
	else
		record "$game_id specs" "FAIL" "lune not found"
	fi
	rm -f "$game_place"
	if command -v rojo >/dev/null 2>&1; then
		run_step "$game_id build" "$LOG_DIR/$game_id-rojo.log" rojo build "$game_project" -o "$game_place"
		code=$?
		if [[ $code == 0 && -f "$game_place" ]]; then
			record "$game_id build" "PASS" "$game_place ($(wc -c < "$game_place" | tr -d ' ') bytes)"
		else
			record "$game_id build" "FAIL" "exit $code"
		fi
	else
		record "$game_id build" "FAIL" "rojo not found"
	fi
	if command -v lune >/dev/null 2>&1; then
		run_step "$game_id place" "$LOG_DIR/$game_id-place.log" with_timeout lune run roblox/scripts/check_place.luau \
			"$game_place" --project "$game_project" $REQUIRE_STAMP
		code=$?
		summary="$(grep -E '^place check:' "$LOG_DIR/$game_id-place.log" | tail -1 | sed -E 's/^place check: ((PASS|FAIL) — )?//')"
		if [[ $code == 0 ]]; then record "$game_id place" "PASS" "$summary"; else record "$game_id place" "FAIL" "$summary"; fi
	else
		record "$game_id place" "FAIL" "lune not found"
	fi
done

# ---------------------------------------------------------------- summary
overall="PASS"
echo
echo "FORGELOOP Roblox gates — $(git rev-parse --short HEAD 2>/dev/null || echo 'no git')$( [[ -n "$(git status --porcelain 2>/dev/null)" ]] && echo ' (uncommitted changes)')"
printf '%-16s %-6s %s\n' "STEP" "RESULT" "DETAIL"
recorded=${#NAMES[@]}
i=0
while [[ $i -lt $recorded ]]; do
	printf '%-16s %-6s %s\n' "${NAMES[$i]}" "${RESULTS[$i]}" "${DETAILS[$i]}"
	[[ "${RESULTS[$i]}" == "PASS" ]] || overall="FAIL"
	i=$((i + 1))
done
if [[ $recorded -ne $EXPECTED_STEPS ]]; then
	printf '%-16s %-6s %s\n' "steps" "FAIL" "$recorded of $EXPECTED_STEPS steps recorded a result (a step aborted; see the log above)"
	overall="FAIL"
fi
printf '%-16s %-6s\n' "OVERALL" "$overall"
[[ "$overall" == "PASS" ]]
