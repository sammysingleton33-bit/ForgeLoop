# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12); one PR branch per task: `forge/03-ui-economy-<task>` |
| Open PRs | #88 FL-0087 plot picker on `Build/Fit.typesFor` (`b76003a`, main merged; FORGE-05 reviews next under D-040) · FL-0105 follow-ups (FORGE-05's #86 review: M1 Studio-doc sentence, L2-L9). Merged today: #63, #66, #86, #95. Merged before: #9, #12, #23, #24, #25, #34, #41, #44, #48, #52, #55, #58, #65, #71, #74, #76, #79. Closed: #13, #19. |
| Current task | FL-0105 follow-ups. Next: FL-0099 cinematic conversation UI (G13.8) once FL-0097/FL-0098 exist; Talk as the primary action lights up when FORGE-01's #77 sends `hasRequest` (client done) |
| Last verified check | FL-0105 follow-ups check.sh exit 0 (see the PR) · #88 `b76003a` exit 0 (516/0, game-001 1102/0) · #86 merged on FORGE-05's test merge (516/0, 1101/0) |
| Blockers | none; Studio checks (G6) need the user |
| Needs from others | FORGE-01: `not_on_plot` on the Reasons line once served (the client words it already). User: upload `gem.png` and `emblem_crown.png` (handoff 2026-10-13-forge-03-to-user-icons-d039). FORGE-02: check the shorter oak midrib by eye. FORGE-07: post-merge reviews (D-040). |

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
- **Done:** merged #63 (army drawer, objective tracker, summary), #66 (conversation confirm step),
  #86 (FL-0105: every server refusal code in words, including plots #89 and bunks D-041; crests drawn
  as on the world banners, D-039; gem Crown Points; achievement toast), #95 (tracker waits for the Army
  remotes; Choose refusals in words). FORGE-05's end-to-end runs against FORGE-01's real Army (#70) and
  conversation (#77) servers worked.
- **Verified:** check.sh exit 0 on each branch; mutations listed per PR; renders looked at.
- **Unverified:** Studio (G6); the drawn emblems and the 💎/★/🏅 glyphs on each platform.
- **Next:** #88 review; FL-0105 follow-ups PR; FL-0099 once FL-0097/FL-0098 exist.

## Doubles in use
- game-001 specs use local doubles for FORGE-01 services (`KingdomWorld`, `SlotDoubles`) and FORGE-04
  controllers (`InputModeController.selected`); listed in each PR.
