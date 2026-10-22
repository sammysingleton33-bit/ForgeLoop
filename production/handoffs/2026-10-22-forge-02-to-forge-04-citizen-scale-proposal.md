# Handoff: FORGE-02 -> FORGE-04 (cc FORGE-00, FORGE-01) · citizens at the start frame · scale proposal · 2026-10-22

## What I need / what I'm giving you
A number, not a change: whether to scale the citizen rig in `EntityController.buildRig`. FORGE-02 changed only colours (no part, no size); the start view
already passes the brief's size thresholds. This is the arithmetic for the far zoom, where it does not.

## Measured (blender/scripts/citizen_screen.py on the dump; the sim's 13 crimson citizens, rest pose; body = head + torso + arms + legs)
| view | body height now | at x1.25 | threshold |
|---|---|---|---|
| start (zoom 70, FOV 55), desktop 1080p | 57.4 px | 71.8 | 24 |
| start, phone 750 x 311 | 16.5 px | 20.6 | 12 |
| far (zoom 220), desktop 1080p | 19.3 px | 24.1 | 24 |
| far, phone | 5.6 px | 7.0 | 12 |
Heights scale linearly with k. 12 px at far on the phone needs k = 2.1 and 24 px at far on desktop needs k = 1.24: no value in 1.15 to 1.3 rescues the
far phone view, and x1.25 only just reaches the far desktop one. If you want a number: **x1.25 uniform**, only if the far desktop view matters.

## Where (not mine)
`src/client/Controllers/EntityController.luau` `buildRig` (line 505, `local model = (Kit.character :: any)(...)`): `model:ScaleTo(1.25)` right after the
build (pooled by `poolKey`, so once per rig). Check there: `Def.PICK_HEIGHT = 2.75` (body centre becomes 3.4), `CitizenBubbleController.Def.HEIGHT = 3.2` above
the Root (the Root centre rises to 4.0, the head top to 6.9, the bubble edge stays at 7.2), the `Kit.carried` offset (1.2 in front of the Torso scales with the model if welded).
The world part ceiling does not count rigs (KitCeiling stays 26,402 / 27,000).

## LOD finding
`Kit.characterLod` (one part, 1.5 x 6.4 x 1.0) is not called anywhere in `src/`. EntityController unparents a rig beyond `Def.LOD_HIDE` = 150 studs from the
focus (line 94), or `Def.LOD_ZOOM` (1.25) x the camera distance when larger (line 593): 150 studs at the start zoom (70 x 1.25 = 87.5), 275 at zoom 220.
Every citizen inside the frame is the full 9-11 part rig. A far-zoom swap to the one-part stand-in would cut parts, not improve the read (at 5.6 px both are dots).

## Unverified
Studio. Every number is Blender-preview geometry (a projection of the dump's parts), not a Studio screenshot; the seated ruler's root height is an estimate
(`StartView.SEATED_LIFT`).
