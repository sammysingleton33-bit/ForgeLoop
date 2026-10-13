# FORGELOOP-01 — Project status

_Manual sections are maintained by FORGE-00 (last full audit 2026-10-13, D-038). The task tables below are generated._

## Now
- **Game #1: AI Kingdoms** (D-020). Milestone **VS-1**, the user's nine first-playable items (BRIEF §4). The full game stays the target, and builds are inspection checkpoints (D-034).
- **Latest build: B12**, main `21904e4`, delivered 2026-10-13 14:35 UTC. **This is the build to test.** Not yet run in Studio.
  - **New since B11 (#49, FL-0062):**
    - A kingdom announcer: toasts and celebrations for builds, recruits, captures, keep upgrades, phases and the match end, each to the right audience.
    - Construction, recruit and territory effects.
    - Work feedback.
    - Phase music. It stays silent until the P0 sounds are picked.
    - Tests added: #117.
  - **Since B10 (B11):** a captured tower is rebuilt in the capturer's look (#115).
  - **Since B9 (B10):** co-rulers share conversations, stale requests clear, struck carriers deliver (#114), and thrones are for their own rulers (#112).
  - **Since B8 (B9):** kingdom emblems (#105), Talk-close-Talk (#107), the tutorial hints (#99), and keep-upgrade credit (#104).
  - **Not yet:**
    - Nothing is audible until the P0 sounds are picked.
    - The oak leaf is hard to read at full zoom.
    - The throne is hard to see from behind.
    - Dialogue is DRAFT.
    - The other kingdoms are empty by design (D-043).
    - FPS is unknown.
  - The Studio asks are in `production/quality-gates/studio-runs.md` and STUDIO_PLAYTEST §9 (the captured tower look; the end-of-slice celebration with Victory and the summary, O3).
- **Next build: B13.** It follows the first Studio feedback or FORGE-07 merges.
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

## Review queue (FORGE-07 works top-down; under D-040, FORGE-05 gives fallback verdicts on rows marked ★ while FORGE-07 is paused)
Updated 2026-10-13 16:05 UTC, main 20303a4 (CI green).

**Merged under D-040 so far:** #83, #66, #63, #45, #68, #95, #81, #70, #91, #89, #87, #86, #88, #101, #103, #106, #77, #99, #104, #107, #105, #114, #112, #115, #117 and #49. #116 and #120 (CI and test harness, ≤ 50 lines) merged under the D-037 exemption. #109 was merged with FORGE-00's contract approval. FORGE-07 owes a post-merge verdict on each.

**No ★ rows are open.** #115 (with the tower rebuild) merged for B11. Every other known VS-1 defect from B8 and B9 is merged.

| # | PR | Owner | Lane | State | Next |
|---|---|---|---|---|---|
| 1 | #96 SPEC v1.5 presentation tags (FORGE-00) | FORGE-00 | Content | Green and mergeable. It unblocks FORGE-06's starter pack | FORGE-07 |
| 2 | #111 FL-0107 G9 `CitizenAnswered` fired | FORGE-01 | Conversation | Unreviewed | FORGE-07 |
| 3 | #113 FL-0050 remainder: D-045 births, keep-L2 celebration, ruler visit, decision budget | FORGE-01 | Living kingdom | Unreviewed | FORGE-07 |
| 4 | #98 PACING and EXPERIENCE fixes, `idleSec`, `Subjects.missing` | FORGE-04 | Design and docs | FORGE-00 design verdict: APPROVED WITH CHANGES (N1–N3) | FORGE-04 doc edits, then FORGE-07 |
| 5 | #110 economy.md: D-045 births, the 6–8 min slice | FORGE-03 | Design | FORGE-00 design verdict: APPROVED | FORGE-07 |
| 7 | #92 D-038 (7) per-feature files; #82 notification follow-ups | FORGE-04 | Process, feel | Unreviewed | FORGE-07 |
| 8 | #64 analytics funnel | FORGE-04 | Data | M1 and M2 owed; D-044 rulings apply | FORGE-04, then FORGE-07 |
| 9 | #97 late-joiner `Match.Ended`; #93 replication hardening; #94 fair nodes | FORGE-01 | Robustness | Unreviewed | FORGE-07 |
| 10 | #102 pacing probe spec | FORGE-05 | QA | Unreviewed | FORGE-07 |
| 11 | #90 Blender pipeline (PR-A) | FORGE-02 | Assets | FORGE-00 calibration PASS posted | FORGE-07 |
| 12 | #108 FL-0097 conversation hold and EndConversation; #84 conversation camera; #85 Kit.portrait | FORGE-01, FORGE-04, FORGE-02 | Cinematic (D-036) | Unreviewed | FORGE-07 |
| 13 | #119 match-end toast ruling (FORGE-00 on #49); #118 specs actually try nil | FORGE-04, FORGE-01 | Feel, tests | Unreviewed | FORGE-07 |
| — | #100 ruler gather | FORGE-01 | Off the VS-1 path | On hold until VS-1 is accepted | — |
| — | Post-merge verdicts: #42, #75, #76, #79 and every D-040 merge | FORGE-07 | — | Owed | B and M findings become fix-forward PRs |

## Audit 2026-10-13 05:00 UTC snapshot (54 tasks, 12 open PRs; each classification adversarially re-checked; the queue above supersedes it)
- **Open PRs:**
  - 6 never reviewed: #45, #77, #81, #82, #83, #84.
  - 4 reviewed, but not on their current content: #49, #63, #66, #68.
  - 2 with open review findings: #64, #70.
  - 0 ready to merge right now. The new rule needs a FORGE-07 verdict on current content.
- **Need code changes from their authors:**
  - 4 for findings or contract migrations: #70, #64, #68, #77.
  - 3 more only to merge `main` to clear conflicts: #45, #49, #63.
- **Merged but not accepted: 27 tasks.**
  - 6 wait only on the user's Studio run: FL-0003, 0007, 0009, 0046, 0067, 0090.
  - 18 also need a record or a small follow-up first. Those follow-ups are now tracked in FL-0103 to FL-0105 and the review queue.
  - 3 FORGE-00 research and prompt tasks need only an acceptance record: FL-0004, 0005, 0006.
- **21 statuses were stale.** FORGE-00 fixed the ones no open PR touches (FL-0040, 0050, 0051, 0065). The rest are fixed by their PRs or their owners (D-038 (5)).
- **Systemic causes:**
  - The review lane started late.
  - Acceptance records were never written at merge.
  - FORGE-04's shared append-only files make its PRs conflict (D-038 (7)).
  - FORGE-01 carries most of the critical path.
  - Nothing has been run in Studio yet.

## Top integration blockers (VS-1)
1. **No Studio evidence on any build (B1–B8).** Every merged task waits on G6, and frame rate (G7) is unknown. B8 is the first build with all nine VS-1 rows present in some form.
2. **FORGE-07 is paused.** Every open PR now waits on it (rows 1–12, some rows group several PRs). They include #96, which unblocks FORGE-06, #49, which brings sound, and the cinematic lane (#108, #84, #85). Post-merge verdicts are also owed on 19 D-040 merges.
3. **No known open VS-1 defects** after B12 (#114, #112, #115, #49). What remains is Studio-only: feel, FPS and readability.
4. **No sound is audible.** #49 is merged (B12), but the P0 sound picks wait on the user.
5. **Dialogue is DRAFT.** FORGE-06's starter pack waits on #96 and on the user's approval for temporary testing (FL-0095).

## Decisions needed from the user
1. **Run B12 in Studio on your Mac.** It supersedes B6–B11. The asks are in the B8 and B9 rows of `production/quality-gates/studio-runs.md`: Output lines, a conversation's panel and result, `vs1.strike`, zoom-out, the plot-taken check, a full tutorial run, the four-kingdom screenshot, and FPS.
2. **Give FORGE-07 its OK.** Type it in the Forge07 session: "FORGE-07 may post COMMENT reviews and push agents/forge-07/STATUS.md and production/reviews/ to main." A relayed OK is not accepted.
3. **Pick the P0 sounds** (handoff `2026-10-12-forge-04-to-user-sounds.md`) and **upload the icons** `gem.png` and `emblem_crown.png`. Drawn fallbacks are in the game until then.
4. **Approve FORGE-06's starter pack for temporary testing:** 10 conversations, every row DRAFT (D-035 (2)).
5. **Still open:**
   - match length, 25 + 5 or the current schedule (FL-0096);
   - Crown Arena format, victory rules and support strength (FL-0077);
   - approval of the DRAFT dialogue (FL-0095);
   - BRIEF §16 items (monetization, PvP intensity, governor difficulty, title).

<!-- forge:auto:start -->

_Generated by `python tools/forge.py dashboard` from `production/tasks/`. Do not edit by hand._

**Tasks:** 108 — SPECIFIED 27 · READY 23 · BUILDING 6 · REVIEW 38 · ACCEPTED 7 · REJECTED 7

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
| [FL-0050](production/tasks/FL-0050-citizen-ai-and-jobs-farmer-woodcutter-miner-haul.md) | Citizen AI and jobs: farmer, woodcutter, miner, hauler with treasury deposits | BUILDING | P0 | build |
| [FL-0051](production/tasks/FL-0051-buildings-construction-territory-and-ruler-gathe.md) | Buildings, construction, territory and ruler gathering | BUILDING | P0 | build |
| [FL-0052](production/tasks/FL-0052-military-recruit-command-and-capture-objective.md) | Military: recruit, command and capture objective | REVIEW | P0 | build |
| [FL-0078](production/tasks/FL-0078-generated-population-names-traits-looks-relation.md) | Generated population: names, traits, looks, relationships, chemistry, loyalty (G13.2) | REVIEW | P0 | build |
| [FL-0079](production/tasks/FL-0079-conversationservice-thought-bubbles-converse-cho.md) | ConversationService: thought bubbles, Converse/Choose, decision effects and memories (G13.3) | REVIEW | P0 | build |
| [FL-0080](production/tasks/FL-0080-reputationservice-six-categories-history-anti-fa.md) | ReputationService (six categories, history, anti-farming) and kingdom conditions (G13.4) | REVIEW | P0 | build |
| [FL-0081](production/tasks/FL-0081-plot-construction-upgrade-times-and-ruler-seated.md) | Plot construction, upgrade times and ruler seated on the throne (G13.5, G13.6) | REVIEW | P0 | build |
| [FL-0104](production/tasks/FL-0104-vs-1-polish-forge-01-aerial-view-lod-focus-39-m1.md) | VS-1 polish (FORGE-01): aerial-view LOD focus (#39 M1), G13.7 debug hooks, soldier kingdom crest plumbing | REVIEW | P0 | build |
| [FL-0008](production/tasks/FL-0008-dataservice-with-session-locking-and-namespaced-.md) | DataService with session locking and namespaced profiles + PlayerService | READY | P1 | build |
| [FL-0012](production/tasks/FL-0012-server-authoritative-combat-and-damage-framework.md) | Server-authoritative combat and damage framework | SPECIFIED | P1 | build |
| [FL-0069](production/tasks/FL-0069-leadership-ledger-citizen-loyalty-and-key-citize.md) | Leadership ledger, citizen loyalty and key citizens (Crown Arena support inputs) | SPECIFIED | P1 | build |
| [FL-0070](production/tasks/FL-0070-supportmodel-supportservice-trigger-offers-and-f.md) | SupportModel, SupportService, trigger offers and fairness caps | SPECIFIED | P1 | build |
| [FL-0071](production/tasks/FL-0071-crown-arena-phase-and-duel-core-arenaservice-due.md) | Crown Arena phase and duel core (ArenaService, DuelModel, DuelService, AI champion) | SPECIFIED | P1 | build |
| [FL-0082](production/tasks/FL-0082-consequence-rules-strikes-shortages-riots-rebell.md) | Consequence rules: strikes, shortages, riots, rebellion gating, army morale effects | SPECIFIED | P1 | build |
| [FL-0097](production/tasks/FL-0097-cinematic-conversation-server-converse-look-posi.md) | Cinematic conversation server: Converse look/position, conversation hold, EndConversation (G13.8) | SPECIFIED | P1 | build |
| [FL-0106](production/tasks/FL-0106-match-ended-for-players-who-arrive-during-result.md) | Match.Ended for players who arrive during Results (#70 M2) | REVIEW | P1 | build |
| [FL-0107](production/tasks/FL-0107-g9-citizenanswered-event-from-conversationservic.md) | G9 CitizenAnswered event from ConversationService (D-044 (3)) | SPECIFIED | P1 | build |
| [FL-0084](production/tasks/FL-0084-ruler-policy-hook-for-headless-leadership-strate.md) | Ruler policy hook for headless leadership-strategy simulation | SPECIFIED | P2 | build |
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
| [FL-0057](production/tasks/FL-0057-blender-medieval-organic-batch-1-and-import-pack.md) | Blender medieval organic batch 1 and import pack | READY | P1 | asset |
| [FL-0086](production/tasks/FL-0086-new-building-types-part-built-mine-blacksmith-ma.md) | New building types part-built: mine, blacksmith, market, infirmary, granary, shrine | SPECIFIED | P1 | asset |
| [FL-0098](production/tasks/FL-0098-portrait-ready-character-kit-portrait-with-portr.md) | Portrait-ready character: Kit.portrait with PortraitFocus (G13.8) | SPECIFIED | P1 | asset |
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
| [FL-0099](production/tasks/FL-0099-cinematic-conversation-ui-rising-portrait-speech.md) | Cinematic conversation UI: rising portrait, speech bubble, answers, consequence chips (G13.8) | SPECIFIED | P1 | build |
| [FL-0018](production/tasks/FL-0018-economy-core-items-inventory-wallet-reward-table.md) | Economy core: items, inventory, wallet, reward tables with odds and pity | READY | P2 | build |
| [FL-0019](production/tasks/FL-0019-purchaseservice-idempotent-processreceipt-game-p.md) | PurchaseService: idempotent ProcessReceipt, game passes, PolicyService gating | READY | P2 | build |
| [FL-0021](production/tasks/FL-0021-screens-hud-currencies-shop-inventory-reward-rev.md) | Screens: HUD currencies, Shop, Inventory, Reward reveal with odds panel | READY | P2 | build |
| [FL-0022](production/tasks/FL-0022-economy-balance-simulator.md) | Economy balance simulator | SPECIFIED | P2 | build |
| [FL-0045](production/tasks/FL-0045-economy-server-services-economyservice-inventory.md) | Economy server services: EconomyService, InventoryService, RewardService, ShopService | READY | P2 | build |
| [FL-0073](production/tasks/FL-0073-support-meter-perk-previews-petitions-loadout-an.md) | Support meter, perk previews, petitions, loadout and perk picker, arena intro and HUD, leadership recap | READY | P2 | build |

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
| [FL-0023](production/tasks/FL-0023-analyticsservice-adapter-event-taxonomy-and-funn.md) | AnalyticsService adapter, event taxonomy and funnels | REVIEW | P1 | build |
| [FL-0063](production/tasks/FL-0063-vs-1-analytics-funnel-and-match-analytics.md) | VS-1 analytics funnel and match analytics | READY | P1 | build |
| [FL-0092](production/tasks/FL-0092-match30-evaluation-pacing-profile-and-onboarding.md) | match30 evaluation pacing profile and onboarding v2 | REVIEW | P1 | design |
| [FL-0100](production/tasks/FL-0100-conversation-camera-focuson-restore-and-reaction.md) | Conversation camera focusOn/restore and reaction poses (G13.8) | SPECIFIED | P1 | build |
| [FL-0074](production/tasks/FL-0074-crowd-director-chants-and-boos-perk-moments-aren.md) | Crowd director, chants and boos, perk moments, arena camera and music, emotional payoff | READY | P2 | build |
| [FL-0075](production/tasks/FL-0075-duel-input-mode-pc-touch-gamepad-bound-to-duelco.md) | Duel input mode (PC, touch, gamepad) bound to DuelController | READY | P2 | build |
| [FL-0103](production/tasks/FL-0103-settings-panel-audio-reduced-motion-graphics-for.md) | Settings panel: audio, reduced motion, graphics (FORGE-03 components; D-038 (4)) | READY | P2 | build |
| [FL-0108](production/tasks/FL-0108-onboarding-answercitizen-and-conversationanswere.md) | Onboarding AnswerCitizen and ConversationAnswered on G9 CitizenAnswered (D-044 (3)) | SPECIFIED | P2 | build |
| [FL-0026](production/tasks/FL-0026-retention-systems-daily-rewards-streaks-quests-a.md) | Retention systems: daily rewards/streaks, quests and achievements | SPECIFIED | P3 | build |

### FORGE-05 Integration & QA — open

| id | title | status | priority | track |
|---|---|---|---|---|
| [FL-0028](production/tasks/FL-0028-own-the-skeleton-ci-green-on-github-harness-and-.md) | Own the skeleton: CI green on GitHub, harness and mocks upkeep | BUILDING | P0 | qa |
| [FL-0029](production/tasks/FL-0029-pr-review-and-merge-pipeline-with-identifiable-i.md) | PR review and merge pipeline with identifiable integration builds | REVIEW | P0 | qa |
| [FL-0031](production/tasks/FL-0031-studio-test-plan-and-user-smoke-test-pack.md) | Studio test plan and user smoke-test pack | REVIEW | P0 | qa |
| [FL-0046](production/tasks/FL-0046-game-001-project-wiring-rojo-project-game-tree-d.md) | game-001 project wiring: Rojo project, Game-tree discovery, harness, require policy, CI | REVIEW | P0 | infra |
| [FL-0047](production/tasks/FL-0047-vs-1-studio-playtest-script-and-integration-buil.md) | VS-1 Studio playtest script and integration builds | REVIEW | P0 | qa |
| [FL-0067](production/tasks/FL-0067-game-001-wiring-follow-ups-from-the-plan-review-.md) | game-001 wiring follow-ups from the plan review: streaming, character spawn, world mount, buffer-faithful mocks | REVIEW | P0 | infra |
| [FL-0068](production/tasks/FL-0068-studio-debug-panel-playtest-presets-and-playtest.md) | Studio debug panel, playtest presets and Playtest A | BUILDING | P0 | qa |
| [FL-0093](production/tasks/FL-0093-vs-1-v2-integration-build-cadence-to-the-user-pl.md) | VS-1 v2 integration: build cadence to the user, playtest rows 1-9, G13.7 debug presets | BUILDING | P0 | qa |
| [FL-0101](production/tasks/FL-0101-integrate-cinematic-conversations-v1-studio-play.md) | Integrate cinematic conversations v1; Studio playtest rows and build (G13.8) | SPECIFIED | P1 | qa |
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
| [FL-0035](production/tasks/FL-0035-select-game-1-from-the-shortlist.md) | Select Game #1 from the shortlist | ACCEPTED | 2026-10-12 |
| [FL-0038](production/tasks/FL-0038-decide-the-repository-home-for-forgeloop.md) | Decide the repository home for FORGELOOP | ACCEPTED | 2026-10-12 |

### Estimate vs actual (accepted tasks with both recorded)

_No accepted task has an actual time recorded yet._

### Recent commits

```
20303a4e 2026-10-13 Integration bookkeeping: #120 merged (MockEnv EngineStubs); main CI green for #117 and #49
5b9fece3 2026-10-13 [FORGE-05] FL-0046 MockEnv installs EngineStubs (ParticleEmitter:Emit, Sound:Play) once per process; boot spec proves a celebration presents headlessly
53186d89 2026-10-13 [FORGE-00] FL-0061: #98 design re-review APPROVED (088a784)
962984f7 2026-10-13 [FORGE-00] B12 delivered (21904e4): Now, queue, blockers, dashboard
1e84914c 2026-10-13 Integration bookkeeping: #49 merged (D-040 star, FL-0062 feedback layer); FL-0062 REVIEW only G6; STUDIO_PLAYTEST end-of-slice stack check
04a78cdd 2026-10-13 FL-0062: announcer recruit line to co-rulers only; silent-music spec
e524249c 2026-10-13 Merge remote-tracking branch 'origin/main' into forge/04-experience-fl0062
3d3cb82e 2026-10-13 Integration bookkeeping: #117 merged (D-040 star, spec-only #115 L1); main CI green for #115
```

<!-- forge:auto:end -->
