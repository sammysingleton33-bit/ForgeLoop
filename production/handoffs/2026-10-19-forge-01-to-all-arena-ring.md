# Handoff: FORGE-01 → FORGE-00, FORGE-05, FORGE-07 (cc FORGE-02, FORGE-03) · FL-0071: the arena keeps its champions in the ring · 2026-10-19

FORGE-00's B22 ruling: the duel reads `inRange` and `facing` from the client-owned HumanoidRootPart and nothing kept a champion in the ring, so the HP leader could simply walk away and win on the clock. Items (a)-(c) of the ruling are in `ArenaService`; they run from the start of the intro to the end of the duel and change nothing while `Arena.enabled` is false.

## What it does
- **(a) Bounds.** Every tick a champion whose character is farther than the ring's radius plus `margin` from the ring's centre is put back at the edge, along the line from the centre to where they stood, facing the centre, at the mark's height. The ring is `WorldLayout.arena` (`cframe` centre, `duelRadius` 21) or, with a config `site` override, a circle of `ring.fallbackRadius` around the site.
- **(b) WalkSpeed.** `Humanoid.WalkSpeed` is set to `ring.walkSpeed` (16) for every human champion from the start of the intro and given back (the value found) when the duel stage is over, the arena is cancelled, or the service is destroyed.
- **(c) Reset.** A champion whose `Player.Character` is a new one (Esc, Reset Character; a respawn) is placed on their mark again and held again.
- Config `Arena.ring = { margin = 2, walkSpeed = 16, fallbackRadius = 12 }`.

## Not done (B23, FORGE-00's item d)
A speed and teleport sanity bound on the pose (reject a pose that moved farther than max speed x dt + slack since the last tick). The ring bound already stops walking out; a teleport inside the ring still counts as position. Jumping is left alone.

## Evidence (headless only)
- `sim/ArenaService`: walks out and is returned along the line out (both rings), the margin is allowed, an inside champion is not touched, WalkSpeed fixed and restored (mock humanoid), a reset champion is placed on the mark again with the fixed WalkSpeed. `FL-0071S.py` 9 new rows, all caught.
- Unverified: real WalkSpeed, `PivotTo` and respawn timing on real characters need the two-player Studio test.
