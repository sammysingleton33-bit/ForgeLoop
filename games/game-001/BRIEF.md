# Game brief: AI Kingdoms — working title *Kingdoms: Crownfall* (game-001)

_Status: **selected by the user on 2026-10-12** (D-020). Author: FORGE-00. Contracts: `games/game-001/CONTRACTS.md`. Unresolved design and monetization questions stay with the user (§16)._

## 1. Pitch and target player
Four medieval kingdoms compete in one 30–45 minute match. Each kingdom has up to four human rulers (solo, duo, trio or squad). They rule from the throne through an aerial management view, and they direct a living population of AI citizens who are generated anew each match. Citizens farm, gather, build, trade and fight, have personalities and relationships, and react to the ruler's decisions through structured conversations and six reputation values (`design/living-kingdom.md`). Grow, fortify, raid and besiege. The match ends in the **Crown Arena**: the leading rulers duel in front of their own citizens, whose support reflects how each ruler led (§18). The remaining victory rules are the user's decision (§16.4, §16.9). Target (proposal, pending §16.7): mid-core Roblox players aged 13+, on PC and mobile, in 30–45 minute sessions with friends.

## 2. Core loop
- **30 s:** walk to a job, gather or place something, and see citizens react.
- **5 min:** grow the economy (food, wood, stone, gold) → build or upgrade → unlock units and territory.
- **Match (30–45 min):** Founding → Expansion → Conflict → Endgame (sieges) → Crown Arena → Results with a leadership recap.
- **Week:** account progression, cosmetics, kingdom banners, ranked or seasonal play. Scope for this is the user's decision (§16).

## 3. Match structure (target; numbers tuned in config)
| Phase | Time | What happens |
|---|---|---|
| Founding | 0–8 min | Claim the keep, assign first citizens, first farms and lumber, first houses |
| Expansion | 8–20 min | Grow population, take neutral outposts and resource nodes, upgrade the keep, raise walls |
| Conflict | 20–32 min | Armies, raids on rival farms and stores, alliances form and break |
| Endgame | 32–38 min | Siege of rival keeps. Crown Points decide who reaches the arena (§18) |
| Crown Arena | 38–44 min | Final duel in front of each kingdom's citizens; support earned during the match gives moderate buffs and clutch moments (§18). Results and leadership recap to 45 min |

Empty kingdom slots are run by AI governors. Their behaviour level, from passive to competitive, is a user decision (§16.3).

## 4. Vertical slice VS-1 (first playable; user directive 2026-10-12, D-030)
The **only** milestone that matters now.
- It is accepted only after a **Studio playtest by the user**, with screenshots and the BuildInfo sha. Headless tests never count as acceptance.
- Temporary assets and simplified mechanics are fine where needed. They are improved after the loop works.
- FORGE-05 hands the user a fresh `.rbxl` after every merge that changes what can be seen or played. Each build comes with a truthful "works / doesn't yet" list.

