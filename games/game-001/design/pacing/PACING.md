# AI Kingdoms — match pacing (FL-0061)

_Owner: FORGE-04. Status: **revised after FORGE-00's review** (`production/handoffs/2026-10-13-forge-00-to-forge-04-doc-reviews.md` §2). Numbers: placeholders; FL-0058 numbers (`design/economy.md`, `config/Costs.luau`, `config/Jobs.luau`) applied 2026-10-13. Open disagreement: the slice length with keep level 2 (§3). Last updated 2026-10-13._

Code:
- config `games/game-001/config/Pacing.luau`;
- `PacingService:phaseDurations(mode)` (CONTRACTS G11), pulled by MatchService (G3).

Everything marked *target* is a tuning goal for playtests, not a measured result. Nothing here has been played yet. This doc decides none of the user's open questions (§9): match length, the Crown Arena format, PvP intensity, walk mode.

## 1. What good pacing means here
- **Something meaningful to do every 30 seconds** (BRIEF §2): inspect a citizen, answer a request, build on a plot, upgrade, recruit, command, capture.
- **A visible step up about every five minutes:** first building, first answered request, first army, first capture, keep level 2.
- **No dead air.** If the local kingdom does nothing meaningful for a while, a contextual hint appears (§6).
- **The match escalates even when players are passive.** Phases are timed in match mode, so Conflict arrives whether or not anyone attacks.
- **Rivals get a fair start.** No raid can land before the defenders have had time to see it coming (§4).

## 2. Phase lengths (seconds; `math.huge` = untimed)

| Phase | slice (VS-1, CONTRACTS G3 interim) | match (config `modes.match`: pre-D-029 split, held until FL-0096; see note) | Ends when |
|---|---|---|---|
| Lobby | 0 | 20 (countdown) | timer |
| Founding | untimed | 480 (0–8 min) | slice: the first `ObjectiveCaptured` moves to Results / match: timer |
| Expansion | untimed (not reached) | 720 (8–20 min) | timer |
| Conflict | untimed (not reached) | 900 (20–35 min) | timer |
| Endgame | untimed (not reached) | 600 (35–45 min) | timer. In VS-1 config, the PROVISIONAL G3 default (Match.luau `victory`) may end it early. From VS-2 (D-029), Endgame always leads to the Crown Arena; last keep standing becomes a coronation there |
| Arena (VS-2; CONTRACTS G12.1 draft) | — | not in `match` until VS-2; BRIEF §3: 360 (38–44 min) | ArenaService stage `done` (crown-arena §2) |
| Results | untimed (summary stays up) | 30 | timer |

**Note.** BRIEF §3 (D-029) times the match as Founding 0–8, Expansion 8–20, Conflict 20–32, Endgame 32–38 and Crown Arena 38–44, then Results with the leadership recap to 45 (about 60 s; config Results is 30 s). `modes.match` keeps the pre-D-029 split for two reasons:
- MatchPhase has no Arena before VS-2 (G2, G12.1);
- match length is open (BRIEF §16.10, FL-0096; `design/living-kingdom.md` §6 holds the config until the user decides).

The split must be re-cut before VS-2 whatever FL-0096 decides, because adding an Arena to it gives about 51 minutes, outside BRIEF §1's 30–45. When FL-0096 is decided or G12 freezes, whichever comes first, FORGE-04 re-splits `modes.match` and `PacingService.DEFAULTS`, and FORGE-01 updates Match.luau `durations.match`.

- If Founding..Endgame falls outside 30–45 min, PacingService logs an error and serves its built-in defaults for the whole config; the match is never blocked. From VS-2 the bound must cover Founding..Arena (G12.1).

### `match30`: evaluation profile, not the default (D-030 (6), FL-0092)
The user prefers about 25 minutes of kingdom play, then a 5-minute final phase, ending around minute 30. BRIEF §3 puts the arena at 38–44 minutes. The conflict is recorded and not resolved (`design/living-kingdom.md` §6, BRIEF §16.10). `match30` lets the team play the short version without changing the default.

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
- Results is 30 s as in `design/living-kingdom.md` §6; BRIEF §3 implies about 60 s for the leadership recap. FORGE-00 settles this with FL-0096.

