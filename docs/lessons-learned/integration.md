# Lessons learned — integration (FORGE-05)

Format: date · lesson · evidence · tag (`observed-once` / `repeated` / `standard`). Verified entries only.

- 2026-10-12 · In Lune 0.11, mapping `@game` to a mirrored directory with a `.luaurc` alias loads a
  **second copy** of a module that is also required relatively (module identity breaks: two
  GameEvents buses). The harness therefore resolves requires itself and caches by source file. ·
  scratch repro: `.luaurc {"aliases":{"game":"./mirror"}}` with `mirror/ReplicatedStorage/Forge` →
  symlink to `src/shared`; `rawequal(require("@game/ReplicatedStorage/Forge/Core/Signal"),
  require("../shared/Core/Signal"))` printed `false` · `observed-once`
- 2026-10-12 · `stylua` installed with plain `cargo install stylua` has no Luau parser: it panics on
  `local x: number = 1`, and `stylua --check <directory>` exits 0 without checking any `.luau` file.
  Install with `--features lua52,lua53,lua54,luau,luajit,cfxlua` (what release binaries use) and pass
  explicit file lists in gates. · observed on stylua 2.6.0 before/after reinstall; fixed in
  `tools/setup/cloud-setup.sh` and `roblox/scripts/check.sh` · `observed-once`
- 2026-10-12 · `selene generate-roblox-std` cannot download the API dump behind the cloud sandbox's
  TLS proxy (`invalid peer certificate: UnknownIssuer`), and `SSL_CERT_FILE` does not help (selene's
  HTTP client uses built-in roots). Commit a pinned `roblox.yml` (`roblox-std-source = "pinned"`). The
  config key is kebab-case; `roblox_std_source` is rejected. · selene 0.31.0 output, 2026-10-12 ·
  `observed-once`
- 2026-10-12 · Lune `roblox.implementMethod`/`implementProperty` can be registered only once per
  class member per process (`class 'Players' already registered property 'PlayerAdded'`), and
  `implementProperty` does not override a reflected property (`Players.LocalPlayer` stayed nil; set it
  directly instead). Mocks keep that state in `roblox/tests/harness/LuneInstances.luau`. · first full
  spec run failed with the error above; fixed run green · `observed-once`
- 2026-10-12 · Lune Instance userdata keep their identity (`rawequal` holds across `GetService`,
  `GetChildren`, method `self`), so they work as table keys for per-instance mock state. · probe script
  · `observed-once`
- 2026-10-12 · An error inside a `task.spawn`ed thread makes `lune run` exit 1 at the end even though
  the script continued; the test runner ends with an explicit `process.exit` and the harness routes
  spawned-thread errors to the running test instead. · probe script exit code 1 after "after spawn
  error" · `observed-once`
- 2026-10-12 · Rojo 7.7.1 builds `README.md`/`.gitkeep` into nothing, empty directories into Folders,
  `X.json` into a ModuleScript returning the table, and accepts `$className` + a directory `$path` on
  `Workspace`. · `rojo build` + `@lune/roblox` tree dump of `roblox/default.project.json` · `observed-once`
- 2026-10-12 · A Rojo project node with `$path` and no `$ignoreUnknownInstances: true` is synced as
  authoritative: `rojo serve` removes children Studio has but the project does not (a Baseplate's
  `Workspace.Baseplate`, anything built in Studio). Map `Workspace` only with
  `"$ignoreUnknownInstances": true`. · Rojo 7.7.1 source (cargo registry): `snapshot_middleware/project.rs`
  sets ignore_unknown_instances only when `$path` is absent; plugin `Reconciler/diff.lua` marks unknown
  children for removal. Source reading, not observed in Studio · `observed-once`
- 2026-10-12 · Lune 0.11's `implementMethod`/`implementProperty` on the base class `"Instance"` apply to
  every subclass (`Folder`, `ReplicatedStorage`, ...), but cannot override a built-in member
  (`Parent`), so there is no hook on reparenting: Instance events in the mocks are detected by diffing
  children at each scheduler step. · probe script (WaitForChild on Folder and ReplicatedStorage; a
  custom `Parent` setter was never called) · `observed-once`
- 2026-10-12 · In Lune 0.11 the main chunk is yieldable (`coroutine.isyieldable()` is true), so
  "not yieldable" cannot identify the spec's own thread; MockEnv asks the test runner which thread is
  running the test body (`Test.isDriverThread`). · probe script · `observed-once`
