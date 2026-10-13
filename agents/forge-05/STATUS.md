# FORGE-05 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/05-integration` (PR branches `forge/05-*`); cloud session 2026-10-12 |
| Open PR | none of mine (#47 G13.5 spec and #57 CI openpyxl merged) |
| Current task | D-030 / FL-0093: merge in dependency order; user builds B1–B4 delivered, B5 being prepared from `71a0257` (#60 throne/levels/looks, #62 no trees in buildings + rectangle placement, #58/#65 UI fixes, #33 notifications). Waiting on the user's first Studio report |
| Last verified check | main `bcd0d23` CI green [run 38321307926](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38321307926); user build B4 `forgeloop-game001-bcd0d23` (id 11779067478) |
| Blockers | none |
| In review / queued | #61 (FORGE-01 population; reviewed, held for FORGE-03's JobModel target-order fix) · #45 (reviewed; held: tutorial stalls at AnswerCitizen until FORGE-03 reports it) · #42, #49 (reviewed; need FORGE-04 main merge) · #63 (needs FORGE-03 main merge) |
| Merge gates I hold | FORGE-01 `Kingdom.Converse` server only after the client shows option cost and risks (#52 M1, G13.3); #61 only with FORGE-03's JobModel fix (stale `quotas` loses quick taps) |
| Needs from others | User: run B4 and send the Output/FPS/screenshots ask-list (via FORGE-00). FORGE-01: #46 M1 trees through starting buildings, #50 M1/M2/M4/M5, population remotes, FL-0081 PlaceSlot server. FORGE-03: #58 re-sync, FL-0088 gate PR. FORGE-04: R42-1/R42-6, #49 M1/M2 |

## Merged so far (integration log: `production/quality-gates/integration-log.md`)
| PR | What | main sha |
|---|---|---|
| #1 | FORGE-00 skeleton (FL-0003) | `f9e9b0a` |
| #3 | FL-0029 ownership gate (G8), PR template, merge checklist | `3a7b983` |
| #4 | FORGE-01 FL-0007 core utilities | `1e27297` |
| #5 | FORGE-01 FL-0009 RemoteService | `fb5c086` |
| #6 | FL-0046 game-001 wiring + G9 events | `cbe3881` |
| #7 | FL-0047 VS-1 Studio playtest script | `9ba7283` |
| #8 | FORGE-01 review follow-ups (fail-closed validators) | `a0cf019` |
| #9 | FORGE-03 hour-0 stubs: Resources, Costs | `245b6c1` |
| #10 | FL-0029 ownership rule for `world/.gitkeep` | `74f779f` |
| #11 | FL-0067 game-001 wiring follow-ups | `979f1ba` |
| #16 | FORGE-02 hour-0 stubs: Kit (G10), world/Layout (G10.1) | `55846d2` |
| #15 | FORGE-04 PacingService (G11) | `d3a0561` |
| #17 | FL-0029 G8 base = first parent of the test merge commit (stale `base.sha` fix) | `db58aa8` |
| #12 | FORGE-03 TreasuryService, ProductionService, Treasury remotes | `d1910dd` |
| #14 | FL-0068 Studio debug panel (DebugCommands, DebugServer, DebugPanel F8) | `5eb33ae` |
| #18 | FL-0076 Crown Arena fairness harness scaffold | `6f3ce4b` |
| #26 | FORGE-01 hour-0 stub: Kingdom/Types (G2) | `3b22fc9` |
| #23 | FORGE-03 FL-0058 review follow-ups | `63e374d` |
| #24 | FORGE-03 UI kit (replaces #13) | `e3a5e74` |
| #22 (+#20, #21) | FORGE-04 analytics, settings/audio/VFX, onboarding | `fc0ef69` |
| #27, #28 | FORGE-02 Kit v0.2.0; world v0 (WorldService) | `caa376d`, `242c081` |
| #30 | Lighting.Technology = Future | `b6f252f` (user build B1) |
| #32 | ownership row for the G13.7 presets | `2afa5d5` |
| #35 | G13.7 debug presets, STUDIO_PLAYTEST rows 1–9 | `51ebfb3` |
| #36 | boot gate: error-level logs fail, 75 virtual seconds | `da90aba` |
| #25 | FORGE-03 Kingdom HUD and build menu | `bdf1689` |
| #38 (re-target of #37) | FORGE-02 build slots (G13.5) | `dc0b09f` |
| #31 | FORGE-01 Match + Kingdom core | `232bb39` |
| #29 | FORGE-04 ruler controls + aerial camera | `32ef652` |
| #40 | merge checklist: base = main, ls-remote after | `1ba711b` |
| #43 | FORGE-02 world hardening | `986c773` (user build B2) |
| #34 | FORGE-03 plot picker and upgrade panel | `f33e434` |
| #39 | FORGE-01 entity replication | `b37cf9f` |
| #41 | FORGE-03 menus keep their instances (M1) | `94db2a2` |
| #51 | FORGE-01 F1: no ground slab | `a0377a1` (user build B3) |
| #44 | FORGE-03 reputation strip and screen | `81b3b13` |
| #54 | FORGE-01 citizen height | `a65d99b` |
| #52 | FORGE-03 citizen card and conversation UI | `3e0bbfc` |
| #53 | FORGE-00 content library | `4d880a4` |
| #46 | FORGE-01 living-kingdom groundwork | `efa81fe` |
| #48 | FORGE-03 plot-picker follow-ups | `8685b4a` |
| #57 | CI tools job installs openpyxl | `4a67058` |
| #55 | FORGE-03 Jobs tab | `cb03ff8` |
| #50 | FORGE-01 Build remotes | `a683d66` |
| #56 | FORGE-01 G13.5 alignment, Build/Fit | `bcd0d23` (user build B4) |
| #47 | G13.5 Costs vs Buildings integration spec | `9520a57` |
| #59 | FORGE-01 F2/F3 spawn robustness | `6a36062` |
| #58 | FORGE-03 #41/#44/#48 follow-ups (strip gap, state label, modal) | `84c7798` |
| #60 | FORGE-02 throne, building levels, citizen looks | `25b11cb` |
| #65 | FORGE-03 Jobs tab M1/M2 + #58 follow-ups | `0072e9d` |
| #33 | FORGE-04 NotificationController | `575fa3e` |
| #62 | FORGE-01 Kit-rectangle placement, nodes clear of buildings/slots | `71a0257` |

Closed: #2 (sandbox map, superseded by the AI Kingdoms brief); #13 and #19 (replaced by #24 and #25).

## Toolchain (this session)
Pinned release binaries via `roblox/scripts/ci_install_tools.sh` (Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0,
Lune 0.11.0) — the same binaries as CI; GitHub release downloads worked through the proxy.