| # | Player can… | Acceptance in Studio | Owners |
|---|---|---|---|
| 1 | See a colourful medieval kingdom | A colourful valley with a river, forest, quarry, farm fields and roads. The player's own kingdom plot is fully dressed; the other three are blocked out | FORGE-02 (WorldService, Kit, lighting), FORGE-05 |
| 2 | Rule from the throne with an aerial camera | The ruler (crown and cape in kingdom colours) sits on the throne in the keep. The default camera is an aerial management view over the kingdom: pan, zoom and rotate on PC and on the phone emulator. Tapping selects a citizen, a building or a plot. Walk mode is optional in VS-1 | FORGE-04 (camera, selection), FORGE-01 (spawn and seat), FORGE-02 (throne) |
| 3 | Belong to a kingdom | Auto-assigned to one of 4 kingdoms with banner colour and name. The HUD shows the kingdom and its members. Two players in one simulated party share a kingdom (Party Simulator) | FORGE-01, FORGE-03 |
| 4 | Watch AI citizens live and work | At least 12 citizens in the player's kingdom, **generated for this match**: names, 2–3 traits, varied looks. They walk to work, gather or farm, carry goods to the storehouse, and the stockpile rises | FORGE-01 (population, sim, replication), FORGE-02 (looks), FORGE-04 (work feedback) |
| 4b | See that citizens think | Selecting a citizen opens a card with name, occupation, traits, mood, loyalty, current intent, family, friends and recent memories. A job panel reassigns workers | FORGE-01, FORGE-03 |
| 5 | Run the kingdom economy | The treasury (food, wood, stone, gold) rises from citizen work, falls with costs and upkeep, and is always visible on the HUD | FORGE-01, FORGE-03 |
| 6 | Construct and upgrade | Select a free plot, choose a structure (House, Farm, Barracks and more) with its cost, then confirm. Builders walk over and raise it through visible stages. The Keep and Barracks upgrade (Barracks levels 1–2 at about 8 s and 18 s, PROVISIONAL) and look different at each level | FORGE-01, FORGE-03 (plot picker, build menu, upgrade panel), FORGE-02 (stages, levels) |
| 7 | Recruit and capture | Recruit 3 soldiers at the Barracks, paid from the treasury, then press Send-to-capture. They walk to the neutral Watchtower, a capture bar fills and the tower takes the kingdom colour. Crown Points rise and the slice summary appears | FORGE-01, FORGE-03, FORGE-04, FORGE-02 |
| 8 | Use an interactive kingdom HUD | Resources, population, kingdom and Crown Points are on the HUD, with build, army and objective panels and the six reputation values. A reputation screen shows the history of changes and what each value means | FORGE-03 |
| 9 | Decide in a conversation and see the result | At least one citizen shows a thought bubble with a real request. Selecting them opens a conversation with 2–4 choices. The chosen answer plays the reaction and changes the world visibly: resources, that citizen's loyalty and mood on the card, a reputation value with a history line, and a visible work boost, strike or follow-up | FORGE-01 (ConversationService, reputation, effects), FORGE-03 (conversation panel, reputation screen), FORGE-04 (bubbles, reactions), FORGE-00 (content library) |
| — | First minutes guided | Onboarding walks a new player through: inspect a citizen → build on a plot → answer a citizen → recruit → capture | FORGE-04 |

The interim slice rules are unchanged (CONTRACTS G3): start on first join, untimed Founding, and the first capture ends the slice. They are not the game's victory rules. The full living-kingdom requirements are in `design/living-kingdom.md`. VS-1 carries the smallest working version of each.

**VS-2 — a complete four-kingdom match (draft; ask the user before VS-2 starts about every item tagged §16.x):**

| # | Player can… | Acceptance |
|---|---|---|
| 1 | Play a timed match | Phases with a timer from Pacing (Founding → Results); mid-match joiners are placed by a written join policy (§16.3) |
| 2 | Face rival kingdoms | AI governors run empty kingdoms at a chosen difficulty (§16.3) |
| 3 | Fight | Unit vs unit and unit vs building combat; the ruler's combat role, death and respawn (§16.2) |
| 4 | Raid and defend | Raids on farms and stores; walls, gates and towers that block or shoot; citizens flee and remember raids (§16.2) |
| 5 | Besiege | One siege engine (e.g. a ram) that can breach a gate and damage a keep (§16.2) |
| 6 | Expand | At least 3 neutral outposts that grant territory; territory limits building |
| 7 | Produce | Production chain v1 (e.g. wheat → bread or ore → weapons) |
| 8 | Lose and keep playing | Elimination → spectate or assist (§16.4) |
| 9 | Share a kingdom safely | Co-ruler spending permissions; "join this kingdom" banner for friends outside a party; solo/duo/trio/squad queueing design |
| 10 | Win in the Crown Arena | Qualification, champion vote, loadout and trigger pick, crowd support, final duel, crowning and leadership recap (§18, `design/crown-arena.md`). The fairness harness passes the outcome caps; the user accepts the feel in a two-client Studio run (§16.4, §16.9) |
| 11 | Run at scale | Interest-managed snapshots; day/night clock; custom animations (FL-0066); 300 entities measured on a published private test place with ≥ 8 real clients (user approval) |

