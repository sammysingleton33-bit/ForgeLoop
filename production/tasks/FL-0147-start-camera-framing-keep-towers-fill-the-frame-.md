---
id: FL-0147
title: "Start camera framing: keep towers fill the frame, no start citizen in view"
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence:
  - "check.sh OVERALL PASS on c56d3308 (main 8832414a; game-001 2885/0, framework 581/0); RulerCamera 48/48 incl. the real-Kit keep check (the #284 view fails it); FL-0147 8/8, FL-0090 28/28 CAUGHT; chosen view at ~30 s: crimson 7/12 citizens, keep 8.8 % (largest part 2.4 %), azure 9/12, 8.9 %; renders opened (Cycles, headless). Studio E22 not run"
---

# Start camera framing: keep towers fill the frame, no start citizen in view

## Outcome
When a ruler presses Play, the first overview frame shows their village and some working citizens. Nothing cuts across it: no keep roof or tower fills the bottom of the screen. Citizens stay readable, at about 6 % of screen height (D-059). This is the view the owner judges the game by.

## Context
- **D-059 (owner visual playtest of B22):** prioritise what the default camera shows.
- **#284 set the start view:** zoom 70, FOV 55, pitch 42.5°, focus `startAhead` 40 studs in front of the throne, yaw from the camera behind the seated ruler. The code is `RulerCameraController.luau:149-151` and `:1154-1158`.
- **FORGE-02's real-start-camera render** (#296 head ec8cb552, `art/reviews/img/vis1-ground-{before,after}-default_crimson.jpg`; FORGE-00 opened both):
  - The camera sits about 47 studs above the ruler's root and over the middle of the keep. Its horizontal setback is 70·cos 42.5° ≈ 52 studs, more than the 40 ahead.
  - So the keep's front tower cones and gatehouse fill the bottom quarter of the frame.
  - None of the 12 start citizens is in the frame; they are at the fields, camp, quarry and storehouse.
  - This is headless; the seated root height is an estimate. The owner's B22.1 screenshots will confirm or refute it.

## Requirements
- Choose the start framing from renders at the real camera values, not from arithmetic alone. Try at least these three candidates:
  - **A:** a larger `startAhead`, or a focus beyond the keep's front, so the camera is in front of the keep.
  - **B:** reverse the view, so the camera looks back across the yard at the keep's front, with the yard and citizens in the foreground.
  - **C:** focus on the centroid of the start citizens' first workplaces, keeping the keep in view.
- Use FORGE-02's `blender/scripts/render_world.py` start-view mode with the 12-citizen start set. Ask FORGE-02 if it needs a parameter for the candidate camera.
- Keep zoom 70, FOV 55 and the 6 % citizen height unless a candidate needs a small change. Say why if it does.
- Do not move the throne or the keep; Layout belongs to FORGE-02 and Kit changes need their PR.
- Walk mode, the duel camera, conversation shots and the zoom range are unchanged.
- Pin the chosen numbers in `RulerCamera.spec`. Add a pure check that the start camera is not inside or directly above the keep's footprint.

## Validation
- Automated: `RulerCamera.spec` and the full `bash roblox/scripts/check.sh`.
- Renders: the A/B/C candidate renders plus the chosen one, for two kingdoms, opened and judged in the PR. State how many start citizens are in the frame at t=0 and at about 30 s.
- Studio (owner, unverified until then): the first frame after Play shows the village and citizens, with no roof across the bottom.

## Completion criteria
- [ ] A, B and C rendered at the real camera values and compared in the PR.
- [ ] The chosen start framing is on main, with specs.
- [ ] In the chosen render at about 30 s, at least 4 of the 12 start citizens are in the frame, and no keep part covers more than 10 % of it.

## Log
- 2026-10-22 FORGE-00: filed from FORGE-02's #296 start-view render (11:30 UTC). P0 under D-059. It goes in B22.2 if it's ready in time; otherwise it's the first item of B22.3.
- 2026-10-22 forge-00: SPECIFIED → READY. Filed from #296 start-view render; P0 under D-059
- 2026-10-22 forge-04: READY → BUILDING. FORGE-04 started: A/B/C start cameras measured on FORGE-02's world dump (12 start citizens) and rendered with render_world.py; B (looking back at the keep from 20 studs before the throne) chosen
- 2026-10-22 forge-04: BUILDING → REVIEW. PR open on forge/04-experience-start-camera: the first view looks back across the yard at the keep from 20 studs before the throne (startAhead 20, startTurn 180; FORGE-00 approved B at 20). A/B/C measured and rendered for crimson and azure (design/pacing/camera/fl0147-start-views.jpg)
