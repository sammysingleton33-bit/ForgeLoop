# VS-1 slice pacing probe (FORGE-05; FORGE-00 request after #70)

Headless evidence only (Lune + MockEnv, every real server service on one MockEnv per run). Not a Studio
play test and not a measure of how a real new player plays. Spec: `games/game-001/tests/balance/PacingProbe.spec.luau`
(FORGE-05 PR). Measured on main `6c567e5` (after #70, #89 and #91; seeds 1-5) and re-run on `8cb3af0`
(after #86 and #87; seeds 1-3, identical values). Slice mode, default job quotas, one human in crimson
who acts only through the real remotes (`Build.GetSlots`, `Build.PlaceSlot`, `Army.Recruit`,
`Army.Command`). Times are seconds after spawn (Founding starts on the join). Targets: `config/Pacing.luau`
`targets` (tuning goals for a typical new player, not rules). `!` = more than 25 % off target.

## Results (medians over seeds; per-seed spread under 6 s)
| Milestone | A greedy (House, Barracks, recruit 3, capture) | Abf greedy, barracks first | C onboarding-paced | Target |
|---|---|---|---|---|
| First building placed | 1.0 (−99 % !) | 38.5 (−57 % !) | 70.5 (−22 %) | 90 |
| First building complete | 19.0 (−87 % !) | 50.4 (−66 % !) | 127.9 (−15 %) | 150 |
| First recruit (3 soldiers) | 65.0 (−80 % !) | 50.5 (−85 % !) | 220.5 (−33 % !) | 330 |
| First capture | 143.6 (−68 % !) | 130.3 (−71 % !) | 395.1 (−12 %) | 450 |

- C waits for the onboarding `expectSec` of each step (House at 2 + 18 + 50 s, recruit 150 s after the
  House, Send 120 s after the recruit; AnswerCitizen is passed over while ConversationService is absent).
  The economy allowed C's recruit at about 81 s. Inferred: with Send pressed as soon as the soldiers are
  trained, C captures at about 299 s (−34 %); with AnswerCitizen's 90 s in the flow, C recruits at about 310 s.
- `firstGatherSec` (45) is not measurable headless: ruler gathering needs a character, which MockEnv
  lacks. Citizens make their first deposit at a median of 17.2 s.
- Every run: 0 error logs, 0 thread errors, 0 refusals; each charge exactly once (one House, one Barracks,
  one recruit of 3 at food 90 + wood 30); one `Match.Ended`.

## AI kingdoms in the slice (profile B, idle human, 900 s)
- **On main the AI kingdoms do nothing in slice mode**: `Kingdom/Match.luau:148` installs RulerAI only in
  `match` mode, and `:149` populates a kingdom only when a ruler joins. Azure, emerald and gold keep their
  5 starting buildings with 0 citizens, 0 rulers and 0 soldiers; the watchtower stays neutral; the phase
  stays Founding. A new player cannot lose the slice to an AI capture, and sees three empty kingdoms.
- What-if (not main; `FORGE_PACING_FULL=1`, AI governor on and every kingdom populated as in match mode):
  no AI ever captures. AIs recruit at about 378-426 s and reach the tower at about 438-446 s; from the
  second arrival on, the AI armies contest the tower for good (PvP off, `config/Match.luau:37`;
  `Sim/Objectives.luau:67-69`). The onboarding-paced human still wins at 395 s; a human who sends at 480 s
  never captures. Inferred: with AI on, any human who arrives after about 440-455 s is blocked.

## Where the time goes (A, median)
House affordable at t = 0 (start wood 100, house 40; `Costs.luau:90`, `:41`), done at 19 s (about 8 s
walk-in, 20 builder-seconds). Then about 43 s waiting for wood for the Barracks (wood reaches 120 at
43.9 s; stone reaches 60 at 38.4 s; `Costs.luau:63`), Barracks done at 53.8 s (8 builder-seconds), about
11 s waiting for the recruit's 30 wood, 24 s training (3 × 8 s one at a time; `Costs.luau:85`,
`Sim/Military.luau:982`), about 35 s march (speed 14, `config/Military.luau:22`), about 19.7 s capture
(`config/Objectives.luau:16`). Fixed tail after the recruit: about 79 s. Food is never the limit. Night
(citizens sleep 90-120 s, 210-240 s, …; `Citizens.luau:11-12`) only slows slower players.
Idle kingdom income over 0-300 s: food 86, wood 76-86, stone 52 per minute.

`games/game-001/design/pacing/PACING.md` §3 no longer matches the code: it assumes a 45 s Barracks build
(line 51; code 8 s), per-worker gather rates (line 53) that give about a third to a half of the measured
kingdom income, and a 2:30-4:00 wait for the Barracks (line 61; measured about 43 s).

## Knobs (none changed; owners decide)
- First building placed: player pacing only (House affordable at t = 0); onboarding `expectSec`.
- First building complete: House build time (`Costs.luau:41`), builders and builders per site
  (`Kingdoms.luau:20`, `Sim/Simulation.luau:98`), build rate (`Jobs.luau:33`), slot distance, night.
- First recruit: Barracks and soldier cost and time (`Costs.luau:63`, `:85`) against start stock
  (`Costs.luau:90`) and income (job quotas, gather rate and carry `Jobs.luau:31/34`, node sizes
  `:26-29`); or a keep-level gate on the Barracks like the watchtower's `requiresKeepLevel`.
- First capture: training time × batch and the one-at-a-time queue, soldier speed, tower position,
  capture time; onboarding Capture 120 s.
- AI in the slice: decided by FORGE-00, D-043: the VS-1 slice stays AI-free (BRIEF §4 row 1, G3); AI governors come in VS-2. `Kingdom/Match.luau:148-149` defaults unchanged.

Sent to FORGE-00, FORGE-03 (economy) and FORGE-04 (Pacing.luau, PACING.md) on 2026-10-13. Tuning waits
for the user's play (FORGE-00).
