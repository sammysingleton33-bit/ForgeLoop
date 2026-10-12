# Game brief: AI Kingdoms — working title *Kingdoms: Crownfall* (game-001)

_Status: **selected by the user on 2026-10-12** (D-020). Author: FORGE-00. Contracts: `games/game-001/CONTRACTS.md`. Unresolved design and monetization questions stay with the user (§16)._

## 1. Pitch and target player
Four medieval kingdoms compete in one 30–45 minute match. Each kingdom has up to four human rulers (solo, duo, trio or squad) who walk their land in third person. They direct a living population of AI citizens who farm, gather, build, trade and fight. Grow, fortify, raid and besiege until one crown stands. Target: Roblox players aged 13+, on PC and mobile, in 30–45 minute sessions with friends.

## 2. Core loop
- **30 s:** walk to a job, gather or place something, and see citizens react.
- **5 min:** grow the economy (food, wood, stone, gold) → build or upgrade → unlock units and territory.
- **Match (30–45 min):** Founding → Expansion → Conflict → Siege / Endgame → Victory screen.
- **Week:** account progression, cosmetics, kingdom banners, ranked or seasonal play. Scope for this is the user's decision (§16).

## 3. Match structure (target; numbers tuned in config)
| Phase | Time | What happens |
|---|---|---|
| Founding | 0–8 min | Claim the keep, assign first citizens, first farms and lumber, first houses |
| Expansion | 8–20 min | Grow population, take neutral outposts and resource nodes, upgrade the keep, raise walls |
| Conflict | 20–35 min | Armies, raids on rival farms and stores, alliances form and break |
| Endgame | 35–45 min | Siege of rival keeps; last keep standing, or most Crown Points at the timer |

Empty kingdom slots are run by AI governors. Their behaviour level, from passive to competitive, is a user decision (§16).

## 4. Vertical slice VS-1 (first playable; target ≈24 h of productive work)
The **only** milestone that matters now. It is accepted only after a **Studio playtest by the user** (G6), with screenshots and the BuildInfo sha. Headless tests never count as acceptance.

| # | Player can… | Acceptance in Studio | Owners |
|---|---|---|---|
| 1 | Enter a medieval world | Spawns at their kingdom's keep in a colourful valley with a river, forest, quarry, farm fields and roads. At least one kingdom plot is fully dressed; the other three are blocked out | FORGE-02 (world, architecture, foliage), FORGE-05 (integration) |
| 2 | Control a ruler in third person | Smooth movement and camera on PC and phone emulator; ruler visibly distinguished (crown/cape in kingdom colours) | FORGE-01 (controller), FORGE-02 (ruler look) |
| 3 | Belong to a kingdom | Auto-assigned to one of 4 kingdoms with banner colour and name; HUD shows kingdom and members; two players in one server can share a kingdom | FORGE-01 (KingdomService), FORGE-03 (HUD) |
| 4 | See AI citizens working | At least 12 citizens in the player's kingdom with visible jobs (farmer, woodcutter, miner, builder, hauler). They walk to work, work, carry goods to the storehouse, and the stockpile rises | FORGE-01 (sim + replication), FORGE-02 (citizen look, props), FORGE-04 (work sounds/VFX) |
| 5 | Gather resources | The ruler can harvest a tree or rock with feedback; the kingdom treasury updates on the HUD | FORGE-01 (interaction), FORGE-03 (treasury + HUD), FORGE-04 (feedback) |
| 6 | Construct or upgrade | The build menu places a House, Farm, Barracks or Watchtower on valid ground with costs shown. Builders walk there and raise it through visible stages; the keep upgrades to level 2 | FORGE-01 (construction sim), FORGE-03 (build menu + costs), FORGE-02 (staged models) |
| 7 | Military / kingdom objective | Recruit 3 soldiers at the Barracks (paid from the treasury) and command them to capture the neutral Watchtower. A capture bar fills and the kingdom gains territory and Crown Points; the objective panel tracks progress | FORGE-01 (military + objective), FORGE-03 (army/objective UI), FORGE-04 (announcer, celebration) |
| — | First two minutes guided | The onboarding hints walk a new player through gather → build → recruit → capture | FORGE-04 |

**VS-2 (next):** all four kingdoms dressed, AI governors, raids between kingdoms, walls/gates, a simple siege of a rival keep, match timer with phases, victory screen. **VS-3:** alliances and betrayal, trade, persistent progression, polish, mobile performance pass, release checklist.

