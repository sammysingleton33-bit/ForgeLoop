# FORGE-05 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/05-integration` (PR branches `forge/05-*`); cloud session 2026-10-12 |
| Open PR | #102 (pacing probe spec; not ★, waits for FORGE-07). #120 merged (`0d71eff`) |
| Current task | **B19 (in progress):** merged batch C (#170, #168, #167, #165), #172, #173 (ConsequenceChanged fire), #174, #110 (economy doc). Last item: #175 (FORGE-04 riot placard, consequence notices, fire VFX). FORGE-07 CHANGES REQUESTED (M1 sound pick list, M2 start/stop toast keys coalesce into "×2"); fixes asked of FORGE-04; I re-gate, then cut B19. B18 = `f3298dd` (artifact 12017020957) |
| Last verified check | B18 `f3298dd`: check.sh PASS (framework 551/0, game-001 1692/0, Selene 0/0, StyLua 525, place check PASS; sim#1/2 444 s, sim#2/2 171 s); B14/B15 probes 11/11; exact clearance probe on #169 (arms +0.35…+0.68, tools ≥ 1.05) |
| Blockers | none. Lesson: long gates (check + four mutation runners) exceed the 30-min background default: pass a longer `timeout`, and restore any mutated file in the test worktree if a run is killed |
| In review / queued | B19: #175 (FORGE-04 fixing M1/M2). Then #118, #100 (held), #90. Low for FORGE-03: economy.md:90/:100 still says the ruler caps are not applied (they are, `RulerGather.perMinute`) |
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
| #99 | FORGE-04 onboarding hints on BuildSlot / Army button, walk-mode unseat, D-040 ★ | `d887beb` |
| #104 | FORGE-01 #68 follow-ups (upgrade credit), D-040 ★ | `3f3ac6d` |
| #109 | FORGE-05 G9 CitizenAnswered declaration (FORGE-00 approved) | `b0509b0` |
| #107 | FORGE-01 #77 follow-ups N2-N5 (M1-M3 tracked), D-040 ★ | `276d933` |
| #105 | FORGE-02 kingdom emblems from the overview camera, D-040 ★ | `f562a31` (user build B9) |
| #114 | FORGE-01 #107 follow-ups M1-M3, D-040 ★ | `74db60c` |
| #112 | FORGE-01 throne for its kingdom's rulers only (#89 L2), D-040 ★ | `1c48149` (user build B10, FORGE-00) |
| #116 | FORGE-05 check.sh: game specs per top-level folder, each under STEP_TIMEOUT | `56b4d7c` |
| #115 | FORGE-01 owner change rebuilds the building or captured watchtower in the owner's Kit look (VS-1 row 7; ★ for B11) | `38526a4` |
| #117 | FORGE-01 #115 L1 spec: rebuilt tower keeps its pivot, a second capture, no leak (★, spec-only) | `1d4c076` |
| #49 | FORGE-04 FL-0062 VS-1 feedback layer: announcer, kingdom effects, work feedback, phase music (★) | `21904e4` |
| #120 | FORGE-05 MockEnv installs EngineStubs once per process (Lune has no ParticleEmitter:Emit); Boot spec celebration case | `0d71eff` |
| #92 | FORGE-04 D-038 (7) per-feature mutation rows, Studio-test history, analytics taxonomy (★, D-046) | `13acf26` |
| #113 | FORGE-01 FL-0050 remainder: D-045 births, keep-L2 celebration, ruler visit, decision budget (★, D-046) | `cac9522` |
| #97 | FORGE-01 FL-0106 Match.Ended for late joiners during Results (★, D-046) | `681f38c` |
| #111 | FORGE-01 FL-0107 G9 CitizenAnswered (★, D-046) | `003e180` |
| #122 | FORGE-00 reputation notices for soldiers_recruited / wall_built (★, B13) | `196b1df` |
| #119 | FORGE-04 FL-0062 follow-up: the summary owns the result line (★, D-046) | `d65fb2e` |
| #93 | FORGE-01 FL-0049 replication hardening (★, D-046; M1 fixed) | `7694638` |
| #85 | FORGE-02 FL-0098 `Kit.portrait` (B14) | `76396d1` |
| #108 | FORGE-01 FL-0097 conversation server, g9f hold (B14) | `787f24e` |
| #84 | FORGE-04 FL-0100 (1/2) conversation camera (B14) | `5eba538` |
| #121 | FORGE-04 FL-0100 (2/2) reaction poses (B14) | `2bffebf` |
| #126 | FORGE-03 FL-0099 cinematic conversation UI (B14 = this sha) | `3691475` |
| #131 | FORGE-01 FL-0112 farm and plot clearance (B15) | `81f9637` |
| #134 | FORGE-04 B14 Studio probes (docs) | `c651ff4` |
| #133 | FORGE-04 FL-0115 bubble readability (B15) | `d5587b7` |
| #132 | FORGE-01 FL-0113 PlaceSlot turn (B15) | `f36b1f0` |
| #137 | FORGE-04 FL-0115 hover and selection outlines (B15) | `e7ab2f5` |
| #135 | FORGE-03 FL-0114 rotation UI (B15 = this sha) | `b2e3164` |
| #96 | FORGE-00 FL-0083 SPEC v1.5 / CONTRACTS g10 | `3add643` |
| #128 #94 #82 #64 #98 #102 | FORGE-07 READY set (combined gate) | `f11817c` … `9d02bc2` |
| #141 | FORGE-02 FL-0117 interim environment art (B16) | `d9bb32a` |
| #143 | FORGE-04 hover-clear spec | `c2f1e7b` |
| #136 | FORGE-01 wallGap (B16) | `dffa488` |
| #139 | FORGE-03 pad turn R1/L1 (B16 = this sha) | `e447364` |
| #145 | FORGE-01 FL-0122 server hardening (D-050) | `c3c6b8a` |
| #130 | FORGE-04 InputModeController.back | `e639c79` |
| #151 | FORGE-02 FL-0117 round 2 trees (interim art) | `968a24a` |
| #142 | FORGE-04 FL-0121 edit mode input and camera | `520988e` |
| #150 | FORGE-01 STATUS refresh | `e57b198` |
| #152 | FORGE-01 FL-0112 farm clearance by drawn extent | `9983ed4` |
| #154 | FORGE-01 cheer pose clears the head | `7918184` |
| #149 | FORGE-04 FL-0115 request badges | `33f1e4e` |
| #127 | FORGE-01 FL-0109 paged GetEntities | `41d6b46` |
| #129 | FORGE-01 History text | `5653a97` |
| #124 | FORGE-04 FL-0108 (1/2) | `a6a514e` |
| #144 | FORGE-04 FL-0092 hint targets (House) | `f8c85ac` |
| #158 | FORGE-01 cheer pose for tool assemblies | `8f27511` |
| #123 | FORGE-04 FL-0103 settings panel | `98698c4` |
| #146 | FORGE-04 FL-0108 (2/2) | `7f22ab4` |
| #159 | FORGE-02 FL-0116 world trim (interim art) | `93e41e6` |
| #157 | FORGE-04 E12 Move flow, no edit-mode pan | `3b159e2` |
| #148 | FORGE-03 FL-0120 base editing UI | `08f1d63` |
| #140 | FORGE-01 FL-0119 base editing server | `43895b9` |
| #147 | FORGE-04 FL-0063 analytics review items | `9b0de55` |
| #163 | FORGE-04 FL-0025 completeReward rule | `99ef428` |
| #161 | FORGE-01 Pose.spec tip sign | `d982a33` |
| #160 | FORGE-02 FL-0124 world nodes out of farms (B17 cut) | `41a70e8` |
| #138 | FORGE-02 FL-0118 phase 1 citizens (interim art) | `8682686` |
| #162 | FORGE-03 FL-0059 back key | `4bb9039` |
| #164 | FORGE-04 isTap + E11 | `fde793d` |
| #153 | FORGE-02 FL-0118 phase 1b (interim art) | `8eca5f5` |
| #125 | FORGE-01 FL-0082 consequences | `61eea1d` |
| #156 | FORGE-01 FL-0110 presentation tags | `ad790b6` |
| #155 | FORGE-02 FL-0118 phase 2 tools (interim art) | `5fbc515` |
| #169 | FORGE-02 Kit shoulder pivots | `f6cb4c1` |
| #171 | FORGE-05 harness shards (B18 cut) | `f3298dd` |
| #172 | FORGE-02 STATUS refresh | `bdc8b69` |

Closed: #2 (sandbox map, superseded by the AI Kingdoms brief); #13 and #19 (replaced by #24 and #25).

## Toolchain (this session)
Pinned release binaries via `roblox/scripts/ci_install_tools.sh` (Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0,
Lune 0.11.0) — the same binaries as CI; GitHub release downloads worked through the proxy.
