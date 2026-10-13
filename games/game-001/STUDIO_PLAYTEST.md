# AI Kingdoms — VS-1 Studio playtest (gate G6; FL-0047, FL-0093; owner FORGE-05)

VS-1 (the nine first-playable items of BRIEF §4, D-030) is accepted **only** by this playtest. It takes about 25 minutes. You (the user) run
it on Windows in Roblox Studio against an integrated build of `main`; FORGE-05 records the result in
`production/quality-gates/studio-runs.md` and on the VS-1 tasks.

Each check says what to do, what you should see, which screenshot to take and which Output lines to
copy. Framework smoke tests S1–S3 (`roblox/STUDIO_TEST_PLAN.md`) use the same build; check 1 below
repeats S1's key lines. A check marked **waiting** depends on work that is not merged yet: skip it and write
`SKIPPED (waiting)`. FORGE-05 fills in the exact controls of each check in the PR that merges the
feature, so the steps always match the build you test.

## 0. Setup (5 minutes)
Pick one:
- **Downloaded build (no tools):** GitHub → ForgeLoop → **Actions** → newest **CI** run on `main` with
  artifacts → download `forgeloop-game001-<sha>` → unzip → Studio → **File → Open from File…** →
  `forgeloop-game001-<sha>.rbxl`.
- **Local build:** Git Bash in the repo: `git checkout main && git pull && bash roblox/scripts/stamp_build.sh &&
  mkdir -p roblox/build && rojo build games/game-001/default.project.json -o roblox/build/game-001.rbxl`,
  then open `roblox/build/game-001.rbxl` in Studio.

Then: **View → Output** open. **Home → Game Settings → Security → Enable Studio Access to API
Services: ON** (only needed once player data saving lands; harmless before). Write down the sha:
Explorer → ReplicatedStorage → Forge → **BuildInfo** (double-click) → `sha`.

## Debug panel and presets (FL-0068, FL-0093; Studio only)
Press **Play**, then **F8** (or the **Debug (F8)** button, top left) to open the panel. It lists:
- **Presets**: each puts the server into a known start state for a check. Press the one a check names
  before you start it. The G13.7 presets (FORGE-05) are:

  | Preset | What it does | Used in |
  |---|---|---|
  | `vs1.reseed` | regenerates your kingdom's citizens from seed 1234 (same seed → same citizens) | row 4 |
  | `vs1.hungry` | sets your kingdom's fed ratio to 0.3 until the next upkeep tick (60 s) | rows 5, 9 |
  | `vs1.repLow` / `vs1.repHigh` | sets your reputation (compassion 10 + fear 80 / compassion 90 + honor 90) | row 8 |
  | `vs1.request` | makes one of your citizens raise a request now (thought bubble) | row 9 |
  | `vs1.strike` | the farmers of your kingdom go on strike | row 9 |

  Row owners add their own presets (e.g. treasury, construction). A preset that fails says why. For
  example, `KingdomService is not running yet` means that part of the game is still **waiting**.
  **As of B6:** `vs1.reseed`, `vs1.request` and `vs1.strike` answer **FAIL** on purpose: they fail closed
  until FORGE-01 adds their server hooks (FL-0104). Write `SKIPPED (waiting FL-0104)` for the steps that use them.
- **Commands** such as `forge.buildInfo` (shows the sha; use it for the report) and `forge.services`.
  Commands with arguments are listed as text only. Use the presets.

The panel only exists in Studio; live servers create no debug remotes. Every button shows **OK** or
**FAIL** with the server's message at the bottom of the panel. Copy any FAIL text into the report.

## 1. Boot (always runnable)
1. Press **Play** (F5), wait 10 s.
2. Output shows, with the same sha, and no red errors:
   - `ForgeLoop server starting ... game=game-001 ... sha=<sha>`
   - `ForgeLoop server services started count=<n> order=... trees=Forge,Game`
   - `ForgeLoop client controllers started count=<n> order=... trees=Forge,Game`
3. Copy those three lines into the report.