**VS-3:** alliances and betrayal (§16.2), trade, diplomacy, replayability (layout seeds and variants, governor personalities), persistent progression (§16.5), polish, mobile performance pass, release checklist.

## 5. Architecture (decisions D-021 to D-026)
- **Code layout (D-022, D-026):** game code lives in `games/game-001/src/{shared,server,client}`, with config in `games/game-001/config` and the world data in `games/game-001/world`. FORGE-05's game project keeps every framework mount and adds:
  - `src/shared` → `ReplicatedStorage.Game`;
  - `world` → `ReplicatedStorage.Game.World`;
  - `src/server` → `ServerScriptService.Game`;
  - `src/client` → `StarterPlayerScripts.Game`;
  - `config` → `ReplicatedStorage.Forge.Config`.

  The loader discovers services in both `Forge` and `Game` trees. Names may not repeat across the two trees. Game code reaches framework modules with `@game/ReplicatedStorage/Forge/...` and game modules with `@game/ReplicatedStorage/Game/...` (policy extension of D-017). Framework code never requires game code. Full rules: CONTRACTS G1.
- **Simulation and replication (D-023, D-025):** citizens and soldiers are server-simulated **entities**, not Humanoids.
  - The server runs a fixed tick (target 10 Hz for AI decisions, staggered across frames; 20 Hz for movement) on a navigation graph from `world/Layout.luau`.
  - The server replicates compact `buffer` snapshots through an unreliable remote: chunks of at most 900 B with a sequence number and server time. Reliable batched events carry state changes.
  - Clients render entities with pooled rigs of at most 8 parts, animate them procedurally, and interpolate positions. No animation assets are needed for VS-1.
  - Budget: 300 entities per server (about 75 per kingdom); see §14. The slice uses about 20–40. Interest management arrives in VS-2.
- **Persistence:** within-match memory (who attacked whom, citizen mood/morale, relationships) lives in the sim. VS-1 has no persistence (D-027). Cross-match persistence scope (player progression; optionally citizen or governor memory of rival players across matches) is a user decision (§16.5).
- **Assets (D-021, D-026):**
  - Architecture (keeps, houses, walls, farms, barracks, towers, bridges) is built **in Luau from primitive Parts only by FORGE-02's Kit at runtime**: Block, Wedge, CornerWedge, Cylinder and Ball. There is no runtime CSG. Curved or complex pieces come only as imported meshes through `Kit.prop` ids. The Kit is styled by the art direction and is testable through Rojo with no uploads.
  - Organic and detail assets (trees, rocks, crops, props, banners) come from **Blender**. They are imported in batches by the user via Studio (or Open Cloud once FL-0039 lands). Until imported, the Kit uses stylised part-built stand-ins with the same asset ids.
  - Custom keyframe animations need assets published by the user's account. They are a VS-2 batch (FL-0066).
- **Streaming (D-025):** Workspace streaming is on and set in the project file. Client rigs live in a client-created folder, and clients never depend on far-away tagged instances.

