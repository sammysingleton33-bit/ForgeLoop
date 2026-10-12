# Git, worker branches, worktrees and integration

Repository: `github.com/sammysingleton33-bit/forgeloop` (private).

## Branches
| Branch | Purpose | Who writes |
|---|---|---|
| `main` | **The integrated build.** Only validated work arrives here, through PRs. Studio testing always uses `main`. | FORGE-05 merges PRs. FORGE-00 may push coordination-only files (dashboard, tasks, decisions, prompts). Nobody else pushes to `main`. |
| `forge/01-gameplay` | FORGE-01 workspace | FORGE-01 only |
| `forge/02-blender` | FORGE-02 workspace | FORGE-02 only |
| `forge/03-ui-economy` | FORGE-03 workspace | FORGE-03 only |
| `forge/04-experience` | FORGE-04 workspace | FORGE-04 only |
| `forge/05-integration` | FORGE-05 workspace (harness, CI, sandbox, test plan) | FORGE-05 only |
| `codex/<task-id>-<slug>` | Codex work | Codex |
| `release/game-00N-vX` tags | Published versions (user-approved) | FORGE-05 after approval |

Worker branches are long-lived: one per worker, reused across sessions. Each worker submits work by PR from its branch into `main`.

## Starting a worker session
Cloud session (Claude app → Code → new session on `sammysingleton33-bit/forgeloop`): every session has its own container, so the working copy is already isolated. Check out your worker branch:
```bash
B=forge/01-gameplay                       # your worker branch (see table)
git fetch origin "$B" main
git checkout -B "$B" "origin/$B"
git merge --no-edit origin/main           # pick up everything integrated so far
git push -u origin "$B"
```
The user's startup prompt explicitly authorises pushing to your worker branch. If the push is refused because the session only allows its own assigned `claude/...` branch, use that assigned branch instead, open your PRs from it, and record it in `agents/<id>/STATUS.md`.

Local session (Claude Code CLI/desktop on the user's PC): one worktree per worker, so sessions never share a working directory:
```bash
git clone https://github.com/sammysingleton33-bit/forgeloop.git forgeloop && cd forgeloop
git worktree add --track -b forge/01-gameplay ../forgeloop-wt/forge-01 origin/forge/01-gameplay
cd ../forgeloop-wt/forge-01 && git merge --no-edit origin/main
```
A branch can be checked out in only one worktree at a time, which enforces "one worker, one branch".

Toolchain (Linux cloud sessions; ~10 min the first time, run it in the background and read docs meanwhile):
```bash
nohup bash tools/setup/cloud-setup.sh > /tmp/forge-setup.log 2>&1 &            # Roblox tools
nohup bash tools/setup/cloud-setup.sh --blender > /tmp/forge-setup.log 2>&1 &  # FORGE-02: + Blender
tail -3 /tmp/forge-setup.log   # "FORGE SETUP DONE" when ready
```
Windows: install [Rokit](https://github.com/rojo-rbx/rokit), then `rokit install` in the repo (reads `rokit.toml`).

## Staying in sync
- `git fetch origin main && git merge --no-edit origin/main` at the start of every session, before opening/updating a PR, and right after your PR is merged. Merge, don't rebase, pushed branches.
- Small PRs (one task, ideally < ~600 changed lines of code). Asset/generator PRs can be larger but stay in one area.

## Pull requests (worker → main)
- From your worker branch into `main`. Title: `[FORGE-0N] FL-0000 <summary>`.
- Body: tasks, what changed, **evidence** (exact commands and results), what is unverified, Studio steps needed, contract changes (none / additive / breaking).
- Only paths you own (`docs/workflows/team.md`). CI (`.github/workflows/ci.yml`) must be green.
- Task files: set `REVIEW` with evidence in the same PR. Don't regenerate `PROJECT_STATUS.md` (FORGE-00 does that after merges; it would conflict between workers).

## Merge procedure (FORGE-05)
1. CI green on the PR head; merge `origin/main` into a local check-out of the PR branch, then `bash roblox/scripts/check.sh` green on that merge result.
2. Ownership respected; contract changes reviewed (breaking → FORGE-00 approval recorded in `DECISIONS.md`).
3. Merge with a merge commit (keeps the worker's evidence commit shas reachable from `main`).
4. Move the PR's tasks to `ACCEPTED` (or leave `REVIEW` if only the Studio gate G6 is pending) and append a line to `production/quality-gates/integration-log.md` (main sha, PRs, checks).
5. Tell workers whose code depends on it (handoff file or PR comment).

## Conflicts
- Code conflict in a path one worker owns → that worker resolves it in their branch.
- Contract conflict → FORGE-05 proposes, FORGE-00 decides, recorded in `DECISIONS.md`.
- Never force-push `main` or another worker's branch.

## Integrated build in Studio
- Live sync (Windows): checkout `main`, `bash roblox/scripts/stamp_build.sh`, `rojo serve roblox/default.project.json`, connect the Rojo plugin in Studio.
- File: CI on `main` uploads `forgeloop-main-<sha>.rbxl` as an artifact; open it in Studio.
- Either way `ReplicatedStorage.Forge.BuildInfo` shows the sha being tested; quote it in every Studio test report.
