# FORGE-05 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/05-integration` (PR branches `forge/05-*`); cloud session 2026-10-12 |
| Open PR | none of mine (#47, #57, #69 merged) |
| Current task | D-030 / D-034 / FL-0093: merge in dependency order and ship numbered builds. **B8** (`751138b`, conversation lane: #77 + #101/#103/#106) prepared and sent to FORGE-00. D-040 fallback verdicts on FORGE-00's ★ list while FORGE-07 is paused; next: #104 (after FORGE-01 merges main), #105 (review running) |
| Last verified check | main `751138b` (#77): check.sh 9/9 on the merge result (game-001 1146/0); main CI [run 38375686542](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38375686542) green; B8 artifact id 11801272018 |
| Blockers | none. Process note: #79, #76, #75, #42 merged minutes after D-037 without FORGE-07 verdicts (FORGE-00: no reverts, post-merge verdicts) |
| In review / queued | #77 re-review running on c5ad31d (B1/M1/M2 fixes pushed) → B8. Not ★ (wait for FORGE-07 unless promoted): #100 (gather, on #94), #101 (#91 follow-ups), #102 (my pacing probe spec). Waiting for FORGE-07 (not on the D-040 list): #86, #88, #85, #93, #94, #90, #96, #97, #49, #64, #82, #84, #92 |
| Merge gates I hold | Conversation lane: #77 after B1/M1/M2 fixes (#87 client already on main) → B8 |
| Needs from others | User: run B6/B7 and send Output/FPS/screenshots (via FORGE-00). FORGE-01: #68 M1 upgrade credit, #91 M1 reseed looks, #89 M1 slot reservation + M3 lumber/quarry level bonus. FORGE-03: #86 M1 (ui-economy.md U4 text), #86 L5/L6 (Overview 👑 icon, gem.png upload). FORGE-04: onboarding hints `BuildOnPlot` → `BuildSlot`, `Recruit` → `HUD.ArmyButton`. FORGE-00: #89 L3 walls/gates on plots; pacing probe numbers (next) |

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
| #62 | FORGE-01 Kit-rectangle placement, nodes clear of buildings/slots | `71a0257` (user build B5) |
| #69 | FORGE-05 D-033 (4) colour-vision check, run 1 | `124af89` |
| #72 | FORGE-01 destroyed buildings broadcast (#50 M1) | `c5208ac` |
| #67 | FORGE-00 content follow-ups, `fireAction`, integer `startLoyalty` | `27c8cbe` |
| #71 | FORGE-03 Jobs ack beats older payload (unblocks #61) | `0c272f6` |
| #74 | FORGE-03 HUD places NotificationController (#33 M1) | `0a7c9f1` |
| #73 | FORGE-02 kingdom colours from `config/Kingdoms.luau` (D-033) | `bf84416` |
| #61 | FORGE-01 generated population, CitizenView | `ad71b3e` |
| #78 | FORGE-06 ownership rows (cross-owner, accepted) | `1a6bebc` |
| #79 | FORGE-03 UI tinctures = canonical colours | `84e143a` |
| #76 | FORGE-03 ghost "Room" outline | `36d5ca9` |
| #75 | FORGE-02 throne clearance, coplanar faces | `7b6cd51` |
| #42 | FORGE-04 citizen bubbles and placards | `c28576a` (user build B6) |
| #80 | FORGE-07 ownership row (cross-owner, accepted) | `54f7390` |
| #83 | FORGE-00 content v0.4-g7 (`choicePreview` fillNames), D-040 | `f3d84b5` |
| #66 | FORGE-03 conversation cost/risk panel, D-040 | `9710822` |
| #63 | FORGE-03 Army drawer, objective tracker, slice summary, D-040 | `5764630` |
| #45 | FORGE-04 match30 profile, onboarding v2, D-040 | `ac97689` |
| #68 | FORGE-01 ReputationService (M1 tracked), D-040 | `9478229` |
| #95 | FORGE-03 #63 L1, #77 L4, D-040 | `fd1369f` |
| #81 | FORGE-02 soldier helmet crest per kingdom, D-040 | `ec5218a` |
| #70 | FORGE-01 Army server: recruit (bunks, D-041), command, capture, D-040 | `d3525db` |
| #91 | FORGE-01 aerial LOD centre, crest plumbing, debugReseed (M1 tracked), D-040 | `ab70493` |
| #89 | FORGE-01 build slots, throne seat (M1/M3 tracked), D-040 | `297eac5` (user build B7) |
| #87 | FORGE-04 bubble targets v0.4-g6, rest effect stops, D-040 | `42b6709` |
| #86 | FORGE-03 FL-0105 refusal words, D-039 emblems + gem badge (M1 tracked), D-040 ★ | `2a6a247` |
| #88 | FORGE-03 FL-0087 plot picker on Build/Fit, D-040 ★ | `c338f44` |
| #101 | FORGE-01 #91 follow-ups (reseed looks, LOD zoom), D-040 ★ | `c8572f4` |
| #103 | FORGE-03 #86 follow-ups (Studio text, gem, banner tab), D-040 ★ | `f2d430a` |
| #106 | FORGE-01 #89 follow-ups (slot reservation, not_on_plot, camp levels), D-040 ★ | `aecd245` |
| #77 | FORGE-01 FL-0079 ConversationService (conversation lane), D-040 | `751138b` (user build B8) |

Closed: #2 (sandbox map, superseded by the AI Kingdoms brief); #13 and #19 (replaced by #24 and #25).

## Toolchain (this session)
Pinned release binaries via `roblox/scripts/ci_install_tools.sh` (Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0,
Lune 0.11.0) — the same binaries as CI; GitHub release downloads worked through the proxy.
