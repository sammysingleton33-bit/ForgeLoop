# Git, worktrees and integration

## Branches
| Branch | Purpose | Who writes |
|---|---|---|
| `forge/integration` | The integrated, validated build. Studio testing always uses this. | FORGE-05 merges PRs; FORGE-00 for coordination files |
| worker branches | One per worker session (cloud sessions get an assigned `claude/...` name; local sessions use `forge/0N-<area>`) | that worker only |
| `codex/<task-id>-<slug>` | Codex work | Codex |
| `main` | DLS default branch. FORGELOOP reaches it only at user-approved milestones. | user |

## Starting a worker session
Cloud session (Claude app / claude.ai/code): the session has its own assigned branch and container.
```bash
git fetch origin forge/integration
git status                      # fresh session: no local work
git checkout -B "$(git branch --show-current)" origin/forge/integration
git push -u origin "$(git branch --show-current)"
```
If your branch already has commits, merge instead: `git merge origin/forge/integration`.

Local session (Claude Code CLI/desktop on the user's PC): one worktree per worker, so sessions never share a working directory.
```bash
git fetch origin
git worktree add ../forgeloop-wt/forge-01 -b forge/01-gameplay origin/forge/integration
```

## Staying in sync
- Merge `origin/forge/integration` into your branch at least at the start of each session and before opening/updating a PR. Merge, don't rebase, once a branch is pushed.
- Small PRs (one task, < ~600 changed lines of code where possible). Large asset/generator work can be bigger but keep it to one area.

## Pull requests
- Base: `forge/integration`. Title: `[FORGE-0N] FL-0000 <summary>`.
- Body: tasks, what changed, **evidence** (exact commands and results), what is unverified, Studio steps needed, contract changes (none / additive / breaking).
- Only paths you own (see `team.md`). CI (`.github/workflows/forgeloop.yml`) must be green.

## Merge procedure (FORGE-05)
1. CI green on the PR head; `bash roblox/scripts/check.sh` green on the merge result locally.
2. Ownership respected; contract changes reviewed (breaking → FORGE-00 approval recorded in `DECISIONS.md`).
3. Task files updated by the author (status `REVIEW` with evidence).
4. Squash-merge into `forge/integration`; move tasks to `ACCEPTED` with the merge commit as evidence.
5. Post the new integration sha in `PROJECT_STATUS.md` → "Integrated build" (FORGE-00 regenerates the dashboard).

## Conflicts
- Code conflict in a path one worker owns → that worker resolves it in their branch.
- Contract conflict (two workers need incompatible changes) → FORGE-05 proposes, FORGE-00 decides, decision goes in `DECISIONS.md`.
- Never force-push `forge/integration` or another worker's branch.

## Integrated build in Studio
- Live sync: checkout `forge/integration` locally, `bash roblox/scripts/stamp_build.sh`, `rojo serve roblox/default.project.json`, connect the Rojo plugin in Studio.
- File: CI on `forge/integration` uploads `forgeloop-integration-<sha>.rbxl` as a workflow artifact; open it in Studio.
- Either way, `ReplicatedStorage.Forge.BuildInfo` shows the sha being tested.
