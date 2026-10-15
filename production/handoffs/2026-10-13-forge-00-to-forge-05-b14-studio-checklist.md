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

