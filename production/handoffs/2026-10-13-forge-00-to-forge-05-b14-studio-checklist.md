# Handoff: FORGE-00 → FORGE-05 and the user's local Forge Studio session · B14 Studio checklist · 2026-10-13

## What I need / what I'm giving you
- **The checklist:** this is the Studio checklist for **B14**, the cinematic conversation set (#85, #108, #84, #121, #126 on top of B13 and #93).
- **Who runs it:** the user's **local Claude Code session**, which is connected to Roblox Studio on their Windows PC through Studio's built-in MCP server. It can also be run by hand.
- **Recording:** FORGE-05 records the results in `production/quality-gates/studio-runs.md` and folds the B14 rows into `games/game-001/STUDIO_PLAYTEST.md`.
- **Baseline:** section F captures "before" screenshots for the next cycle (D-048).

## Rules for the Studio session (read first)
- **Test only.** Open the build file, play it, and report:
  - Don't edit scripts. No `multi_edit` on the place.
  - Don't save the place over the build.
  - Don't publish.
  - Don't create assets on the account: no `generate_mesh`, `generate_material`, `upload_image` or `insert_asset`. Assets need the user's approval (AGENTS.md approval gates).
- **Evidence.** Every check is PASS, FAIL or NOT RUN, with evidence:
  - a `screen_capture` image saved under the check's ID (e.g. `B14-C3.png`);
  - the Output lines (`get_console_output`);
  - or a value returned by `execute_luau`.
  Say "unverified" for anything you only inferred.
- **Real input first.** For the conversation flow, use `user_mouse_input` and `user_keyboard_input` like a player would. `execute_luau` is only for presets, reading state and measuring.

## Setup
**Build:** B14 = main `3691475` (BuildInfo sha `369147563493…`).

1. **Get the build.** Use the `AIKingdoms-B14-<sha>.rbxl` FORGE-00 sends, or the CI artifact `forgeloop-game001-<sha>`: GitHub → ForgeLoop → Actions → the CI run on that `main` sha → Artifacts. Studio → **File → Open from File…**.
2. **Check the sha.** `get_studio_state` shows Edit mode. Then `execute_luau` (Edit): `return require(game.ReplicatedStorage.Forge.BuildInfo).sha`. Note the sha. (If BuildInfo is a ModuleScript elsewhere, use `search_game_tree` with the keyword `BuildInfo`.)
3. **Start play.** `start_stop_play` → start. Wait 10 s.

**Useful facts:**
- Debug presets run from the client: `execute_luau` (Client): `return game.ReplicatedStorage.ForgeDebug.Run:InvokeServer("preset", "vs1.request")`.
- Citizen rigs live in `workspace.KingdomEntities`; each model has the attribute `EntityId`.
- A request bubble is a BillboardGui named `ForgeCitizenBubble`, parented to the citizen model, with the attribute `BubbleKind`.
- The citizen card has a `Talk` button.
- The conversation stage is `PlayerGui…Conversation`; its footer is `Done` after answering, `Close` before.
- Camera keys: V toggles aerial ↔ behind the ruler; WASD pans; Q/E rotate; the wheel zooms.

## A. Boot (regression)
| ID | Check | Pass |
|---|---|---|
| A1 | `get_console_output` after 10 s | `ForgeLoop server starting … game=game-001 … sha=<sha>`, `… services started …`, `… client controllers started …`, all with the same sha. **No red errors.** Copy the lines. |
| A2 | `screen_capture` of the default view | the aerial view over your own kingdom, ruler at the keep (`B14-A2.png`) |

## B. Cinematic conversation — the B14 feature
| ID | Check | Pass |
|---|---|---|
| B1 | (If `vs1.request` answers "no citizen … can raise any", let the kingdom gather for 2–3 minutes first. Every request needs stock, e.g. 120 wood; see STUDIO_PLAYTEST §11.) Run preset `vs1.request`; wait up to 10 s; `search_game_tree` for `ForgeCitizenBubble`; `screen_capture` at the default aerial zoom | a citizen shows a request bubble; screenshot `B14-B1.png`. Also note **how easy the bubble is to see at this zoom** (baseline for D-048 item 5). |
| B2 | Record the camera, `execute_luau` (Client): `local c = workspace.CurrentCamera return tostring(c.CFrame), c.FieldOfView`. Then click that citizen with `user_mouse_input`, aiming at the citizen model or bubble, and press **Talk** on the card | the camera glides to the citizen's face. The screen dims behind the stage, a 3D portrait of **that** citizen rises (same skin, hair and outfit as the rig), and a speech bubble shows the question. You see 2–4 choices, each with its cost and any risk with its chance. `B14-B2.png` |
| B3 | Read the question and choices | real content: no ids such as `decision_…`, no `TODO`, no empty buttons. Copy the question text and choice labels. |
| B4 | Do nothing for 20 s, then `screen_capture` | the citizen stays where they stopped, **facing your ruler**, and doesn't walk off. `B14-B4.png` |
| B5 | Pick a choice that costs something you can afford | the portrait plays a reaction pose that fits the answer (happy, grateful, angry, …). Consequence chips appear, the resources change once, and the stage stays open while you read. `B14-B5.png` |
| B6 | Wait. Note the seconds from choosing until the citizen walks away (`os.clock` in `execute_luau`, or screenshots 2 s apart) | the citizen is held while the stage is open, and released **when you press Done, or at most 12 s after choosing**, never sooner while you're still reading (CONTRACTS v0.4-g9f) |
| B7 | After the stage closes, read the camera again with the same `execute_luau` | the camera is back where it was before Talk, in the same mode (aerial or behind the ruler). The CFrame is close to the one recorded in B2. `B14-B7.png` |
| B8 | Open the citizen's card again, and Reputation → History | the loyalty and mood on the card changed, and a readable history line exists with **no raw ids** (e.g. no `ruler_visit` or `soldiers_recruited`) |

## C. Closing paths (every way out must release the citizen and restore the camera)
| ID | Check | Pass |
|---|---|---|
| C1 | `vs1.request` → Talk → close with the **X** (or `Close`) before answering | the stage closes, the camera restores, the citizen walks away within a few seconds, and the bubble stays up. Talk again gives the **same** question. |
| C2 | Talk → answer → press **Done** at once | the stage closes, the citizen is released at once, and the camera restores |
| C3 | Talk, then press **V** (switch view) or Esc while the stage is open | nothing breaks. After closing, the camera is in a sane view (not stuck, not inside a wall). Note what happened. |
| C4 | Talk while in the view behind the ruler (press V first), then answer and close | the camera restores to the view behind the ruler, not the aerial view |
| C5 | Talk to a citizen standing close to a building or wall | the camera doesn't clip into geometry. If the citizen gets pushed more than about 2 studs, the camera stops following instead of jerking. `B14-C5.png` |

## D. Two players (optional, M1: Test → Clients and Servers → Local Server, 2 players)
| ID | Check | Pass |
|---|---|---|
| D1 | Player 1 opens a conversation and player 2 (same kingdom) taps the same citizen | player 2 can't start a second conversation with the held citizen. Nothing breaks. |
| D2 | Player 1 leaves the game while the stage is open | the citizen is released (within the next refresh) |

## E. Regression from B13 (short)
| ID | Check | Pass |
|---|---|---|
| E1 | Let it run 3–4 minutes with food in stock; Kingdom panel | the population rises, and the food pill doesn't drop at each birth |
| E2 | Recruit 3 soldiers (build a Barracks first if needed) | exactly one toast; History shows a readable line |
| E3 | `get_console_output` at the end | no red errors. Copy any warnings. |
| E4 | Stats (`execute_luau` (Client): `return workspace:GetRealPhysicsFPS()`), or Studio's Stats panel, during a conversation | note the FPS. A Studio number is indicative only. |

## F. Baseline screenshots for the next cycle (D-048; no pass/fail)
Capture these at the default aerial zoom and once zoomed in, so B15 can be compared:
- **F1:** your starting kingdom's farms, with any trees or rocks inside fields or build plots. Count them.
- **F2:** a close-up of trees and rocks.
- **F3:** a close-up of 3–4 citizens with different jobs. Can you tell the jobs apart from the air?
- **F4:** a request bubble at the default zoom and at maximum zoom-out.
- **F5:** start placing a House and a Wall. Does **R** rotate the ghost? Note what happens.

## Report (paste back to FORGE-00)
```
B14 Studio run — BuildInfo sha: <sha> — place: <artifact | local file> — Studio <version>
A1 PASS/FAIL … | A2 …
B1 … B8 (with the B3 question text, the B6 seconds and the B7 camera match)
C1 … C5 | D1 D2 (or NOT RUN) | E1 … E4 (FPS value)
F1 count of obstructions, F5 rotation result
Red errors: <lines or none>
Screenshots: <file names>
```

## Next actions for the receiver
- **FORGE-05:** fold the B14 rows into `STUDIO_PLAYTEST.md` §11 and record the run in `studio-runs.md` when the report arrives.
- **FORGE-00:** triage FAILs into tasks (★ for B15).

## B15 additions (main `b2e3164`, BuildInfo `b2e316414255…`): the user's first-playtest fixes
Run sections A–E on B15 too (B15 contains B14). Then:

| ID | Check | Pass |
|---|---|---|
| G1 | Your starting farms from the aerial view and from the ground (`screen_capture` both) | no tree, rock or gold vein inside a crop field, the front yard or a plot's flanks. Compare with F1 if you have it. |
| G2 | A request bubble at the default zoom and fully zoomed out (`vs1.request`; gather first if refused) | easy to spot; drawn over roofs and trees; a coloured badge (! request, ? concern, … idea); a new request pops twice |
| G3 | Click the bubble | that citizen's card opens. Then press B (build) and click a bubble: it places instead of opening the card (known). |
| G4 | Hover a citizen, then click it | a light outline on hover, a gold outline when selected |
| G5 | Tap a free plot marker → House → Turn once → place | the picker said "Faces right"; the house stands turned that way, its door matching the ghost's arrow |
| G6 | Build rail → House → press R, then Shift+R | the ghost turns 90° each way and the Rotate button shows the facing; it is placed as shown |
| G7 | Gamepad only, if you have one: Y while placing | **known:** it flips the camera view instead of turning (FORGE-03 follow-up). Note what happens. |

**Report:** add G1–G7 to the report block above.

## B16 additions (main `e447364`, BuildInfo `e44736414c4f…`)
| ID | Check | Pass |
|---|---|---|
| H1 | Trees, rocks and a farm, at the default zoom and close up; compare with B15 / F2 | pines layered, boulders angular with moss. **Known:** oaks and birches are still sphere clusters, and wheat is flat planks (interim art). |
| H2 | Ore and quarry nodes from the air | gold, iron and crystal tell apart by colour |
| H3 | Place two wall pieces end to end | they join with no gap |
| H4 | Gamepad (or Studio's emulator) while placing | R1/L1 turn the ghost; Y flips the view |

## B17 additions (main `41a70e8`, BuildInfo `41a70e8baadb…`): base editing and clean farms
On a mouse, a left press confirms a move, so pan with WASD while moving. FORGE-05's U18 and E12 rows in STUDIO_PLAYTEST hold the detailed steps.

| ID | Check | Pass |
|---|---|---|
| I1 | Tap one of your completed buildings → **Move** → move the mouse, then click a free spot | the ghost follows; the building moves there with the same level; no resources are charged or refunded |
| I2 | Move again: press R (or R1) to turn, then tap a free plot marker | it snaps to the plot, facing as shown |
| I3 | Start a House, and while it is under construction, Move it | construction progress is kept, and the builders walk to the new spot and continue |
| I4 | Move a Farm that has workers | the workers follow it and keep farming |
| I5 | Barracks with a recruit in training → Move | the queue continues; the new soldier appears at the new spot |
| I6 | Refusals: try to Move the keep; move the same building twice within 10 s; try to place on a crop field, plot road or spawn area | each is refused with a clear message |
| I7 | Re-check G1: every starting farm from the air and from the ground | no tree, rock, bush or node inside a field, front yard or plot flank |
| I8 | A moved building next to your ruler | your character is never trapped or stuck inside it |


## B18 additions (main `f3298dd`, BuildInfo `f3298dd50b42…`): citizens' new look and kingdom consequences
| ID | Check | Pass |
|---|---|---|
| J1 | 3–4 citizens with different jobs, from the default aerial zoom and close up | jobs tell apart by silhouette and tool. **Known (interim art, D-051):** the pick reads as a hammer; variation is limited. |
| J2 | Make citizens cheer (answer a request generously, or watch a celebration) and screenshot close up | no arm or tool passes into a head. **Known:** the cheer is now wider, arms out. |
| J3 | Open a drawer, then the conversation stage, and press the back key (Esc, or B on a gamepad) | each press steps back exactly one level |
| J4 | Preset `vs1.riot`, then watch for about 4 minutes (STUDIO_PLAYTEST / `roblox/studio-tests/gameplay.md` K12) | after about 2 minutes one building (never the keep) gets `Burning = true` and loses Hp, never below a quarter; rioters stop work with the grumble cue, **not** "On strike"; the burning building produces nothing; the riot ends within 90 s. **Known:** no notice text and no riot placard yet (FORGE-04). |
| J5 | Spend the kingdom's food so citizens go hungry, then watch for about 2 minutes (K12 step 3) | the hungriest citizens grumble; no red errors |

## B19 additions (main `2923bd1`, BuildInfo `2923bd13de1d…`): consequences on screen and the Waiting button
FORGE-05's B19 asks in `production/quality-gates/studio-runs.md` and FORGE-04's E13 hold the detailed steps.

| ID | Check | Pass |
|---|---|---|
| K1 | Preset `vs1.riot`; when a building catches fire, `screen_capture` at the start zoom and fully zoomed out | flames and a smoke column on the burning building (never the keep); rioters wear an orange "Rioting" placard, readable at both zooms |
| K2 | Watch the riot start and end | two separate toasts (start and end), no "×2"; "A rioter set it alight" when there is one. **Known:** no crackle sound (no asset). |
| K3 | If a strike or food shortage happens (J5 helps), watch the toasts | one toast at the start and one at the end |
| K4 | With a request open, tap the 💬 Waiting button on the rail | it shows the count; a tap centres on the next citizen and opens their card; it hides while placing, moving, talking and in the walking view |
| K5 | Studio device emulator at a phone size (667×375) | placards, toasts and the Waiting button fit and don't overlap |
| K6 | `get_console_output` at the end | no red errors |

## B20 additions (main `9b688ec`, BuildInfo `9b688ecb81c6…`): the real four-kingdom match
B20 starts the **full match** by default. To run the older B14–B19 rows in the short slice, use the debug command `match.mode slice` first.

| ID | Check | Pass |
|---|---|---|
| L1 | Start Play; read the phase bar | the phase bar shows Founding with a timer and names the next phase; the other three kingdoms are run by AI governors and build on their own |
| L2 | Debug `match.phase Conflict`, then watch the rivals for a few minutes (Rivals tab, notices) | an AI kingdom declares war on someone; war notices appear; soldiers march and fight, with hit flashes and deaths (kneel and fade, no gore) |
| L3 | Recruit until the cap | the 16th soldier is refused with an "army full" message (`army_cap`) |
| L4 | Let an AI army attack your keep (or weaken it with debug), so your kingdom falls | you become a spectator: the spectate camera works. **Known:** the spectate screen arrives in B20.1 |
| L5 | Let the match run out (or jump to Endgame and wait) | the match ends on Crown Points and Results shows. **Known:** the recap screen arrives in B20.1 |
| L6 | Debug `match.mode slice` | the match restarts as the VS-1 slice; one B19 row still passes |
| L7 | Output during an AI war, and Studio's Stats panel | no red errors; note FPS and anything that hitches |

## B20.1 additions (main `2f6dc35`, BuildInfo `2f6dc35b36e1…`): you declare war and make peace
**Known:** the war, siege and raid notices and the far-entity tiers are **not** in B20.1 (stacked-PR merge gap); they arrive in B20.2.

| ID | Check | Pass |
|---|---|---|
| M1 | Debug `match.phase Conflict`, then open Kingdom, then Rivals, and press Declare war on one rival | after a confirm step, war is declared; the rival's row shows "at war"; their soldiers start fighting yours |
| M2 | Propose peace; let the AI accept, or wait | the row shows the open proposal; once both agree, peace holds and the war stops |
| M3 | 2-player Local Server, both in one kingdom | only the player who joined first can declare war or accept peace. The other sees "Ask <senior> to declare war"; pressing it gives the senior a notice |
| M4 | Second player joins after Founding began | for 2 minutes they see "New ruler · m:ss" on war and Accept peace, and can't move buildings |
| M5 | Let your kingdom fall (or force it) | the spectate screen shows who defeated you and a list of what to watch; Leave asks "Leave the match?" first |

## B20.2 additions (main `d03fd70`, BuildInfo `d03fd70f6f1a…`): war notices and far-entity tiers
Run the B20.1 rows (M1–M5) on B20.2, then:

| ID | Check | Pass |
|---|---|---|
| N1 | Declare war, or let an AI declare on you | one "war declared" notice per declaration; the declaring senior ruler gets none, their co-rulers and the target do |
| N2 | Let an enemy army hit your keep | a siege notice when it starts; an "ended" notice about 20 s after the last hit |
| N3 | Enemy soldiers enter your territory | a raid notice and a "Go to the raid" button (phone too); it ends about 10 s after they leave |
| N4 | Pan the camera far from your kingdom during an AI war | units under the camera move smoothly; far-off citizens step at about 2 Hz; your own soldiers never freeze |
| N5 | MicroProfiler during Endgame | note server and client frame time (also gates #200's paint cost) |

## B21 additions (main `ebdd564`, BuildInfo `ebdd56445476…`): sieges decide wars
Run the B20.1 rows (M1–M5) and the B20.2 rows (N1–N5) on B21, then the B21 asks in `production/quality-gates/studio-runs.md` (asks 1–4), summarised here:

| ID | Check | Pass |
|---|---|---|
| O1 | Play Solo, `match.phase Conflict`, watch from the aerial view | within about 10 minutes an AI governor builds rams, besieges a rival keep (siege notice) and takes it; note the time from Conflict to the first fall (screenshot B21-1) |
| O2 | At war with an AI, keep soldiers at your keep | an assault of about your size breaks against it; note whether it held |
| O3 | Recruit a ram (barracks level 2, wood 200) and attack a building | the ram hits buildings far harder than soldiers do (screenshot B21-2) |
| O4 | Output window through a full match | copy every red line; citizens still use the part-built rig (no mesh data yet) |

## B21.1 additions (main `ec52722`, BuildInfo `ec52722284aa…`): imported-mesh citizens (owner import), phone fit
Run the B21 rows (O1–O4) on B21.1. Then do the import per `games/game-001/art/IMPORT_CHARACTERS.md` (Asset Privacy on BEFORE any upload), and the studio-runs B21.1 asks 1–6, summarised here:

| ID | Check | Pass |
|---|---|---|
| P1 | Before the import, play | identical to B21 (part-built citizens) |
| P2 | Bulk Import `citizen_kit.fbx`, run `import_char_kit.luau` in the Command Bar | Output ends `RESULT: OK`, `N imported, 0 missing`, no `stripped:` lines; paste the Output |
| P3 | Play: citizens, ruler, soldiers of each kingdom, close and aerial | `KingdomEntities` citizens hold MeshParts; jobs, crest and kingdom colours read; walk and work animations play; screenshots close and aerial |
| P4 | MicroProfiler at Endgame; Render Stats on a 667×375 phone | note FPS, triangles and draw calls at the population caps |
| P5 | Phone 667×375: the drawer, spectate, Rivals and the recap | the drawer shows jobs, reputation, army and standings rows; buttons are easy to tap |
| P6 | Output through a full match | copy every red line; delete `CitizenKit` to revert (IMPORT_CHARACTERS §4) |

## B21.2 additions (main `6a738d7`, BuildInfo `6a738d71cdae…`): arena venue, silhouettes
Run the B21 rows (O1–O4) and the B21.1 rows (P1–P6) on B21.2, importing **this build's** `citizen_kit.fbx`. Then:

| ID | Check | Pass |
|---|---|---|
| Q1 | Aerial view of the map centre, then walk to the arena gate | the venue stands at the neutral centre the whole match: stands, royal boxes, gate and duel ring; it reads as an arena from the air (screenshot) |
| Q2 | After the import, the aerial view at 170 studs over a busy kingdom | each job reads as a differently coloured shape (farmer, merchant and soldier clearly; the others at least partly); note any you can't tell apart |
| Q3 | Output through a full match | copy every red line |

## B21.3 additions (main `5a74e42`, BuildInfo `5a74e4228072…`): tips, How to play, siege alert, drag, desktop
Run the B21.2 rows (Q1–Q3) on B21.3, importing **this build's** `citizen_kit.fbx`, then the studio-runs B21.3 asks. Summary:

| ID | Check | Pass |
|---|---|---|
| R1 | Kingdom menu → How to play, on desktop and in the 667×375 emulator | six short cards, Back and Next work, the phase lengths look right; the Crown Arena card describes B22 (not playable yet) |
| R2 | Play into Conflict and get besieged (or `match.phase Conflict`, then let an AI attack) | a war or siege tip shows once, "Got it" closes it, and it never blocks play; a siege alert names your keep and the "Siege" rail button jumps there |
| R3 | Move a building: press and hold, then drag to the screen edge | it follows your finger or mouse, the camera edge-pans, and the drop snaps to a slot |
| R4 | Desktop at 1280×720 and 1920×1080 | the Kingdom drawer's Rivals tab no longer touches Close; nothing is clipped |
| R5 | After the import: idle citizens and hat jobs at 40 and 170 studs | idle citizens wear a headband and pack; hat jobs show a hair tuft (screenshot) |
| R6 | Output through a full match | copy every red line |

## B22 additions (main `e8ea78c`, BuildInfo `e8ea78c4e099…`): the Crown Arena is playable, nature meshes
Run R1–R6 on B22 first, then these. FORGE-05's B22 asks in `production/quality-gates/studio-runs.md` hold the detailed steps (E16 step 8, E20 steps 4–5). To reach the arena fast: in the server console, `match.mode match`, then `match.phase Endgame`, then wait about 10 min (or play a full match).

| ID | Check | Pass |
|---|---|---|
| S1 | Reach the arena: the two kingdoms with the most Crown Points qualify | the vote (no vote panel yet: it waits about 10 s, then leadership picks; FL-0142), then the loadout (weapon, armour, up to 2 support triggers), the intro, the duel, the crowning; no step hangs. Known in B22: the picked weapon and armour are not shown on the champions, and the venue stays neutral (FL-0140); champions do not animate their actions (FL-0141) |
| S2 | Duel against the AI champion (play solo) | **Known in B22: the AI champion has no body yet, so you fight an invisible opponent that is always in reach (FL-0140).** Check that light, heavy, block, parry and dodge register in the arena HUD, that the AI's attacks register too, that either side can win, and that the result matches the HP bars |
| S3 | Start the intro while sitting on your throne (the default overview camera) | you stand up on your mark at the intro, not on the throne and not at the ring edge |
| S4 | During the duel, walk or run away from the other champion | you stop at the ring edge (radius about 21 studs) and face the centre; running away cannot run out the clock |
| S5 | Two clients in a duel, one holds sprint (E16 step 8) | both champions move at the same speed; sprint works again after the crowning |
| S6 | Press Reset mid-duel | you come back on your mark (or at the ring edge, facing in), the duel goes on, and WalkSpeed is normal after the crowning |
| S7 | Join a second client mid-duel (E20 step 5) | the new client sees the stands, the crowd and the arena HUD for the current stage at once |
| S8 | The crowd and stands (E20 step 4) | both stands fill with figures in their kingdom colours; neutral stands stay grey; no frame hitch when the crowd appears (MicroProfiler) |
| S9 | The support meter and the arena recap | the meter shows your tier and top reasons; offered triggers match your key citizens; nothing feels unfair or unexplained |
| S10 | Kingdom menu → How to play → the Crown Arena card | it describes the arena as it now plays |
| S11 | Phone emulator (667×375): duel buttons and the arena HUD | buttons sit around the jump button without covering it; the HUD and subtitles fit |
| S12 | Optional: import `env_kit.fbx` (art/IMPORT_ENVIRONMENT.md) after the citizen kit, then Play (F5) | server Output has **no** `Kit.prop: the imported … is not used` line; `envMeshStatus()` shows `rejected` empty and `accepted` > 0 (not 56; the doc is corrected in B22.1); trees and rocks look like one world with the buildings (aerial and 82-stud screenshots); Render Stats on a phone |
| S13 | Mesh citizens in Play (after the citizen kit import; Bulk Import `citizen_kit.fbx` again before running the B22 import script, so every piece gets Box) | in Explorer during Play, the citizens under `Workspace.KingdomEntities` are MeshParts, not blocks. Rigs are built on the client, so check in the client view, not the server Output (a rig fallback is not logged) |
| S14 | Output through a full match ending in the arena | copy every red line |
