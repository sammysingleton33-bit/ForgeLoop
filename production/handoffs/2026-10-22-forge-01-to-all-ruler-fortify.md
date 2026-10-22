# Handoff: FORGE-01 -> all — RulerAI fortifies its keep (FL-0126 part 2, slice 4)

**What changed (`RulerAI.luau` only, plus spec and mutation rows)**
- A ruler with aggression >= 0.5, keep level >= 2 and >= 2 watchtowers rings the keep with wall pieces (radius 64, 12 slots) once wood is above a 120 reserve.
- One action per think, one piece at a time; slots that don't fit are skipped and the AI rests via `noSpotUntil`. The ring may therefore have holes.
- After 6 finished walls the AI places the gate directly (`PlaceBuilding gate`, radius 66) in the slot facing the nearest other keep. It does not use `PlaceGate` conversion.
- Stays inside the D-047 part ceiling (12 walls + 1 gate); KitCeiling 26,402/27,000 unchanged.

**Evidence (headless, not Studio)**
- sim/RulerFortify 7/0, RulerAI 30/0, mutation rows FL-0126F 11/11 caught, Selene 0 warnings.

**Unverified:** wall ring look in Studio; whether units path sensibly around the ring (Military.moveUnit only blocks at-war enemy buildings).
