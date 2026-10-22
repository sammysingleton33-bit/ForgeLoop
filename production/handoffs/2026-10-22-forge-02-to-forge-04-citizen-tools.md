# Handoff: FORGE-02 -> FORGE-04 (cc FORGE-00) · citizen tools and props, job-coded and bigger (pass 3, stacked on #317) · 2026-10-22

## What changed (Kit/Character.luau; citizens only; same part count: idle 8, working jobs 11; grips, joints and Pose unchanged)
Each job carries one saturated colour on its tool head (the hauler on its sack): a hue the ground has none of, none of the four kingdom colours, >= 49 dE from the other jobs. Handles are ink so they show against every ground. Tool heads and handles are SmoothPlastic (they were Metal / Wood).

| job | tool head colour | handle | sizes before (#317) -> now (studs, at RIG_SCALE 1) |
|---|---|---|---|
| farmer | hoe blade magenta 232,48,168 (was steel 138,146,158) | ink 34,30,40 (was pale wood) | handle 6.76 x 0.49 -> **7.28 x 0.61** (x1.4, thicker x1.15); blade 1.43 x 1.69 -> **2.23 x 2.64** (x1.45 more); straw disc 3.41 -> **2.79** (HAT_SCALE.farmer 0.9) |
| woodcutter | axe bit cyan 0,200,220 (was steel) | ink 28,36,40 | handle 5.07 x 0.55 -> **5.85 x 0.72** (x1.5); bit 0.65 x 2.21 x 2.47 -> **0.97 x 3.31 x 3.71** (x1.3 more) |
| miner | pick tines violet 140,72,224 (was iron 104,110,122) | ink 40,30,30 | handle 7.02 x 0.52 -> 7.02 x **0.60** (thicker only); tines unchanged 0.58 x 1.04 x 3.25: bigger, they meet the pot in the cheer |
| builder | mallet head lime 200,255,0 (was dirt brown) | ink 30,30,44 | handle 3.45 x 0.48 -> 3.45 x **0.56**; mallet head unchanged 1.38 x 1.32 x 2.3: bigger, it meets the head in the fight pose |
| hauler | sack orange 255,128,0 (was pale grain yellow, which merged with the gold kingdom and the straw) | the tie is ink | sack 3.1 across, unchanged: the hauler's long hair in the cheer limits it |
Scale knobs: `Character.TOOL_SCALE` 1.5 (hoe 1.4, pick 1.3, mallet 1.15 in `TOOL_SCALES`), `TOOL_HEAD_SCALE` 1.45 (axe 1.3, mallet 1, pick 1 in `TOOL_HEAD_SCALES`), `TOOL_THICKNESS` 1.15, `HAT_SCALE.farmer` 0.9. Every Pose clearance rule is unchanged and passes (arm to head, tool to head 0.1, hat seat, sack); the pick and the mallet were held at their old sizes by exactly those sweeps (tried and reverted: fat tines meet the pot, a x1.25 mallet head is -0.13 from the head).

## x1.5 interplay (your RIG_SCALE; numbers = studs at x1.5)
| | x1.0 | x1.5 | vs doors (house 7.6, keep 10.4) |
|---|---|---|---|
| body top (head) | 5.97 | 8.96 | 118 % of a house door, 86 % of the keep's |
| farmer, hoe tip | 8.77 | 13.2 | above the keep's door by 2.8 |
| woodcutter, axe top | 7.66 | 11.5 | |
| miner, pick top | 8.62 | 12.9 | |
| builder, hat / mallet top | 6.59 | 9.9 | |
| hauler, sack top | 6.18 | 9.3 | |
| farmer straw disc (width) | 2.79 | 4.19 | 3.5-stud work slots: overlap 0.7 in plan (x1.25: 3.5, exactly the spacing). To fit at x1.5 the disc needs <= 2.33 (HAT_SCALE.farmer 0.75); tell me |
| hoe / pick / axe handle length | 7.28 / 7.02 / 5.85 | 10.9 / 10.5 / 8.8 | |
| sack | 3.1 | 4.65 | |
Your checks: doorways and gates (the hoe tip 13.2 and the pick tip 12.9 are above the keep's door 10.4 and a house door 7.6: fine in the open, the tools lean out 14 to 24 degrees, but check a work slot beside a door and the bridge rails), `Kit.carried` scaled with the model, `PICK_HEIGHT` 2.75 -> 4.1 (the pick aims at the body centre), `CitizenBubbleController.Def.HEIGHT`: the bubble's bottom edge (Root 4.8 + 3.2 = 8.0 at x1.5) sits about 1 stud INSIDE the head top (8.96), so raise it by about 2 to clear the hats too. #316's 105-degree cap on the harvest blow was found with the pass-2 hoe; the hoe is now longer and its blade 1.6 x bigger (tried against the Pose joint transforms in KitCharacter's sweeps, which sample Sim/Pose as on this branch, not #316's cap).

## Unverified
Studio, and the Pose of #316 (not merged here). All numbers are Blender-preview geometry.
