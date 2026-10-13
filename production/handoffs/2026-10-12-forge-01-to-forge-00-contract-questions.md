# Handoff: forge-01 → forge-00 · CONTRACTS v0.4-g1 questions (FL-0048..FL-0052) · 2026-10-12

## What I need / what I'm giving you
Four small contract gaps I hit while moving the kingdom simulation onto G2–G9. I proceed with the
defaults in brackets so nothing waits; tell me if any default is wrong.

## Questions (default I use until told otherwise)
1. **MatchPhase has no countdown.** [Lobby carries `endsAt` while the start countdown runs; the
   Founding phase starts the simulation.]
2. **JobId "miner" covers stone and gold?** [Yes: a miner works rocks and gold veins, choosing by
   kingdom need.] **"hauler"** [a generalist: carries goods from farms/lumber camps/quarries to the
   storehouse and helps build when idle; it is also the pool that `requestWorkers` draws from.]
3. **Treasury capacity.** G7 has no storage cap; my simulation had per-resource capacity from
   storehouses. [No cap in the treasury; storehouses are drop-off points only. FORGE-03 may add a
   cap later; I asked them in a separate handoff.]
4. **Victory** is reserved for the user (BRIEF §16.4). [Both: last keep standing ends the match
   early; otherwise most Crown Points at the end of Endgame. Ties share the win.]
5. **Diplomacy/PvP** is reserved for the user (BRIEF §16.2). [War declarations allowed from the
   Conflict phase on; peace needs both sides; no betrayal mechanics yet.]

## Done
- FL-0007 → PR #4, FL-0009 → PR #5 (stacked). Both REVIEW, check.sh green, ownership PASS.
- On `forge/01-gameplay`: a working, deterministic kingdom simulation (citizens AI, jobs, construction,
  population, military, diplomacy, AI governor, match) with 380+ Lune specs, currently under
  `roblox/src/shared/Gameplay/Kingdom/`. It moves to `games/game-001/src/shared/{Kingdom,Sim}` as soon
  as FL-0046 lets game code run in the harness.

## Interfaces touched
None yet; I will implement G2–G9 as written.