- 2026-10-12 · Catching an error with `coroutine.resume`'s result only covers the first resume; a
  handler that yields and errors after a later resume (by the task scheduler) is lost. Wrap the body
  in `xpcall` *inside* the coroutine. · review repro: spec passed and the runner exited 0 although a
  GameEvents handler errored after `Signal:wait()`; fixed in Core/Signal, MockEnv, MockSignal ·
  `observed-once`
- 2026-10-12 · Git for Windows defaults to `core.autocrlf=true`: without `.gitattributes`, a clone
  gets CRLF and `bash stamp_build.sh` fails (`set: pipefail: invalid option name`), and
  `stylua --check` (line_endings Unix) flags every file. `* text=auto eol=lf` fixes both. · scratch
  clone with `-c core.autocrlf=true` before/after adding `.gitattributes` · `observed-once`
- 2026-10-12 · From the cloud sandbox, `api.github.com` release endpoints for unattached repositories
  return 403 and GitHub release downloads are blocked; release asset names can still be checked in
  each tag's release workflow via `raw.githubusercontent.com`, and tags via `git ls-remote`. ·
  `.github/workflows/ci.yml` asset notes · `observed-once`
- 2026-10-12 · Rojo 7.7.1 accepts a `"Position"` property in a `.model.json` and builds without a
  warning, but the part lands at the origin. Write `"CFrame": {"CFrame": {"position": [...],
  "orientation": [[row1], [row2], [row3]]}}` (row-major). `"Tags"` and `"attributes"` round-trip. ·
  `rojo build` + `@lune/roblox` read-back (FORGE-05, closed PR #2) · `observed-once`
- 2026-10-12 · Rojo 7.7.1 fails the whole build when a project `$path` does not exist ("could not be
  turned into a Roblox Instance"), so a game project can only mount folders that already exist in
  git: keep an empty-folder placeholder (`.gitkeep`) or add the mount in the PR that creates the
  folder. · scratch project with a missing `$path` · `observed-once`
- 2026-10-12 · Lune 0.11 `fs.isFile(path)` raises "Not a directory (os error 20)" instead of
  returning false when a component of `path` is a file (e.g. `.gitkeep/Remotes.luau`). Check
  `fs.isDir(parent)` first. · `games/game-001/tests/integration/Boot.spec.luau` first run · `observed-once`
- 2026-10-12 · Never restore temporary test edits with `git checkout -- .` in a worktree that holds
  uncommitted work: it reverts every tracked file (FORGE-05 lost a block of FL-0046 edits this way and
  re-applied them from the session's edit scripts). Commit WIP first, then delete only the temporary
  files and confirm `git status` is clean. · FL-0046 negative-test run · `observed-once`
- 2026-10-12 · GitHub release downloads worked from a cloud session through the agent proxy
  (`roblox/scripts/ci_install_tools.sh` fetched all four pinned tools in seconds) where an earlier
  session found them blocked; Actions artifact downloads (`*.blob.core.windows.net`) were refused.
  Try release binaries before compiling with cargo; read artifact facts from the CI log. · FORGE-05
  session · `observed-once`
- 2026-10-12 · In `pull_request` runs, `github.event.pull_request.base.sha` can be older than the
  base branch: after a D-014 direct push to `main`, a PR branch that merged `main` was diffed against
  the old base, so `main`'s own commits (PROJECT_STATUS.md, team.md, integration-log…) were charged to
  the PR and the ownership gate failed falsely. Diff against the first parent of the checked-out test
  merge commit (`HEAD^1`) instead. · PR #12 run 38303576284 (`base 7ff75ca`, FAIL 6 of 17); local
  reproduction with the merge onto `0267e23`: `--base 7ff75ca` FAIL 6 of 17, `--base HEAD^1` PASS 10;
  a deliberate PROJECT_STATUS.md edit still fails with `HEAD^1` · `observed-once`
- 2026-10-12 · In a clone whose fetch refspec maps only `main`, `git fetch origin <branch>` updates
  `FETCH_HEAD` but not `refs/remotes/origin/<branch>`. Pushes then look unpushed (a stop hook counted
  42 "unpushed" commits that were on the remote), and a filtered `git push -q … | grep` can hide the
  real result. Verify pushes with `git ls-remote origin refs/heads/<branch>`, and fetch branches with an
  explicit refspec `+refs/heads/<b>:refs/remotes/origin/<b>`. · FORGE-05 session, `forge/05-integration`
  (ls-remote 5348570 = local) · `observed-once`
- 2026-10-12 · A stacked PR keeps the lower PR's branch as its base after the lower PR merges. Merging
  it then succeeds (the API returns `merged: true` and a sha) but lands on that stale branch, not on
  `main`. Check `base.ref == "main"` before every merge and confirm with `git ls-remote origin
  refs/heads/main` after it. · PR #37 merged into `forge/02-blender-fl0055-world` as 0590952; main
  stayed at da90aba; re-targeted as #38 and merged as dc0b09f · `observed-once`
- 2026-10-12 · Lune hands out a new userdata for an Instance once Lua stops referencing the old one,
  so a weak-keyed table keyed by Instances loses entries when the GC runs (flaky only in the full
  suite, under GC pressure). Key test registries strongly and reset them per test. · FORGE-03 #25:
  `Create.useTestConnector` weak keys made `KingdomUI.spec` fail 2 of 3 full runs; strong keys gave
  6/6 · `observed-once`
- 2026-10-15 · A gate piped into `tail` can't stop a push: in `check_ownership.py … | tail -1 && git push`, the
  `&&` sees `tail`'s exit code (0), so the push runs even when the gate prints FAIL. Capture the gate's own
  status (`gate > log; rc=$?; tail -1 log; [ $rc -eq 0 ] && git push`) or use `set -o pipefail`. Also: the
  `task-status` exception allows front matter and Log appends only, so ticking a completion box in
  another owner's task file fails G8. · Bookkeeping 4d1dd69 pushed with ownership FAIL (an FL-0101
  checkbox); forward-fixed in e3a1af8 · `observed-once`

## Mock change log (FL-0028)
- 2026-10-12 FL-0003 (FORGE-00 skeleton): first versions of MockEnv, MockDataStoreService,
  MockPlayers, MockMarketplaceService, MockPolicyService, MockAnalyticsService (no caps enforced yet),
  MockRemotes, MockCollectionService, MockSignal, MockRandom, MockServices; specs in
  `roblox/tests/unit/contracts/`.
- 2026-10-12 FL-0003 review fixes (FORGE-00 skeleton, before merge):
  - MockEnv `env.wait` parks every scheduled thread (handlers, Loader `new()`, wrapped coroutines),
    not only `env.spawn` threads; only the spec's own thread fast-forwards. Minimum wait is one
    frame (1/60 s); `advance()` is non-re-entrant and errors after `MockEnv.MAX_RESUMES` resumes.
    Errors after any resume are reported. New: `env.mock.warnings`, `MockEnv.FRAME`.
  - MockDataStoreService: every request yields (≥ 1 frame); budgets refill per virtual minute
    (60 + 40 × players, cap one minute; burst `budget` default 1000); UpdateAsync spends StandardWrite
    even when cancelled (legacy SetIncrementAsync only on a write). Spec changed accordingly.
  - MockPolicyService / MockMarketplaceService.UserOwnsGamePassAsync yield one frame under MockEnv.
  - New MockInstanceEvents: `WaitForChild`, `ChildAdded`, `ChildRemoved`; clear errors for the
    unsupported Instance events.
  - Harness: per-spec-file `Random` loaded through the module loader; `TweenInfo`, `RaycastParams`,
    `OverlapParams`, `DateTime` (UTC) stand-ins; spawned-thread errors charged to the spawning test
    (also late ones); `*.spec.lua` collected and misnamed specs fail the run.
- 2026-10-12 FL-0067 (FORGE-05): `Wire.copyForRemote` copies buffers (sender writes after firing no
  longer reach the receiver); `Wire.estimateBytes` counts buffers as `buffer.len` (they were measured
  as their `tostring`, ~20 bytes, so oversized snapshots were never dropped) and only arguments
  1..n (it also counted the `n` field of `table.pack`, adding a byte, and gave negative sizes for nil
  arguments); `MockRemotes` gains `holdUnreliable`/`releaseUnreliable` for delay and reordering.
  Source: creator-docs `UnreliableRemoteEvent.yaml` ("payloads larger than 1000 bytes are dropped";
  buffers may be compressed). Specs: 4 new in `MockRemotes.spec.luau`, each proven able to fail.
- 2026-10-13 FL-0046 (#120, FORGE-05): `MockEnv.new` installs FORGE-04's `EngineStubs`
  (`ParticleEmitter:Emit`/`:Clear`, `Sound:Play`/`:Stop`) once per Lune process: since #49 a client spec
  that fires a celebration crashed in VFXController ("Emit is not a valid member"; Lune has no Emit).
  Lune allows one `implementMethod` per member per process (a second throws "already registered
  method"), so EngineStubs stays the only registrar and MockEnv calls its idempotent `install`. Source:
  creator-docs `ParticleEmitter.yaml` (Emit(count)). Proof: Boot.spec "a booted client presents a
  celebration and a kingdom effect" fails without the install.
- 2026-10-15 B17 (#159 + #160, FORGE-05) `observed-once`: two PRs from the same author that each pass alone can
  fail together when one pins a fingerprint of generated output (WorldService.spec's full-density plan hash) and
  the other changes an input to that generator (world resource-node positions; WorldPlan keeps decor clear of
  nodes). Only the combined test merge caught it (game-001 1 failure; each PR alone green). Gate stacked or
  sibling PRs together before merging the first, and ask the author to re-pin with a note of what moved (here:
  12 flower placements, nothing else).
- 2026-10-15 B17 (FORGE-05) `observed-once`: a full gate (check.sh + four mutation runners + probes) takes longer
  than the 30-minute default background limit; the run was stopped mid-mutation and left
  `games/game-001/config/Society.luau` mutated in the test worktree. Give long gates an explicit timeout
  (≥ 60 min), check `git status` in the worktree after any killed run, and restore before re-running.
- 2026-10-19 B20.1 (FORGE-05) `observed-once`: two stacked PRs (#198 on #195, #201 on #198) showed "merged" but
  landed in their stacked base branches, not main, because GitHub keeps a stacked PR's base after the lower PR merges
  (it retargets only when the base branch is deleted). The gate tree had merged their heads onto main, so every local
  check passed. B20.1 shipped without them and its row claimed them; FORGE-00 caught it with
  `git merge-base --is-ancestor`. Check `base.ref == main` before every merge, and run the ancestor check for every
  claimed PR before cutting a build (merge-checklist §5, §6).

## Run long gates as tracked background jobs, not detached shell jobs (`repeated`, 2026-10-19)
- **What happened:** twice on 2026-10-19 (g209 at 05:26, gate 8g at 09:39) a full `check.sh` started with a trailing `&` from a tool call died partway through the sim shards. There was no error and no OVERALL line, and the log simply stopped. A worker noticed only at the next scheduled check, about 20 minutes later.
- **Rule:** start `check.sh` as a tracked background job (the harness's run-in-background, which notifies on exit), and write OVERALL plus the per-step lines to the job output. When a log has an older mtime and no OVERALL line, treat the run as dead and rerun it; never read it as still running.
- **Also:** don't `git checkout` in the worktree a gate is running in. Use a second worktree for side checks (FORGE-05 uses fl-b2 for gates and fl-m93 for probes).

## Lune cannot see a write that Roblox refuses outside a plugin: scan for it (`observed-once`, 2026-10-19)
- **What happened:** the Kit wrote `MeshPart.CollisionFidelity` inside a `pcall`. In a live game server that write is refused ("lacking capability Plugin"), so the `pcall` failed quietly and every mesh rig and env mesh fell back to part-built. Every Lune gate passed, because Lune's roblox library allows the write. FORGE-00 found it by hand. The fix is #247 (FL-0136): the import scripts set CollisionFidelity in Studio, and the Kit no longer writes it.
- **Rule:** `check.sh` step "plugin props" (`roblox/scripts/check_plugin_props.luau`) scans every `.luau` file under `roblox/src` and `games/*/src`. It fails on an assignment to a Plugin-security property (CollisionFidelity, RenderFidelity, MeshId, DoubleSided, FluidFidelity and the SurfaceAppearance maps), whether written as `.Prop =` or as `["Prop"] =`. A line that only ever runs inside a plugin can carry `-- plugin-context`. Import scripts under `blender/studio` are not scanned, because they run as plugins.
- **Evidence:** before #247 the step failed on main at `Kit/CharacterMesh.luau:773`, the one real write. After #247 it passes (263 files). A negative test with a string literal, a comment, `==` and both write forms flagged exactly the two real writes.
- **Also:** a spec double cannot prove engine capability rules. When a property's write security matters, check it statically or in Studio, and record which of the two you did.
