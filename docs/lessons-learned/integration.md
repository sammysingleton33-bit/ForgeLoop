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
  warning, but the part lands at the origin (`CFrame` stays identity). Write
  `"CFrame": {"CFrame": {"position": [...], "orientation": [[row1], [row2], [row3]]}}` (orientation
  is row-major: a part rotated +90° about Y has RightVector (0, 0, −1)). Tags (`"Tags": [...]`) and
  `"attributes"` round-trip into the place. · `rojo build` + `@lune/roblox` read-back of a scratch
  project; map gate negative test M1 (place check FAIL "at 0, 0, 0") · `observed-once`
- 2026-10-12 · GitHub release downloads (`github.com/<repo>/releases/download/...`) worked from a
  cloud session through the agent proxy (`roblox/scripts/ci_install_tools.sh` fetched all four pinned
  tools in seconds), contradicting an earlier session where they were blocked; Actions artifact
  downloads (redirect to `*.blob.core.windows.net`) were still refused. Try the release binaries
  before compiling with cargo; read artifact contents from the CI log instead. · FORGE-05 session
  2026-10-12 · `observed-once`

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
