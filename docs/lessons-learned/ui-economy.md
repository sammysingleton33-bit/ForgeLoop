# Lessons — UI & Economy (FORGE-03)

Tag each lesson: `observed-once`, `repeated` or `standard`.

- **Lune rejects fractional UDim2 offsets** (`Invalid arguments to constructor`); Roblox rounds them.
  Keep layout maths in whole pixels (`math.floor`) so headless specs and Studio agree.
  `observed-once` (2026-10-12, Lune 0.11.0).
- **Lune instances have no events** (`Activated is not a valid member of TextButton`) and no
  `AbsoluteSize`. Route every connection through one builder function (`UI/Create.connect`) that
  specs can swap (`Create.useTestConnector` + `Create.fire`), and never read measured sizes in
  layout logic — feed the safe-area size in. `observed-once`.
- **`Enum.FontWeight.Black` does not exist** (Lune's enum, matching Roblox): the heaviest weight is
  `Heavy` (900). `observed-once`.
- **Clearing a container also destroys its UIScale.** Give screens their own child container and
  keep modifiers (UIScale) on the root. `observed-once`.
- **UIListLayout positions every GuiObject child**, so decorations (tab underline, floating
  deltas, badges) must live outside the laid-out row: keep a `Row` child for the layout. Hit three
  times (tab underline, pill delta caught only by the Luau snapshot render). `repeated`.
- **Render the real Luau tree, not only the prototype.** `design/ui/render/` found a layout bug the
  HTML prototype could not (the prototype positions by hand). `observed-once`.
- **Pipelines hide failures.** `cmd | tail -3 && git commit` commits even when `cmd` failed. Use
  `set -o pipefail` (or no pipe) before chaining a commit/push to a check. Cost: one pushed commit
  with a failing spec (`e9e7766`, fixed in `83761e7`). `observed-once`.
- **Scripted string edits miss StyLua-wrapped lines.** After `stylua`, long expressions move to new
  lines; re-read the file before an exact-match edit and verify the edit applied (grep) before
  committing. `observed-once`.
- **The default Roblox top bar can hold your timer:** `ScreenInsets.TopbarSafeInsets` gives the
  free part of the top bar (creator-docs ScreenInsets.yaml), which saves a row on phones in
  landscape. Studio confirmation pending (U7). `observed-once` (docs only).
- **Game code cannot reach `StarterPlayerScripts`.** The D-017/D-022 require policy lets game code
  use `@game/` only for `ReplicatedStorage/Forge/...` and `ReplicatedStorage/Game/...`; a UI kit in
  the framework client tree is unusable from `games/<game>/src/client`. Shared client libraries go in
  `roblox/src/shared` (→ `ReplicatedStorage.Forge`). Caught by `check_place` before any game code
  used the old path. `observed-once` (2026-10-12).
- **"Apply the end state at once" breaks exit animations.** Motion's no-tween fallback (reduced
  motion, no TweenService) applies a tween's target immediately; for a fade-out that means the
  element is invisible from the first frame (the spend float). Tween exits only when
  `motion.enabled`, and remove the element on a timer either way. `observed-once`.
- **A git worktree has no `node_modules`.** Renders in a fresh worktree silently fell back to system
  fonts. Link `design/ui/node_modules` from the main checkout (git-excluded) before shooting, and
  watch for the renderer's "no @fontsource fonts" line. `observed-once`.
- **Mutate against the strongest double you have.** A late-join refetch survived its mutation
  because the real TreasuryService also pushes on join; the spec now models a missed push.
  `observed-once`.
- **Never key a weak table by an Instance in Lune.** Lune hands out a new userdata for an instance
  once nothing in Lua holds the old one, so a `__mode = "k"` table keyed by instances loses entries
  whenever the GC runs. The kit's test connector did, and a tap spec failed in about a third of full
  game-001 runs while passing alone. Hold instances strongly and reset per test. Repro: a spec that
  drops the reference and forces GC with allocations (`collectgarbage("collect")` is not allowed).
  `observed-once` (2026-10-12).
- **Re-render by key, patch values in place.** A full rebuild per push swapped the button under the
  player's finger and reset scroll (FORGE-05 M1). Views keep a layout key (`UI/Signature`) and only
  rebuild when it changes; balances, CTA state and progress are patched. Check it with instance
  identity in specs (`expect(find(...)).toBe(before)`) and pixel-compare the committed renders.
  `observed-once` (2026-10-12).
