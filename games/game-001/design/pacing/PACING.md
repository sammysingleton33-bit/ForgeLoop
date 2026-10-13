# AI Kingdoms — match pacing (FL-0061)

_Owner: FORGE-04. Status: **draft for FORGE-00 review**; numbers agreed as placeholders with FORGE-03's hour-0 `Costs.luau` (FL-0058 replaces them). Last updated 2026-10-12._

Code:
- config `games/game-001/config/Pacing.luau`;
- `PacingService:phaseDurations(mode)` (CONTRACTS G11), pulled by MatchService (G3).

Everything marked *target* is a tuning goal for playtests, not a measured result. Nothing here has been played yet.

## 1. What good pacing means here
- **Something meaningful to do every 30 seconds:** walk to a job, gather, place, upgrade, recruit, capture (BRIEF §2).
- **A visible step up about every five minutes:** first building, keep level 2, first army, first capture.
- **No dead air.** If the local kingdom does nothing meaningful for a while, a contextual hint appears (§6).
- **The match escalates even when players are passive.** Phases are timed in match mode, so Conflict arrives whether or not anyone attacks.
- **Rivals get a fair start.** No raid can land before the defenders have had time to see it coming (§4).

## 2. Phase lengths (seconds; `math.huge` = untimed)

| Phase | slice (VS-1, CONTRACTS G3 interim) | match (BRIEF §3) | Ends when |
|---|---|---|---|
| Lobby | 0 | 20 (countdown) | timer |
| Founding | untimed | 480 (0–8 min) | slice: the first `ObjectiveCaptured` moves to Results / match: timer |
| Expansion | untimed (not reached) | 720 (8–20 min) | timer |
| Conflict | untimed (not reached) | 900 (20–35 min) | timer |
| Endgame | untimed (not reached) | 600 (35–45 min) | timer, or early victory (rules are the user's, BRIEF §16.4) |
| Results | untimed (summary stays up) | 30 | timer |

- Match mode runs 45 minutes from Founding to the end of Endgame. An early victory in Endgame (the default proposal is last keep standing) can shorten a match toward 35 minutes.
- `PacingService` rejects configs outside 30–45 minutes.

### `match30`: evaluation profile, not the default (D-030 (6), FL-0092)
The user prefers about 25 minutes of kingdom play, then a 5-minute final phase, ending around minute 30. The current timing puts the arena at 38–44 minutes. The conflict is recorded and not resolved (`design/living-kingdom.md` §6). `match30` lets the team play the short version without changing the default.

| Phase | match30 (s) | Minutes |
|---|---|---|
| Lobby | 20 | countdown |
| Founding | 300 | 0–5 |
| Expansion | 420 | 5–12 |
| Conflict | 480 | 12–20 |
| Endgame | 300 | 20–25 |
| Arena | 270 | 25–29.5 (VS-2 phase, CONTRACTS G12) |
| Results | 30 | |

- Total: 1,820 s (30 min 20 s). `PacingService` checks that Founding..Arena lasts 25–35 minutes.
- `phaseDurations("match30")` also returns `Arena`; `match` and `slice` have none until VS-2.
- The default stays `slice` in VS-1 and `match` for the full match; `match30` runs only when deliberately selected. Selecting it needs a FORGE-01 change to `Match.durationsFor` and MatchService, plus an optional FORGE-05 debug preset; both are pending. Until MatchPhase gains Arena (G12.1), a `match30` run ends after Endgame (25 min) without the final phase.

## 3. VS-1 slice, minute by minute (*targets*, from spawn)
Assumptions:
- FORGE-03 placeholder costs: starting treasury food 120 / wood 100 / stone 50; house 40 wood (20 builder-s); farm 50 wood (25 s); barracks 120 wood + 60 stone (45 s); soldier 30 food + 10 wood (8 s); upkeep 1 food per citizen per minute.
- FORGE-01's starting population: farmer 3, woodcutter 3, miner 2, builder 2, hauler 2.
- Gather and trip rates are **not specified anywhere yet**. I assume ≈ 15 wood/min per woodcutter, ≈ 12 food/min per farmer and ≈ 8 stone/min per miner. FL-0050 (citizen jobs) and FL-0058 (balance sheet) must confirm or replace these, and §3 is re-timed when they land.

| Time | Player does | Feedback (FL-0062) | Onboarding step | Analytics (FL-0063) |
|---|---|---|---|---|
| 0:00 | spawns at own keep, sees own banner, citizens already working | founding horn, kingdom toast | 1 `KingdomJoined` (auto) | funnel 1 Spawn |
| 0:10–0:45 | walks to a tree or rock and gathers | chop/mine sound, chips VFX, "+N Wood" float | 2 gather (`ResourceGathered`, source ruler) | funnel 2 FirstGather (*≤ 45 s*) |
| 0:45–1:30 | opens Build, places a House or Farm (affordable from the start: 100 wood) | place thunk, dust puff | 3 place (`BuildingPlaced`, `placedBy`) | funnel 3 FirstBuildPlaced (*≤ 90 s*) |
| 1:30–2:30 | watches builders walk over and raise it in stages | hammering loop near the site; completion fanfare and cheer | 4 complete (`BuildingCompleted`) | funnel 4 FirstBuildingComplete (*≤ 150 s*) |
| 2:30–4:00 | saves for the Barracks (needs +~70 wood, +~10 stone; at the assumed rates ≈ 1.5 min), places it | stockpile counters rising | (hint: "Build a Barracks") | — |
| 4:00–5:30 | Barracks completes; recruits 3 soldiers (90 food + 30 wood) | horn + soldiers at Rally | 5 recruit (`UnitsRecruited`) | funnel 5 FirstRecruit (*≤ 330 s*) |
| 5:30–7:30 | presses Send-to-capture; soldiers walk to the neutral Watchtower; the capture bar fills | capture sting, tower recolours, border flags, celebration | 6 capture (`ObjectiveCaptured`) | funnel 6 FirstCapture (*≤ 450 s*) |
| 7:30 | slice summary (FORGE-03) | — | done | `MatchEnded` |

The slice's target length is **6–8 minutes** for a new player. BRIEF §4 asks for a guided first two minutes: steps 1–4 fall in that window, and steps 5–6 continue the same thread.

Watch points:
- **Food after recruiting:** 120 starting food, plus ~36/min from farmers, minus 12/min upkeep for 12 citizens, minus 90 for soldiers. Food stays positive. *Unverified until FL-0050/FL-0058.*
- **The Barracks wait (2:30–4:00) is the slice's dead-air risk.** Mitigations:
  - the idle hint after 25 s ("Gather wood to build faster");
  - ruler gathering speeds it up, so the player always has something useful to do;
  - if playtests show more than 45 s of waiting, FORGE-03 can lower the Barracks cost or raise starting wood.

## 4. Full match (*targets*)
| Minute | Phase | Typical state of a kingdom | Big moment | First-conflict guard |
|---|---|---|---|---|
| 0–2 | Founding | the slice flow above | founding, first harvest/gather | — |
| 2–8 | Founding | 3–5 new buildings; population grows with houses; keep level 2 around minute 6–8 | keep L2 (citizens cheer) | no war: diplomacy default is war only from Conflict (CONTRACTS G3 clarification) |
| 8–20 | Expansion | outposts and neutral nodes claimed; walls start; ~25–40 citizens | first outpost captured | border contact is possible but there is no PvP damage until Conflict |
| 20 | Conflict starts | first armies (5–10 soldiers) | "War is declared" announcement + horn | **earliest raid ≈ minute 21–22**: soldiers must walk across the valley, so defenders have about 60 s of warning |
| 20–35 | Conflict | raids on farms and stores; alliances form and break (VS-3) | first raid repelled / first raid landed | — |
| 35–45 | Endgame | sieges on keeps; Crown Point race | siege, keep falls / holds | — |
| 45 | Results | standings, slice/match summary | victory / defeat | — |

**Rhythm:** one "big moment" about every 5 minutes (*target*). The announcer (FL-0062) amplifies the moments that matter to the local kingdom and stays quiet otherwise.

## 5. Economy growth targets (for FORGE-03's balance sheet, FL-0058)
| By minute | Population | Buildings (own) | Stockpile income (all resources) | Army |
|---|---|---|---|---|
| 2 | 12 | starting 5 + 1 | ~80/min | 0 |
| 8 | 18–22 | 8–10, keep L2 | ~150/min | 0–3 |
| 20 | 25–40 | 12–16 | ~250/min | 5–10 |
| 35 | 35–50 | 15–20, walls | ~300/min | 10–20 |
These are targets for pacing, not balance decisions. FORGE-03 owns the numbers and tells me where they disagree.

## 6. Dead air and hints
- "Meaningful action" means: gather, place, upgrade, recruit, command, capture, change a job quota.
- Idle thresholds before a contextual hint, per phase: Founding 25 s, Expansion 45 s, Conflict 60 s, Endgame 90 s (*targets*). The hint shows once per idle spell, only after onboarding and only if the `showHints` setting is on.
- Hint texts come from FL-0062 (examples: "Build another farm: more food means more citizens", "Upgrade your keep", "Rivals arm themselves: train soldiers at the Barracks").

## 7. How we measure it (FL-0063, `analytics/schemas/events.md`)
- VS-1 funnel: Spawn → FirstGather → FirstBuildPlaced → FirstBuildingComplete → FirstRecruit → FirstCapture, with step times compared against §3.
- Match length (`MatchEnded.durationSec`), and the phase reached when players leave (disconnects).
- Idle hints shown per match (target < 3 for an engaged player).

## 8. Tuning knobs
- `Pacing.luau` `modes.match.*` (phase lengths) and `targets.*` (milestone goals).
- FORGE-03: starting treasury, costs, upkeep.
- FORGE-01: gather and trip times, AI governor aggression (VS-2), and citizen growth from houses.

## 9. Open questions (the user's decisions; nothing here assumes the answers)
- BRIEF §16.3: can a match start with fewer than 4 human teams, and what is the mid-match join policy? This changes Lobby and early Founding.
- BRIEF §16.4: victory rules. Early victory changes Endgame length.
- BRIEF §16.2: PvP intensity. The first-conflict guard in §4 assumes the default (war from Conflict onward).