## 5. Architecture (decisions D-021 to D-023)
- **Code layout (D-022):** game code lives in `games/game-001/src/{shared,server,client}`, with config in `games/game-001/config` and the world in `games/game-001/world`. FORGE-05's game project maps it as follows:
  - `src/shared` → `ReplicatedStorage.Game`;
  - `src/server` → `ServerScriptService.Game`;
  - `src/client` → `StarterPlayerScripts.Game`;
  - `config` → `ReplicatedStorage.Forge.Config`.

  The loader discovers services in both `Forge` and `Game` trees. Game code reaches framework modules with `@game/ReplicatedStorage/Forge/...` and game shared modules with `@game/ReplicatedStorage/Game/...` (policy extension of D-017). Framework code never requires game code.
- **Simulation and replication (D-023):** citizens and soldiers are server-simulated **entities**, not Humanoids.
  - The server runs a fixed tick (target 10 Hz for AI decisions, 20 Hz for movement) on a navigation graph of roads, paths and work spots.
  - The server replicates compact snapshots (`buffer`) through an unreliable remote, plus reliable events for state changes.
  - Clients render entities with pooled rigs and animations, interpolating positions.
  - Budget: 300 entities per server (about 75 per kingdom) at under 4 ms per server frame for the sim, measured in Studio. The slice uses about 20.
- **Persistence:** within-match memory (who attacked whom, citizen mood/morale, relationships) lives in the sim. Cross-match persistence covers only player progression (DataService namespaces `game` + `economy`); its scope is a user decision.
- **Assets (D-021):**
  - Architecture (keeps, houses, walls, farms, barracks, towers, bridges) is built **in Luau from Parts/Unions by FORGE-02's kit builder at runtime**, styled by the art direction. It is instantly testable through Rojo with no uploads.
  - Organic and detail assets (trees, rocks, crops, props, banners) come from **Blender**. They are imported in batches by the user via Studio (or Open Cloud once FL-0039 lands). Until imported, the kit builder uses stylised part-built stand-ins with the same asset ids.

## 6. Visual direction
Colourful, readable, stylised medieval: warm sunlit valleys, saturated kingdom colours (four distinct banners: crimson, azure, emerald, gold), chunky readable silhouettes, timber-and-plaster houses, stone keeps with banners, golden wheat fields, deep green forests, blue river.
- Readable at RTS-ish camera distances and on phones.
- No grey placeholder look in anything shown to players.
- Art direction sheet: `games/game-001/art/ART_DIRECTION.md` (FORGE-02).

## 7. Economy (starting point; FORGE-03 owns numbers, FORGE-04 pacing)
- **Kingdom resources:** Food, Wood, Stone, Gold (Iron at VS-2), held in a **shared kingdom treasury**.
- **Sources:** citizen jobs and ruler gathering. **Sinks:** buildings, upgrades, units, upkeep (food per citizen/soldier).
- **Crown Points** decide victory at the timer: buildings, territory, objectives, raids.
- **Player meta-currency and cosmetics:** design only for now. Monetization needs the user's approval (§16).

## 8. AI citizens (FORGE-01)
- **Behaviour model:** utility-based. It scores job, need and threat, uses simple per-job state machines, and runs a day/night routine (work, eat, rest).
- **Reactions:** flee from raids, cheer at upgrades, morale changes.
- **Memory:** small per-citizen memory of notable events (attacked by kingdom X, fed or hungry, ruler visited) that shifts behaviour, e.g. reluctance or loyalty.
- **Testability:** all of it is deterministic and Lune-testable with an injected clock and RNG.

## 9. Ownership for game-001 (added to `docs/workflows/team.md`)
| Owner | Paths |
|---|---|
| FORGE-01 | `games/game-001/src/shared/Sim/`, `src/shared/Kingdom/`, `src/server/Services/{Match,Kingdom,Citizen,Entity,Building,Construction,Territory,Military,Objective,Diplomacy,Governor,Interaction}*`, `src/client/Controllers/{Ruler,Camera,Entity,Command,Selection,Interaction}*`, config `{Match,Kingdoms,Citizens,Jobs,Buildings,Military,Objectives,Governor}.luau`, `games/game-001/tests/sim/` |
| FORGE-02 | `games/game-001/world/`, `games/game-001/art/`, `src/shared/Kit/` (part-built architecture kit + stand-ins), `src/server/Services/{World,KitBuilder}*`, `blender/**` |
| FORGE-03 | `src/shared/Economy/`, `src/server/Services/{Treasury,Production,Trade,Progression,Shop}*`, `src/client/UI/` (kingdom HUD, build menu, army/objective panels, end-of-match), config `{Resources,Costs,Recipes,Progression,Products,Shop,UITheme}.luau`, `games/game-001/tests/economy/`, `games/game-001/design/ui/` |
| FORGE-04 | `src/shared/Experience/`, `src/server/Services/{Pacing,Announcer,Onboarding,MatchAnalytics}*`, `src/client/Controllers/{Audio,Music,VFX,Feedback,Onboarding,Notification,Announcer}*`, config `{Pacing,Onboarding,Sounds,Analytics}.luau`, `games/game-001/tests/experience/`, `games/game-001/design/pacing/` |
| FORGE-05 | `games/game-001/default.project.json`, `games/game-001/README.md`, `games/game-001/STUDIO_PLAYTEST.md`, game wiring in Loader/harness/place check/CI, `games/game-001/tests/integration/` |
| FORGE-00 | `games/game-001/BRIEF.md`, `games/game-001/CONTRACTS.md` |

