# FORGELOOP-01 — Project status

_Manual sections are maintained by FORGE-00 (last full audit 2026-10-13, D-038). The task tables below are generated._

## Now
- **Game #1: AI Kingdoms** (D-020). Milestone **VS-1**, the user's nine first-playable items (BRIEF §4). The full game stays the target, and builds are inspection checkpoints (D-034).
- **Latest build: B18**, main `f3298dd`, delivered 2026-10-16 00:23 UTC. **This is the build to test.** B14 to B18 have not been run in Studio yet. Checklist: the B14 handoff with its B15 to B18 sections.
  - **New since B17:**
    - Citizens' new look, interim art (D-051): job silhouettes (#138), per-citizen variation (#153), 11-part tools (#155), shoulder pivots so the cheer clears the head (#169).
    - Kingdom consequences: strikes, food shortage, riots with fire, gated rebellion, morale (#125; G13.3/G9 v0.4-g10c).
    - Back key: one press, one step (#162, #164).
    - Conversation presentation tags, server side only (#156).
    - Sim specs in two shards (#171).
  - **Not yet:**
    - FL-0118 art is still D-019 NEEDS-WORK: the pick reads as a hammer; variation and the hauler/idle look need work.
    - Consequence notices and the riot placard (FORGE-04); FORGE-01's `ConsequenceChanged` fire.
    - Wheat and boulders parked (mesh pilot); drag-to-move (FL-0123).
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

**Tasks:** 124 — SPECIFIED 26 · READY 17 · BUILDING 4 · TESTING 1 · REVIEW 60 · ACCEPTED 9 · REJECTED 7

### Needs the user (decisions, approvals, local-machine steps)

| id | title | status | priority |
|---|---|---|---|
| [FL-0034](production/tasks/FL-0034-run-the-windows-project-inventory-script.md) | Run the Windows project inventory script | READY | P0 |
| [FL-0036](production/tasks/FL-0036-studio-smoke-test-of-the-integrated-build.md) | Studio smoke test of the integrated build | SPECIFIED | P0 |
| [FL-0064](production/tasks/FL-0064-user-studio-playtest-of-vs-1.md) | User Studio playtest of VS-1 | SPECIFIED | P0 |
| [FL-0037](production/tasks/FL-0037-launch-codex-with-the-intelligence-mission.md) | Launch Codex with the intelligence mission | READY | P1 |
| [FL-0077](production/tasks/FL-0077-decide-crown-arena-open-points-format-champion-w.md) | Decide Crown Arena open points (format, champion, what the duel decides, support strength) | READY | P1 |
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
| [FL-0008](production/tasks/FL-0008-dataservice-with-session-locking-and-namespaced-.md) | DataService with session locking and namespaced profiles + PlayerService | READY | P1 | build |
| [FL-0012](production/tasks/FL-0012-server-authoritative-combat-and-damage-framework.md) | Server-authoritative combat and damage framework | SPECIFIED | P1 | build |
| [FL-0069](production/tasks/FL-0069-leadership-ledger-citizen-loyalty-and-key-citize.md) | Leadership ledger, citizen loyalty and key citizens (Crown Arena support inputs) | SPECIFIED | P1 | build |
| [FL-0070](production/tasks/FL-0070-supportmodel-supportservice-trigger-offers-and-f.md) | SupportModel, SupportService, trigger offers and fairness caps | SPECIFIED | P1 | build |
| [FL-0071](production/tasks/FL-0071-crown-arena-phase-and-duel-core-arenaservice-due.md) | Crown Arena phase and duel core (ArenaService, DuelModel, DuelService, AI champion) | SPECIFIED | P1 | build |
| [FL-0082](production/tasks/FL-0082-consequence-rules-strikes-shortages-riots-rebell.md) | Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects | REVIEW | P1 | build |
| [FL-0097](production/tasks/FL-0097-cinematic-conversation-server-converse-look-posi.md) | Cinematic conversation server: Converse look/position, conversation hold, EndConversation (G13.8) | REVIEW | P1 | build |
| [FL-0106](production/tasks/FL-0106-match-ended-for-players-who-arrive-during-result.md) | Match.Ended for players who arrive during Results (#70 M2) | REVIEW | P1 | build |
| [FL-0119](production/tasks/FL-0119-base-editing-phase-1-server-build-move.md) | Base editing phase 1, server: Build.CanMove / Move / MoveToSlot, atomic in-place moves (CONTRACTS G13.9, B16) | REVIEW | P1 | build |
| [FL-0122](production/tasks/FL-0122-server-hardening-converse-hold-cap-ruler-presence.md) | Server hardening from FORGE-07's audit — Converse hold cap, ruler presence plausibility, ruler gathering ownership and rate | REVIEW | P1 | build |
| [FL-0084](production/tasks/FL-0084-ruler-policy-hook-for-headless-leadership-strate.md) | Ruler policy hook for headless leadership-strategy simulation | READY | P2 | build |
| [FL-0109](production/tasks/FL-0109-fl-0078-61-review-lows-getentities-size-display-.md) | FL-0078 #61 review lows: GetEntities size, display names, look key, quota revision | REVIEW | P2 | build |
| [FL-0110](production/tasks/FL-0110-converse-choose-carry-spec-v1-5-presentation-tag.md) | Converse/Choose carry SPEC v1.5 presentation tags (G13.8 v0.4-g10) | SPECIFIED | P2 | build |
| [FL-0010](production/tasks/FL-0010-roundservice-with-spawn-spectate-and-results.md) | RoundService with spawn, spectate and results | SPECIFIED | P3 | build |
| [FL-0011](production/tasks/FL-0011-hazardservice-framework-with-a-real-flood-hazard.md) | HazardService framework with a real flood hazard | SPECIFIED | P3 | build |

### FORGE-02 Blender — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0013](production/tasks/FL-0013-blender-pipeline-core-render-rig-export-lod-coll.md) | Blender pipeline core: render rig, export, LOD, collision, validation, manifest | READY | P0 | asset |
| [FL-0054](production/tasks/FL-0054-art-direction-sheet-and-kit-builder-v0-part-buil.md) | Art direction sheet and Kit builder v0 (part-built medieval architecture with construction stages) | READY | P0 | asset |
| [FL-0055](production/tasks/FL-0055-world-layout-v0-and-worldservice-valley-river-fo.md) | World layout v0 and WorldService: valley, river, forests, quarries, roads, 4 kingdom plots, nodes, objective | READY | P0 | asset |
| [FL-0056](production/tasks/FL-0056-characters-citizens-by-job-soldier-ruler-crown-a.md) | Characters: citizens by job, soldier, ruler crown and cape | READY | P0 | asset |
| [FL-0085](production/tasks/FL-0085-throne-seat-build-slots-citizen-look-variation-v.md) | Throne seat, build slots, citizen look variation, visible building levels (G13) | REVIEW | P0 | asset |
| [FL-0124](production/tasks/FL-0124-world-layout-nodes-and-bushes-keep-out-of-farm-fields.md) | World-layout resource nodes and bushes keep out of farm fields and build zones (visual extent) | REVIEW | P0 | asset |
| [FL-0057](production/tasks/FL-0057-blender-medieval-organic-batch-1-and-import-pack.md) | Blender medieval organic batch 1 and import pack | READY | P1 | asset |
| [FL-0086](production/tasks/FL-0086-new-building-types-part-built-mine-blacksmith-ma.md) | New building types part-built: mine, blacksmith, market, infirmary, granary, shrine | READY | P1 | asset |
| [FL-0098](production/tasks/FL-0098-portrait-ready-character-kit-portrait-with-portr.md) | Portrait-ready character: Kit.portrait with PortraitFocus (G13.8) | REVIEW | P1 | asset |
| [FL-0116](production/tasks/FL-0116-world-dressing-trim-to-the-27k-ceiling-d-047.md) | World dressing trim to the D-047 part ceiling (density knob, D-019 renders) | REVIEW | P1 | asset |
| [FL-0117](production/tasks/FL-0117-environment-polish-organic-trees-rocks-nodes.md) | Environment polish: organic trees, rocks, resource nodes and crop rows within the part budget (B15 art where ready) | REVIEW | P1 | asset |
| [FL-0118](production/tasks/FL-0118-citizen-job-silhouettes-clothing-and-tools-d-048.md) | Citizen job silhouettes, clothing and tools readable from the air (D-048 11-part rigs) | REVIEW | P1 | asset |
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
| [FL-0099](production/tasks/FL-0099-cinematic-conversation-ui-rising-portrait-speech.md) | Cinematic conversation UI: rising portrait, speech bubble, answers, consequence chips (G13.8) | REVIEW | P1 | build |
| [FL-0120](production/tasks/FL-0120-base-editing-phase-1-edit-mode-ui.md) | Base editing phase 1, UI: Move button, edit-mode ghost, slot snap with Turn (B16) | REVIEW | P1 | build |
| [FL-0018](production/tasks/FL-0018-economy-core-items-inventory-wallet-reward-table.md) | Economy core: items, inventory, wallet, reward tables with odds and pity | READY | P2 | build |
| [FL-0019](production/tasks/FL-0019-purchaseservice-idempotent-processreceipt-game-p.md) | PurchaseService: idempotent ProcessReceipt, game passes, PolicyService gating | SPECIFIED | P2 | build |
| [FL-0021](production/tasks/FL-0021-screens-hud-currencies-shop-inventory-reward-rev.md) | Screens: HUD currencies, Shop, Inventory, Reward reveal with odds panel | SPECIFIED | P2 | build |
| [FL-0022](production/tasks/FL-0022-economy-balance-simulator.md) | Economy balance simulator | SPECIFIED | P2 | build |
| [FL-0045](production/tasks/FL-0045-economy-server-services-economyservice-inventory.md) | Economy server services: EconomyService, InventoryService, RewardService, ShopService | SPECIFIED | P2 | build |
| [FL-0073](production/tasks/FL-0073-support-meter-perk-previews-petitions-loadout-an.md) | Support meter, perk previews, petitions, loadout and perk picker, arena intro and HUD, leadership recap | SPECIFIED | P2 | build |
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
| [FL-0074](production/tasks/FL-0074-crowd-director-chants-and-boos-perk-moments-aren.md) | Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff | SPECIFIED | P2 | build |
| [FL-0075](production/tasks/FL-0075-duel-input-mode-pc-touch-gamepad-bound-to-duelco.md) | Duel input mode (PC, touch, gamepad) bound to DuelController | SPECIFIED | P2 | build |
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
| [FL-0101](production/tasks/FL-0101-integrate-cinematic-conversations-v1-studio-play.md) | Integrate cinematic conversations v1; Studio playtest rows and build (G13.8) | TESTING | P1 | qa |
| [FL-0032](production/tasks/FL-0032-performance-budgets-mobile-checklist-and-release.md) | Performance budgets, mobile checklist and release checklist | SPECIFIED | P2 | qa |
| [FL-0033](production/tasks/FL-0033-open-cloud-luau-execution-test-runner-feasibilit.md) | Open Cloud Luau Execution test runner feasibility | SPECIFIED | P2 | qa |
| [FL-0076](production/tasks/FL-0076-crown-arena-fairness-harness-caps-spec-and-arena.md) | Crown Arena fairness harness, caps spec and arena integration | BUILDING | P2 | qa |
| [FL-0094](production/tasks/FL-0094-leadership-strategy-balance-harness-tests-balanc.md) | Leadership-strategy balance harness (tests/balance) | SPECIFIED | P2 | qa |

### FORGE-06 Dialogue & Content — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0102](production/tasks/FL-0102-draft-dialogue-starter-pack-and-variants-for-cin.md) | DRAFT dialogue starter pack and variants for cinematic conversations (D-035, D-036) | READY | P1 | design |

### FORGE-07 Review & QA — open

_None._

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
| [FL-0107](production/tasks/FL-0107-g9-citizenanswered-event-from-conversationservic.md) | G9 CitizenAnswered event from ConversationService (D-044 (3)) | ACCEPTED | 2026-10-13 |

### Estimate vs actual (accepted tasks with both recorded)

_No accepted task has an actual time recorded yet._

### Recent commits

```
ff287d08 2026-10-16 integration-log: #173 ConsequenceChanged fire (dd9e356), #174 Waiting fallback removed (4fae7ca)
4fae7cab 2026-10-15 Merge PR #174: [FORGE-03] FL-0088: Waiting drops the walking-view fallback notice (FORGE-05's #168 survivor)
dd9e3567 2026-10-15 Merge PR #173: [FORGE-01] ConsequenceService fires G9 ConsequenceChanged (v0.4-g10c)
ab1cc27e 2026-10-16 Waiting: drop the walking-view notice; FORGE-04's active() (#170) hides the button there
f10fbebe 2026-10-16 integration-log: batch C #170 #168 #167 #165
02ba4d9f 2026-10-15 Merge PR #165: [FORGE-04] FL-0092 onboarding hint targets clear of the no-build areas (FORGE-00's #140 ask)
dbc98a70 2026-10-15 Merge PR #167: [FORGE-01] LayoutZones.spec: FL-0124 moved the world nodes, so the ratchet is strict (no exceptions left)
1c35515c 2026-10-15 Merge PR #168: [FORGE-03] FL-0088 "Waiting" on the rail: citizens with an open request, a tap goes to the next one (+ #162 L1)
```

<!-- forge:auto:end -->
