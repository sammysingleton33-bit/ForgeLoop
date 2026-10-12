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
- **Framework modules must not require game config.** Static `require(Config.Items)` in shared
  economy modules passed every sandbox gate and broke the game-001 build the moment a second project
  existed (its config folder has no Items). Pattern: `X.setDefault(<the game's config>)` /
  `X.default()` that errors until set; only files every project provides (UITheme) may be required.
  `observed-once` (2026-10-12).
