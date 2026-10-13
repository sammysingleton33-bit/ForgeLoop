# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-<task>` |
| Open PRs | #86 FL-0105 (refusal codes, gold crest sunburst, Toast achievement accent, this file) · #66 FL-0088 gate + confirm step (`256ad31`), waiting on FORGE-07's verdict (D-037) · #63 FL-0060 (`9effd04`): Army rail hidden until `Army.Recruit` is served (D-038 (2)). Merged: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #65, #71, #74, #76, #79. Closed: #13, #19. |
| Current task | FL-0105 (P0). Next: FL-0087 plot picker → `Fit.typesFor` (delete `UI/SlotFit`); #63 re-shoot of army/objectives/summary renders after #86 lands; FL-0099 cinematic conversation UI (G13.8) once FL-0088 merges and FL-0097/FL-0098 exist |
| Last verified check | #86 check.sh PASS (see the PR) · #63 `9effd04` PASS (972/0) · #66 `256ad31` PASS (967/0) |
| Blockers | none; Studio checks (G6) need the user and FORGE-01's real Kingdom/Match/Build/Slot services |
| Needs from others | FORGE-07: verdicts on #66, #63, #86. FORGE-01: #70 (Army remotes; #63 shows the rail once they exist), Converse/Choose server (#77). FORGE-05: Studio steps U4.5, U5.5, U13, U15. |

## Estimate to VS-1 (FORGE-03 rows, unverified, hours of FORGE-03 work)
| Item | Hours | Notes |
|---|---|---|
| FL-0088 conversation + citizen card v2 | done (#52); gate in #66 | costs and risks before choosing |
| FL-0089 reputation strip + screen | done (#44); 0.5 | text switches to the content library when FL-0083 lands |
| FL-0060 army/objective panels, slice summary | done (#63) | doubles until FORGE-01's #70 |
| FL-0105 refusal codes, crest, achievement toast | done (#86) | |
| FL-0087 plot picker on `Fit.typesFor` | 1 | |
| Swap doubles for FORGE-01's real services | 3 | contract mismatches show up here |
| Fix round after the user's Studio playtest | 3 | depends on what the playtest finds |
| **Remaining** | **7–8** | review rounds (0.5–1), FL-0087 switch (1), real-service swap (3), playtest fixes (3). FL-0073 Crown Arena UI (P2, 18 h) is outside VS-1 |

## Last report
- **Done:** FL-0105 in #86: every refusal code the server returns has its own sentence (spec reads
  the Reasons line of `Build/Remotes.luau`); Sunspire's crest is a drawn dark-gold sunburst on an ivory
  roundel (FORGE-02's world design), at least 3:1 against the roundel; Toast `achievement` = purpure
  accent + laurel icon. #63: D-038 (2) Army rail hidden until the remotes exist.
- **Verified:** check.sh PASS; mutations killed (listed in #86); renders looked at (4 crests,
  standings, refusal text, kit toast row).
- **Unverified:** Studio; FORGE-01's real Army and Converse/Choose services.
- **Next:** FL-0087 `Fit.typesFor`; #63 re-shoot after #86.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