## 3. VS-1 slice, minute by minute (*targets*, from spawn; onboarding v2, D-030)
EXPERIENCE.md §2 cites these numbers; this section holds them.

Assumptions (FL-0058 numbers; FL-0050 measures them; **unverified**):
- Costs (`config/Costs.luau`): starting treasury food 120 / wood 100 / stone 50; house 40 wood (20 builder-s); farm 50 wood (25 s); barracks 120 wood + 60 stone (**8 builder-s**, D-030); soldier 30 food + 10 wood (8 s, 1 food/min upkeep); keep L2 150 wood + 150 stone (60 s); upkeep 1 food per citizen per minute.
- Starting population (FORGE-01): farmer 3, woodcutter 3, miner 2, builder 2, hauler 2.
- Rates: the FL-0058 targets (`design/economy.md`): about **8 wood/min per woodcutter, ≥ 5 food/min per farmer, 8 stone/min per miner**. FORGE-01's `config/Jobs.luau` (gatherRate, harvestTime 6 s, carry 10) and `config/Citizens.luau` (citizenSpeed 12) set the trips that produce them. So the kingdom earns about 24 wood, 15 food and 16 stone per minute.
- **Ruler gathering is optional (D-030): an accelerator, not a step.** The ruler starts seated on the throne in the aerial view (G13.6).

| Time | Player does | Feedback (FL-0062, FL-0091) | Onboarding step | Analytics (FL-0063) |
|---|---|---|---|---|
| 0:00 | The view opens above the keep with the ruler seated; citizens already working | founding horn, kingdom toast | 1 Spawn (`KingdomJoined`, auto) | VS1 1 Spawn |
| 0:02–0:20 | taps a citizen; the citizen card opens | selection sound | 2 InspectCitizen (client-reported; first interaction ≤ 30 s = Onboarding `limits.firstInteractionSec`) | `targets.firstInspectSec` 30 (timing only; no funnel step) |
| 0:20–1:10 | opens Build and places a House or Farm (affordable from the start: 100 wood). Builders raise it (20–25 builder-s) | place thunk, dust puff, hammering, completion fanfare | 3 BuildOnPlot (`BuildingPlaced` with the placer match; Build-button hint until FL-0081, then the plot markers) | VS1 3 FirstBuildPlaced (*≤ 90 s*); VS1 4 FirstBuildingComplete (*≤ 150 s*; a funnel step, not an onboarding step in v2) |
| 1:10–2:40 | answers a citizen's "!" request (`Kingdom.Choose` ok) | reaction bubble and pose, the visible consequence | 4 AnswerCitizen (client-reported; passed over without ConversationService, moves on after 120 s) | `targets.firstAnswerSec` 180 (timing only) |
| 2:30–3:00 | places the Barracks once the treasury reaches 120 wood (about 2:30 at 24 wood/min after the house); stone is enough by then (≈ 90). It builds in seconds (8 builder-s) | stockpile counters rising, hammering | (Recruit card: "Build a Barracks, then recruit 3 soldiers") | — |
| 3:00–5:10 | recruits 3 soldiers (90 food + 30 wood; the wood arrives at about 3:45) | horn, soldiers at the Rally | 5 Recruit (`UnitsRecruited`) | VS1 5 FirstRecruit (*≤ 330 s*) |
| 5:10–7:10 | presses Send-to-capture; soldiers walk to the neutral Watchtower; the capture bar fills | capture sting, tower recolours, border flags, celebration | 6 Capture (`ObjectiveCaptured`) | VS1 6 FirstCapture (*≤ 450 s*) |
| ~7:30 | slice summary (FORGE-03) | — | done | `MatchEnded` |

