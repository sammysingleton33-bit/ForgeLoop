# FORGELOOP-01 — Project status

_Manual sections are maintained by FORGE-00 (last full audit 2026-10-13, D-038). The task tables below are generated._

## Now
- **Game #1: AI Kingdoms** (D-020). Milestone **VS-1**, the user's nine first-playable items (BRIEF §4). The full game stays the target, and builds are inspection checkpoints (D-034).
- **Operation Crownfall (D-053, 2026-10-18):** the owner's full-game directive. The default build becomes the real four-kingdom match (FL-0125), then sieges that decide wars (B21, delivered), then the Crown Arena (B22, delivered), then walls, gates and outposts (FL-0126 part 2, after B22; FORGE-00 sequencing 2026-10-19, because FORGE-01 carries both and the arena is the bigger gap), then a release candidate (B23). Missions: `production/handoffs/2026-10-18-forge-00-to-all-operation-crownfall.md`.
- **Latest build: B22.1**, main `4200e40`, delivered 2026-10-22 UTC. **This is the build to test** (it replaces B22). New since B22 (up to gate 8v): the default camera is closer and centred on the yard (zoom 70, FOV 55, pitch 42.5; a citizen is about 6% of screen height, up from 2%; #284); lighting pass 1 (#287); building damage states (#273); duel poses (#269); a live co-ruler vote panel (#275); env phase 3, 56 nature ids (#274; re-import `env_kit.fbx`); and per-controller client start isolation, so a failing controller prints its name in red and the `started` line lists `failed=` (#283). Owner asks (D-059, FL-0144): start with Play (F5), not Run (F8), then report the `failed=` line, any red `Loader:` lines, whether `PlayerGui.KingdomHUD` exists and is Enabled, and whether the match clock shows; plus two screenshots from the default camera. **Known gaps:** the AI champion is still invisible (#271, B22.2); ground, roads, forest clustering and village layout are not done yet (FL-0145, FORGE-02). Not yet run in Studio.
- **Earlier build: B22**, main `e8ea78c`, delivered 2026-10-19 13:10 UTC. It replaced B21.3. New since B21.3 (gates g8h to g8k): **the Crown Arena is playable** (#241, #246 ArenaService and SupportService; #249 DuelController; #255 ring bounds, duel walk speed, re-place after a reset, a seated champion stood up; #254 switches it on); the crowd and arena HUD follow the duel controller, so late joiners see the current stage (#256, #257); no sprinting for champions and a refused block release is retried (#259); style-B nature meshes for trees, rocks, crops and nodes, after the owner imports `env_kit.fbx` (#247); and the Kit no longer writes `MeshPart.CollisionFidelity`, which a game script may not do, so imported mesh citizens and nature props now hold in Play (the import scripts set it; B21.1 to B21.3 would have fallen back to part-built in Play). **Known gaps (found after delivery, B23):** the AI champion has no body (a solo player duels an invisible opponent), loadout gear and venue dress are not shown (FL-0140), champions do not animate (FL-0141), and there is no vote panel (FL-0142). Checklist: the B14 handoff, B22 section (S1–S14). Not in B22: the pose speed bound (B23), the war kit (#260, B22.x), #250. Not yet run in Studio.
- **Earlier build: B21.3**, main `5a74e42`, delivered 2026-10-19 09:25 UTC. It replaced B21.2. New since B21.2 (17 PRs, gate 8): the arena intro camera and music (#231), a How to play panel (#232, #244), full-match tips (#236), siege alerts and the "Siege" label (#235, #243), building drag (#234), the desktop layout pass (#233), and idle-citizen accessories and hair tufts (#242, a new citizen_kit.fbx, so import this kit). Server groundwork that is not yet visible: ArenaFlow, DuelAI, DuelRunner (#223, #224), acts from sim state (#222), the arenaDress fix (#240), petitions and the arena recap (#227, #229, dark). **The Crown Arena is not playable yet** (B22: ArenaService #241, the DuelController, the flag flip). The How to play arena card describes B22. Not yet run in Studio.
- **Earlier build: B21.2**, main `6a738d7`, delivered 2026-10-19 05:20 UTC (replaced B21.1). New since B21.1: the Crown Arena venue, crowd figures, armour and weapons (#217, interim art; the arena is not playable until DuelService), the 170-stud silhouette pass (#226: a new citizen_kit.fbx, so import this kit rather than B21.1's), the support meter (#225, dark), the leadership ledger (#216), the crowd relay (#221) and the fairness gate (#219). Not yet run in Studio. Checklist: the B14 handoff, B15 to B21.2 sections; studio-runs B21.2 asks 1–3.
- **Earlier build: B21.1**, main `ec52722`, delivered 2026-10-19 03:36 UTC (replaced B21). It is B21 plus the real imported-mesh citizen kit data (#220: 113 pieces, 13 assemblies; Blender budgets max citizen 982/1,000, soldiers and governors ≤ 978/1,500; FORGE-07 re-measured), the arena UI (#214, dark until DuelService), SupportModel with trim C (#209), the arena caps fixes (#218) and the phone fit (#215). **Until the owner imports `citizen_kit.fbx` (art/IMPORT_CHARACTERS.md: Asset Privacy first), B21.1 plays like B21.** The mesh look is interim: D-019 NEEDS-WORK for job readability at 170 studs, and FORGE-02 is doing a silhouette pass. Not yet run in Studio. Checklist: the B14 handoff, B15 to B21.1 sections; studio-runs B21.1 asks 1–6.
- **Earlier build: B21**, main `ebdd564`, delivered 2026-10-19 02:08 UTC (replaced B20.2). Not yet run in Studio. Checklist: the B14 handoff, B15 to B21 sections; the B21 asks are in `production/quality-gates/studio-runs.md`.
  - **New since B20.2:** sieges decide wars (#206, FL-0126 part 1): keeps have double hp, soldiers barely scratch buildings, rams (wood 200) do the work, and AI governors build rams and attack as one body. Headless AI-only runs: a kingdom fell in 7 of 8 seeds; a defended keep holds. Also the imported-mesh citizen runtime (#207, #211; D-057), arena core (#208: Types, Caps, DuelModel; server code only), and the Rivals live spec and war-bus spec (#210, #212).
  - **Citizens look the same as B20.2.** The mesh runtime is in, but no mesh data is committed yet (`Kit/CharacterMeshData` is empty on purpose), so every citizen uses the part-built fallback until FORGE-02 ships the kit and the owner does the Studio import (`games/game-001/art/IMPORT_CHARACTERS.md`).
  - Not in B21: #209 (arena SupportModel), #214 (arena UI), #215 (phone fit).
- **Earlier build: B20.2**, main `d03fd70`, delivered 2026-10-19 01:32 UTC (replaced B20.1). It is B20.1 plus the war, siege and raid notices (G9 events live) and the far-entity interest tiers (Sim.Focus), re-landed by #213. FORGE-00 verified both are in with an ancestor check. Not yet run in Studio. Checklist: the B14 handoff, B15 to B20.2 sections.
- **Earlier build: B20.1**, main `2f6dc35`, delivered 2026-10-19 01:20 UTC. B14 to B20.1 have not been run in Studio yet. Checklist: the B14 handoff with its B15 to B20.1 sections.
  - **New since B20:** human war and peace with the senior-ruler and newcomer rules (#195); the spectate screen (#185); arena duel input (#191) and crowd captions (#199); four kingdom architecture styles in the Kit (#200); a two-tine pickaxe on the fallback rig (#197); war, siege and outpost-lost conversation triggers in content (#196).
  - **Not in B20.1, despite the cut note:** the G9 war, siege and raid events (#198) and Sim.Focus with interest tiers (#201). Both were merged into stacked branches, not main, so they are being re-landed for **B20.2**. Until then the war, siege and raid notices stay silent and distant entities aren't tiered.
- **Earlier build: B20**, main `9b688ec`, delivered 2026-10-18 23:45 UTC. B14 to B20 have not been run in Studio yet. Checklist: the B14 handoff with its B15 to B20 sections.
  - **New since B19 (Operation Crownfall):**
    - **The real four-kingdom match by default** (#187, FL-0125): timed phases, AI governors that build, recruit and go to war, elimination with spectating, arena hooks (Crown Points decide until the arena lands), per-kingdom caps of 60 citizens and 15 soldiers.
    - Phase bar, Rivals panel (dormant until B20.1), war notices, timed phase toasts, battle music, hit flashes, deaths, building damage and collapse, raid ping, spectate camera (#178, #180, #182, #183).
    - Studio debug `match.mode slice` restarts in the VS-1 slice, so the older checklists still run.
  - **Not yet:**
    - Human war and peace (#195), the spectate screen (#185) and the Results recap (#192) arrive in B20.1.
    - Interest tiers and Sim.Focus; walls, gates and outposts; the Crown Arena.
    - Keeps rarely fall: 0 in the headless AI-only match (FL-0126 siege viability).
    - Art is interim and the new art is in production (D-057). All sounds silent (the owner's pick list).
    - A co-ruler's build hint may point at a built plot.
    - Sounds, DRAFT dialogue, FPS unknown.
- **Next build: B18:**
  - citizen job art (#138/#153, later #155);
  - riots and consequences (#125);
  - presentation tags (#156 FL-0110, FL-0111);
  - FORGE-02 B12 visuals and FL-0086 building types.
- **Workers:**
  - FORGE-01 gameplay
  - FORGE-02 assets and Kit
  - FORGE-03 UI and economy
  - FORGE-04 experience
  - FORGE-05 integration and builds
  - FORGE-06 dialogue content (D-035)
  - FORGE-07 review and QA (D-037). **It is paused**, waiting for the user's OK in its own session.

  FORGE-00 sets direction and rulings (latest: D-044).
- **Process:**
  - FORGE-07 gives the review verdict. While it is paused, FORGE-05 gives fallback verdicts on ★ rows (D-040).
  - FORGE-05 merges and ships.
  - A merge never makes a task ACCEPTED.
  - The Studio gate G6 is the user's.
  - The flow is in `docs/workflows/git-and-integration.md` → Review lane.

## Review queue (cycle D-046, 2026-10-13 evening; ★ = FORGE-05 D-040 fallback verdict while FORGE-07 is paused)
Updated 18:45 UTC, main 8673907. 19 PRs are open. Apart from FORGE-00's design-only verdicts on #98, #110 and #90, **none of them has a code-review verdict on its current head**. FORGE-07 is set up (D-037) but has been paused since 05:11, waiting for the user's OK in its own session.

**B13 ★ set, in merge order:**

| # | PR | Owner | Why | State |
|---|---|---|---|---|
| 1 ★ | #92 per-feature files (no runtime code) | FORGE-04 | #64, #82, #84, #98 and #119 conflict with it by design | Clean, never reviewed |
| 2 ★ | #119 match-end toast ruling | FORGE-04 | Row 7 polish | Clean |
| 3 ★ | #113 FL-0050 remainder: ruler visit memory and mood, D-045 births, keep-L2 celebration, 100-citizen budget | FORGE-01 | Living citizens (rows 4/4b/6) | Clean |
| 4 ★ | #97 Match.Ended for late joiners (FL-0106) | FORGE-01 | Row 7 | Clean |
| 5 ★ | #111 G9 CitizenAnswered (FL-0107) | FORGE-01 | Unblocks FL-0108 onboarding | Clean |
| 6 ★ | #93 replication hardening (FL-0049 lows) | FORGE-01 | Stability of row 4 | Clean |
| 7 ★ | #122 reputation history text for recruits and post-raid walls (FL-0089 defect) | FORGE-00 | Row 8 visible defect | Clean; ≤ 50 lines, text only |

**B14 ★ set: cinematic conversations, integrated together under FL-0101 (D-046 (2); ★ since FL-0099 is up and FORGE-07 is still paused).** Merge order:
1. #85 Kit.portrait (FORGE-02).
2. #108 server hold and `Kingdom.EndConversation` (FORGE-01). It needs a main merge, and its new client remote needs a G4 review.
3. #84 camera (FORGE-04; frames the face, CONTRACTS v0.4-g9e).
4. #121 reaction poses (FORGE-04).
5. #126 FL-0099 UI (FORGE-03).

One combined gate for all five. If any PR fails review, the whole set waits.

**FORGE-07 queue** (once the user gives the OK):
1. #96 SPEC v1.5 (unblocks FORGE-06).
2. The cinematic set.
3. #98: FORGE-00 design APPROVED; it needs a main merge.
4. #110: FORGE-00 design APPROVED.
5. #64: needs a main merge after #92.
6. #82.
7. #94.
8. #102.
9. #90: owes log lines.
10. #118.
11. Post-merge verdicts on all 25 D-040 merges.

#100 is on hold until VS-1 is accepted.

## Audit 2026-10-13 18:30 UTC (REVIEW tasks, open PRs and the stale-status sweep; every row re-checked by an independent verifier)
- **38 REVIEW tasks:**
  - **25 wait only on the user's Studio run (G6).** All their code is merged, and every other gate is recorded.
  - **7 wait for a code review:** FL-0023, 0025, 0027, 0053, 0058, 0061, 0106.
  - **4 are merged but owe a record:**
    - FL-0024, 0031 and 0089: FORGE-05.
    - FL-0085: FORGE-02 previews and D-019 scoring.
  - **1 had an open item:** FL-0062 (rival sparkle, now deferred by D-046 (3)).
  - **1 waits on the user:** FL-0083 (DRAFT dialogue approval).
- **Stale statuses:** 15 task files did not match reality.
  - **Fixed on main (8673907):** FL-0082, 0084, 0086 → READY; six FORGE-03/04 tasks → SPECIFIED.
  - **Corrected on their PR branches:** FL-0050, 0097, 0107, 0013, 0054–0057, 0098, 0063, 0100. Those files land when the PRs merge (D-038 (5)).
- **Merged under D-040 since this morning:** 25 PRs. No regressions: FORGE-05's 19-set re-run on main 962984f was clean.

## Top integration blockers (VS-1)
1. **No Studio run on any build (B1–B12).** 25 merged tasks wait only on G6, and FPS (G7) is unknown. Run B12 now, or B13 when it lands.
2. **FORGE-07 is paused.** 13 open PRs and 25 post-merge reviews wait on it, among them #96 (it unblocks FORGE-06) and the cinematic set. One message from the user in the Forge07 session unblocks it.
3. **Merge conflicts with main:** #85 (FORGE-02) and #64 and #98 (FORGE-04) need a main merge. #92 must merge before the rest of FORGE-04's PRs.
4. **Cinematic conversations need FL-0099**, FORGE-03's UI (started this cycle), before FORGE-05 can integrate the set.
5. **No audible sound** until the user picks the P0 sounds. Dialogue is DRAFT until FL-0095.

## Decisions needed from the user
1. **Run B13 in Studio** (Windows: F5 Play; the Mac keys are in STUDIO_PLAYTEST §0). The asks are in `production/quality-gates/studio-runs.md`. A Mac section is coming in STUDIO_PLAYTEST.
2. **Give FORGE-07 its OK** in the Forge07 session: "FORGE-07 may post COMMENT reviews and push agents/forge-07/STATUS.md and production/reviews/ to main."
3. **VS-2 start:** may FORGE-01 begin the combat framework (FL-0012, §16.2) in parallel, before VS-1 is accepted? (D-046 (4))
4. **Pick the P0 sounds** and upload `gem.png` and `emblem_crown.png`. Approve FORGE-06's DRAFT starter pack for temporary testing.
5. **Still open:** match length (FL-0096), Crown Arena (FL-0077), dialogue approval (FL-0095), and the BRIEF §16 items.

<!-- forge:auto:start -->

_Generated by `python tools/forge.py dashboard` from `production/tasks/`. Do not edit by hand._

**Tasks:** 136 — SPECIFIED 19 · READY 22 · BUILDING 10 · TESTING 1 · REVIEW 64 · ACCEPTED 10 · REJECTED 10

### Needs the user (decisions, approvals, local-machine steps)

| id | title | status | priority |
|---|---|---|---|
| [FL-0034](production/tasks/FL-0034-run-the-windows-project-inventory-script.md) | Run the Windows project inventory script | READY | P0 |
| [FL-0036](production/tasks/FL-0036-studio-smoke-test-of-the-integrated-build.md) | Studio smoke test of the integrated build | SPECIFIED | P0 |
| [FL-0064](production/tasks/FL-0064-user-studio-playtest-of-vs-1.md) | User Studio playtest of VS-1 | SPECIFIED | P0 |
| [FL-0037](production/tasks/FL-0037-launch-codex-with-the-intelligence-mission.md) | Launch Codex with the intelligence mission | READY | P1 |
| [FL-0095](production/tasks/FL-0095-review-and-edit-the-draft-dialogue-library-suppl.md) | Review and edit the DRAFT dialogue library; supply the 16-archetype files | READY | P1 |
| [FL-0096](production/tasks/FL-0096-decide-match-length-about-30-min-vs-current-afte.md) | Decide match length (about 30 min vs current) after a match30 playtest | READY | P1 |
| [FL-0039](production/tasks/FL-0039-create-a-roblox-open-cloud-api-key-later.md) | Create a Roblox Open Cloud API key (later) | SPECIFIED | P2 |

### Blocked

_None._

### FORGE-00 Director — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0003](production/tasks/FL-0003-shared-roblox-skeleton-contracts-loader-harness-.md) | Shared Roblox skeleton: contracts, loader, harness, mocks, checks, CI | REVIEW | P0 | infra |
| [FL-0083](production/tasks/FL-0083-content-library-editable-csv-spreadsheet-round-t.md) | Content library: editable CSV, spreadsheet round-trip, generated Content modules, ContentQuery, DRAFT starter content | REVIEW | P0 | design |

### FORGE-01 Gameplay — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0007](production/tasks/FL-0007-core-utilities-validate-ratelimiter-statemachine.md) | Core utilities: Validate, RateLimiter, StateMachine, Trove, RemoteClient | REVIEW | P0 | build |
| [FL-0009](production/tasks/FL-0009-remoteservice-declarative-per-area-remotes-with-.md) | RemoteService: declarative per-area remotes with validation and rate limits | REVIEW | P0 | build |
| [FL-0048](production/tasks/FL-0048-match-and-kingdom-core-phases-kingdom-assignment.md) | Match and Kingdom core: phases, kingdom assignment, teams, crown points | REVIEW | P0 | build |
| [FL-0049](production/tasks/FL-0049-entity-simulation-core-snapshot-codec-replicatio.md) | Entity simulation core, snapshot codec, replication and client rendering | REVIEW | P0 | build |
| [FL-0050](production/tasks/FL-0050-citizen-ai-and-jobs-farmer-woodcutter-miner-haul.md) | Citizen AI and jobs: farmer, woodcutter, miner, hauler with treasury deposits | REVIEW | P0 | build |
| [FL-0051](production/tasks/FL-0051-buildings-construction-territory-and-ruler-gathe.md) | Buildings, construction, territory and ruler gathering | BUILDING | P0 | build |
| [FL-0052](production/tasks/FL-0052-military-recruit-command-and-capture-objective.md) | Military: recruit, command and capture objective | REVIEW | P0 | build |
| [FL-0078](production/tasks/FL-0078-generated-population-names-traits-looks-relation.md) | Generated population: names, traits, looks, relationships, chemistry, loyalty (G13.2) | REVIEW | P0 | build |
| [FL-0079](production/tasks/FL-0079-conversationservice-thought-bubbles-converse-cho.md) | ConversationService: thought bubbles, Converse/Choose, decision effects and memories (G13.3) | REVIEW | P0 | build |
| [FL-0080](production/tasks/FL-0080-reputationservice-six-categories-history-anti-fa.md) | ReputationService (six categories, history, anti-farming) and kingdom conditions (G13.4) | REVIEW | P0 | build |
| [FL-0081](production/tasks/FL-0081-plot-construction-upgrade-times-and-ruler-seated.md) | Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6) | REVIEW | P0 | build |
| [FL-0104](production/tasks/FL-0104-vs-1-polish-forge-01-aerial-view-lod-focus-39-m1.md) | VS-1 polish (FORGE-01): aerial-view LOD focus (#39 M1), G13.7 debug hooks, soldier kingdom crest plumbing | REVIEW | P0 | build |
| [FL-0112](production/tasks/FL-0112-starting-kingdom-cleanup-nodes-out-of-crop-field.md) | Starting kingdom cleanup: generated trees and rocks keep out of crop fields and build zones (B15 #1) | REVIEW | P0 | build |
| [FL-0113](production/tasks/FL-0113-build-placeslot-turn-server-and-fit-g9h.md) | Build.PlaceSlot turn: rotate buildings on plots, server and Fit (CONTRACTS v0.4-g9h, B15 #2) | REVIEW | P0 | build |
| [FL-0125](production/tasks/FL-0125-full-match-by-default.md) | Full four-kingdom match by default: match mode, PvP from Conflict, active AI governors, elimination and spectate (D-053 (1)-(3)) | REVIEW | P0 | build |
| [FL-0008](production/tasks/FL-0008-dataservice-with-session-locking-and-namespaced-.md) | DataService with session locking and namespaced profiles + PlayerService | READY | P1 | build |
| [FL-0012](production/tasks/FL-0012-server-authoritative-combat-and-damage-framework.md) | Server-authoritative combat and damage framework | SPECIFIED | P1 | build |
| [FL-0069](production/tasks/FL-0069-leadership-ledger-citizen-loyalty-and-key-citize.md) | Leadership ledger, citizen loyalty and key citizens (Crown Arena support inputs) | READY | P1 | build |
| [FL-0070](production/tasks/FL-0070-supportmodel-supportservice-trigger-offers-and-f.md) | SupportModel, SupportService, trigger offers and fairness caps | READY | P1 | build |
| [FL-0071](production/tasks/FL-0071-crown-arena-phase-and-duel-core-arenaservice-due.md) | Crown Arena phase and duel core (ArenaService, DuelModel, DuelService, AI champion) | READY | P1 | build |
| [FL-0082](production/tasks/FL-0082-consequence-rules-strikes-shortages-riots-rebell.md) | Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects | REVIEW | P1 | build |
| [FL-0097](production/tasks/FL-0097-cinematic-conversation-server-converse-look-posi.md) | Cinematic conversation server: Converse look/position, conversation hold, EndConversation (G13.8) | REVIEW | P1 | build |
| [FL-0106](production/tasks/FL-0106-match-ended-for-players-who-arrive-during-result.md) | Match.Ended for players who arrive during Results (#70 M2) | REVIEW | P1 | build |
| [FL-0119](production/tasks/FL-0119-base-editing-phase-1-server-build-move.md) | Base editing phase 1, server: Build.CanMove / Move / MoveToSlot, atomic in-place moves (CONTRACTS G13.9, B16) | REVIEW | P1 | build |
| [FL-0122](production/tasks/FL-0122-server-hardening-converse-hold-cap-ruler-presence.md) | Server hardening from FORGE-07's audit — Converse hold cap, ruler presence plausibility, ruler gathering ownership and rate | REVIEW | P1 | build |
| [FL-0126](production/tasks/FL-0126-walls-gates-outposts.md) | Walls, gates and towers on territory lines (Build.PlaceLine), plus three neutral outposts that grant territory | READY | P1 | build |
| [FL-0134](production/tasks/FL-0134-war-events-and-conversation-triggers.md) | Fire G9 WarChanged, SiegeChanged and RaidChanged, and raise the matching conversation triggers (war, siege, raid, strike, riot, objective lost) | READY | P1 | build |
| [FL-0084](production/tasks/FL-0084-ruler-policy-hook-for-headless-leadership-strate.md) | Ruler policy hook for headless leadership-strategy simulation | READY | P2 | build |
| [FL-0109](production/tasks/FL-0109-fl-0078-61-review-lows-getentities-size-display-.md) | FL-0078 #61 review lows: GetEntities size, display names, look key, quota revision | REVIEW | P2 | build |
| [FL-0110](production/tasks/FL-0110-converse-choose-carry-spec-v1-5-presentation-tag.md) | Converse/Choose carry SPEC v1.5 presentation tags (G13.8 v0.4-g10) | SPECIFIED | P2 | build |
| [FL-0011](production/tasks/FL-0011-hazardservice-framework-with-a-real-flood-hazard.md) | HazardService framework with a real flood hazard | SPECIFIED | P3 | build |

### FORGE-02 Blender — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0013](production/tasks/FL-0013-blender-pipeline-core-render-rig-export-lod-coll.md) | Blender pipeline core: render rig, export, LOD, collision, validation, manifest | REVIEW | P0 | asset |
| [FL-0054](production/tasks/FL-0054-art-direction-sheet-and-kit-builder-v0-part-buil.md) | Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages) | REVIEW | P0 | asset |
| [FL-0055](production/tasks/FL-0055-world-layout-v0-and-worldservice-valley-river-fo.md) | World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective | REVIEW | P0 | asset |
| [FL-0056](production/tasks/FL-0056-characters-citizens-by-job-soldier-ruler-crown-a.md) | Characters: citizens by job, soldier, ruler crown and cape | REVIEW | P0 | asset |
| [FL-0085](production/tasks/FL-0085-throne-seat-build-slots-citizen-look-variation-v.md) | Throne seat, build slots, citizen look variation, visible building levels (G13) | REVIEW | P0 | asset |
| [FL-0124](production/tasks/FL-0124-world-layout-nodes-and-bushes-keep-out-of-farm-fields.md) | World-layout resource nodes and bushes keep out of farm fields and build zones (visual extent) | REVIEW | P0 | asset |
| [FL-0135](production/tasks/FL-0135-citizen-visual-upgrade-licensed-assets.md) | Citizen and ruler visual upgrade with licensed prebuilt assets: faces, hair, clothing, job identities, rulers, variation (D-057) | READY | P0 | asset |
| [FL-0057](production/tasks/FL-0057-blender-medieval-organic-batch-1-and-import-pack.md) | Blender medieval organic batch 1 and import pack | BUILDING | P1 | asset |
| [FL-0086](production/tasks/FL-0086-new-building-types-part-built-mine-blacksmith-ma.md) | New building types part-built: mine, blacksmith, market, infirmary, granary, shrine | READY | P1 | asset |
| [FL-0098](production/tasks/FL-0098-portrait-ready-character-kit-portrait-with-portr.md) | Portrait-ready character: Kit.portrait with PortraitFocus (G13.8) | REVIEW | P1 | asset |
| [FL-0116](production/tasks/FL-0116-world-dressing-trim-to-the-27k-ceiling-d-047.md) | World dressing trim to the D-047 part ceiling (density knob, D-019 renders) | REVIEW | P1 | asset |
| [FL-0127](production/tasks/FL-0127-four-distinct-kingdoms.md) | Four distinct, fully dressed kingdoms: architecture, emblems and surroundings per kingdom (VS-2 row 1) | BUILDING | P1 | asset |
| [FL-0128](production/tasks/FL-0128-war-kit-and-damage-states.md) | War kit: wall, gate and tower levels, siege ram, kingdom soldier variants and weapons, damaged and burning building states | READY | P1 | asset |
| [FL-0136](production/tasks/FL-0136-environment-architecture-visual-upgrade.md) | Environment and architecture visual upgrade with licensed assets: farms and crops, trees, rocks, markets, walls, castles, props, kingdom identity (D-057) | READY | P1 | asset |
| [FL-0017](production/tasks/FL-0017-ci-job-that-builds-asset-exports-as-a-downloadab.md) | CI job that builds asset exports as a downloadable artifact | SPECIFIED | P2 | asset |
| [FL-0066](production/tasks/FL-0066-animation-upload-batch-for-vs-2-keyframesequence.md) | Animation upload batch for VS-2 (KeyframeSequence files, user publishes) | SPECIFIED | P2 | asset |
| [FL-0072](production/tasks/FL-0072-crown-arena-venue-crowd-figures-armour-and-weapo.md) | Crown Arena venue, crowd figures, armour and weapon sets (Kit) | READY | P2 | asset |

### FORGE-03 UI & Economy — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0020](production/tasks/FL-0020-ui-foundation-builder-theme-tokens-component-lib.md) | UI foundation: builder, theme tokens, component library, responsive rules | REVIEW | P0 | build |
| [FL-0058](production/tasks/FL-0058-kingdom-treasury-costs-catalogue-and-upkeep-trea.md) | Kingdom treasury, costs catalogue and upkeep (Treasury, Costs, Production) | REVIEW | P0 | build |
| [FL-0059](production/tasks/FL-0059-kingdom-hud-and-build-menu-prototype-then-luau.md) | Kingdom HUD and build menu (prototype then Luau) | REVIEW | P0 | build |
| [FL-0060](production/tasks/FL-0060-army-and-objective-panels-end-of-slice-summary.md) | Army and objective panels, end-of-slice summary | REVIEW | P0 | build |
| [FL-0065](production/tasks/FL-0065-citizen-card-and-job-panel-vs-1-row-4b.md) | Citizen card and job panel (VS-1 row 4b) | REVIEW | P0 | build |
| [FL-0087](production/tasks/FL-0087-plot-picker-slot-build-menu-and-upgrade-panel-g1.md) | Plot picker, slot build menu and upgrade panel (G13.5) | REVIEW | P0 | build |
| [FL-0088](production/tasks/FL-0088-conversation-panel-and-citizen-card-v2-g13-2-g13.md) | Conversation panel and citizen card v2 (G13.2, G13.3) | REVIEW | P0 | build |
| [FL-0089](production/tasks/FL-0089-reputation-screen-hud-reputation-strip-and-kingd.md) | Reputation screen, HUD reputation strip and kingdom conditions (G13.4) | REVIEW | P0 | build |
| [FL-0105](production/tasks/FL-0105-vs-1-polish-forge-03-map-every-server-refusal-co.md) | VS-1 polish (FORGE-03): map every server refusal code, dark emblem on light tinctures, Toast achievement accent | REVIEW | P0 | build |
| [FL-0114](production/tasks/FL-0114-rotation-ui-ghost-facing-and-plot-picker-turn.md) | Rotation UI: ghost facing arrow, discoverable Rotate, plot picker Turn (B15 #2) | REVIEW | P0 | build |
| [FL-0129](production/tasks/FL-0129-full-match-hud-war-results.md) | Full-match UI: phase and timer bar, war and peace panel, spectate screen, Results with the leadership recap, wall placement UI | BUILDING | P0 | build |
| [FL-0099](production/tasks/FL-0099-cinematic-conversation-ui-rising-portrait-speech.md) | Cinematic conversation UI: rising portrait, speech bubble, answers, consequence chips (G13.8) | REVIEW | P1 | build |
| [FL-0120](production/tasks/FL-0120-base-editing-phase-1-edit-mode-ui.md) | Base editing phase 1, UI: Move button, edit-mode ghost, slot snap with Turn (B16) | REVIEW | P1 | build |
| [FL-0018](production/tasks/FL-0018-economy-core-items-inventory-wallet-reward-table.md) | Economy core: items, inventory, wallet, reward tables with odds and pity | READY | P2 | build |
| [FL-0019](production/tasks/FL-0019-purchaseservice-idempotent-processreceipt-game-p.md) | PurchaseService: idempotent ProcessReceipt, game passes, PolicyService gating | SPECIFIED | P2 | build |
| [FL-0021](production/tasks/FL-0021-screens-hud-currencies-shop-inventory-reward-rev.md) | Screens: HUD currencies, Shop, Inventory, Reward reveal with odds panel | SPECIFIED | P2 | build |
| [FL-0022](production/tasks/FL-0022-economy-balance-simulator.md) | Economy balance simulator | SPECIFIED | P2 | build |
| [FL-0045](production/tasks/FL-0045-economy-server-services-economyservice-inventory.md) | Economy server services: EconomyService, InventoryService, RewardService, ShopService | SPECIFIED | P2 | build |
| [FL-0073](production/tasks/FL-0073-support-meter-perk-previews-petitions-loadout-an.md) | Support meter, perk previews, petitions, loadout and perk picker, arena intro and HUD, leadership recap | READY | P2 | build |
| [FL-0111](production/tasks/FL-0111-cinematic-conversation-ui-styles-from-presentati.md) | Cinematic conversation UI styles from presentation tags (G13.8 v0.4-g10) | SPECIFIED | P2 | build |
| [FL-0123](production/tasks/FL-0123-base-editing-drag-gesture-and-edit-drag-camera.md) | Base editing, drag gesture: press-and-drag a building with edge-pan (setEditDrag), on top of the Move flow | SPECIFIED | P2 | build |

### FORGE-04 Experience — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0024](production/tasks/FL-0024-settings-audio-and-vfx-foundation.md) | Settings, audio and VFX foundation | REVIEW | P0 | build |
| [FL-0025](production/tasks/FL-0025-onboarding-and-tutorial-framework.md) | Onboarding and tutorial framework | REVIEW | P0 | build |
| [FL-0027](production/tasks/FL-0027-notifications-and-celebration-moments.md) | Notifications and celebration moments | REVIEW | P0 | build |
| [FL-0053](production/tasks/FL-0053-ruler-third-person-controller-and-camera.md) | Ruler third-person controller, camera and input modes | REVIEW | P0 | build |
| [FL-0061](production/tasks/FL-0061-match-pacing-design-and-pacingservice.md) | Match pacing design and PacingService | REVIEW | P0 | design |
| [FL-0062](production/tasks/FL-0062-vs-1-onboarding-and-feedback-layer-hints-sounds-.md) | VS-1 onboarding and feedback layer: hints, sounds, VFX, announcer | REVIEW | P0 | build |
| [FL-0090](production/tasks/FL-0090-aerial-management-camera-default-selection-signa.md) | Aerial management camera (overview, default), selection signal, walk mode kept (G13.6) | REVIEW | P0 | build |
| [FL-0091](production/tasks/FL-0091-citizen-thought-and-speech-bubbles-reactions-str.md) | Citizen thought and speech bubbles, reactions, strike placards, consequence cues (G13.3) | REVIEW | P0 | build |
| [FL-0115](production/tasks/FL-0115-citizen-bubble-readability-from-the-aerial-camer.md) | Citizen bubbles readable and tappable from the aerial camera (B15 #3; FL-0091 follow-up) | REVIEW | P0 | build |
| [FL-0023](production/tasks/FL-0023-analyticsservice-adapter-event-taxonomy-and-funn.md) | AnalyticsService adapter, event taxonomy and funnels | REVIEW | P1 | build |
| [FL-0063](production/tasks/FL-0063-vs-1-analytics-funnel-and-match-analytics.md) | VS-1 analytics funnel and match analytics | REVIEW | P1 | build |
| [FL-0092](production/tasks/FL-0092-match30-evaluation-pacing-profile-and-onboarding.md) | match30 evaluation pacing profile and onboarding v2 | REVIEW | P1 | design |
| [FL-0100](production/tasks/FL-0100-conversation-camera-focuson-restore-and-reaction.md) | Conversation camera focusOn/restore and reaction poses (G13.8) | REVIEW | P1 | build |
| [FL-0121](production/tasks/FL-0121-base-editing-phase-1-edit-input-mode-and-camera.md) | Base editing phase 1, input and camera: "edit" input mode and edit-drag camera (B16) | REVIEW | P1 | build |
| [FL-0130](production/tasks/FL-0130-war-feedback-and-spectate-camera.md) | War feedback: hits, deaths, building damage and collapse, raid alarm, war and siege announcer moments, spectate camera | BUILDING | P1 | build |
| [FL-0074](production/tasks/FL-0074-crowd-director-chants-and-boos-perk-moments-aren.md) | Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff | BUILDING | P2 | build |
| [FL-0075](production/tasks/FL-0075-duel-input-mode-pc-touch-gamepad-bound-to-duelco.md) | Duel input mode (PC, touch, gamepad) bound to DuelController | REVIEW | P2 | build |
| [FL-0103](production/tasks/FL-0103-settings-panel-audio-reduced-motion-graphics-for.md) | Settings panel: audio, reduced motion, graphics (FORGE-03 components; D-038 (4)) | REVIEW | P2 | build |
| [FL-0108](production/tasks/FL-0108-onboarding-answercitizen-and-conversationanswere.md) | Onboarding AnswerCitizen and ConversationAnswered on G9 CitizenAnswered (D-044 (3)) | REVIEW | P2 | build |
| [FL-0026](production/tasks/FL-0026-retention-systems-daily-rewards-streaks-quests-a.md) | Retention systems: daily rewards/streaks, quests and achievements | SPECIFIED | P3 | build |

### FORGE-05 Integration & QA — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0029](production/tasks/FL-0029-pr-review-and-merge-pipeline-with-identifiable-i.md) | PR review and merge pipeline with identifiable integration builds | REVIEW | P0 | qa |
| [FL-0031](production/tasks/FL-0031-studio-test-plan-and-user-smoke-test-pack.md) | Studio test plan and user smoke-test pack | REVIEW | P0 | qa |
| [FL-0046](production/tasks/FL-0046-game-001-project-wiring-rojo-project-game-tree-d.md) | game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI | REVIEW | P0 | infra |
| [FL-0047](production/tasks/FL-0047-vs-1-studio-playtest-script-and-integration-buil.md) | VS-1 Studio playtest script and integration builds | REVIEW | P0 | qa |
| [FL-0067](production/tasks/FL-0067-game-001-wiring-follow-ups-from-the-plan-review-.md) | game-001 wiring follow-ups from the plan review: streaming, character spawn, world mount, buffer-faithful mocks | REVIEW | P0 | infra |
| [FL-0068](production/tasks/FL-0068-studio-debug-panel-playtest-presets-and-playtest.md) | Studio debug panel, playtest presets and Playtest A | BUILDING | P0 | qa |
| [FL-0093](production/tasks/FL-0093-vs-1-v2-integration-build-cadence-to-the-user-pl.md) | VS-1 v2 integration: build cadence to the user, playtest rows 1-9, G13.7 debug presets | BUILDING | P0 | qa |
| [FL-0131](production/tasks/FL-0131-b20-full-match-integration.md) | B20 full-match integration build, gates and Studio rows; release-candidate checklist started | BUILDING | P0 | qa |
| [FL-0101](production/tasks/FL-0101-integrate-cinematic-conversations-v1-studio-play.md) | Integrate cinematic conversations v1; Studio playtest rows and build (G13.8) | TESTING | P1 | qa |
| [FL-0032](production/tasks/FL-0032-performance-budgets-mobile-checklist-and-release.md) | Performance budgets, mobile checklist and release checklist | SPECIFIED | P2 | qa |
| [FL-0033](production/tasks/FL-0033-open-cloud-luau-execution-test-runner-feasibilit.md) | Open Cloud Luau Execution test runner feasibility | SPECIFIED | P2 | qa |
| [FL-0076](production/tasks/FL-0076-crown-arena-fairness-harness-caps-spec-and-arena.md) | Crown Arena fairness harness, caps spec and arena integration | BUILDING | P2 | qa |
| [FL-0094](production/tasks/FL-0094-leadership-strategy-balance-harness-tests-balanc.md) | Leadership-strategy balance harness (tests/balance) | SPECIFIED | P2 | qa |

### FORGE-06 Dialogue & Content — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0102](production/tasks/FL-0102-draft-dialogue-starter-pack-and-variants-for-cin.md) | DRAFT dialogue starter pack and variants for cinematic conversations (D-035, D-036) | READY | P1 | design |
| [FL-0133](production/tasks/FL-0133-vs2-dialogue-drafts.md) | DRAFT VS-2 dialogue: war, raid, siege, famine, arena petitions and key-citizen pledge lines (isolated until the owner approves) | READY | P2 | design |

### FORGE-07 Review & QA — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0132](production/tasks/FL-0132-review-full-match-surface.md) | Independent review: full-match mode, war/diplomacy/army remotes, walls and outposts, arena remotes (exploits, authority, performance) | READY | P1 | qa |

### Codex (intelligence) — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0041](production/tasks/FL-0041-coordination-round-trip-test-codex-to-claude-via.md) | Coordination round-trip test: Codex to Claude via the repository | READY | P1 | coordination |
| [FL-0042](production/tasks/FL-0042-evaluate-worker-prompts-after-the-first-sprint-a.md) | Evaluate worker prompts after the first sprint and propose v2 | SPECIFIED | P2 | research |

### Accepted / reusable

| id | title | status | updated |
|---|---|---|---|
| [FL-0001](production/tasks/FL-0001-shared-operating-contract-and-task-tooling.md) | Shared operating contract and task tooling | ACCEPTED | 2026-10-12 |
| [FL-0002](production/tasks/FL-0002-cloud-environment-audit-and-toolchain.md) | Cloud environment audit and toolchain | ACCEPTED | 2026-10-12 |
| [FL-0004](production/tasks/FL-0004-platform-constraints-and-ai-provider-research.md) | Platform constraints and AI provider research | ACCEPTED | 2026-10-13 |
| [FL-0005](production/tasks/FL-0005-roblox-market-research-and-game-1-shortlist.md) | Roblox market research and Game #1 shortlist | ACCEPTED | 2026-10-13 |
| [FL-0006](production/tasks/FL-0006-worker-startup-prompts-for-forge-01-05.md) | Worker startup prompts for FORGE-01..05 | ACCEPTED | 2026-10-13 |
| [FL-0028](production/tasks/FL-0028-own-the-skeleton-ci-green-on-github-harness-and-.md) | Own the skeleton: CI green on GitHub, harness and mocks upkeep | ACCEPTED | 2026-10-13 |
| [FL-0035](production/tasks/FL-0035-select-game-1-from-the-shortlist.md) | Select Game #1 from the shortlist | ACCEPTED | 2026-10-12 |
| [FL-0038](production/tasks/FL-0038-decide-the-repository-home-for-forgeloop.md) | Decide the repository home for FORGELOOP | ACCEPTED | 2026-10-12 |
| [FL-0077](production/tasks/FL-0077-decide-crown-arena-open-points-format-champion-w.md) | Decide Crown Arena open points (format, champion, what the duel decides, support strength) | ACCEPTED | 2026-10-18 |
| [FL-0107](production/tasks/FL-0107-g9-citizenanswered-event-from-conversationservic.md) | G9 CitizenAnswered event from ConversationService (D-044 (3)) | ACCEPTED | 2026-10-13 |

### Estimate vs actual (accepted tasks with both recorded)

_No accepted task has an actual time recorded yet._

### Recent commits

```
e60b4a9e 2026-10-19 studio-runs: B20.2 = d03fd70 (B20.1 + #213 war events and interest tiers, ancestor-checked); integration-log #213
d03fd70f 2026-10-18 Merge PR #213: [FORGE-01] re-land #198 + #201 into main (war events, Sim.Focus interest tiers)
742ae19d 2026-10-18 FORGE-07 STATUS 01:30 UTC: B20.1 merged (cut 2f6dc35); #206 READY; #207 red on StyLua (one file); #210, #211 reviewed
47da3f27 2026-10-19 B20.1 correction: #198 and #201 merged into stacked bases, not main; studio-runs row, integration-log, merge-checklist base and ancestor checks, lesson
d35bac15 2026-10-19 [FORGE-00] B20.1 delivered (2f6dc35): Now (with the #198/#201 stacked-merge gap), checklist rows M1-M5
e7759498 2026-10-19 studio-runs: B20.1 = 2f6dc35 (human war/peace, war notices, spectate screen, interest tiers) + asks; integration-log #199
2f6dc35b 2026-10-18 Merge PR #199: [FORGE-04] FL-0074 part 2a: the arena crowd you hear and read
cd1aae31 2026-10-19 integration-log: B20.1 batch 2 (#191 #197 #202 #195 #198 #201 #185 #196 #203 #205 #204 #200)
```

<!-- forge:auto:end -->
