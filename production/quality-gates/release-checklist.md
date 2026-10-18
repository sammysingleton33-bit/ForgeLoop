# Release checklist: AI Kingdoms (game-001)

_Owner: FORGE-05 (FL-0032, FL-0131). Started 2026-10-18 for Operation Crownfall (D-053). Updated at every build cut._

This checklist is the gate in front of any publish request. It is built on the owner's launch-ready definition: directive 2026-10-18 §7, kept verbatim at the end of `production/handoffs/2026-10-18-forge-00-to-all-operation-crownfall.md`. The game is launch-ready only when all 13 rows L1–L13 are `done`.

The owner's own rules:
- **No publishing without explicit owner approval.** This is also an approval gate in AGENTS.md.
- Patches and content can follow launch, but that does not justify shipping a broken or misleadingly incomplete game.

**Status values**

| Status | Meaning |
|---|---|
| `open` | Not started. |
| `building` | A task is in progress. |
| `headless` | Specs, CI or probes pass. This is not a Studio or device test. |
| `studio` | The owner saw it in Studio, recorded in `studio-runs.md` with the BuildInfo sha. |
| `device` | Measured on a real phone. |
| `owner` | Needs an owner decision or an account action. |
| `done` | Every kind of evidence the row asks for is recorded. |

Headless evidence never closes a row that asks for Studio, device or owner evidence.

## Launch-ready criteria (owner's §7, one row each)
| ID | Criterion (verbatim) | Evidence required | Evidence owner | Status | Supporting checks |
|---|---|---|---|---|---|
| L1 | A new player can understand how to play. | Onboarding works for the full match, not only the slice; the owner (or a fresh player) completes a first match without help; the Studio onboarding rows pass | FORGE-04 (onboarding), FORGE-03 (UI); owner | headless (VS-1 slice onboarding, E6) | S1 |
| L2 | A complete intended match can start, progress and end. | Full-match headless spec; Studio: start → every phase → Results, with conquest and Crown-Points endings (B20 rows) | FORGE-01 FL-0125; FORGE-05 B20 | building | A1, A2, A4, A6, A7, A8 |
| L3 | Multiplayer and competing kingdoms function. | `multiplayer-test-plan.md` M1–M8 in Local Server; AI and human wars; 4 players in 4 kingdoms | Owner (Studio); FORGE-01; FORGE-05 (steps) | open | A3, C1–C3 |
| L4 | Major citizen, construction, military and reputation systems work. | Specs per system; Studio rows per system on the release-candidate build | FORGE-01; FORGE-03; FORGE-04 | headless (VS-1 systems; B14–B19 not yet run in Studio) | A9, B3 |
| L5 | Crown Arena functions as the final payoff. | Arena specs and the fairness harness in CI; Studio: a match ending in the duel, with crowd and venue | FORGE-01 FL-0071; FORGE-05 FL-0076; FORGE-02/03/04 FL-0072–0075 | open | A4, A5 |
| L6 | The game looks coherent and finished from primary camera views. | Renders reviewed by a non-author; Studio screenshots from the aerial, ground and arena views; no interim art left | FORGE-02; FORGE-05 (D-051 gate) | building (interim art in B17–B19; **D-057:** the owner rejected the current art for launch, so this row cannot pass while characters or environments look unfinished; licensed imported characters FL-0135 and environment FL-0136, FORGE-02) | A10, E3, H1, H2 |
| L7 | Critical UI works on supported desktop and mobile devices. | Studio emulator (phone 667×375, tablet) and desktop screenshots per critical screen; touch and gamepad reach every action | FORGE-03; FORGE-04; owner | headless (VS-1 scenes) | E1, E2 |
| L8 | Performance is acceptable on representative devices. | Headless tick, entity and part numbers per build; Studio MicroProfiler; on-device FPS and memory on the baseline Android device (2–4 GB) | FORGE-05 (probe); FORGE-02 (budgets); owner (device) | building (match probe) | D1–D6 |
| L9 | No known critical gameplay, persistence, economy or security exploits remain. | FORGE-07's independent review of every remote (FL-0132); exploit snippets in Studio; persistence specs | FORGE-07; FORGE-01; FORGE-05 | open | B1–B3, F1, F2 |
| L10 | Core systems have been verified in real Roblox Studio / appropriate live tests. | `studio-runs.md` rows on the release-candidate sha covering L2–L5, L7 and L9, with Output and no red lines | Owner; FORGE-00 (rows); FORGE-05 (asks) | open (B14–B19 asks not yet run) | I2 |
| L11 | Content, assets and monetization meet Roblox requirements. | Rights recorded for every sound and asset; dialogue final; no paid advantages or paid random items; monetization only if the owner approves | FORGE-04 (sounds); FORGE-06 (dialogue); FORGE-02 (assets); owner | owner | G1–G5, D3 |
| L12 | Published experience metadata, permissions and release materials are ready. | Name, description, icon, thumbnails, maturity questionnaire, ownership (group or personal) and permissions, set on the owner's account | Owner; FORGE-00 | owner | I4 |
| L13 | The owner has played and approved the release candidate. | The owner's written approval in DECISIONS.md, naming the sha | Owner | owner | I5 |

