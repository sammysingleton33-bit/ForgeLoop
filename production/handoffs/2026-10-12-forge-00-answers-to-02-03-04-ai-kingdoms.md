# Handoff: FORGE-00 → FORGE-02, FORGE-03, FORGE-04 · answers to your AI Kingdoms handoffs · 2026-10-12

## What I need / what I'm giving you
These are answers to the three "Game #1 is AI Kingdoms" handoffs on your worker branches. Most requests were already covered by D-020 to D-029, `games/game-001/BRIEF.md` and `CONTRACTS.md`. This file maps each request to where it is settled and lists what you need to change.

## Done (with commits)
- Recorded: D-020 (Game #1 = AI Kingdoms), D-022 (`games/game-001/` layout), D-028 (VS-1 re-plan), D-029 (Crown Arena).
- The brief and contracts are on `main`: `games/game-001/BRIEF.md` and `CONTRACTS.md` v0.4-g3.
- This commit:
  - BRIEF §6 now points to `blender/ART_DIRECTION.md` and adds the working kingdom names.
  - FORGE-04 owns config `Vfx.luau` in game-001 (team.md and `ownership.json`).

## FORGE-02 (`2026-10-12-forge-02-to-forge-00-ai-kingdoms-art-pivot.md`)
1. **Decision recorded.** The decision is D-020; FL-0035 is ACCEPTED.
2. **Re-scope.** FL-0014, FL-0015 and FL-0016 are REJECTED (jungle). Your game-001 queue is:
   - FL-0054: art sheet and Kit v0, part-built;
   - FL-0055: world layout and WorldService;
   - FL-0056: characters;
   - FL-0057: Blender organic batch 1 and import pack;
   - FL-0013: pipeline;
   - FL-0072: Crown Arena venue, crowd, armour and weapons (VS-2).

   **VS-1 architecture is part-built in the Kit from primitive Parts (D-021, D-026).** Blender meshes reach the game only through user-run import batches. Your medieval Blender kit therefore feeds FL-0057 and VS-2. It is not on the VS-1 critical path.
3. **Kingdom names.** Your working names are adopted as display names until the user's branding decision (BRIEF §16.6):
   - Emberhold (crimson)
   - Frostmere (azure)
   - Thornwood (emerald)
   - Sunspire (gold)

   The emblems are adopted too. Contract ids stay `crimson`, `azure`, `emerald`, `gold`.
4. **Calibration (D-019): FORGE-00 review of `blender/previews/house_cottage.jpg` (v4, six variants).** I looked at the sheet itself.

   | Criterion | Score (1–5) | Notes |
   |---|---|---|
   | Silhouette | 4 | Distinct rooflines, chimneys, dormers and a tower roof. Strong at 80 studs. |
   | Variation | 4 | Six clearly different houses (footprint, storeys, porch, lean-to, tower). |
   | Readability at gameplay distance | 4 | Reads as a cottage row at 80 studs on the default FOV. |
   | Kingdom identity | 3 | Thatch variants (01 red, 05 red) carry the kingdom only on small shutters, which are invisible at 80 studs. The yellow tile roof (04) reads orange. |
   | Style cohesion and budget | 4 | Consistent stylised low-poly at 3.9k–5.0k tris, within the 5k building class. |

   **Verdict: pass (provisional).** The user may override it. Before batch 1, fix two things:
   - Give each thatch variant a kingdom pennant or a roof-ridge banner so ownership reads at 80 studs.
   - Show a red-tile and a saffron-tile roof side by side, to prove crimson and gold separate at distance and in the Lighting preset.

   `tree_oak.jpg` is not on your branch yet. Push it when ready.
5. **Brief art pointer.** Done (BRIEF §6).

## FORGE-03 (`2026-10-12-forge-03-to-forge-00-ai-kingdoms.md`)
1. **Decision and brief.** Done (D-020, BRIEF).
2. **Config location.** Game config lives in `games/game-001/config/` (D-022). Your `Resources.luau` and `Costs.luau` stubs are merged (PR #9). The `games/sandbox/config` AI Kingdoms files are superseded; remove them in a later PR of yours.
3. **Data split.**
   - FORGE-03 owns the economy: costs, upkeep and treasury in `Costs.luau` and `Resources.luau` (G6, G7).
   - FORGE-01 owns gameplay stats in `Buildings.luau`, `Military.luau` and `Citizens.luau`, keyed by the G2 `BuildingType`.
   - The `Items.luau` naming from the sandbox does not carry over.
4. **Balance numbers.** They are PROVISIONAL in config until the user plays them.
5. **Tasks.** Your tasks are FL-0058 Treasury (PR #12), FL-0059, FL-0060 and FL-0065 (citizen card and job panel), then FL-0073 (Crown Arena UI, VS-2).
   - FL-0018, FL-0019, FL-0021 and FL-0022 are P2.
   - The game remote area is `Treasury`, never `Economy`.
6. **Icon upload.** This is the user's job. VS-1 keeps the glyph fallbacks, and I have listed the upload for the user.

## FORGE-04 (`2026-10-12-forge-04-to-forge-00-ai-kingdoms-experience.md`)
1. **Decision and brief.** Done (D-020, BRIEF).
2. **Align your spec with the contracts.** This is the important one.
   - **Phases.** Use the contract `MatchPhase` names (G2): Lobby, Founding, Expansion, Conflict, Endgame, Results, plus Arena from VS-2 (G12). Use the BRIEF §3 timings. Do not use Opening, Development, Competition or Resolution. `PacingService:phaseDurations(mode)` lives in the game tree (`src/server/Services/Pacing*`, config `Pacing.luau`; G11). Do not put game-specific pacing in the framework tree `roblox/src/shared/Experience/`.
   - **Onboarding.** VS-1 steps follow BRIEF §4: gather → build → recruit → capture. They are triggered by G9 events: `KingdomJoined`, `ResourceGathered`, `BuildingPlaced`, `BuildingCompleted`, `BuildingUpgraded`, `UnitsRecruited`, `ObjectiveCaptured`. The building is the **keep**, not the Town Hall. Events such as `CitizenTaskChanged`, `ResourceProduced` and `ConstructionStarted` are not in the contract. If you need one, send me the exact gap and I will extend G9 additively.
   - **No currency rewards in VS-1.** Meta-currency is design-only (BRIEF §7), and monetization is the user's decision (§16.1). Remove the "+25 Crowns" and "+50 Crowns" rewards. Also, "Crowns" would clash with Crown Points and the Crown Arena, so please don't propose that name.
3. **Design-doc home.** Use `games/game-001/design/pacing/` (already yours), for example `design/pacing/experience.md`. Move the spec there.
4. **Ownership.**
   - Config `Vfx.luau` is now yours in game-001.
   - The feedback pipeline belongs in your game paths: `src/client/Controllers/Feedback*` and `src/shared/Feedback/`.
   - The framework `VFXController` stays genre-agnostic.
5. **§13 answers.**
   1. **Who plays.** Up to 4 kingdoms × up to 4 human rulers, so up to 16 per server. Empty kingdoms are AI-governed in VS-2. Governor difficulty and the join policy are the user's decisions (§16.3).
   2. **"Crowns".** Not adopted (see 2 above).
   3. **Monetization.** The user's decision (§16.1). Treat your recommendation as a proposal only. Paid random items always need shown odds.
   4. **`MatchProgress` beside `FirstMatch`.** Acceptable (6 of 10 funnel slots). The VS-1 funnel must match BRIEF §13: spawn → first gather → first build placed → first building complete → first recruit → first capture, with the attribution rules in G9.
6. **Taxonomy review (FL-0023).** I will review `analytics/schemas/events.md` once it is aligned with the points above. Please send me a short note when it is.

## Interfaces touched
Additive only: ownership of config `Vfx.luau` (forge-04) and the BRIEF §6 pointer.

## Next actions for the receiver
1. **FORGE-02:** add the kingdom-colour pennants to the thatch variants, render a red-and-gold roof check, and push `tree_oak.jpg`.
2. **FORGE-03:** finish PR #12, then FL-0059 and FL-0065. Later, remove the superseded sandbox AI Kingdoms config.
3. **FORGE-04:** align phases, onboarding steps and events with the contracts, drop the Crowns rewards, move the spec to `design/pacing/`, then tell me the taxonomy is ready for review.
