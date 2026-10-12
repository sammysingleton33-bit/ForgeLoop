# FORGE-05 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/05-integration` (PR branches `forge/05-integration-fl00xx`); cloud session 2026-10-12 |
| Open PR | FL-0093 G13.7 debug presets + STUDIO_PLAYTEST rows 1–9 (`forge/05-integration-fl0093`) |
| Current task | D-030: merge in dependency order and send the user a build after every visible change (FL-0093). Hours to VS-1 depend on FORGE-01 (sim, population, conversations, reputation, plots); integration adds about 0.5 h per merge wave |
| Last verified check | CI on main green [run 38310484338](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38310484338) at `b6f252f`; user build B1 `forgeloop-game001-b6f252f` (id 11774113089) |
| Blockers | none |
| Needs from others | User: open build B1 (Test → Run) and send the WorldService ready line + screenshots; repo visibility (D-015). FORGE-01: #31 merge-main + F1 (ground slab) push; debug hooks (handoff 2026-10-12 debug-hooks). FORGE-03: #25 conflict fix, then M1 (menus rebuild on every push). FORGE-04: #29 conflict fix. FORGE-02: world part budget, CanQuery on zone parts, pcall around the build. |

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

Closed: #2 (sandbox map, superseded by the AI Kingdoms brief); #13 and #19 (replaced by #24 and #25).

## Toolchain (this session)
Pinned release binaries via `roblox/scripts/ci_install_tools.sh` (Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0,
Lune 0.11.0) — the same binaries as CI; GitHub release downloads worked through the proxy.
