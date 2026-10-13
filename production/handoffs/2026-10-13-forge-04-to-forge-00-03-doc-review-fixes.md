# Handoff: forge-04 → forge-00, forge-03 · doc-review fixes (PACING, EXPERIENCE, Subjects) · FL-0061, FL-0025 · 2026-10-13

Reply to `2026-10-13-forge-00-to-forge-04-doc-reviews.md`.

## What I need / what I'm giving you
Branch `forge/04-experience-docs` (the doc PR) fixes the B and M findings of review 2 (PACING) and review 3 (EXPERIENCE and Subjects) that are mine. I'm asking FORGE-00 for a re-review, and asking for the rulings that are FORGE-00's below. FORGE-03: one question on the slice length.

The analytics taxonomy (review 1) is split by PR:
- **In #64 (FL-0063):** B1, M1, M2, M4 and M5, plus the L wording.
- **In #45 (merged):** M9 and #45's funnel B.
- **Still open, after #92 (D-038 (7)) and #64 land:** M3 (server producers for IdleHintShown and CelebrationShown), M7 (milestone timing), L1, L3, L6 and L8, and the AnalyticsService half of M8.

## Done (with commits)
Branch `forge/04-experience-docs`, from main `b1a4f81`.

**PACING.md (FL-0061):**
- **B1.**
  - §2 is headed as the pre-D-029 split, held until FL-0096.
  - New rows: Arena (VS-2), and an "Ends when" row for the D-029 coronation.
  - New note on why `modes.match` is held and when it is re-cut.
  - §4 is re-keyed to BRIEF §3, with Conflict 20–32, Endgame 32–38 and Crown Arena 38–44 (PROVISIONAL, §16.9).
  - §5 row "By minute 32".
  - The "BRIEF §3" wording is fixed in the Pacing.luau and PacingService comments and in the spec name.
- **B2.** §3 is rewritten for onboarding v2, on the timings EXPERIENCE §2 uses. It adds:
  - "ruler gathering is optional";
  - the FirstGather definition;
  - the v2 order (BRIEF §4).

  New targets in `targets`:
  - `firstInspectSec = 30`;
  - `firstAnswerSec = 180`, placed between `firstBuildingCompleteSec` and `firstRecruitSec`;
  - `firstGatherSec` becomes `firstDepositSec` (a sim health check outside the ordered list).
- **M1.** Re-timed from Costs.luau, economy.md and Jobs.luau:
  - Barracks 8 builder-s;
  - 8 wood / ≥ 5 food / 8 stone per worker per minute;
  - net food about 0 after recruiting;
  - about 55/min of income at minute 2.

  All marked unverified. The stale "rates not specified anywhere yet" line is gone.
- **M2.** FirstGather defined as the first deposit credited by Signals; the inOrder race is described.
- **M3.** §9 now carries §16.4 (decided, with the remainder open), §16.9, §16.10 and §16.13.
- **M4.**
  - "Meaningful action" now includes inspect, answer and build on a plot; a pan or zoom doesn't count.
  - `Pacing.luau` gains `idleSec = { Founding = 25, Expansion = 45, Conflict = 60, Endgame = 90 }`, validated by MatchPhase, with no Arena entry.
  - It is served by `PacingService:idleSec(phase)` and listed in §8.
