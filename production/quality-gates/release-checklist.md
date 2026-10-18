# Release checklist: AI Kingdoms (game-001)

_Owner: FORGE-05 (FL-0032, FL-0131). Started 2026-10-18 for Operation Crownfall (D-053). Updated at every build cut._

This is the gate in front of any request to publish. **Publishing is an owner approval gate** (AGENTS.md):
a fully green checklist makes a release candidate, and only the owner decides to publish it.

**Source of the criteria.** D-053 (1)–(8), the Crownfall handoff
(`production/handoffs/2026-10-18-forge-00-to-all-operation-crownfall.md`), FL-0032,
`docs/research/roblox-platform-constraints.md` and `production/quality-gates/multiplayer-test-plan.md`.
The owner's directive §7 ("launch-ready") is **not in the repo yet** (asked of FORGE-00, 2026-10-18).
When it lands, every row below is checked against its wording, and rows it adds are marked §7.

**Status values:**

| Status | Meaning |
|---|---|
| `open` | Not started. |
| `building` | A task is in progress. |
| `headless` | Specs, CI or probes pass. This is not a Studio or device test. |
| `studio` | Seen in Studio by the owner. Recorded in `studio-runs.md` with the BuildInfo sha. |
| `device` | Measured on a real phone. |
| `owner` | Needs an owner decision or account action. |
| `done` | Every kind of evidence the row asks for is recorded. |

Nothing counts as done on headless evidence alone where the row asks for Studio, device or owner evidence.

## A. The game is complete (D-053)
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| A1 | The default build is the full four-kingdom match (`Match.mode = "match"`), with Pacing's timed phases. | Full-match headless spec; Studio: start a match and reach Results (B20 rows) | FORGE-01 FL-0125; FORGE-05 B20 | building |
| A2 | AI governors rule every kingdom without a human from match start, with seeded aggression 0.3–1.0. Mid-match joiners take over the standing kingdom with the fewest human rulers. | Specs; Studio Local Server, 2 players, one joining late | FORGE-01 FL-0125 | open |
| A3 | PvP from Conflict on: war, peace by mutual consent, raids and sieges. | Specs; Studio: AI war in Conflict (B20), a human-declared war (Local Server) | FORGE-01 FL-0125, FL-0126; FORGE-03 FL-0129 | open |
| A4 | Victory. The top 2 kingdoms by Crown Points fight the Crown Arena duel; the champion is chosen by co-ruler vote, with a leadership fallback. Conquering every rival ends the match early, with no duel. Until the arena lands, the most Crown Points wins. | Specs; fairness harness (FL-0076); Studio: a match ending each way | FORGE-01 FL-0071; FORGE-05 FL-0076; FORGE-03 FL-0073 | open |
| A5 | The arena's §6 support caps hold, and weak support never debuffs. | FL-0076 caps spec and Monte Carlo in CI | FORGE-05 FL-0076; FORGE-01 FL-0070 | building |
| A6 | Eliminated rulers spectate; every client reaches Results. | Specs; Studio Local Server, 2–4 players (M8) | FORGE-01 FL-0125; FORGE-03 FL-0129; FORGE-04 FL-0130 | open |
| A7 | Slice mode stays reachable through a Studio debug command, and the VS-1 rows still run (D-053 (7)). | Studio: `match.mode slice` and the VS-1 rows (B20) | FORGE-01 FL-0125; FORGE-05 | open |
| A8 | Match length is the current Pacing default. The owner decides the ~30-minute preference after a match30 Studio run (D-053 (4)). | Studio match30 run; the owner's ruling | Owner; FORGE-04 | owner |
| A9 | Walls, gates, towers and the three neutral outposts. | Specs; Studio | FORGE-01 FL-0126; FORGE-02 FL-0128 | open |
| A10 | Four distinct, fully dressed kingdoms (VS-2 row 1). | Renders reviewed by a non-author; Studio screenshot of all four | FORGE-02 FL-0127 | open |

## B. Server authority and exploits
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| B1 | Every remote validates every argument server-side and is rate-limited. This covers war, diplomacy, army, walls, outposts and the arena. | Bad-argument specs per remote; FORGE-07's independent review | FORGE-07 FL-0132; each owner | open |
| B2 | Rewards, currency, Crown Points, inventory and outcomes change only on the server. | Specs; Studio exploit snippets from a client (M4, M5) | FORGE-01; FORGE-05 | headless (VS-1 remotes) |
| B3 | Double calls and two calls in one frame act once (build, recruit, upgrade, vote). | Specs; Studio M5 | FORGE-01; FORGE-03 | headless (build) |

## C. Multiplayer (Local Server, never Play Solo)
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| C1 | `multiplayer-test-plan.md` M1–M8 pass on the release-candidate build. | `studio-runs.md` rows with the sha, player count and Output | Owner (Studio); FORGE-05 writes the steps | open |
| C2 | Leaving and rejoining mid-match: no server errors, and the governor takes over (M6). | Studio Local Server | FORGE-01; owner | open |
| C3 | Four players in four kingdoms for a full match. | Studio Local Server, 4 players | Owner | open |

