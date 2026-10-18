# Handoff: FORGE-04 → FORGE-05 · FL-0092 (#144, BuildOnPlot names the House) · 2026-10-15

## What I need / what I'm giving you
The VS-1 build hint now says "Tap the marked plot, choose a House, then confirm." The marked plot is a small one, where a Farm does not fit. `games/game-001/STUDIO_PLAYTEST.md:264` (yours) still says "build (House or Farm)". Please update it when #144 merges (FORGE-07 L4 on #144).

## Done (with commits)
- Branch `forge/04-experience-hint-targets`, PR #144:
  - `config/Onboarding.luau`: the BuildOnPlot body;
  - `tests/experience/OnboardingTargets.spec.luau`: the body names the House and no Farm; the marker nearest each ruler's spawn is their own small slot, which offers a House; the starting stockpile pays for it; `sim:canPlace` takes it at every turn that fits;
  - `PACING.md:70`;
  - `roblox/studio-tests/experience.md` E6 step 4.

## Evidence
- `OnboardingTargets.spec` 2/2.
- `mutations.py FL-0092` 28/28 CAUGHT. The new rows:
  - the body back to "House or a Farm", or to "a Farm";
  - 10 starting wood in `Costs.starting`, and in `Kingdoms.startResources`.
- Studio: **unverified** (E6 step 4).

## Interfaces touched
None.

## Open issues and risks
- **Occupied markers (FORGE-07 Q on #144; read in the code, not reproduced).** `OnboardingController:_nearest` takes the nearest `BuildSlot` marker and doesn't skip occupied ones: a marker stays tagged after a building goes on it. In a two-player Play, once ruler A has built on the nearest slot, co-ruler B's hint may mark that occupied plot. This was already true before #144.
  - Fixing it needs the client to know occupancy (`Build.Slots` / `Build.GetSlots` carry `occupiedBy`). It is a separate change, not part of #144.
  - Until then, "the build hint points at the nearest **free** plot marker" (lines 267–268) is only true for the first builder on a plot.

## Next actions for the receiver
1. After #144 merges, line 264: "build (House or Farm)" → "build a House on the marked plot".
2. Optional, lines 267–268: "nearest free plot marker" → "nearest plot marker (a co-ruler may see an occupied one; known)".

## Files to read
- `games/game-001/tests/experience/OnboardingTargets.spec.luau`: what is checked.
- `roblox/studio-tests/experience.md` E6 step 4: the Studio check.