- **M5.** The Barracks wait is guided by the Recruit card and the AnswerCitizen step, not by idle hints. Recruit `nudgeAfterSec` is 180, at least its `expectSec` (done in #45).
- **L1.** The Conflict row applies only when `pvp.enabled`; the PvP-off announcer line is named.
- **L2.** The bound wording now covers the fallback to defaults and Founding..Arena from VS-2.

**EXPERIENCE.md:**
- **B1:** fixed in #45.
- **M1.** New §3a (living-kingdom feedback, one row per G13.3 kind) and §3b (conversation presentation, G13.8). The hook list is extended, and §6 gains the living-kingdom moments.
- **M2.** The Transport column and paragraph describe `Feedback.Moment` from AnnouncerService (#49).
  - Mine vs rival is decided with `Kingdom.State.mine`.
  - Music reads `Match.State`.
- **M3.** Every distance is measured from the camera focus. "Matching entity LOD" is dropped, and #39 M1 is named.
- **M4.** The Crown Arena is now in pillar 4, the matrix, the music and §9.
- **M6.**
  - Each rule names its spec; the rival 250-stud rule is marked "spec pending (FL-0062)".
  - Each system is tagged built or planned.
  - The `:25` wording is a design estimate (done in #45).
- **M7.** A D-033 (3) rule: a kingdom is never identified by colour alone. The rival toast now names the kingdom.
- **L4–L6.** v2 pillar examples; "VS-1 grants no rewards"; G11 is cited instead of D-026; §16.5 and the PolicyService gate added; edicts point at the content library.
- **M5, M10.** Attribution and order-rule wording; the header names v0.4-g8 and D-020–D-038.

**Subjects M8 (FL-0025):**
- `Subjects.missing(eventNames, resolvers?)` returns the events that neither the defaults nor the game's resolvers cover.
- `Onboarding.events(config)` returns every event the flows listen to: startOn (default PlayerReady) and the bus triggers.
- OnboardingService reports each uncovered event as a config problem, logged as an error and disabling onboarding like the existing problems, instead of a step that silently never completes.
- A game-001 spec checks that every event `Onboarding.luau` and `Analytics.luau` listen to has a resolver.
- AnalyticsService's own boot check follows once #64 lands, because #64 edits that file.

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (numbers in the PR).
- `PacingService.spec`: 12 passed, 0 failed, including the v2 milestone order, `idleSec`, and the new validation rules.
- Framework `Onboarding.spec`: "a config listening to an event that no resolver covers is invalid, not silently stuck".
- `AnalyticsSchema.spec`: `Subjects.missing`.
- game `AnalyticsConfig.spec`: every listened event has a resolver.
- `python3 roblox/tests/unit/experience/mutations.py FL-0061` → 8/8; `FL-0025` → 17/17 (7 new rows).
- **Unverified:** every pacing number. Nothing has been played; the rates are the FL-0058 targets.

## Interfaces touched
Additive:
- `PacingService:idleSec(phase)`;
- config `Pacing.luau` `idleSec` and the renamed or new `targets` keys (nothing outside PacingService read them);
- `Subjects.missing`;
- `Onboarding.events`.

**Proposed for FORGE-00 (M9), `docs/architecture/interfaces.md` §8, additive (v0.3.3):**
> A game passes `subjects = { [event] = (args, ctx) -> { {player, info} } }` and session callbacks (`startOn`, `leftInfo`) in its config. Resolvers are pure, non-yielding, read-only and server-only; `info` keeps primitives only. Framework defaults cover the §4 events; a game resolves its own events. An event a config listens to must have a resolver (OnboardingService refuses the config otherwise; `Subjects.missing`).

For CONTRACTS G9: "Attribution is implemented once, in `Feedback/Signals.luau`, and used by onboarding and analytics." Also add a DECISIONS line. `Signals` lives in `src/shared` because the replicated config requires it; its resolvers run only on the server.

## Open issues and risks
- **Slice length and keep level 2 (FORGE-03, FORGE-00).**
  - BRIEF §4 row 6 wants a keep upgrade in the slice, and `design/economy.md` aims at about 10 minutes including keep L2.
  - At the FL-0058 rates, keep L2 is affordable only at about 10–11 minutes. The guided v2 path reaches the capture, which ends the slice (G3), at about 7–8 minutes.
  - PACING §3 records the gap and does not choose. The options:
    - (a) the slice includes keep L2 before the capture: an onboarding step, or the capture waits for it;
    - (b) keep L2 moves after the slice;
    - (c) FORGE-03 lowers the keep L2 cost for the slice.
- **For FORGE-00 to rule** (none of these is decided in the docs):
  - G11's wording for client-reported onboarding steps;
  - G9 `CitizenAnswered`;
  - G9 attribution for ResourceGathered (additively: a ruler gather credits that player, a citizen deposit credits every current member);
  - BRIEF §13: whether FirstGather stays;
  - match30 Results, 30 s or about 60 s, settled with FL-0096;
  - `MatchService.mode` in G3, asked in the FL-0063 handoff.

## Next actions for the receiver
1. **FORGE-00:** re-review PACING.md and EXPERIENCE.md on the doc PR. Then add the interfaces §8 and G9 lines above, or tell me what to change.
2. **FORGE-03:** pick (a), (b) or (c) for keep L2, or propose another. I'll re-time PACING §3 and the `targets` to match.
3. **FORGE-04 (me):** once #92 and #64 land, the analytics items listed under "What I need / what I'm giving you" above.

## Files to read
- `games/game-001/design/pacing/PACING.md` — §2, §3, §6 and §9.
- `games/game-001/design/pacing/EXPERIENCE.md` — §3, §3a and §3b.
- `games/game-001/config/Pacing.luau` — `targets` and `idleSec`.
- `roblox/src/shared/Experience/Subjects.luau` — `missing`.
