# AI Kingdoms — VS-1 Studio playtest (gate G6; FL-0047, owner FORGE-05)

VS-1 is accepted **only** by this playtest (BRIEF §4). It takes about 20 minutes. You (the user) run
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

## 1. Boot (always runnable)
1. Press **Play** (F5), wait 10 s.
2. Output shows, with the same sha, and no red errors:
   - `ForgeLoop server starting ... game=game-001 ... sha=<sha>`
   - `ForgeLoop server services started count=<n> order=... trees=Forge,Game`
   - `ForgeLoop client controllers started count=<n> order=... trees=Forge,Game`
3. Copy those three lines into the report.

4. With the game stopped: Explorer → **Workspace** → Properties → **StreamingEnabled** is ticked, and
   **Players** → **CharacterAutoLoads** is unticked (D-025, D-026).
5. Until FL-0048 spawns rulers, **no character appears** when you press Play (the camera is free).
   That is correct: characters only load when the game puts you in a kingdom.

**Pass:** all three lines, `game=game-001`, `trees=Forge,Game`, no red text, both properties as above.

## 2. Enter a medieval world — VS-1 row 1 (waiting: FL-0054 Kit, FL-0055 World)
1. Play. You spawn at **your kingdom's keep** in a sunny valley: river, forest, quarry, farm fields,
   roads. One kingdom plot is fully dressed; the other three are blocked out.
   Your ruler must appear **only** at your own keep: never at the map centre, never falling, never
   respawning somewhere else (CharacterAutoLoads is off; the game spawns you).
2. Screenshot **W1**: your character in front of the keep (third-person view).
3. Screenshot **W2**: zoomed out / from high up so the river and at least two kingdom plots are visible.

**Pass:** spawn at your keep (not at the map centre or falling), no grey placeholder look on the dressed
kingdom, nothing floating or sunk. **Fail:** anything else — describe it next to the screenshot.

## 3. Control the ruler — row 2 (waiting: FL-0053 controller, FL-0056 ruler look)
1. Walk, sprint, turn and zoom the camera (exact keys filled in by FL-0053).
2. **Test → Device** (emulator) → pick a phone → walk with the on-screen thumbstick.
3. Screenshot **R1**: your ruler close-up (crown and cape in your kingdom colour).

**Pass:** smooth movement and camera on PC and in the phone emulator; crown + cape visible.

## 4. Belong to a kingdom — row 3 (waiting: FL-0048 KingdomService, FL-0059 HUD)
1. Play. The HUD shows your kingdom's name and banner colour and its member list.
2. Screenshot **K1**: the HUD.
3. Two players: see **M2** below.

**Pass:** auto-assigned to one of crimson / azure / emerald / gold; HUD name, colour and members correct.

## 5. AI citizens working — row 4 (waiting: FL-0049 entities, FL-0050 citizens)
1. Stand near your storehouse for 60 s.
2. Count the citizens of your kingdom (at least **12**). You can see farmers, woodcutters, miners,
   builders and haulers by their look and tool.
3. They walk to work, work (animation/sound), carry goods to the storehouse; the HUD stockpile rises.
4. Screenshot **C1**: citizens at work with the HUD stockpile visible; note the stockpile numbers at
   the start and after 60 s.

**Pass:** ≥ 12 citizens, every job visible, stockpile rose during the minute, no citizen stuck in place.

## 6. Gather resources — row 5 (waiting: FL-0051 gathering, FL-0058 treasury, FL-0062 feedback)
1. Walk to a tree, harvest it (key filled in by FL-0051). Then a rock.
2. You get feedback (sound/VFX/number) and the HUD treasury rises by the shown amount.
3. Spam the harvest key on one tree: the cooldown stops extra gains (no free resources).

**Pass:** each harvest adds exactly what is shown, cooldown respected, node depletes/regrows as designed.

## 7. Construct and upgrade — row 6 (waiting: FL-0051 construction, FL-0059 build menu, FL-0054 stages)
1. Open the build menu: House, Farm, Barracks, Watchtower with costs.
2. Place a **House** on valid ground in your territory; try once on invalid ground (water/outside your
   land/overlapping): it is refused with a reason.
3. Builders walk there and raise it through visible stages; the cost leaves the treasury once.
4. Upgrade the **keep to level 2** when affordable.
5. Screenshots **B1** (a building mid-construction) and **B2** (keep level 2).

**Pass:** costs shown and charged once; invalid placement refused; stages visible; keep upgrades.

## 8. Military and objective — row 7 (waiting: FL-0052 military/objective, FL-0060 panels)
1. At the Barracks, recruit **3 soldiers** (paid from the treasury).
2. Command them to capture the neutral **Watchtower**. A capture bar fills while only your units stand
   there; your kingdom gains territory and Crown Points; the objective panel tracks progress.
3. Screenshot **O1**: capture in progress; **O2**: captured.

**Pass:** recruitment charged once, soldiers obey, capture completes, territory + Crown Points awarded.

## 9. First two minutes guided — onboarding (waiting: FL-0062)
Start a fresh Play; follow the hints gather → build → recruit → capture. **Pass:** each hint appears at
the right moment and can be skipped.

## M1 / M2 — two players (Test → Clients and Servers → Local Server, 2 players → Start)
(Later multiplayer checks M3–M8: `production/quality-gates/multiplayer-test-plan.md`.)
- **M1 (always runnable):** both client windows log the same sha and `trees=Forge,Game`. Once FL-0048
  spawns rulers: both rulers appear at their keeps and each sees the other move (with streaming on,
  a far ruler may not be visible until you walk closer).
- **M2 shared kingdom (waiting: FL-0048):** both players can be in **one** kingdom (party) — the HUD
  member list shows both; resources one player gathers appear in the other's HUD; both see the same
  citizens in the same places. Then **Cleanup**.

## Performance note (G7; 1 minute, during check 5)
In the **Server** window: **View → Script Performance**; note the Activity % of
`ServerScriptService.Forge.Main` while citizens work, and **View → Stats** frame rate. Paste both.

## Report (paste into the FORGE-05 chat)
```
VS-1 playtest — date, setup (artifact/local), BuildInfo sha: <sha>
1 Boot: PASS/FAIL   2 World: PASS/FAIL/SKIPPED   3 Ruler: ...   4 Kingdom: ...   5 Citizens: ...
6 Gather: ...   7 Build: ...   8 Military: ...   9 Onboarding: ...   M1: ...   M2: ...
Perf: Main activity <x>%, FPS <y>
Screenshots: W1 W2 R1 K1 C1 B1 B2 O1 O2 (attached)
<Output lines>
```