4. With the game stopped: Explorer → **Workspace** → Properties → **StreamingEnabled** is ticked, and
   **Players** → **CharacterAutoLoads** is unticked (D-025, D-026), and **Lighting** → **Technology** is
   **Future**.
5. Press **Play**: your ruler (crown and cape) appears at **your own kingdom's keep**. Characters only load
   once the game puts you in a kingdom (FL-0048), so a second or two with no character is normal.

**Pass:** all three lines, `game=game-001`, `trees=Forge,Game`, no red text, both properties as above, and the
ruler appears at your keep.

## Keys (as of FL-0053; the aerial view is the default since FL-0090)
| Action | PC | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrow keys | left stick | thumbstick |
| Jump | Space | A | jump button |
| Sprint | hold Left Shift | L3 (toggle) | "Sprint" button (toggle) |
| Toggle view (behind the ruler ↔ aerial) | V | Y | "View" button |
| Zoom | mouse wheel | — | pinch |
| Leave build mode | X or Q | B | Cancel button |
| Debug panel (Studio only) | F8 | — | "Debug (F8)" button |

## 2. See a colourful medieval kingdom (row 1; runnable from build B1)
Use **Test → Run** for this row (no avatar is needed). Fly with the Studio camera: right mouse button +
WASD, mouse wheel to zoom.
1. Output shows `WorldService ready ms=… terrainOps=… props=… parts=…`. Copy the line and note the ms.
2. Fly over the valley: a river with water, two bridges, four corner plots, the mountain ring, forests and
   fields. No holes at the world edge; nothing floating or sunk. Your plot (crimson in VS-1) is fully
   dressed; the other three are blocked out.
3. Lighting: warm late-morning light, haze, clouds. Note anything washed out or too dark.
4. **View → Stats**: note the FPS while flying.
5. Optional, **View → Command Bar**, paste and press Enter:
   `local C = game:GetService("CollectionService") print(#C:GetTagged("ResourceNode"), #C:GetTagged("BuildZone"), #C:GetTagged("ObjectiveZone"), #C:GetTagged("KingdomPlot"))`
   Expected: `38 12 1 4`.
6. Screenshots **W1** (the whole valley from high up), **W2** (the dressed plot close up), and **W3** (the
   keep and a house from a 3/4 view, about 35° to the side and 22° above; FORGE-02 calibrates the
   building look from it).

**Pass:** the valley as described, readable lighting, `WorldService ready` logged. **Fail:** holes, floating
or sunk props, unreadable lighting. Describe what you see next to the screenshot.

