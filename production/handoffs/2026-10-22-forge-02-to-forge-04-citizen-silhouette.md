# Handoff: FORGE-02 -> FORGE-04 (cc FORGE-00, FORGE-01) · citizen silhouette pass 2 · the x1.25 ScaleTo interplay · 2026-10-22

## What changed (Kit/Character.luau, citizens only; soldiers, governors and the mesh kit keep 1)
Same part count (idle 8, working jobs 11, rig <= 11: D-032/D-048), same joints, same Pose, same Root height (3.2), torso / arms / legs untouched. Silhouette parts are drawn bigger:

| part | before | now | how |
|---|---|---|---|
| head | 1.6 across, centre 4.64 | **2.08** (x1.3), centre 4.932 (neck + 0.74 x 1.3 + 0.07 lift) | `Character.HEAD_SCALE` 1.3, `NECK_LIFT` 0.07 (it still touches the torso top, 3.9) |
| hats and hair (everything welded to the head) | 3.1 / 1.5 / 1.9 / 1.8 across (farmer / woodcutter / miner / builder), hair ball 1.66 | farmer **3.41** (x1.1), woodcutter **1.95**, miner **2.47**, builder **2.34** (x1.3), hair ball 2.16 | scaled about the head centre; discs and drums are re-seated so the head enters them by the old depth (<= 0.4 holds); head details (crown, pompom, visor) follow; `Character.HAT_SCALE` = { farmer = 1.1 } because the work slots are 3.5 apart and a x1.3 straw disc (4.0) would overlap its neighbour |
| tool handle (cylinder length) | hoe 5.2, axe 3.9, pick 5.4, mallet 3.0 | **6.76, 5.07, 7.02, 3.45** (x1.3, mallet x1.15) | scaled about the butt, so the fist keeps its grip: **no grip offset moved**; heads (hoeblade, axehead, pick tines, mallet) scale with the handle; `Character.TOOL_SCALE` 1.3, `TOOL_SCALES` = { hammer = 1.15 } |
| mallet lean | 15 degrees | 24 degrees | `LEAN_HAMMER`: the bigger head met the mallet in the fight pose (0.003 clearance; needs 0.1) |
| hauler's sack | 2.7 across, 1.45-4.15 high | **3.1** across (x1.15), 1.3-4.4 high, 0.4 further back and 0.14 lower | about its bottom front; any bigger it meets the hauler's long hair in the cheer; the chest strap keeps its size, hung 0.15 lower |
| body top (head top) | 5.44 | 5.97 | |
Figure top with hat and tool at rest (studs): farmer 6.2 -> 7.9 (hoe), woodcutter 6.5 -> 7.4, miner 7.0 -> 8.6 (pick), builder 5.8 -> 6.6, hauler 5.6 -> 6.2. Widest at rest: 4.2 to 6.2 (farmer 4.9 -> 5.5, builder 5.5 -> 6.2).

Specs: clearance pins that are absolute studs were moved with the scale (body top 5.97, beanie width, handle thickness, sack top 4.5, headband and scarf offsets x HEAD_SCALE, miner pot vs farmer disc 0.75); every clearance RULE (arm to head 0.2 / 0.3, tool to head 0.1, sack to head 0.1, hat seat <= 0.4, face clear) is unchanged and passes.

## Measured (crimson, the sim's 13 citizens, from the dump; body = head + torso + arms + legs; `citizen_screen.py measure [--scale 1.25]`)
| view | before | now | now x1.25 (ScaleTo) | target |
|---|---|---|---|---|
| start 1080p body | 57.4 px | 62.8 px | **79.1 px** | >= 75 |
| start phone 750 x 311 body | 16.5 px | 18.1 px | **22.8 px** | >= 22 |
| far (zoom 220) 1080p body | 19.3 | 20.0 | 25.0 | |
| far phone body | 5.6 | 5.7 | 7.2 | |
| start 1080p figure (hat and tool) | 65.9 | 72.7 | 91.7 | |
| start phone figure | 19.0 | 20.9 | 26.4 | |
The pass alone does not reach 75 / 22 (body = head + torso + legs, and only the head is bigger: +9 % in body height); with the x1.25 you add it does (79.1 / 22.8). The hat, tool and sack grow the FIGURE (median height with hat and tool +10 %), not the body metric.

## x1.25 ScaleTo interplay (yours to check; I measured geometry only)
- `Model:ScaleTo(1.25)` in `EntityController.buildRig` scales the head (2.6), hats (farmer 4.3 wide: **work slots are 3.5 apart, so neighbouring farmers' straw discs now overlap by 0.8 in plan**; same height, so they z-fight where coplanar: lower `HAT_SCALE.farmer` to 0.9 if you ship x1.25, or tell me), tools (pick 8.8 long, hoe 8.5) and the sack (3.9 across).
- Tool tips at x1.25: miner pick top 10.8, farmer hoe top 9.9 (check doorways, the keep gate, bridge rails, carry props `Kit.carried` at `Torso * CFrame.new(0, 0, -1.2)`: the hands' midpoint scales with the model; the prop should be ScaleTo'd with it).
- `Def.PICK_HEIGHT` 2.75 -> body centre 3.4; `CitizenBubbleController.Def.HEIGHT` 3.2 above the Root: the Root centre rises 3.2 -> 4.0 and the head top is 7.5, so the bubble's bottom edge (Root + 3.2 = 7.2) sits 0.26 inside the head top (7.46): raise `Def.HEIGHT` by about 1 with the scale.
- Grips: unchanged in the hand; the handle's butt is 1.8 below the hand (hoe) as before, x1.25.

## Unverified
Studio. All numbers are Blender-preview geometry (a projection of the dump's parts); the Pose sweeps run in Lune on the rest-pose rigs and the Pose joint transforms you ship.