## 10. Assets needed for VS-1 (FORGE-02)
- **Architecture kit (part-built):** keep L1/L2, house, farm field + farmhouse, storehouse/granary, lumber camp, quarry, barracks, watchtower, wall segment and gate (VS-2), roads, fences, bridge, construction scaffolding stages (3 per building).
- **Organic (Blender):** oak, pine, birch, bushes, rocks S/M/L, wheat crop stages, logs/stone piles, crates and barrels, banners in 4 colours.
- **Characters:** a citizen look per job (blocky R15-compatible, tinted by kingdom and job, with a tool in hand), a soldier look, and a ruler crown/cape.

## 11. Audio and VFX (FORGE-04)
Chopping, mining, building hammer, coin and resource pickups, construction complete fanfare, horn for raids, capture sting, ambience (birds, river, wind), simple medieval music loops. Sources must be licence-clear.

## 12. Systems map
| Category | Systems |
|---|---|
| Reused framework | Loader/Env, Signal, StateMachine, Validate, RateLimiter, RemoteService/RemoteClient, DataService/PlayerService, Analytics, Settings, Notifications, UI kit, Economy/Inventory (meta) |
| New game systems | Match, Kingdom, Entity sim + replication, Citizen AI, Construction, Territory, Military, Objectives, Treasury, Kit builder/world, Pacing/Announcer |

## 13. Analytics (VS-1)
- **Funnel:** spawn → first gather → first build placed → first building complete → first recruit → first capture.
- **Also logged:** match length, kingdom outcomes, disconnects.

## 14. Performance budget
| Metric | Target |
|---|---|
| Server sim | ≤ 4 ms/frame at 300 entities |
| Client | ≤ 150 rendered entity rigs on screen (LOD/impostors beyond 150 studs) |
| Parts | ≤ 25k in the world at VS-2 |
| Texture memory | Mobile-safe |
| Players | 16 per server (4×4) |

All of these are measured in Studio (G7), not assumed.

## 15. Plan to first playable (parallel; nobody waits idle)
| Hours | FORGE-01 | FORGE-02 | FORGE-03 | FORGE-04 | FORGE-05 |
|---|---|---|---|---|---|
| 0–4 | Kingdom/Match core, entity sim core + snapshot format (pure, Lune) | Art direction + kit builder v0 (keep, house, farm, storehouse) + valley layout v0 | Kingdom HUD + build menu prototypes (HTML) ; Treasury/Costs contracts | Pacing doc + VS-1 onboarding script + sound/VFX list | Merge PR #1, game-001 project + loader/harness/CI support |
| 4–12 | Citizen jobs (farm, wood, stone, haul), storehouse deposits; replication + client rendering | Kit pieces for slice + construction stages; Blender trees/rocks batch 1 + import guide | Treasury + Costs services, HUD + build menu in Luau | Feedback layer (sounds/VFX/notifications) + onboarding controller | Integrate every PR; Studio playtest script VS-1; first `.rbxl` |
| 12–24 | Construction + builders, ruler gathering, barracks/recruit, command + capture objective | Dress kingdom 1 + block out 2–4; ruler/citizen/soldier looks | Army/objective panels, end-of-slice summary | Announcer + objective celebration; analytics funnel | Integration, perf capture, **user playtest** |

## 16. Decisions reserved for the user (do not assume)
1. Monetization model (passes, products, cosmetics, any paid random items) and pricing.
2. PvP intensity between human kingdoms (full raids/sieges vs. PvE-first), and whether betrayal mechanics ship.
3. AI governor difficulty for empty kingdoms, and whether a match can start with fewer than 4 human teams.
4. Victory rules: last keep standing vs. Crown Points at the timer (or both).
5. Cross-match persistence scope (account levels, unlocks, cosmetics only?).
6. Final title and branding.

## 17. Risks
| Risk | Mitigation |
|---|---|
| Entity scale on Roblox servers | D-023 architecture; measure early in Studio |
| Mesh import needs the user | Part-built kit first (D-021) |
| Scope (it is an RTS + city builder + social game) | VS-1 first; every addition must fit the 30–45 min match |
| Studio-only verification | Short, frequent user playtests with scripted checklists |