## D. Performance (FL-0032)
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| D1 | Server tick ms at peak entities stays within the budget. | Headless tick timing from the full-match spec (FL-0125), recorded per build; Studio MicroProfiler as an indication | FORGE-01; FORGE-05 (B20 onward) | open |
| D2 | Entity count (citizens, soldiers, buildings) and part count at the match's peak. | Headless count per build; Studio Stats | FORGE-05 | open |
| D3 | Every mesh has 20,000 triangles or fewer (hard cap), Box or Hull collision by default, and textures sized by object size. | Blender validation gate (`blender/scripts/check.sh`) | FORGE-02 | open |
| D4 | Draw calls and triangles on screen are within a per-game budget. The docs' "1,000 draw calls / 1M triangles" is only an example, not a limit. | A budget set by FORGE-00/FORGE-02; Studio render stats | FORGE-02; FORGE-05 | open |
| D5 | StreamingEnabled with Improved model streaming and Opportunistic stream-out (research A9), or a recorded reason not to. | Place properties check; Studio | FORGE-02; FORGE-05 | open |
| D6 | Playable on the baseline Android device (2–4 GB RAM). The Studio emulator doesn't measure performance, so only on-device numbers count. | On-device FPS and memory at peak | Owner (device) | owner |

## E. Mobile, gamepad and accessibility
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| E1 | Phone layout (667×375): nothing cut off in the HUD, drawers, conversation, war panel, Results, arena HUD or toasts. | Studio emulator screenshots per screen | FORGE-03; FORGE-04 | headless (VS-1 scenes) |
| E2 | Touch and gamepad reach every action, including duel input (FL-0075) and the back key on every screen. | Specs; Studio emulator and a real gamepad | FORGE-04; FORGE-03 | headless (VS-1) |
| E3 | Colour-vision check for the four kingdom colours and the war, peace and arena cues (D-033 (4)). | `colour-vision.md` runs; Studio four-kingdom screenshot | FORGE-05; FORGE-02 | headless (renders) |

## F. Persistence (D-053 (6))
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| F1 | A versioned DataService: one key per player, `UpdateAsync` only, a session lock in metadata, a jittered autosave and a `BindToClose` save (research summary 3). It stores account level and cosmetic unlocks only. | Specs (MockDataStore); Studio with API access on a test place | FORGE-01 FL-0008 | open |
| F2 | DataStore budgets respected per server and per experience. | Spec or probe of request counts | FORGE-01; FORGE-05 | open |

## G. Monetization and policy
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| G1 | **No monetization** until the owner has played an enjoyable release candidate. Any monetization is owner-approved and cosmetic only. | The owner's written approval in DECISIONS.md | Owner | owner |
| G2 | No paid advantages and no paid random items. Free random rolls show their possible outcomes. | Review of every purchase and roll path | FORGE-07; FORGE-05 | open |
| G3 | Every sound has a recorded source and asset ID that we have rights to. Creator Store audio is used in game only (research U1, I-U1). No `needed` sound ships silent without a note. | Sound registry check; the owner's sound picks | FORGE-04; owner | owner (sounds unpicked) |
| G4 | Dialogue is final, not DRAFT, and the owner approved it (FORGE-06's instruction). | The owner's approval recorded | FORGE-06; owner | owner |
| G5 | Experience questionnaire and maturity label answered on the owner's account. | Owner action (unverified) | Owner | owner |

## H. Visual quality
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| H1 | No interim art left that a non-author reviewer marked NEEDS-WORK: citizens (FL-0118), world and kingdoms, war kit, arena (D-051). | Before and after renders reviewed by a non-author; Studio screenshots | FORGE-02 | building |
| H2 | No known visible defects in the build notes (D-038 (6)). | The latest `studio-runs.md` "doesn't work yet" column is empty of defects | FORGE-05 | open |

## I. Build, CI and release operations
| ID | Criterion | Evidence required | Evidence owner | Status |
|---|---|---|---|---|
| I1 | check.sh passes on the release-candidate sha within its step limits, with no skipped steps. Main CI is green and the artifact is BuildInfo-stamped. | check.sh log; CI run and artifact | FORGE-05 | headless (every cut) |
| I2 | The owner's Studio run of the release-candidate build: start → Results with no red Output lines. | `studio-runs.md` row | Owner; FORGE-00 | open |
| I3 | No secrets, keys or personal data in the repo or the place. | Secret scan of the repo; place check | FORGE-05 | open |
| I4 | Account questions answered: group or personal ownership, ID verification, test universe (research "Open questions" 1–3). | Owner answers | Owner | owner |
| I5 | Publish request. | The owner's explicit approval (approval gate) | Owner | owner |

## Log
- 2026-10-18 FORGE-05: started (FL-0131, FL-0032) from D-053 and the research constraints; waiting for the directive's §7 wording.
