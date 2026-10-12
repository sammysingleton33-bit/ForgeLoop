# FORGELOOP-01

A repeatable, AI-run Roblox game factory: the system that builds the games. Claude Code workers build code and 3D assets, Codex supplies strategy and reviews, Blender produces art, Roblox Studio validates, GitHub is the shared memory.

**Start here:** `PROJECT_STATUS.md` (live dashboard) · `AGENTS.md` (rules for every agent) · `docs/workflows/team.md` (who owns what) · `docs/architecture/interfaces.md` (contracts) · `DECISIONS.md`.

| Folder | What | Owner |
|---|---|---|
| `agents/` | Role missions, startup prompts, worker status | FORGE-00 (prompts), each worker (STATUS) |
| `production/` | Task queue (`tasks/FL-*.md`), handoffs, quality gates, release checklists | FORGE-00 / FORGE-05 |
| `roblox/` | Shared Luau framework (Rojo project), tests, scripts | FORGE-01/03/04 by area, FORGE-05 harness |
| `blender/` | Asset generators, pipeline, manifest, previews | FORGE-02 |
| `games/` | `sandbox/` integration place; `game-00N/` once approved | FORGE-05 / per brief |
| `intelligence/` | Market, design, retention, monetization research | FORGE-00 → Codex |
| `docs/` | Architecture, workflows, standards, research, lessons learned | FORGE-00 |
| `tools/` | `forge.py` task/dashboard/prompt tool, setup, diagnostics | FORGE-00 |

## Commands
```bash
python tools/forge.py list --owner forge-01      # your queue
python tools/forge.py set-status FL-0007 BUILDING --note "starting"
python tools/forge.py dashboard                   # refresh PROJECT_STATUS.md
python tools/forge.py prompt FL-0040 --out p.md   # self-contained prompt for any model
python tools/forge.py check                       # run every gate this machine can run
bash roblox/scripts/check.sh                      # Roblox gates
```

Integrated build: branch `forge/integration` (see `docs/workflows/git-and-integration.md`).
