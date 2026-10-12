# Team and ownership

| ID | Role | Owns (writes) | Main consumers of its output |
|---|---|---|---|
| FORGE-00 | Director | `PROJECT_STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, `production/tasks/` (creates/assigns), `agents/*/MISSION.md`, `agents/*/PROMPT.md`, `intelligence/` (until Codex is live), `docs/workflows/`, `docs/research/` | everyone |
| FORGE-01 | Gameplay | `roblox/src/shared/Core/`, `roblox/src/shared/Gameplay/`, `roblox/src/server/Services/{Data,Player,Remote,Round,Spawn,Combat,Hazard}*`, `roblox/src/client/Controllers/{Input,Camera,Movement,Combat,Spectate,Round}*` (client state only; screens are FORGE-03), `roblox/tests/unit/core/`, `roblox/tests/unit/gameplay/`, `roblox/studio-tests/gameplay.md`, `docs/lessons-learned/gameplay.md` | 03, 04, 05 |
| FORGE-02 | Blender | `blender/**`, `roblox/studio-tests/assets.md`, `docs/lessons-learned/blender.md` | 01 (placement), 05 (import), 04 (VFX props) |
| FORGE-03 | UI & Economy | `roblox/src/shared/Economy/`, `roblox/src/server/Services/{Economy,Purchase,Shop,Reward,Inventory}*`, `roblox/src/shared/UI/`, `roblox/src/client/UI/`, `roblox/src/client/Controllers/UIController*`, `roblox/tests/unit/economy/`, `roblox/tests/unit/ui/`, `roblox/studio-tests/ui-economy.md`, `design/ui/`, `docs/lessons-learned/ui-economy.md` | 04 (components), 05 |
| FORGE-04 | Experience | `roblox/src/shared/Experience/`, `roblox/src/server/Services/{Analytics,Onboarding,Quest,DailyReward,Settings}*`, `roblox/src/client/Controllers/{Audio,VFX,Onboarding,Settings,Notification,Quest,DailyReward}*`, `roblox/tests/unit/experience/`, `roblox/studio-tests/experience.md`, `analytics/`, `docs/lessons-learned/experience.md` | 03, 05 |
| FORGE-05 | Integration & QA | `roblox/default.project.json`, `roblox/src/server/Main.server.luau`, `roblox/src/client/Main.client.luau`, `roblox/src/shared/Contracts/` (custodian), `roblox/tests/harness/`, `roblox/tests/mocks/`, `roblox/scripts/`, `roblox/README.md`, `rokit.toml`, `selene.toml`, `stylua.toml`, `.github/workflows/ci.yml`, `.github/pull_request_template.md`, `tools/check_ownership.py` (+ its tests), `roblox/src/shared/Debug/`, `roblox/assets/`, `games/sandbox/` (except per-area config files, see Rules), `production/quality-gates/` (incl. `integration-log.md`), `production/release-checklists/`, `roblox/STUDIO_TEST_PLAN.md`, `docs/lessons-learned/integration.md` | everyone |
| Codex | Intelligence | `intelligence/` (takes over from FORGE-00 once launched), `prompts/`, reviews | FORGE-00 |
| Everyone | Shared | new files in `production/handoffs/` (never edit another agent's handoff); own `agents/<id>/STATUS.md`; status/evidence/Log of tasks they own | — |
| User | Executive | approvals, Studio sessions on Windows, accounts/keys | — |

Rules
- One owner per path; the most specific rule wins (an exact-file pattern beats a directory pattern; otherwise the pattern with more literal path segments wins). A path not listed belongs to FORGE-00 until assigned.
- Task files: FORGE-00 creates tasks (others request them by handoff); the task owner updates status/evidence/Log; FORGE-05 may update status/evidence/Log of any task when recording a merge or acceptance.
- `games/game-00N/` is created by FORGE-00 when a game is approved; its sub-folders are then assigned per the game brief.
- Each worker keeps `agents/<id>/STATUS.md` current: branch, open PR, current task, blockers, last verified check.
- Game config files are owned per area in every `games/<game>/config/` folder: `Rounds`, `Spawns`, `Hazards`, `Combat` → FORGE-01; `Items`, `Currencies`, `RewardTables`, `Products`, `Shop`, `UITheme` → FORGE-03; `Onboarding`, `Quests`, `DailyRewards`, `Sounds`, `Analytics` → FORGE-04; everything else in `games/sandbox/` (map, `Game.luau`, README) → FORGE-05. For `game-00N` the game brief may reassign.
- Studio test steps: each worker writes its own `roblox/studio-tests/<area>.md`; FORGE-05's `roblox/STUDIO_TEST_PLAN.md` links them and runs the smoke tests.
- Cross-area requests: `production/handoffs/YYYY-MM-DD-<from>-to-<to>-<topic>.md`; FORGE-00 turns it into a task for the receiver if it is more than a small fix.

## Why the split works in parallel
- Profile data is namespaced (`core`, `economy`, `experience`, `game`) so no two workers edit one schema.
- Remotes are declared per area (`shared/<Area>/Remotes.luau`) and aggregated by RemoteService, so no shared remote list.
- Services register with the loader by file; adding a service never edits another worker's file.
- UI components (FORGE-03) are consumed by FORGE-04 through the documented component API in `docs/architecture/interfaces.md`.
- FORGE-02 hands assets over through `blender/manifest.json`; gameplay code refers to assets only by asset id.

## game-001 — AI Kingdoms (D-020, D-022)
Game code lives in `games/game-001/` (layout in `games/game-001/CONTRACTS.md` G1). The framework rows above still apply to `roblox/`. Most specific rule wins.

| Owner | game-001 paths |
|---|---|
| FORGE-01 | `games/game-001/src/shared/Sim/`, `src/shared/Kingdom/`, `src/server/Services/{Match,Kingdom,Citizen,Entity,Building,Construction,Territory,Military,Objective,Diplomacy,Governor,Interaction}*`, `src/client/Controllers/{Ruler,Camera,Entity,Command,Selection,Interaction}*`, config `{Match,Kingdoms,Citizens,Jobs,Buildings,Military,Objectives,Governor}.luau`, `games/game-001/tests/sim/` |
| FORGE-02 | `games/game-001/world/`, `games/game-001/art/`, `src/shared/Kit/`, `src/server/Services/{World,KitBuilder}*`, `games/game-001/tests/world/` (plus `blender/**`) |
| FORGE-03 | `src/shared/Economy/`, `src/server/Services/{Treasury,Production,Trade,Progression,Shop}*`, `src/client/UI/`, config `{Resources,Costs,Recipes,Progression,Products,Shop,UITheme}.luau`, `games/game-001/tests/economy/`, `games/game-001/design/ui/`, `games/game-001/design/economy.md` |
| FORGE-04 | `src/shared/Experience/`, `src/server/Services/{Pacing,Announcer,Onboarding,MatchAnalytics}*`, `src/client/Controllers/{Audio,Music,VFX,Feedback,Onboarding,Notification,Announcer}*`, config `{Pacing,Onboarding,Sounds,Analytics}.luau`, `games/game-001/tests/experience/`, `games/game-001/design/pacing/` |
| FORGE-05 | `games/game-001/default.project.json`, `games/game-001/README.md`, `games/game-001/STUDIO_PLAYTEST.md`, `games/game-001/tests/integration/`, game wiring in Loader/harness/place check/CI |
| FORGE-00 | `games/game-001/BRIEF.md`, `games/game-001/CONTRACTS.md` |

(`src/` above means `games/game-001/src/`; config means `games/game-001/config/`.) Remote areas: `Kingdom`, `Sim`, `Build`, `Army` → FORGE-01; `Economy` → FORGE-03; `Match` → FORGE-01; `Experience` → FORGE-04.
