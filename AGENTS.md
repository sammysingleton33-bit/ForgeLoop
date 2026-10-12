# FORGELOOP-01 — rules for every agent (FORGE workers, Codex, any other model)

This folder is a Roblox game factory. The repository is the only shared memory: never rely on what another chat "knows". If it matters, it is in a file and a commit.

## Start of every session
1. Read `PROJECT_STATUS.md`, `DECISIONS.md`, your role file `agents/<your-id>/MISSION.md`, and `docs/workflows/team.md` (who owns what).
2. Sync with the integration branch: `git fetch origin forge/integration` and make sure your branch contains it (see `docs/workflows/git-and-integration.md`).
3. Pick work from `production/tasks/` assigned to you (`python tools/forge.py list --owner <your-id>`). Move it to `BUILDING` with a note before you start.

## While working
- Edit only paths you own (`docs/workflows/team.md`). Need a change elsewhere? Write a request in `production/handoffs/` or open a task for the owner — don't edit their files.
- Shared contracts (`roblox/src/shared/Contracts/`, `docs/architecture/interfaces.md`) change only by PR reviewed by FORGE-05 and approved by FORGE-00. Additive changes (new fields, new remotes in your own area) are fine; breaking changes need a migration note.
- Server is authoritative for anything valuable: rewards, currency, inventory, purchases, outcomes. Validate every remote argument server-side.
- Randomized rewards: show possible outcomes; paid random items need numerical odds + Roblox policy gating (`docs/research/` when available). Never fake odds or reveal animations.
- Assets: commit generators, manifests and small previews. Exported binaries are reproducible; don't commit large files unless the team decides to.
- Never commit credentials, API keys, cookies, `.ROBLOSECURITY`, Open Cloud keys or personal data.

## Evidence rules (non-negotiable)
- Never claim something works, passed, looks good or is playable without having run/seen it. Say "unverified" when you couldn't check.
- Headless checks (Lune tests, Selene, StyLua, Rojo build, Blender validation) are not Studio play tests. Record which kind of evidence you have.
- Visual work is accepted only after someone has looked at a render/screenshot. Script success is not visual quality.

## End of every session / task
1. Run `bash roblox/scripts/check.sh` (Roblox code) and/or `bash blender/scripts/check.sh` (assets) and `python tools/forge.py validate`.
2. Update your task(s) with `python tools/forge.py set-status <ID> <STATUS> --note "..." --evidence "..."` (set `FORGE_AGENT=<your-id>`).
3. Write a handoff (`production/handoffs/TEMPLATE.md`) when another worker must act on your output.
4. Commit, push your branch, and open/update a PR into `forge/integration`. Update `agents/<your-id>/STATUS.md` (branch, PR, current task, blockers).
5. Add a lesson to `docs/lessons-learned/<area>.md` only if verified and reusable; tag it `observed-once`, `repeated` or `standard`.

## Commands
- Tasks: `python tools/forge.py validate | list | new | set-status | dashboard | prompt <ID> | check`
- Roblox: `bash roblox/scripts/check.sh` (Lune tests + Selene + StyLua + Rojo build + place-structure check)
- Blender: `bash blender/scripts/check.sh` (once FORGE-02 lands it)
- Tool tests: `python -m pytest -q tools/tests`

## Approval gates (ask the user; never assume)
Choosing a game, major creative or monetization changes, spending money, publishing anything publicly, changing Roblox/GitHub permissions, deleting or rewriting history on shared branches.