## 3. Rule from the throne with an aerial camera (row 2; runnable from B6 except the seat: waiting FL-0081)
1. Press **Play**. Your ruler (crown and cape in your kingdom's colour) appears at your keep. The **throne**
   stands on a dais in the keep's entrance arch. *Sitting on it waits on FL-0081*: until then write
   `SKIPPED (waiting FL-0081)` for the seat and check only that the throne is there and clear of the door.
2. The camera is an aerial view over your kingdom: pan (WASD or drag), zoom (wheel, about 40–220 studs),
   rotate (Q/E).
3. **Test → Device** → pick a phone. Drag pans, pinch zooms, two fingers rotate.
4. Tap or click a citizen, a building and an empty plot: each one is selected (its panel opens).
5. Optional: V switches to walking behind the ruler, and back.
6. Screenshots **R1** (ruler on the throne) and **R2** (the aerial view in the phone emulator).

**Pass:** ruler with crown and cape at the keep, throne visible (seated once FL-0081 lands); smooth pan, zoom
and rotate on PC and phone; tap selects. Known: citizens more than 150 studs from your ruler are hidden in
the aerial view (#39 M1, fix FL-0104); note it, it is not a fail.

## 4. Belong to a kingdom (row 3; runnable from B6)
1. Play. The HUD shows your kingdom's name, banner colour and member list.
2. **Test → Clients and Servers → Local Server, 2 players → Start**, twice:
   - with both clients in **one party** (Studio party simulation; FORGE-01 writes the exact steps here
     when #31 merges): they must get the same kingdom;
   - without a party: humans are spread over kingdoms.

   Write down the kingdom each client got.
3. Screenshot **K1**: the HUD.

**Pass:** auto-assigned to crimson, azure, emerald or gold; HUD name, colour and members correct; the
party stays together.

## 5. Watch AI citizens live and work (row 4; runnable from B6; `vs1.reseed` waits on FL-0104)
Preset: `vs1.reseed` (fails closed until FL-0104; skip step 3 until then).
1. At least **12** citizens of your kingdom. Each has a name, 2–3 traits and its own look.
2. Watch 60 s: they walk to work, gather or farm, carry goods to the storehouse; the HUD stockpile rises.
   Note the stockpile at the start and after 60 s.
3. Press `vs1.reseed` again: the **same** names and looks appear (same seed, same population).
   As of B6: `SKIPPED (waiting FL-0104)`.
4. Screenshot **C1**: citizens at work with the stockpile visible.

**Pass:** ≥ 12 distinct citizens, every job visible, the stockpile rose, no citizen stuck, same seed →
same people.

## 6. See that citizens think (row 4b; runnable from B6; conversation answers wait on FL-0079/FL-0088 #66)
1. Select a citizen. The card shows name, occupation, traits, mood, loyalty, current intent, family,
   friends and recent memories.
2. Kingdom panel → **Jobs**: press **+** on another job. A free citizen takes it and walks to the new work;
   press **−** and they go back. Three quick taps add three (B6).
3. Screenshot **C2**: the citizen card.

**Pass:** every field filled with real values; the job change happens in the world.

## 7. Run the kingdom economy (row 5; runnable from B6)
1. The HUD always shows food, wood, stone and gold. It rises with citizen work and falls with costs.
2. Upkeep: about one minute after the match starts, food falls once per minute.
3. Preset `vs1.hungry`: the kingdom is short of food until the next upkeep tick. Citizens' mood falls
   (card) and they work slower.

**Pass:** numbers move only when something in the world explains it; no negative values.

## 8. Construct and upgrade (row 6; runnable from B4 through the Build rail; ordering on a plot waits on FL-0081)
1. Open **Build** on the rail, choose a structure (House, Farm, Barracks and more) with its cost, place the
   ghost (R rotates; the fainter "Room" outline is the space kept for upgrades), then confirm. Ordering by
   selecting a free plot marker waits on FL-0081: write `SKIPPED (waiting FL-0081)` for that part.
   A spend of half or more of any resource asks you to confirm once more.
2. Builders walk over and raise it through visible stages. The cost leaves the treasury **once**.
3. Try a plot that is taken, or a structure you cannot afford: it is refused with a reason.
4. Upgrade the **Barracks** to level 2 (about 8 s for level 1 and 18 s for level 2, PROVISIONAL), then
   the **Keep**. Each level looks different.
5. Screenshots **B1** (mid-construction) and **B2** (Barracks level 2 next to level 1, or before/after).

**Pass:** costs shown and charged once, refusals explained, stages and levels visible.

## 9. Recruit and capture (row 7; waiting: FL-0052 Army server #70, FL-0060 Army drawer #63)
1. At the Barracks, recruit **3 soldiers** (paid once from the treasury).
2. Press **Send to capture**. They walk to the neutral Watchtower, a capture bar fills, and the tower
   takes your colour. Crown Points rise, and the slice summary appears (the first capture ends the
   slice: CONTRACTS G3).
3. Screenshots **O1** (capture in progress), **O2** (captured) and **O3** (summary).

**Pass:** charged once, soldiers obey, capture completes, Crown Points and summary appear.

## 10. Use the kingdom HUD and reputation screen (row 8; HUD and screen runnable from B6; history waits on FL-0080 #68)
1. The HUD shows resources, population, kingdom, Crown Points, the build/army/objective panels and the
   **six reputation values** (compassion, honor, competence, courage, authority, fear).
2. Press `vs1.repLow`, then `vs1.repHigh`. The values change. The reputation screen lists each change in
   its history ("Studio debug: …") and explains what each value means.
3. Screenshot **H1** (HUD) and **H2** (reputation screen with history).

**Pass:** all HUD parts present and current; the history matches what you did.

## 11. Decide in a conversation and see the result (row 9; waiting: FL-0079 server #77, FL-0088 panel #66; bubbles FL-0091 and content FL-0083 are on main; `vs1.request` / `vs1.strike` wait on FL-0104)
1. Within a minute at least one citizen shows a **thought bubble** with a real request. If none does,
   press `vs1.request`.
2. Select that citizen. A conversation opens with 2–4 choices. Pick one.
3. The citizen reacts, and the world changes visibly, at least:
   - your resources;
   - the citizen's loyalty and mood on their card;
   - a reputation value, with a history line;
   - a work boost, a strike or a follow-up.
4. Press `vs1.strike`: the farmers stop working until it is resolved (visible). `vs1.hungry` makes
   food-related requests more likely.
5. Screenshots **D1** (bubble), **D2** (conversation), **D3** (the visible result).

**Pass:** a real request, 2–4 choices, a reaction and at least three visible consequences.

## 12. First minutes guided (onboarding; waiting: FL-0092 onboarding v2 #45)
Start a fresh Play and follow the hints: inspect a citizen → build on a plot → answer a citizen →
recruit → capture. **Pass:** each hint appears at the right moment and can be skipped. (On main today the
onboarding still waits for the ruler to gather; that is FL-0092's to change.)

## M1 / M2 — two players (Test → Clients and Servers → Local Server, 2 players → Start)
(Later multiplayer checks M3–M8: `production/quality-gates/multiplayer-test-plan.md`.)
- **M1 (always runnable):** both client windows log the same sha and `trees=Forge,Game`; both rulers
  appear at their keeps and each sees the other move (with streaming on, a far ruler may not be visible
  until you walk closer).
- **M2 shared kingdom (runnable from B6):** both players can be in **one** kingdom (party) — the HUD
  member list shows both; resources one player gathers appear in the other's HUD; both see the same
  citizens in the same places. Then **Cleanup**.

## Performance note (G7; 1 minute, during row 4 or later)
In the **Server** window: **View → Script Performance**; note the Activity % of
`ServerScriptService.Forge.Main` while citizens work, and **View → Stats** frame rate. Paste both.

## Colour vision (D-033 (4), before VS-1 acceptance)
1. In Play, pan the aerial camera to a spot where at least two kingdoms' buildings and soldiers are in view; take a screenshot.
2. Open the Kingdom panel (Overview tab, standings visible); take a screenshot.
3. Send both screenshots to FORGE-05, who runs `production/quality-gates/cvd/cvd.py` over them (protanopia, deuteranopia, tritanopia) and records the result in `production/quality-gates/colour-vision.md`.
4. Pass: every kingdom is identifiable without colour (emblem, silhouette or name) in both views.
5. VS-1 acceptance (CONTRACTS G13.2, D-033 (3)): soldiers of different kingdoms are told apart by their helmet crest in the kingdom's tower style (spire, square, plume, dome), not only by torso colour; check two kingdoms' soldiers side by side in the grayscale/protanopia view.
6. Tritanopia: azure and emerald are told apart by tower silhouette and emblem in the four-kingdom screenshot.

## Report (paste into the FORGE-05 chat)
```
VS-1 playtest — date, build (B<n> / artifact / local), BuildInfo sha: <sha>
1 Boot: PASS/FAIL   2 World: ...   3 Throne+camera: ...   4 Kingdom: ...   5 Citizens: ...
6 Citizen card: ...   7 Economy: ...   8 Build: ...   9 Recruit+capture: ...   10 HUD+reputation: ...
11 Conversation: ...   12 Onboarding: ...   M1: ...   M2: ...   (SKIPPED (waiting) where marked)
WorldService ready ms: <ms>   FPS flying: <fps>   Perf: Main activity <x>%, FPS <y>
Screenshots: W1 W2 W3 R1 R2 K1 C1 C2 B1 B2 O1 O2 O3 H1 H2 D1 D2 D3 (attached)
<Output lines and any FAIL text from the debug panel>
```