## Supporting checks
These are the detailed checks behind the rows above. Their sources are:
- D-053 (1)–(8)
- FL-0032
- `docs/research/roblox-platform-constraints.md`
- `production/quality-gates/multiplayer-test-plan.md`

### A. Match and victory (L2, L3, L5)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| A1 | The full four-kingdom match (`Match.mode = "match"`) is the default build, with Pacing's timed phases (D-053 (1)). | Full-match headless spec; Studio start → Results (B20) | FORGE-01 FL-0125; FORGE-05 | building |
| A2 | AI governors rule every kingdom from match start, with seeded aggression 0.3–1.0. Mid-match joiners take over the standing kingdom with the fewest human rulers. | Specs; Studio Local Server with a late joiner | FORGE-01 FL-0125 | open |
| A3 | PvP from Conflict on: war, peace by mutual consent, raids and sieges (D-053 (2)). | Specs; Studio: AI war in Conflict (B20) and a human-declared war | FORGE-01 FL-0125, FL-0126; FORGE-03 FL-0129 | open |
| A4 | Victory (D-053 (3)): the top 2 kingdoms by Crown Points fight the duel, and the champion is chosen by co-ruler vote with a leadership fallback. Conquering every rival ends the match early with no duel. Until the arena lands, the most Crown Points wins. | Specs; Studio: a match ending each way | FORGE-01 FL-0071; FORGE-03 FL-0073 | open |
| A5 | The arena's §6 support caps hold, and weak support never debuffs. | FL-0076 caps spec and Monte Carlo in CI | FORGE-05 FL-0076; FORGE-01 FL-0070 | building |
| A6 | Eliminated rulers spectate, and every client reaches Results. | Specs; Studio Local Server, 2–4 players (M8) | FORGE-01; FORGE-03 FL-0129; FORGE-04 FL-0130 | open |
| A7 | Slice mode stays reachable through a Studio debug command, and the VS-1 rows still run (D-053 (7)). | Studio `match.mode slice` (B20) | FORGE-01 FL-0125; FORGE-05 | open |
| A8 | Match length: the current Pacing default. The owner decides on the ~30-minute preference after a match30 run (D-053 (4)). | Studio match30 run; the owner's ruling | Owner; FORGE-04 | owner |
| A9 | Walls, gates, towers and three neutral outposts. | Specs; Studio | FORGE-01 FL-0126; FORGE-02 FL-0128 | open |
| A10 | Four distinct, fully dressed kingdoms (VS-2 row 1). | Non-author render review; Studio screenshot | FORGE-02 FL-0127 | open |

### B. Server authority and exploits (L9)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| B1 | Every remote validates every argument server-side and is rate-limited. This includes the war, diplomacy, army, wall, outpost and arena remotes. | Bad-argument specs per remote; FORGE-07's review | FORGE-07 FL-0132; each owner | open |
| B2 | Rewards, currency, Crown Points, inventory and outcomes change only on the server. | Specs; Studio exploit snippets (M4, M5) | FORGE-01; FORGE-05 | headless (VS-1 remotes) |
| B3 | Double calls, or two calls in one frame, act once (build, recruit, upgrade, vote). | Specs; Studio M5 | FORGE-01; FORGE-03 | headless (build) |

### C. Multiplayer (L3; Local Server, never Play Solo)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| C1 | M1–M8 of `multiplayer-test-plan.md` pass on the release-candidate build. | `studio-runs.md` rows | Owner; FORGE-05 (steps) | open |
| C2 | Leave and rejoin mid-match: no server errors, and the governor takes over (M6). | Studio Local Server | FORGE-01; owner | open |
| C3 | Four players in four kingdoms play a full match. | Studio Local Server, 4 players | Owner | open |