**VS1 step 2 (FirstGather)** is the first ResourceGathered credited to the player: their own gather, or any citizen deposit into their kingdom (credited to every member, Feedback/Signals). It marks that the economy has started; it is not a ruler-action pacing target. `targets.firstDepositSec` (45 s from Founding) is the matching sim health check. Under the funnel-order rule (G9 v0.4-g6), a ruler who places a building before their first deposit credit loses that FirstBuildPlaced (dropped, not deferred) and is credited at their next placement.

The guided path above follows BRIEF §4 "First minutes guided": inspect a citizen → build on a plot → answer a citizen → recruit → capture. Its target length is **6–8 minutes** for a new player.

**Open, with FORGE-03 and FORGE-00: keep level 2 and the slice length.** BRIEF §4 row 6 asks for a keep upgrade in the slice, and `design/economy.md` aims at about 10 minutes including keep L2. At the FL-0058 rates, keep L2 (150 wood + 150 stone after the barracks and soldiers) is affordable only at about 10–11 minutes, so the guided path reaches the capture first, and the capture ends the slice (G3). Either the slice includes keep L2 before the capture (the onboarding gains a step, or the capture waits for it), or keep L2 moves after the slice. This doc does not choose; it records the gap (handoff to FORGE-03 and FORGE-00).

Watch points (*unverified*):
- **Food after recruiting:** 3 farmers bring about 15 food/min; 12 citizens and 3 soldiers eat about 15/min, so net food is about 0 after recruiting, before births (Citizens.luau `birthFood` 25 each) and meals (while `mealsChargeTreasury = true`). The 120 starting food covers the soldiers (90). If playtests show the stockpile falling, FORGE-03 tunes farms or upkeep.
- **The Barracks and soldier wait (about 2:30–4:00) is the slice's dead-air risk.** During the tutorial, this wait is guided by the Recruit card ("Build a Barracks, then recruit 3 soldiers"). In v2 it is also guided by the AnswerCitizen step and the citizens' request bubbles (FL-0091), which give the ruler something meaningful to do while the stockpile grows. Idle hints apply only after the tutorial (§6). Recruit's `nudgeAfterSec` (180) is above its `expectSec` (150), so its escalation means stuck, not still saving up.
- Playtest measure (not a hint trigger): time from the first BuildingCompleted to the Barracks being placed. If it exceeds 45 s, FORGE-03 can lower the Barracks cost or raise starting wood.

## 4. Full match (*design target*; follows BRIEF §3, differs from `modes.match` until FL-0096)
| Minute | Phase | Typical state of a kingdom | Big moment | First-conflict guard |
|---|---|---|---|---|
| 0–2 | Founding | the slice flow above | founding, first answered request | — |
| 2–8 | Founding | 3–5 new buildings; population grows with houses; keep level 2 around minute 8–11 | keep L2 (citizens cheer) | no war: diplomacy default is war only from Conflict (CONTRACTS G3 clarification) |
| 8–20 | Expansion | outposts and neutral nodes claimed; walls start; ~25–40 citizens | first outpost captured | border contact is possible but there is no PvP damage until Conflict |
| 20 | Conflict starts | first armies (5–10 soldiers) | only when Match.luau `pvp.enabled` (BRIEF §16.2): "War is declared" announcement + horn. With PvP off (the shipped default): "The Conflict begins: rivals arm themselves" | only when `pvp.enabled`: **earliest raid ≈ minute 21–22**: soldiers must walk across the valley, so defenders have about 60 s of warning |
| 20–32 | Conflict | raids on farms and stores (with PvP on); alliances form and break (VS-3) | first raid repelled / first raid landed | — |
| 32–38 | Endgame | sieges; Crown Points decide who reaches the arena | siege, keep falls / holds | — |
| 38–44 | Crown Arena (VS-2; format PROVISIONAL, BRIEF §16.9) | qualification → loadout → intro → duel → crowning, or a coronation if one keep stands | the duel and the crowning | — |
| 44–45 | Results | standings and the leadership recap | victory / defeat | — |

**Rhythm:** one "big moment" about every 5 minutes (*target*). The announcer (FL-0062) amplifies the moments that matter to the local kingdom and stays quiet otherwise.

