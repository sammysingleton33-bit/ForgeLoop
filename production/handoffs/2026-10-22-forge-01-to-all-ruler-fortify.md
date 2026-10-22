# Handoff: FORGE-01 -> all — RulerAI walls the approach to its keep (FL-0126 part 2, slice 4)

**What it does (`Sim/RulerAI.luau` only, plus specs and mutation rows)**
- A governor with aggression >= 0.5, a level-2 keep and two finished watchtowers raises a palisade ARC: up to 12 wall pieces (D-047: 12 walls and one gate), one at a time, laid tangent to the circle 132 studs from its keep and centred on the nearest living rival keep. Each slot tries radii 132, 140, 124, 148; a slot that still does not fit is skipped, so the arc may have holes.
- Why 132 and not a ring: FORGE-07's review of the first version (ring at 64) showed the real yard (farms, houses, camps, towers, trees) fills the ground out to about 120 studs; a ring placed at most 3 pieces and no gate in real matches. The L2 territory (170) leaves room at 120-144.
- The gate: once six pieces are finished, the finished piece nearest the middle of the arc is turned into the gate in place with `PlaceGate` (Build.PlaceGate, #306), tried first in every think so the stone it costs (30) is not spent by the building decisions below it. The palisade holds its other pieces for up to 300 s for the gate, then goes on without it.
- Only walls at war block units (`Military.moveUnit`): the gate is visual and a place to defend until pathing uses it. This slice does not change movement.

**Evidence (headless, not Studio)**
- sim/RulerFortify 12/0, sim/RulerAI 30/0, Selene 0 warnings, mutation rows FL-0126F 17/17 caught.
- long/RulerFortifyMatch (real Match, seeds 11-13, to 2400 s): 9 AI kingdoms reached the trigger, all 9 got >= 6 pieces (7-10); 4 of the 4 still standing at the end got a gate (the 5 that fell had no time to finish one).
- FullMatch: wars 4, kills 210, fallen 2, p99 3.98 ms (budget 4 ms: tight, see below); WarOutcome 2 fallen; KitCeiling unchanged (26,526 of 27,000).

**Unverified:** how the arc looks in Studio; whether the AI's walls annoy human players building near an AI keep; a Studio-measured tick cost (the FullMatch p99 is a headless CPU figure near the 4 ms line).
**For FORGE-03/04:** nothing required. AI palisades appear after about minute 16 of a match.