### D. Performance (L8; FL-0032)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| D1 | Server tick ms at peak entities. | `tests/balance/MatchProbe.spec.luau` (FORGE_MATCH_PROBE=1) per build; Studio MicroProfiler as an indication | FORGE-05; FORGE-01 | building |
| D2 | Entity count (citizens, soldiers, buildings) and part count at peak. | The same probe per build; Studio Stats | FORGE-05 | building |
| D3 | Every mesh has 20,000 triangles or fewer (hard cap), collision is Box or Hull by default, and textures are sized by object size (research A1, A5, A6). | Blender validation gate | FORGE-02 | open |
| D4 | Draw calls and triangles on screen stay within a per-game budget. The docs' 1,000 / 1M figure is only an example (A8). | A budget set by FORGE-00/02; Studio render stats | FORGE-02; FORGE-05 | open |
| D5 | StreamingEnabled with Improved model streaming and Opportunistic stream-out (A9), or a recorded reason not to. | Place properties; Studio | FORGE-02; FORGE-05 | open |
| D6 | Playable on the baseline Android device (2–4 GB RAM). Only on-device numbers count. | On-device FPS and memory at peak | Owner | owner |

### E. UI, devices and accessibility (L6, L7)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| E1 | Phone 667×375: nothing is cut off in the HUD, drawers, conversation, war panel, Results, arena HUD or toasts. | Studio emulator screenshots | FORGE-03; FORGE-04 | headless (VS-1 scenes) |
| E2 | Touch and gamepad reach every action, including duel input (FL-0075) and back on every screen. | Specs; Studio emulator and a gamepad | FORGE-04; FORGE-03 | headless (VS-1) |
| E3 | Colour-vision check of the kingdom colours and the war, peace and arena cues (D-033 (4)). | `colour-vision.md`; Studio four-kingdom screenshot | FORGE-05; FORGE-02 | headless (renders) |

### F. Persistence (L9; D-053 (6))
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| F1 | A versioned DataService:<br>- one key per player<br>- `UpdateAsync` only<br>- a session lock in metadata<br>- jittered autosave<br>- a `BindToClose` save<br><br>It stores account level and cosmetics only (research summary 3). | Specs (MockDataStore); Studio test place with API access | FORGE-01 FL-0008 | open |
| F2 | DataStore request budgets are respected per server and per experience. | Spec or probe of request counts | FORGE-01; FORGE-05 | open |

### G. Content, assets and monetization (L11)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| G1 | No monetization until the owner has played an enjoyable release candidate. Any monetization is owner-approved and cosmetic only (D-053 (6)). | The owner's approval in DECISIONS.md | Owner | owner |
| G2 | No paid advantages and no paid random items. Free random rolls show their possible outcomes. | Review of every purchase and roll path | FORGE-07; FORGE-05 | open |
| G3 | Every sound has a recorded source and asset ID with rights. Creator Store audio is used in game only (research U1, I-U1). | Sound registry check; the owner's sound picks | FORGE-04; owner | owner (sounds unpicked) |
| G4 | Dialogue is final, not DRAFT, and the owner has approved it. | The owner's approval recorded | FORGE-06; owner | owner |
| G5 | The experience questionnaire and maturity label are answered on the owner's account. | Owner action | Owner | owner |

### H. Visual quality (L6)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| H1 | No interim art that a non-author marked NEEDS-WORK remains: citizens (FL-0118), world and kingdoms, war kit, arena (D-051). | Before and after renders reviewed by a non-author; Studio screenshots | FORGE-02 | building |
| H2 | No known visible defects are listed in the build notes (D-038 (6)). | The latest `studio-runs.md` "doesn't work yet" column | FORGE-05 | open |

### I. Build and release operations (L10, L12, L13)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| I1 | check.sh passes on the release-candidate sha within its step limits, with no skipped steps; main CI is green; the artifact is BuildInfo-stamped. | check.sh log; CI run and artifact | FORGE-05 | headless (every cut) |
| I2 | The owner runs the release candidate in Studio from start to Results with no red Output lines. | `studio-runs.md` row | Owner; FORGE-00 | open |
| I3 | No secrets, keys or personal data in the repo or the place. | Repository secret scan; place check | FORGE-05 | open |
| I4 | Account questions are answered: group or personal ownership, ID verification, test universe (research "Open questions" 1–3). | Owner answers | Owner | owner |
| I5 | Publish request. | The owner's explicit approval (approval gate) | Owner | owner |

### S. First-time player (L1)
| ID | Check | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| S1 | Onboarding covers the full match (phases, war and peace, the arena), not only the VS-1 slice. Hints point at real targets on every device. | Specs; Studio E6 on the full match | FORGE-04; FORGE-03 | open |

## Log
- 2026-10-18 FORGE-05: started (FL-0131, FL-0032) from D-053 and the research constraints.
- 2026-10-18 FORGE-05: rebuilt on the owner's 13 launch-ready criteria (directive §7, verbatim on main 989c03a1), one row each; the earlier checks are now the supporting checks.
- 2026-10-18 FORGE-05: L6 cites D-057 (owner rejected the current art; licensed imported characters and environment, FL-0135/FL-0136).