## 5. Economy growth targets (for FORGE-03's balance sheet, FL-0058)
| By minute | Population | Buildings (own) | Stockpile income (all resources) | Army |
|---|---|---|---|---|
| 2 | 12 | starting 5 + 1 | ~55/min (24 wood + 15 food + 16 stone) | 0 |
| 8 | 18–22 | 8–10 | ~150/min | 0–3 |
| 20 | 25–40 | 12–16, keep L2 | ~250/min | 5–10 |
| 32 (Endgame starts) | 35–50 | 15–20, walls | ~300/min | 10–20 |

These are targets for pacing, not balance decisions. FORGE-03 owns the numbers and tells me where they disagree.

## 6. Dead air and hints
- "Meaningful action" means: inspect a citizen (G13.6 selection), answer a citizen (`Kingdom.Choose` ok), build on a plot or place a building (`Build.PlaceSlot` / `Build.Place`), upgrade, recruit, command, capture, change a job quota, and gather (optional). A camera pan or zoom alone does not count.
- Idle thresholds before a contextual hint, per phase (*targets*): config `Pacing.luau` `idleSec` = Founding 25 s, Expansion 45 s, Conflict 60 s, Endgame 90 s, served by `PacingService:idleSec(phase)`. No Arena entry until G12 freezes. The hint shows once per idle spell, only after onboarding and only if the `showHints` setting is on.
- Hint texts come from config `Onboarding.luau` `idleHints` (FL-0062 decides when to show them; examples: "Tap a citizen with a request, or build on a free plot", "Upgrade your keep", "Recruit soldiers at the Barracks").

## 7. How we measure it (FL-0063, `analytics/schemas/events.md`)
- VS1 funnel: Spawn → FirstGather → FirstBuildPlaced → FirstBuildingComplete → FirstRecruit → FirstCapture, step-to-step conversion (G9 order rule, v0.4-g6).
- **Milestone times** (§3 targets) come from Studio `env.log` timestamps in playtests (the `onboarding step` and `analytics funnel` lines). LogFunnelStepEvent carries no time, so live data cannot check them yet; a milestone-timing event is proposed in FORGE-00's review (events M7) and decided with the analytics doc update.
- Match length (`MatchEnded.durationSec`), and the phase reached when players leave (`PhaseLeft`).
- Idle hints shown per match (target < 3 for an engaged player; `IdleHintShown`, server-side when FL-0062 lands).

## 8. Tuning knobs
- `Pacing.luau`: `modes.*` (phase lengths), `targets.*` (milestone goals) and `idleSec.*` (dead-air thresholds).
- `Onboarding.luau`: each step's `expectSec`, `nudgeAfterSec` and `autoAdvanceSec`.
- FORGE-03: starting treasury, costs, upkeep.
- FORGE-01: gather and trip times, AI governor aggression (VS-2), and citizen growth from houses.

## 9. Open questions (the user's decisions; nothing here assumes the answers)
- BRIEF §16.3: can a match start with fewer than 4 human teams, and what is the mid-match join policy? This changes Lobby and early Founding.
- BRIEF §16.4: the match ends in the Crown Arena (D-029). Still open: what eliminated players do. In VS-1 config, last keep standing may end the match early as a PROVISIONAL G3 default (Match.luau `victory`).
- BRIEF §16.9: Crown Arena format, champion choice, what the duel decides and support strength. A bracket changes the Arena length.
- BRIEF §16.10 / FL-0096: match length, about 25 + 5 min (`match30`, evaluation only, FL-0092) or the BRIEF §3 timing. This doc does not choose. `modes.match` stays as configured until the user decides.
- BRIEF §16.13: walk mode outside the arena. The VS-1 default is the throne and the aerial view (D-030), so no pacing step may require walking.
- BRIEF §16.2: PvP intensity. Config ships `pvp.enabled = false` (PROVISIONAL); the first-conflict guard in §4 applies only when it is on (war from Conflict onward).
