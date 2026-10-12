# Team and ownership

| ID | Role | Owns (writes) | Main consumers of its output |
|---|---|---|---|
| FORGE-00 | Director | `PROJECT_STATUS.md`, `ROADMAP.md`, `DECISIONS.md`, `production/tasks/` (creates/assigns), `agents/*/MISSION.md`, `agents/*/PROMPT.md`, `intelligence/` (until Codex is live), `docs/workflows/`, `docs/research/` | everyone |
| FORGE-01 | Gameplay | `roblox/src/shared/Core/`, `roblox/src/shared/Gameplay/`, `roblox/src/server/Services/{Data,Player,Remote,Round,Spawn,Combat,Hazard}*`, `roblox/src/client/Controllers/{Input,Camera,Movement,Combat,Spectate}*`, `roblox/tests/unit/core/`, `roblox/tests/unit/gameplay/`, `docs/lessons-learned/gameplay.md` | 03, 04, 05 |
| FORGE-02 | Blender | `blender/**`, `docs/lessons-learned/blender.md` | 01 (placement), 05 (import), 04 (VFX props) |
| FORGE-03 | UI & Economy | `roblox/src/shared/Economy/`, `roblox/src/server/Services/{Economy,Purchase,Shop,Reward,Inventory}*`, `roblox/src/client/UI/`, `roblox/src/client/Controllers/UIController*`, `roblox/tests/unit/economy/`, `roblox/tests/unit/ui/`, `design/ui/`, `docs/lessons-learned/ui-economy.md` | 04 (components), 05 |
| FORGE-04 | Experience | `roblox/src/shared/Experience/`, `roblox/src/server/Services/{Analytics,Onboarding,Quest,DailyReward,Settings}*`, `roblox/src/client/Controllers/{Audio,VFX,Onboarding,Settings,Notification}*`, `roblox/tests/unit/experience/`, `analytics/`, `docs/lessons-learned/experience.md` | 03, 05 |
| FORGE-05 | Integration & QA | `roblox/default.project.json`, `roblox/src/server/Main.server.luau`, `roblox/src/client/Main.client.luau`, `roblox/src/shared/Contracts/` (custodian), `roblox/tests/harness/`, `roblox/tests/mocks/`, `roblox/scripts/`, `rokit.toml`, `selene.toml`, `stylua.toml`, `.github/workflows/ci.yml`, `games/sandbox/`, `production/quality-gates/` (incl. `integration-log.md`), `production/release-checklists/`, `roblox/STUDIO_TEST_PLAN.md`, `docs/lessons-learned/integration.md` | everyone |
| Codex | Intelligence | `intelligence/` (takes over from FORGE-00 once launched), `prompts/`, reviews | FORGE-00 |
| User | Executive | approvals, Studio sessions on Windows, accounts/keys | — |

Rules
- One owner per path. A path not listed belongs to FORGE-00 until assigned.
- `games/game-00N/` is created by FORGE-00 when a game is approved; its sub-folders are then assigned per the game brief.
- Each worker keeps `agents/<id>/STATUS.md` current: branch, open PR, current task, blockers, last verified check.
- Cross-area requests: `production/handoffs/YYYY-MM-DD-<from>-to-<to>-<topic>.md`, plus a task for the receiver.

## Why the split works in parallel
- Profile data is namespaced (`core`, `economy`, `experience`, `game`) so no two workers edit one schema.
- Remotes are declared per area (`shared/<Area>/Remotes.luau`) and aggregated by RemoteService, so no shared remote list.
- Services register with the loader by file; adding a service never edits another worker's file.
- UI components (FORGE-03) are consumed by FORGE-04 through the documented component API in `docs/architecture/interfaces.md`.
- FORGE-02 hands assets over through `blender/manifest.json`; gameplay code refers to assets only by asset id.
