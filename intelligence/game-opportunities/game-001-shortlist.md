# Game #1 shortlist (FL-0005), draft for the user's decision

- **Prepared:** 2026-10-12 by the Game Design function (Claude, for FORGE-00). **Status: NOT APPROVED.** Under `AGENTS.md`, choosing a game needs the user's approval (task FL-0035). Codex review is task FL-0040.
- **Inputs:** `intelligence/market-research/2026-10-roblox-landscape.md` (cited as **MR x.y**), `docs/research/roblox-platform-constraints.md` (cited as **PC Px**), repo tasks FL-0007..FL-0045, plus new WebSearch evidence and creator-docs pages (cited as **E#**, listed in §10).
- **Labels:** **O** = observed, **I** = inferred. Conf = high/med/low. Scores and estimates are **I** (my judgement). "Not found" means I searched and found nothing.
- **Verification pass 2026-10-12:** a verifier's corrections were checked against the repo (task files, `tools/forge.py`, `git ls-tree`) and fresh WebSearch, then applied. Changed: C6 F7 4→3; C1 MO 2→3, MC 1→2, F7 1→2; totals, §4 and §7 recomputed; framework state restated as "specified, not started"; evidence E1, E2, E11 relabelled; E22–E25 added. C2's scores are unchanged, but its F7 is now explicitly conditional on Phase 1 (§3).

## Executive summary

1. **Recommended (not approved): C2 "Flood Island"**, a round-based PvE disaster-survival game on the jungle island. It keeps the prior concept's island, 12 sectors, lagoon, ruins, disasters, real flood and spectate, and drops loot-and-kill PvP. Weighted score **73.2/100**. **Confidence: medium-low.**
2. Runners-up: **C6 Hidden Hunter** (jungle social deduction) **68.8**; **C4 Jungle Night Expedition** (co-op horror) **68.4**. Only 0.4 points separate them, so the runner-up order is fragile. C4 has the highest upside: it ranks first when the cost criteria are ignored (§4).
3. **The prior concept (C1 Jungle Survival Arena) scores 57.6, 7th of 8.** It is held back by needing a combat system (FL-0012, specified and gated on this choice), PvP lobby liquidity and cheating, and weak evidence for Roblox *battle royales* specifically [E11, E12]. Broad PvP demand on Roblox is large (RIVALS, The Strongest Battlegrounds, Jujutsu Shenanigans; E13, E14, E22, low), and its score now reflects that. Its disaster and island layer lives on in C2, and its PvP arena could become a later C2 mode if player counts support it.
4. **Nothing is built yet.** There are 0 Luau files on any branch, the skeleton (FL-0003) is still BUILDING, and every framework task C2 needs is READY (specified, not started) [E25]. C2's 7-day estimate therefore starts only after Phase 1 lands, and no prototype exists. C2 leads C6 by 4.4 points. If C2's F7 drops to 3, the lead shrinks to 2.4. If its MO also drops to 3, C2 and C6 tie. The top-3 set (C2, C4, C6) holds under all four weightings tested, and C1 stays in the bottom half under every one.
5. Evidence is weak. Most market data comes from third-party tracker snapshots seen only in search snippets (low confidence). There is no Sep–Oct 2026 ranking, and the tracker sites were unreachable (proxy 403/DNS). Creator docs are readable via raw GitHub, so platform rules are high confidence.
6. **Your decision (§8):** choose A (C2), B (C1 as specified, on a longer schedule), C (C4) or D (C6), or ask for changes.

---

## 1. Feasibility context (O, from repo tasks, 2026-10-12)

`READY` comes before `BUILDING` in `tools/forge.py` (`LIFECYCLE = RESEARCH, SPECIFIED, READY, BUILDING, TESTING, REVIEW, ACCEPTED, REUSABLE`). So **READY means specified, not started**. Only FL-0001, FL-0002 and FL-0038 are ACCEPTED. `git ls-tree` finds 0 `.lua`/`.luau` files and no `roblox/` folder on `main`, `forge/00-skeleton` or any `origin/forge/0N-*` branch (local refs, 2026-10-12). Nothing has been checked in Studio: that needs the user's Windows PC (FL-0036, SPECIFIED) [E25].

| Framework piece | Task | State | Relevance |
|---|---|---|---|
| Shared skeleton (contracts, loader, harness, CI) | FL-0003 | BUILDING (0 Luau files so far) | everything |
| Session-locked data, idempotent purchases | FL-0008, FL-0019 | READY (specified, not started) | all candidates |
| Round state machine, spawn platforms, spectate, results | FL-0010, FL-0043 (needs FL-0044 sandbox arena, FL-0020 UI) | READY (specified, not started) | C1, C2, C3, C6, C8 |
| HazardService + **real flood** (~10 ft ≈ 11 studs at 1 stud = 0.28 m, PC A4) | FL-0011 | READY (specified, not started) | C1–C5, C8 |
| Server-authoritative combat | FL-0012 | **SPECIFIED; its spec says "Start only after Game #1 is selected if it needs combat"**; estimate 8 h | C1, C5 (heavy); C6 (light) |
| Reward tables with pity + exact odds, inventory, wallet, shop | FL-0018, FL-0045, FL-0021 | READY (specified, not started) | all |
| Remote validation, analytics funnels, onboarding, daily rewards/quests | FL-0009, FL-0023, FL-0025, FL-0026 | READY (specified, not started) | all |
| Blender: broadleaf trees, palms, ferns, rocks, ruins kit | FL-0013..FL-0016 | READY (specified, not started) | all jungle candidates |
| Studio smoke test of the integrated build | FL-0036 (user) | SPECIFIED | all |
| Creature rig + animation pipeline | none | **not planned** | C4 |

## 2. Candidates (8)

| ID | Working title | One-line pitch | Main evidence | Biggest risk |
|---|---|---|---|---|
| C1 | **Jungle Survival Arena (user's prior concept)** | Hunger-Games-style free-for-all: lobby → spawn platforms → countdown → loot central ruins → fight while disasters (10 ft flood, lightning, gas, falling rocks, fire rings, canopy winds) hit 12 sectors → spectate → last player wins → reset | Large, fresh PvP demand: RIVALS ~130–290K CCU in Jul–Aug 2026 snapshots (MR 1.9); The Strongest Battlegrounds ~64–83K (E14); Jujutsu Shenanigans ~145–186K peak-hour, 338K peak in Mar 2026 (E22). The shooter chart is led by arena/duel games (E13). Battle-royale-specific evidence is weak (E11 undated, E12). Disasters plus last-player-standing already exist on Roblox (E24). All low confidence | Combat not built; PvP liquidity, cheating (MR 10.3), long spectating for early losers |
| C2 | **Flood Island** | Same island and disasters, no weapons. Scavenge gear, read sector warnings, survive escalating disaster waves. Eliminated players vote the next disaster. | Disaster survival is evergreen: NDS ~4.1–4.4B visits, ~8–14K CCU in 2026 snapshots (E1). Other disaster titles run at ~0.6–3K now (E3, E4). Survival was the fastest-growing genre in Jun 2026 (MR 9.3), but that bucket is adjacent evidence (it includes 99 Nights-style games). All low confidence | Shallow-loop reputation of the genre; modest current CCU of incumbents (E1, E3, E4) |
| C3 | Rising Tide Ruins | 1–4 player co-op escape through ruin levels while the real flood rises | Flood Escape 2: ~594M visits, all-time peak 21,486 on 2025-12-22 (E4) | Strong incumbent; each level is hand-built |
| C4 | **Jungle Night Expedition** | 1–4 player co-op horror: survive nights in jungle ruins hunted by a creature, restore beacons, collect relics | Strongest 2026 tailwind: Animal Hospital (solo dev), 99 Nights, Monster in the Mansion (MR 1.4, 1.10, 1.16, 2.1, 9.4) | Creature AI + rig/animation not in pipeline; horror quality depends on polish |
| C5 | Ruins Relic Run | PvPvE extraction-lite: squads loot relics and must extract before the flood | Roblox targets 13+ mid-core (MR 7.2, 9.5); **Roblox extraction hit: not found** | Combat + extraction + gear economy; no demand evidence |
| C6 | **Hidden Hunter** | 8–12 player social deduction in jungle ruins: hidden Hunter, one Ranger, Explorers collect relics while a hazard ticks | Murder Mystery 2 led live charts in Aug 2026; reported peak ~1.35M is single-source (MR 1.1, low); its event mystery boxes and Godly packs drove a jump (MR 1.2) | Clone perception against MM2's entrenched item economy |
| C7 | Lagoon Fishing & Relics | Calm fishing and collection in the central lagoon | Fishing boom after Fish It! (MR 1.13) | Copycat wave already (MR 9.7); paid luck rods count as paid random (PC P2, P6) |
| C8 | Island Party Minigames | Round-based disaster minigames | Epic Minigames ~2.5–3.1K CCU late Jul 2026, down from a 32K peak in Oct 2025 (E15) | Declining genre evidence; novelty fades |

## 3. Rubric (weights stated, scores 1–5, I)

| Criterion | Weight | 5 means | 1 means |
|---|---|---|---|
| Market opportunity (MO) | 12 | demand evidenced in 2026 and room for a new entrant | no demand evidence, or a dominant incumbent |
| Differentiation (DF) | 8 | no close Roblox equivalent found | a near-clone of a leader |
| Player appeal (PA) | 12 | broad ages and devices, instant fun, works without chat (MR 8.9) | narrow, needs chat or skill |
| Dev complexity, inverse (DC) | 10 | almost all framework | many new systems |
| Reusable systems created (RS) | 8 | adds systems Game #2+ will reuse | one-off code |
| Asset requirements, inverse (AR) | 6 | existing jungle kit is enough | many new or rigged assets |
| Multiplayer complexity, inverse (MC) | 8 | works solo, no PvP | PvP hit validation, hidden info, needs full servers |
| Retention potential (RP) | 12 | strong D8–D28 hooks (MR 5.1) | novelty only |
| Monetization fit (MF) | 8 | natural, non-predatory products | weak or policy-heavy |
| 7-day feasibility (F7) | 10 | polished in 7 days with this framework | not feasible |
| Long-term update potential (LT) | 6 | cheap, frequent content | content treadmill or dead end |
| **Total** | **100** | Weighted total = Σ(weight × score) / 5, so the maximum is 100 | |

**F7 and DC are scored as if the Phase 1 framework is complete** (I). ROADMAP Phase 1 runs "until Game #1 is approved" and Phase 2 targets "~7 days from approval". As of 2026-10-12 none of the framework is built (§1, E25). So F7 compares the game-specific work each candidate adds *after* Phase 1, and every 7-day estimate below starts after Phase 1.

### Scores and arithmetic

| Cand. | MO | DF | PA | DC | RS | AR | MC | RP | MF | F7 | LT | Σ(w×s) | Total |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C2 Flood Island | 4 | 3 | 4 | 4 | 4 | 3 | 4 | 3 | 3 | 4 | 4 | 366 | **73.2** |
| C6 Hidden Hunter | 3 | 3 | 4 | 3 | 3 | 4 | 3 | 4 | 4 | 3 | 4 | 344 | **68.8** |
| C4 Night Expedition | 5 | 3 | 4 | 2 | 3 | 2 | 3 | 4 | 4 | 2 | 5 | 342 | **68.4** |
| C7 Lagoon Fishing | 3 | 2 | 3 | 4 | 2 | 3 | 5 | 4 | 3 | 4 | 4 | 338 | 67.6 |
| C3 Rising Tide Ruins | 3 | 2 | 3 | 3 | 3 | 3 | 4 | 3 | 3 | 4 | 4 | 316 | 63.2 |
| C8 Party Minigames | 2 | 2 | 4 | 3 | 4 | 3 | 3 | 2 | 3 | 3 | 4 | 294 | 58.8 |
| C1 Survival Arena (prior) | 3 | 4 | 3 | 2 | 4 | 2 | 2 | 3 | 3 | 2 | 4 | 288 | **57.6** |
| C5 Ruins Relic Run | 2 | 4 | 3 | 2 | 4 | 2 | 2 | 4 | 4 | 1 | 4 | 286 | 57.2 |

Changes on 2026-10-12: C6 F7 4→3 (was 354/70.8). C1 MO 2→3, MC 1→2, F7 1→2 (was 258/51.6, 8th).

Arithmetic (weights in order MO 12, DF 8, PA 12, DC 10, RS 8, AR 6, MC 8, RP 12, MF 8, F7 10, LT 6):
- C2: 48+24+48+40+32+18+32+36+24+40+24 = 366 → 366/5 = **73.2**
- C6: 36+24+48+30+24+24+24+48+32+30+24 = 344 → **68.8**
- C4: 60+24+48+20+24+12+24+48+32+20+30 = 342 → **68.4**
- C7: 36+16+36+40+16+18+40+48+24+40+24 = 338 → 67.6
- C3: 36+16+36+30+24+18+32+36+24+40+24 = 316 → 63.2
- C8: 24+16+48+30+32+18+24+24+24+30+24 = 294 → 58.8
- C1: 36+32+36+20+32+12+16+36+24+20+24 = 288 → **57.6**
- C5: 24+32+36+20+32+12+16+48+32+10+24 = 286 → 57.2

Score rationale (I, short):
- **MO:** C4 = 5 because co-op horror and survival have the most 2026 evidence. C2 = 4 because disaster survival is evergreen (NDS ~8–14K CCU, E1) and the June survival growth is real. That growth is adjacent evidence (the survival bucket includes 99 Nights-style games), and all of it is low-confidence tracker data; §4 tests C2 at MO 3. C1 = 3: PvP demand on Roblox is large and fresh (RIVALS ~130–290K Jul–Aug 2026, MR 1.9; The Strongest Battlegrounds ~64–83K, E14; Jujutsu Shenanigans ~145–186K, E22), but battle-royale-specific evidence is weak (E11 is undated, ~2022; E12) and arena incumbents dominate. C5 = 2 because no Roblox extraction hit was found.
- **MC:** C1 = 2 because it needs PvP hit validation, cheat resistance (MR 10.3), at least ~8 players per server to be fun, and mid-round joins. C6 = 3 because it has the same cold-start liquidity problem (about 6+ players per server) plus a hidden role that must never be sent to other clients, but no ranged PvP hit validation. C2 and C3 = 4 because they are PvE and playable solo.
- **F7 (after Phase 1, see above):** C2 = 4: on top of FL-0010/FL-0011 it needs 5 more hazards, 5 gear behaviours, spectator voting, and the island terrain. Terrain syncback is unproven (§9), so this 4 is optimistic; §4 tests F7 3. C6 = 3: it needs a subset of FL-0012 (tag plus dart), which is outside Phase 1 because its spec gates it on this choice, plus role secrecy. C1 = 2: it shares C2's island and 5 extra hazards. The gaps only C1 has are full combat (FL-0012, estimated 8 h, gated on this choice), loot balance and PvP liquidity. C3 and C7 = 4 rest on the same Phase 1 condition as C2.
- **RP:** C4, C6 and C7 = 4 because they have collection loops (MM2 Godlies, 99 Nights classes, MR 12.6). C2 = 3 because the NDS-style loop is shallow unless collection and quests carry D8–D28.

## 4. Sensitivity (I)

Recomputed 2026-10-12 with the §3 scores (script-checked).

| Weighting | 1st | 2nd | 3rd | C1 |
|---|---|---|---|---|
| As stated | C2 73.2 | C6 68.8 | C4 68.4 | 57.6 (7th) |
| No 7-day feasibility (renormalised) | C2 72.4 | C4 71.6 | C6 69.8 | 59.6 (7th) |
| Upside only (DC, AR, MC, F7 removed) | **C4 80.6** | C2 71.5 = C6 71.5 (tied 2nd) | — | 66.7 (5th) |
| MO and RP doubled | C2 72.6 = C4 72.6 (tied 1st) | — | C6 69.0 | 58.1 (6th) |

Score stress tests on the stated weights (I):

| Change | Result |
|---|---|
| C1 as a 14-day project (F7 2→3) | C1 59.6, 6th; not top 3 |
| C2 F7 4→3 (Phase 1 slips or terrain is hard) | C2 71.2, still 1st, 2.4 ahead of C6 |
| C2 MO 4→3 (adjacent evidence discounted) | C2 70.8, still 1st, 2.0 ahead of C6 |
| C2 F7 3 **and** MO 3 | C2 68.8 = C6 68.8 (tie), C4 68.4 |
| C6 F7 back to 4 (pre-correction) | C6 70.8, 2.4 behind C2 |

Reading: the choice between C2 and C4 is a choice between feasibility and upside. C2's lead rests on two soft scores (F7 and MO); if both drop one step it ties C6. C6 vs C4 for 2nd is 0.4 points and fragile. C1 does not reach the top 3 under any weighting or stress test.

## 5. Honest evaluation of the prior concept (C1)

**What is strong (I):** it is the most distinctive fantasy here. The disasters make each match different, which produces clip-able moments (MR 4.8). It would use the flood, round and spectate systems planned for Phase 1 (specified, not started; §1). It creates reusable combat and loot systems, and it has a clear 13+ hook. Broad PvP demand on Roblox is large in 2026 (MR 1.9, E14, E22).

**What holds it back:**

| Issue | O/I | Evidence |
|---|---|---|
| Combat framework not started; this would be the first PvP code. FL-0012 is SPECIFIED because its spec gates it on this choice ("Start only after Game #1 is selected if it needs combat"); it is estimated at 8 h like other framework tasks | O | FL-0012 task file (2026-10-12) |
| Battle royale/HG demand on Roblox specifically is weakly evidenced: Island Royale (a 2018 Fortnite-style game) had 426.1M visits and up to 200 per match in undated (~2022) coverage, and no current player count was found; Newzoo reports battle-royale playtime −27% in 2025 across platforms; the shooter chart is led by arena/duel games, not BR. General PvP demand is strong (RIVALS, TSB, Jujutsu Shenanigans) | O (low) | E11, E12, E13, E14, E22 |
| The format is not unprecedented: Roblox disaster games already end at the last player standing (DISASTERS; Survive the Disasters per unverified pages) | O (low) | E24 |
| A last-player-standing match has one winner. Early losers spectate for most of the round, which hurts the play-through and bounce signals the ranking now uses | I | MR 5.2, 12.2 |
| A new game starts with few concurrent players, so PvP rounds wait in lobbies or run with 2–3 players. Bots would add AI scope. | I | RoundService has a min-players rule (FL-0010) |
| Exploits and cheating dominate PvP complaints | O (low) | MR 10.3 |
| A "Hunger Games" name or likeness is third-party IP; the game must not use it | I (not researched) | — |
| 7 days after Phase 1 is not realistic at quality: combat, loot balance and PvP tuning on top of the island and 6 hazards it shares with C2 | I | §1, §3 F7 |
| The user's previous survival-arena place, scripts and Blender files are on their PC, not in this repo; the inventory (FL-0034) has not been run. If prior combat or map work exists, C1's DC and F7 could be higher | O (repo state) / I (effect) | PROJECT_STATUS "Not verified / blockers"; FL-0034 READY |

**Fixes that would lift it (I):** PvE-first disasters as the main threat (that is C2); 3–5 minute rounds; placement and survival-time rewards so losers still progress; simple combat (melee and thrown items); spectators who influence the match. Adopting C2 now and shipping the arena as a **later C2 mode** keeps the concept without betting Game #1 on PvP.

## 6. Full sheets: top 3

### 6.1 C2 Flood Island (73.2)

| Field | Content |
|---|---|
| Title (working) | Flood Island |
| Genre | Round-based disaster survival (PvE), Party & Casual / Survival |
| Target experience | 5-minute rounds of escalating, readable chaos on a living jungle island: "I saw the gas coming, grabbed the balloon, and rode the flood up to the ruins." All ages; mobile first (MR 7.5); no chat needed. |
| Core loop | 30 s: read warning → move/use gear → survive the wave. Round: lobby → spawn platforms around the lagoon → countdown → 45–60 s scavenge (design target) → 4–6 waves → final collapse → survivors crowned → reset. Session: earn coins and relic keys → open earned Relic Caches → equip cosmetics and gear loadout → quests. |
| Motivation | Mastery (map knowledge, reading telegraphs), collection (relics, badges), social chaos, short-session wins |
| Mechanics | 12 sectors (outer jungle ring, central lagoon, ruins). Hazards are server-scheduled per sector with warn → active → cleanup (FL-0011): real flood raising the water ~11 studs over low sectors; lightning (marked circles); poison gas spreading through jungle sectors; falling rocks near cliffs; closing fire rings; canopy winds that push players. Gear from ruin caches: balloon, grapple, antidote, umbrella/rod, stamina tonic (all server-validated). Survival time and relics feed rewards. |
| Multiplayer needs | 1–16 players per server (design target, to tune); playable solo; no PvP. Spectators vote the next sector or disaster (server-tallied, rate-limited). |
| Visual direction | Stylized-realistic tropical (FL-0014 rubric); readable hazard colour language (gas = sickly green, fire = orange ring, flood = rising foam line); clear telegraph decals at gameplay distance |
| Progression | Player level (deterministic XP), relic collection log, cosmetic unlocks, gear loadout slots unlocked by level, island "disaster mastery" badges |
| Social | Party join, emotes, survival streak shown on nameplate, spectator voting, results screen moments |
| Replay | Sector-randomised wave order, weekly featured disaster, rotating island events |
| USPs | (1) A **real** rising flood that reshapes the island, not a cosmetic river. (2) **Spectators become the island**: eliminated players vote what hits next, which keeps losers engaged. A Roblox game with spectator voting on the next disaster: **not found** (low; searches returned mostly SEO pages). The nearest is DISASTERS, where eliminated players return as ghosts who can revive or hunt survivors (E24). (3) Sector telegraphs give skill depth that NDS-style games lack. (4) A dense jungle island built with the Blender kit. |
| Difficulty | Medium. Estimate (I): 7 days **after Phase 1 lands**; no prototype exists and nothing has been verified in Studio. Dependencies, all READY (not started) unless noted: code path FL-0003 (BUILDING) → FL-0007, FL-0008 and FL-0044 (in parallel) → FL-0010 → FL-0011, plus FL-0009 (remote validation for gear); island art FL-0013 → FL-0014 / FL-0015 → FL-0016; spectate and results UI FL-0020 → FL-0043; economy FL-0018 → FL-0045 → FL-0019 / FL-0021; first-5-minutes plan FL-0023 → FL-0025, FL-0026; hazard VFX FL-0024; Studio check FL-0031 → FL-0036 (user, SPECIFIED). Terrain `rojo syncback` is unproven and has no task. These 22 framework tasks carry 130 h of planning estimates across five workers; the longest code chain (FL-0003 → FL-0008 → FL-0010 → FL-0011) is 24 h (I: from `depends_on` and `estimate_h`; estimates, not measurements). |

Systems map:

| Need | Framework (task) | New game code |
|---|---|---|
| Rounds, spawn platforms, spectate, results | FL-0010, FL-0043 | spectator voting |
| Flood + 5 more hazards | FL-0011 | lightning, gas, rocks, fire ring, wind hazard modules + sector scheduler |
| Gear pickups | FL-0018 items, FL-0009 validation | 5 gear behaviours |
| Relic Caches (earned random) | FL-0018, FL-0045, FL-0021 reveal | cache config |
| Data, purchases | FL-0008, FL-0019 | product list |
| Onboarding, daily, quests, analytics | FL-0025, FL-0026, FL-0023 | step graph, quest list, funnels |

Assets: broadleaf trees, palms, ferns (FL-0014); rocks and ruins kit (FL-0015); island terrain and lagoon (new; Studio terrain must come back to Git via `rojo syncback`, PC I-S3); hazard VFX (FL-0024); 5 gear props (new, small); relic icons (FORGE-03); SFX from the Creator Store, in game only (PC U3, U6).

Monetization fit (I; pricing observations in `intelligence/monetization/roblox-monetization-patterns.md`):
- **Earned random (no Robux path):** Relic Caches opened with **Relic Keys earned only by play**. No platform odds rule applies (PC P7), but the house rule shows outcomes and odds. Relic Keys **must never be sold for Robux**; otherwise every cache becomes a paid random item (PC P1, P5).
- **Paid, direct:** cosmetic passes and products (umbrella, balloon and trail skins), a small utility-gear pass (NDS gear passes reported at ~80 R$; low, unverified, E2), a season pass whose missions never require hard currency (E21), and paid private servers (Plus payouts, MR 6.6).
- **Rewarded video:** fixed coins only, never random (E20).
- **Paid random:** not proposed. If you approve it later, it needs odds, a `canBuyPaidRandom` gate (fail closed) and the questionnaire (PC P3–P14).

First 5 minutes (targets, I): 0:00 spawn in the lobby, one-tap "Play" pad → 0:20 round countdown on a spawn platform, a contextual hint names one gear item → 0:45 first wave is a slow flood with a big warning; the player climbs ruins and gets a coin burst (first reward under 60 s, MR 12.8) → 2:00 first gear use prompted contextually (FL-0025) → 3:00 round ends, the player is crowned or spectates and votes → 3:30 first Relic Cache opens with an odds panel and honest reveal → 4:00 daily quest shown ("survive 2 floods") → 5:00 second round already running.

**Why it could succeed (I):** it uses the most of the planned Phase 1 framework (specified, not started; §1); the genre is proven, evergreen, all-ages and chat-free; it has clip-able chaos; and weekly new disasters are a cheap live-ops cadence (MR 3.6).
**Why it could fail (I):** NDS-like loops are shallow and D8–D28 may be weak (RP 3). Incumbents are small: NDS ~8–14K CCU; other disaster titles ~0.6–3K now [E1, E3, E4]. That suggests a modest ceiling. Spectator voting could feel griefy. Heavy VFX may hurt low-end Android (PC A8). The 7 days depend on Phase 1 finishing first.

### 6.2 C6 Hidden Hunter (68.8)

| Field | Content |
|---|---|
| Title (working) | Hidden Hunter |
| Genre | Social deduction / round-based (MM2-like), Party & Casual |
| Target experience | Tense 3-minute rounds in jungle ruins: "who is the Hunter?" Clip-able reveals and last-second Ranger shots. |
| Core loop | Lobby → secret roles (1 Hunter, 1 Ranger, rest Explorers) → Explorers collect relic shards while a hazard (gas or flood) shrinks safe space → Hunter tags; Ranger has one dart → win check → results → reset |
| Motivation | Tension, bluffing, role fantasy, cosmetic collection |
| Mechanics | One-hit tag (server-validated range and rate, from a subset of FL-0012); Ranger dart (single projectile); relic shards; hazard as timer (FL-0011); role reveal on elimination |
| Multiplayer needs | 6–12 per server (design target); **the role must never be replicated to non-owners** (exploit-readable); bot fill: not proposed |
| Visual direction | Same jungle kit; compact maps (2–3 sectors of the island); strong silhouettes for cosmetics |
| Progression | Level, cosmetic collection (weapon skins, trails, emotes), role-specific titles |
| Social | Party queue, emotes, spectate, no chat dependence (deduction comes from behaviour) |
| Replay | Random roles, map rotation, hazard variants, seasonal cosmetic sets |
| USPs | Hazards change each round's geography; jungle ruins with verticality; transparent cosmetic economy |
| Difficulty | Medium. Estimate (I): 7 days after Phase 1 for 2 maps, if light tagging is cut from FL-0012 (which is gated on this choice and not started) and role secrecy is built new. |

Systems map: rounds and spectate (FL-0010, FL-0043); light tagging (subset of FL-0012, new); role assignment and secrecy (new); hazards (FL-0011); cosmetics, inventory and reward tables (FL-0018, FL-0045, FL-0021); data and purchases (FL-0008, FL-0019); onboarding with a role tutorial (FL-0025). Assets: jungle and ruins kit (FL-0014, FL-0015); 2–3 compact maps; blowpipe/machete/dart base models plus skin variants (new); trail VFX (FL-0024).

Monetization fit (I): cosmetics drive spending in this genre (MM2 Elite pass 499 R$, Radio 475 R$, E10; MM2 event mystery boxes and Godly packs, MR 1.2). **Earned:** skin crates from shards (earned random, odds shown). **Paid direct:** cosmetic bundles, an Elite-style pass, a season pass. **Paid random** (an MM2-style mystery box) is **gated**: you must approve it, and it needs odds, `canBuyPaidRandom` (fail closed; Brazil under-18 ban, MR 8.7) and questionnaire answers. **Trading: not proposed** (PC P12; scam and moderation load).

First 5 minutes (I): 0:00 lobby; role-tutorial card (10 s) → 0:30 first round as Explorer (forced on first join): collect 3 shards, coin burst → 1:30 Hunter reveal on someone else → 3:00 results; first earned crate opened with odds → 3:30 second round → 5:00 shown the cosmetic log and a daily quest.

**Why it could succeed (I):** MM2 shows the format is evergreen at huge scale (MR 1.1). Rounds are short. Few assets. It works without chat.
**Why it could fail (I):** players may call it an MM2 clone; it needs about 6+ players per server (cold start); hidden-role exploits; MM2's entrenched item economy holds its player base.

### 6.3 C4 Jungle Night Expedition (68.4)

| Field | Content |
|---|---|
| Title (working) | Jungle Night Expedition |
| Genre | Co-op horror survival (1–4 players) |
| Target experience | Friends survive progressively harder nights in overgrown ruins while a creature hunts by sound; storms and floods arrive at dawn |
| Core loop | Day: scavenge and repair beacons → Night: hide, distract, complete objectives → Dawn: hazard event → earn relics → upgrade class and gear → next night |
| Motivation | Fear plus relief, co-op bonding, class mastery, collection |
| Mechanics | Creature AI (pathfinding through jungle, noise-based detection: **new**); beacons and objectives; flashlight and battery; hazards as night events (FL-0011); downed state and revive |
| Multiplayer needs | 1–4 co-op; server-authoritative AI; latency-tolerant chase |
| Visual direction | Dark tropical; volumetric fog, lightning silhouettes; same foliage kit with night lighting |
| Progression | Night depth, classes bought with earned currency (99 Nights model, MR 11.4), relic log |
| Social | Party-first; pings and emotes instead of chat (MR 8.9) |
| Replay | Night modifiers, creature variants, limited events (99 Nights ran events every 1–2 weeks, MR 3.3) |
| USPs | Jungle ruins setting with real flood and storm events; sound-hunting creature |
| Difficulty | High. Estimate (I): 10–14 days to reach horror quality; creature rig/animation is not in the pipeline. |

Systems map: rounds become night cycles (FL-0010 adapted); hazards (FL-0011); economy and classes (FL-0018, FL-0045); **new**: creature AI, stealth/noise, downed and revive, lighting controller. Assets: jungle and ruins kit; **creature model + rig + animations (new pipeline work)**; ambient audio (Creator Store, in game only).

Monetization fit (I): consumable revives and utility items sold in context (the Doors flashlight and revives are Roblox's own examples, E21); classes via earned or purchasable currency (99 Nights diamonds: 20 for 99 R$ … 700 for 2,500 R$, E16). **If that currency can be bought with Robux, any random spend of it becomes paid random** (PC P1). **Earned:** post-night Expedition Chest (earned random, odds shown). **Paid random: not proposed.**

First 5 minutes (I): 0:00 lobby elevator with friends → 0:30 day phase: pick up a flashlight, light the first beacon (reward under 60 s) → 2:00 first night falls; scripted safe "first sighting" of the creature → 3:30 hide tutorial through contextual prompt → 4:30 dawn flood; survive → 5:00 relics plus class preview.

**Why it could succeed (I):** it has the strongest 2026 genre tailwind, solo and small-team hits exist (MR 2.1), there is a fall 2026 Roblox slate of co-op horror (MR 1.16), and its moments are clip-able.
**Why it could fail (I):** the creature/AI/rig work is new and risky, horror needs polish 7 days won't give, many 2026 entrants, and a fear rating may narrow the audience (Moderate fear limits Kids catalogs, E19).

## 7. Recommendation (I)

**Recommend C2 Flood Island for Game #1. It is not approved. Confidence: medium-low.**

Why: it scores highest on the stated weights. It stays top-3 under every weighting: tied 1st with C4 when MO and RP are doubled, and tied 2nd with C6 under upside-only (§4). It uses the most of the planned Phase 1 framework (rounds, spectate, real flood, jungle kit), all of which is specified but not started (§1). It avoids the two risks that hold C1 back (PvP combat and liquidity). It keeps the prior concept's island, disasters and spectate. A C1-style **Arena mode** can follow as an update once the CCU can fill PvP lobbies.

Why confidence is only medium-low: C2 leads C6 by 4.4 points, but that rests on F7 4 (conditional on Phase 1) and MO 4 (partly adjacent evidence). With either at 3 the lead is about 2 points; with both it is a tie (§4). C4 wins on upside. The market evidence is snapshot-level and low confidence. Nothing is built and no prototype has been played.

**Evidence that would change this:**
- A 2026 Roblox battle-royale or HG title holding >20K CCU, from a direct read, would raise C1's MO further. FL-0012 combat landing early, or usable combat or map work in the user's previous survival-arena files (FL-0034), would raise C1's F7 and DC.
- Phase 1 slipping, or terrain syncback proving hard once tested, would lower C2's F7 (§4: C2 F7 3 → 71.2).
- Direct reads showing disaster-survival incumbents well below the snippet figures (E1, E3), or a modern, polished disaster game already dominating, would lower C2's MO and DF.
- A 2-day greybox playtest with D1 or first-session bounce data (MR 5.2) for C2 vs C6.
- A proof that FORGE-02 can produce a rigged, animated creature would raise C4's F7, DC and AR and could make it the pick.

## 8. Decision for the user (exact)

Reply with one letter (FORGE-00 records it in `DECISIONS.md`, FL-0035):

- **A (recommended): Approve C2 Flood Island as Game #1**, with Arena mode (the prior concept's PvP) as a later update, gated on CCU.
- **B: Approve C1 Jungle Survival Arena as specified.** You accept a ~14-day target (I) and FL-0012 combat starts now.
- **C: Approve C4 Jungle Night Expedition.** You accept a longer schedule and a creature-pipeline spike first.
- **D: Approve C6 Hidden Hunter.**
- **E: None yet.** Run a 2-day greybox test of two candidates (for example C2 vs C6) and decide on playtest data. This needs at least the skeleton (FL-0003) and the round and hazard services (FL-0010, FL-0011) first, none of which exists yet.

Separate approvals still needed whatever you choose: paid random items (yes/no), in-game trading (yes/no), price list.

## 9. Key gaps

- Tracker sites (rowatcher, profitable.app, roblox.com, bloxodes) returned proxy 403/DNS errors on 2026-10-12, so all per-game figures are from search snippets.
- No Sep–Oct 2026 top-games ranking (MR gaps).
- No first-party retention benchmarks by genre (MR 12.4 is unsourced).
- Disaster-survival 2026 trend line: only snapshots, no time series.
- Roblox battle-royale market size: no reliable figure. Island Royale's current player count: not found (E11).
- **Nothing is built:** 0 Luau files on any branch, the skeleton is still BUILDING, and no system has been checked in Studio (FL-0036 needs the user's PC). Every F7 score assumes Phase 1 lands first.
- Creature rig feasibility (C4) and terrain syncback (C2) are unproven in this repo; syncback has no task yet.
- **The user's previous survival-arena files** (place, scripts, Blender files) are on their PC, not in the repo; the inventory (FL-0034) has not been run. C1 was scored without them.
- Single-source or unverified figures used here: MM2 ~1.35M peak (MR 1.1); NDS Compass price (E2); Jujutsu Shenanigans 338K peak (E22, from a page with an April Fools ticker).

## 10. Evidence register (new facts; MR/PC rows carry their own URLs in those files)

| ID | Fact | O/I | Source | Date | Conf |
|---|---|---|---|---|---|
| E1 | Natural Disaster Survival: ~4.1–4.4B lifetime visits; CCU snapshots of ~8.4K (2026-09-14), 11.6K (2026-08-29, tracked peak 14.5K) and 13.1K (undated). Range used: ~8–14K | O | [RoWatcher](https://rowatcher.com/games/65241/natural-disaster-survival), [profitable.app](https://profitable.app/roblox/games/natural-disaster-survival), [AllThingsHow](https://allthings.how/?p=174769) (WebSearch snippets, re-searched 2026-10-12) | 2026-08/09 (one undated) | low |
| E2 | NDS gear passes: Green Balloon 80 R$ (earnaldo); a fan wiki says NDS microtransactions cost "only 80 Robux". A Compass pass exists (named on a Roblox page snippet for the 2019 remake), but **its price was not found**; the earlier "60 R$" is withdrawn. **Unverified** | O | [earnaldo](https://earnaldo.com/blog/natural-disaster-survival-free-robux-guide), [Perfection wiki](https://perfectionrobloxgames.miraheze.org/wiki/Natural_Disaster_Survival) (WebSearch 2026-10-12) | undated | low |
| E3 | Build To Survive DISASTERS!: 27.6M visits, ~2K CCU now, peak 12K (May 2026). Disaster Island: 140.1M visits, peak 3K (Apr 2026) | O | [RoWatcher BTSD](https://rowatcher.com/games/7760134732/build-to-survive-disasters), [RoWatcher Disaster Island](https://rowatcher.com/games/5111507958/new-map-disaster-island-survival) (WebSearch 2026-10-12) | 2026-04/05; "now" = snapshot seen 2026-10-12 | low |
| E4 | Flood Escape 2: ~593.7M visits; all-time peak 21,486 on 2025-12-22; snapshots 590 (Rolimons), 594 (Rotrends, 7-day avg ~441), 610 (Bloxodes); last updated 2026-09-02 | O | [Rolimons](https://www.rolimons.com/game/738339342), [Rotrends](https://rotrends.com/game/323675642), [Bloxodes](https://bloxodes.com/stats/games/flood-escape-2-323675642) (WebSearch 2026-10-12) | 2025-12 / 2026-09–10 | low |
| E8 | Dead Rails (2025): >200K CCU at peak times, >600K one weekend, surge credited to discovery placements | O | [GameAnalytics](https://www.gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula) | 2025 | low-med |
| E10 | MM2 Elite pass 499 R$, Radio pass 475 R$ | O | [Sportskeeda](https://www.sportskeeda.com/roblox-news/roblox-murder-mystery-2-official-links-gamepasses), [Bloxodes wiki](https://bloxodes.com/wiki/murder-mystery-2/radios) | Elite entry last updated 2019 (snippet) | low-med |
| E11 | Island Royale: a 2018 Fortnite-style battle royale; 426.1M visits and up to 200 per match in undated (~2022) Sportskeeda coverage. Creation date conflicts across sources (2018-01-08 vs 2018-03-03). The earlier quote "barely gets a few hundred active players" **could not be re-found** (2026-10-12) and is withdrawn. Current player count: not found. **Not 2026 evidence** | O | [Sportskeeda 2022 list](https://sportskeeda.com/esports/top-5-roblox-games-like-fortnite-2022), [Sportskeeda "5 Roblox games like Fortnite"](https://www.sportskeeda.com/roblox-news/5-roblox-games-like-fortnite), [player.me](https://player.me/?p=37353) (WebSearch 2026-10-12) | undated (~2022) | low |
| E12 | Newzoo (reported): battle-royale playtime −27% in 2025 vs 2024, all platforms | O | [GuruGamer](https://gurugamer.com/pc-console/battle-royale-slump-27-percent-playtime-drop-in-2025-sparks-debate-on-genres-future-26524/amp) | 2025–26 | low |
| E13 | RoWatcher shooter chart: RIVALS 217K, Hypershot 29K, One Tap 21K; the top 20 are mostly arena, duel or tactical games | O | [RoWatcher Shooter](https://rowatcher.com/genres/Shooter) | undated | low |
| E14 | PvP comparables: The Strongest Battlegrounds ~64.2K (profitable.app, 2026-07-30) and ~83.3K (RoWatcher, undated); BedWars variant ~42.2K (2026-07-30) | O | [profitable.app TSB](https://profitable.app/roblox/games/the-strongest-battlegrounds), [RoWatcher TSB](https://rowatcher.com/games/3808081382/the-strongest-battlegrounds), [profitable.app BedWars](https://profitable.app/roblox/games/bedwars) (WebSearch 2026-10-12) | 2026-07-30 / undated | low |
| E15 | Epic Minigames ~2.5–3.1K CCU late Jul 2026; peak 32K (Oct 2025); 12 players per server | O | [profitable.app](https://profitable.app/roblox/games/epic-minigames), [RoWatcher](https://rowatcher.com/games/110181652/epic-minigames) | 2026-07 | low |
| E16 | 99 Nights diamonds: 20 = 99 R$, 100 = 400 R$, 250 = 900 R$, 700 = 2,500 R$ (one guide) | O | [esports.gg](https://esports.gg/news/roblox/diamonds-99-nights-in-the-forest/), [Deltia's](https://deltiasgaming.com/?p=296205) | 2025–26 | low |
| E19 | Minimal/Mild ratings are eligible for Roblox Kids and Select; mild violence = unrealistic (e.g. bodies disappear at zero health); moderate fear = Moderate rating | O | creator-docs `content/en-us/production/promotion/content-maturity.md` ([raw](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/promotion/content-maturity.md)), read 2026-10-12 at commit af5f853 | 2026-10-10 | high |
| E20 | Rewarded video rewards must be developer products and **cannot be randomized items**; recommended value 3–10 R$-equivalent; publisher needs 13+, ID verification, ≥2,000 unique visitors/month | O | `content/en-us/production/promotion/rewarded-video-ads.md` ([raw](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/promotion/rewarded-video-ads.md)), read 2026-10-12 | 2026-10-10 | high |
| E21 | Roblox design guidance: Doors' flashlight and revives as contextual items; season pass with free and premium tracks, ~10 tiers to start, "missions never require spending hard currency" | O | `production/game-design/monetization-foundations.md`, `season-pass-design.md` ([raw](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/production/game-design/season-pass-design.md)), read 2026-10-12 | 2026-10-10 | high |
| E22 | Jujutsu Shenanigans (PvP battlegrounds): ~338,296 peak two days after the Disaster Plants update (released 2026-03-20), sustained peak-hour ~145–186K. The article's live ticker is labelled "[APRIL FOOLS]", so treat its figures with caution. Single source. Current count: not found | O | [RoWatcher](https://rowatcher.com/news/jujutsu-shenanigans-surges-past-338k-peak-players-after-disaster-plants-update) (WebSearch 2026-10-12) | 2026-03 | low |
| E23 | Escape Tsunami For Brainrots is a **brainrot collection** game, not disaster-survival evidence: RoWatcher says it briefly overtook Steal a Brainrot in Jan 2026, ranks it 3rd by average CCU for January, peak ~5M, later ~164K. MR 9.2 cites criticism of it as "low-effort". Removed from C2's evidence | O | [RoWatcher brainrot article](https://rowatcher.com/news/is-the-brainrot-trend-dying-what-ccu-data-from-three-top-games-reveals) (WebSearch 2026-10-12) | 2026-01 | low |
| E24 | Disaster + last-player-standing already exists on Roblox. DISASTERS: random disasters until one player is left; eliminated players **return as ghosts** who can earn a revive or get swords to hunt survivors; needs a host; no running servers in the snapshot. A game where spectators **vote the next disaster**: not found. NDS lets players vote on the next map (Sportskeeda). Survive the Disasters is described as last-player-standing only by low-quality aggregator pages (not cited, unverified) | O | [Roblox: DISASTERS](https://www.roblox.com/games/98482965958577) (search snippet; roblox.com blocked by proxy), [Sportskeeda NDS](https://sportskeeda.com/roblox-news/disasters-roblox-natural-disaster-survival) (WebSearch 2026-10-12) | undated | low |
| E25 | Repo state: FL-0010, FL-0011, FL-0013..FL-0016, FL-0008, FL-0018, FL-0019, FL-0043, FL-0044, FL-0045 are READY; `READY` precedes `BUILDING` in `tools/forge.py` `LIFECYCLE`; FL-0003 is BUILDING; FL-0012, FL-0035 and FL-0036 are SPECIFIED; only FL-0001, FL-0002 and FL-0038 are ACCEPTED. `git ls-tree` finds 0 `.lua`/`.luau` files on `main`, `forge/00-skeleton` and `origin/forge/01..05-*` (local refs) | O | `production/tasks/*.md`, `tools/forge.py`, `PROJECT_STATUS.md`, `ROADMAP.md`, read 2026-10-12 | 2026-10-12 | high |
| MR rows used | 1.1, 1.2, 1.4, 1.5, 1.8 (as brainrot context only), 1.9, 1.10, 1.13, 1.16, 2.1, 3.3, 3.6, 4.8, 5.1, 5.2, 6.6, 7.2, 7.5, 8.7, 8.9, 9.3–9.5, 9.7, 10.3, 11.4, 12.2, 12.6, 12.8 | — | `intelligence/market-research/2026-10-roblox-landscape.md` | — | per row |
| PC rows used | P1, P2, P3–P14, P5, P6, P7, P12, A4, A8, U3, U6, I-S3 | — | `docs/research/roblox-platform-constraints.md` | — | per row |