## 6. Visual direction
Colourful, readable, stylised medieval: warm sunlit valleys, saturated kingdom colours (four distinct banners: crimson, azure, emerald, gold), chunky readable silhouettes, timber-and-plaster houses, stone keeps with banners, golden wheat fields, deep green forests, blue river.
- Readable at RTS-ish camera distances and on phones.
- No grey placeholder look in anything shown to players.
- Art direction sheet: `blender/ART_DIRECTION.md` (FORGE-02), with budgets in `blender/budgets.json` and the asset list in `blender/manifest.json`.
- Kingdom display names (working names, PROVISIONAL until the user's branding decision §16.6): Emberhold (crimson, crown; D-039), Frostmere (azure, star), Thornwood (emerald, oak leaf), Sunspire (gold, sun disc). Contract ids stay `crimson`, `azure`, `emerald`, `gold` (G2).
- Lighting preset (Lighting, Atmosphere, Sky, ColorCorrection, Bloom, terrain material colours): `games/game-001/world/Lighting.luau` (FORGE-02). VS-1 uses a fixed time of day.

## 7. Economy (starting point; FORGE-03 owns numbers, FORGE-04 pacing)
- **Kingdom resources:** Food, Wood, Stone, Gold (Iron at VS-2), held in a **shared kingdom treasury**.
- **Sources:** citizen jobs and ruler gathering. **Sinks:** buildings, upgrades, units, upkeep (food per citizen and soldier, charged only by ProductionService).
- **Crown Points:** earned from buildings, territory, objectives and raids. Whether they decide victory at the timer is a user decision (§16.4; default proposal: yes).
- **Player meta-currency and cosmetics:** design only for now. Monetization needs the user's approval (§16).

## 8. AI citizens (FORGE-01)
- **Behaviour model:** utility-based. It scores job, need and threat, and uses simple per-job state machines. The day/night routine (work, eat, rest) arrives in VS-2; VS-1 runs at a fixed time of day.
- **Reactions:** flee from raids (VS-2), cheer at upgrades, morale changes.
- **Memory:** small per-citizen memory of notable events (attacked by kingdom X, fed or hungry, ruler visited) that shifts behaviour, e.g. reluctance or loyalty. VS-1 makes it visible on the citizen card (row 4b).
- **Testability:** all of it is deterministic and Lune-testable with an injected clock and RNG.

## 9. Ownership for game-001
`docs/workflows/team.md`, section "game-001", is the single source. This brief does not copy it.

## 10. Assets needed for VS-1 (FORGE-02)
- **Architecture kit (part-built):** keep L1/L2, house, farm field + farmhouse, storehouse/granary, lumber camp, quarry, barracks, watchtower (neutral and kingdom colours), region border flags, wall segment and gate (VS-2), roads, fences, bridge, construction scaffolding stages (3 per building).
- **Organic (Blender):** oak, pine, birch, bushes, rocks S/M/L, wheat crop stages, logs/stone piles, crates and barrels, banners in 4 colours.
- **Characters:** a citizen look per job (a rig of at most 8 parts, not a Humanoid, tinted by kingdom and job, with a tool in hand), a soldier look, and ruler regalia (crown and cape accessories).

## 11. Audio and VFX (FORGE-04)
Chopping, mining, building hammer, coin and resource pickups, construction complete fanfare, horn for raids, capture sting, ambience (birds, river, wind), simple medieval music loops. Sources must be licence-clear.

## 12. Systems map
| Category | Systems |
|---|---|
| Reused framework | Loader/Env, Signal, StateMachine, Validate, RateLimiter, RemoteService/RemoteClient, Analytics, Settings, Onboarding, Audio/VFX, Notifications, UI kit; DataService/PlayerService and Economy/Inventory (meta) after VS-1 |
| New game systems | Match, Kingdom, Entity sim + replication, Citizen AI, Construction, Territory, Military, Objectives, Treasury, Kit/world, Pacing/Announcer |

## 13. Analytics (VS-1)
- **Funnel:** spawn → first gather → first build placed → first building complete → first recruit → first capture. Attribution rules: CONTRACTS G9.
  - "First gather" is the first gather credited to the player: their own, or any citizen deposit while they are a member. It measures that the kingdom's economy started, not that the ruler gathered (D-044 (2)). Conversations are measured by a custom event, not a funnel step.
- **Also logged:** match length, kingdom outcomes, disconnects.

## 14. Performance budget
| Metric | Target | How it is measured |
|---|---|---|
| Server sim | ≤ 4 ms at p99 per Heartbeat at 300 entities, including snapshot encoding; decisions staggered (e.g. 300 entities over 6 frames) | `os.clock` timing in code. In Studio it is indicative only, because the test server is the user's PC |
| Bandwidth | VS-1 broadcast: ≈ 5 KB/s per player at 50 entities. VS-2 with interest tiers: ≤ 20 KB/s per player | logged bytes/s; 16 viewers via a synthetic-viewer harness on the server plus 1–2 real clients. Studio allows at most 8 clients |
| Client | ≤ 150 rendered entity rigs on screen (custom LOD beyond 150 studs) | Studio stats are skewed by Studio itself. Real phone fps and memory need a published private test place (user approval) |
| Parts | ≤ 25k in the world for a typical VS-2 match; hard ceiling 27k for the all-built-at-max worst case (28,138 measured after FL-0086; a world-dressing trim brings it to about 26.5k, D-047) | Kit and WorldService part counts in specs; a spec fails above 27k |
| Texture memory | Mobile-safe | phone test (as above) |
| Players | 16 per server (4×4) | as above |

## 15. Plan to first playable (parallel; honest hours from task estimates)
_Update 2026-10-12 (D-030): VS-1 v2 adds the aerial camera with the throne, a generated population, conversations, reputation and plot construction. The hour table below is from before that change. Workers report updated estimates in their STATUS.md, and the dashboard tracks real progress._

FORGE-01 holds the critical path at about 47 h of serial work. VS-1 is therefore about 48 h of wall-clock time, not 24. Playtest A (rows 1–4b) comes at about h32. The other workers have slack, and fill it with VS-1 polish and the non-gating tasks.

| Hours | FORGE-01 | FORGE-02 | FORGE-03 | FORGE-04 | FORGE-05 |
|---|---|---|---|---|---|
| 0–2 | `Kingdom/Types` stub; FL-0007 Validate + RateLimiter + RemoteClient | Kit and Layout stubs | Resources/Costs stubs; FL-0020 Toast + Panel | FL-0061 pacing | FL-0046 game wiring, then merge the stubs |
| 2–8 | FL-0009 RemoteService | FL-0054 Kit v0 + preview path, calibration | FL-0058 Treasury | FL-0053 ruler, camera, input modes; FL-0027 | FL-0046 done; FL-0047 playtest script and debug panel; merges |
| 8–32 | FL-0048 → FL-0049 → FL-0050 | FL-0056 characters → FL-0055 world | rest of FL-0020 → FL-0059 → FL-0065 | FL-0024 → FL-0025 → FL-0062 | merges; **Playtest A** |
| 32–48 | FL-0051 → FL-0052 | FL-0013 → FL-0057 (not gating) | FL-0060 | FL-0023 → FL-0063 | merges, perf capture, **user playtest FL-0064** |

Estimated hours to VS-1 per worker:
- FORGE-01 ≈ 47 h;
- FORGE-02 ≈ 22 h, plus 18 h of organic assets;
- FORGE-03 ≈ 30 h;
- FORGE-04 ≈ 32 h, plus 7 h of analytics;
- FORGE-05 ≈ 12 h, plus merges.

## 16. Decisions reserved for the user (do not assume)
1. Monetization model (passes, products, cosmetics, any paid random items) and pricing.
2. PvP intensity between human kingdoms (full raids/sieges vs. PvE-first), and whether betrayal mechanics ship.
3. AI governor difficulty for empty kingdoms, whether a match can start with fewer than 4 human teams, and the mid-match join policy.
4. Victory rules. **Decided (user, 2026-10-12, D-029):** the match ends in the Crown Arena (§18). Still open: what eliminated players do, and the arena points in §16.9.
5. Cross-match persistence scope (account levels, unlocks, cosmetics only, or memory of rival players?).
6. Final title and branding.
7. Target audience and maturity rating: 13+ mid-core vs. all-ages Mild (they pull in different directions; market research rec. 4).
8. Whether to spike Roblox `TextGenerator` (an LLM NPC API, initially 100 requests/min) for citizen petitions voiced from their memory, in VS-2/3. It is not in VS-1.
9. Crown Arena open points (`design/crown-arena.md` §11; defaults are PROVISIONAL and config-driven): (a) format — top-2 kingdoms in one final duel, or a bracket; (b) champion choice in multi-ruler kingdoms; (c) whether the duel decides the match winner or grants Crown Points; (d) support strength — the outcome caps, and whether weak support may ever debuff.
10. **Match length (conflict recorded, unresolved; D-030).** The user's preference is about 25 minutes of kingdom play plus a 5-minute final phase, ending around minute 30. The current §3 and crown-arena §2 timing puts the arena at 38–44 minutes. Nothing changes until the user decides. FORGE-04 adds a non-default `match30` pacing profile for evaluation.
11. Approval of the dialogue library. The starter set is a DRAFT. The earlier 16-archetype / 48-response proposal will be imported once its files are supplied.
12. Balancing acceptance bounds for leadership strategies (`design/living-kingdom.md` §7).
13. Whether walk mode (third person) is offered outside the Crown Arena.

## 17. Risks
| Risk | Mitigation |
|---|---|
| Entity scale and bandwidth on Roblox servers | D-023/D-025 wire format with a size assert; measure early; live numbers on a private test place (user approval) |
| Mesh and animation uploads need the user | Part-built Kit and procedural animation first (D-021, D-026) |
| Scope (it is an RTS + city builder + social game) | VS-1 first; every addition must fit the 30–45 min match |
| Studio-only verification | Short, frequent user playtests with scripted checklists and Studio-only debug presets (FL-0047) |
| Critical path on one worker (FORGE-01) | Contract stubs at hour 0, client controllers moved out (D-028), honest §15 |
| Crown Arena support decides duels (unfair) or feels irrelevant | Contract caps (CONTRACTS G12.3), headless fairness harness with outcome bounds in CI, user feel test in Studio |
| Crown Arena scope pulls FORGE-01 off VS-1 | Arena work starts after FORGE-01's VS-1 rows; other workers prep in slack (§18) |

## 18. Crown Arena — final phase and citizen support (D-029; VS-2)
Full design: `games/game-001/design/crown-arena.md`. Contract: CONTRACTS G12 (draft until VS-2 starts).
- At the end of Endgame the leading rulers enter the **Crown Arena** in their chosen armour and weapons. Behind each ruler sits their own kingdom's stand, filled by the citizens who are actually alive.
- **Support** is a deterministic score built over the whole match: public reputation, happiness, stability, army morale, citizen loyalty, conduct (key decisions, protecting vs exploiting citizens) and personal valour. It sets a tier from Adoring to Hostile that drives crowd behaviour and a small passive blessing.
- **Key citizens** (blacksmith, healer, captain, provisioner, elder, merchant) appear with their buildings. When their loyalty is ≥ 80 they pledge a one-time duel trigger, e.g. a blacksmith at 98 loyalty reinforces the ruler's armour for +10 % damage reduction for 6 s. All of it is earned through play; nothing is random and nothing is purchasable.
- **Fairness:** passive ≤ +5 % per stat, ≤ 3 triggers, ≤ +15 % on any stat at any moment, no support effect touches the opponent. Measured outcome bounds: equal skill, Adoring vs Hostile wins 55–65 %; one skill tier beats maximal support ≥ 60 %.
- **Presentation:** chants, boos, perk moments at the rail, an intro versus card with the reasons for support, and endings that pay off the player's leadership.
- **Order:** VS-1 first. Prep in slack time, then FORGE-01 builds the core after its VS-1 rows (tasks FL-0069 to FL-0077).
