# Merge checklist (FORGE-05, gate G8)

Run for every PR into `main`, in this order; stop at the first failure and post a COMMENT review
starting with `BLOCKING:` that quotes the exact command and its output (one GitHub identity is
shared, so APPROVE / REQUEST_CHANGES are not available). Procedure: `docs/workflows/git-and-integration.md`.

## 1. Eligible
- [ ] Not a draft. Title `[FORGE-0N] FL-00xx …` / `[CODEX] …`; body follows `.github/pull_request_template.md`.
- [ ] Diff against `main` contains no skeleton files from another branch (D-016) and nothing outside the author's paths.
- [ ] Stacked PRs: the PR it is stacked on is merged first.

- [ ] **The PR's base branch is `main`** (`pull_request_read get` → `base.ref`). A PR stacked on another
      PR keeps that PR's branch as its base after the lower one merges, and merging it then lands it
      on the stale branch, not on `main` (PR #37, 2026-10-12: merged into `forge/02-blender-fl0055-world`;
      re-targeted as #38). If the base is not `main`, open a PR from the same head into `main` or ask
      the author to change the base.

## 2. CI green on the PR head
- [ ] `roblox`, `tools` and `ownership` jobs green on the **current head sha** (GitHub MCP: `pull_request_read get_check_runs`; read the job log, not only the conclusion — a skipped Roblox job must say why).

## 3. Merge result green (local)
```bash
git fetch origin main <head-branch>
git worktree add --detach ../merge-check origin/<head-branch> && cd ../merge-check
git merge --no-edit origin/main
bash roblox/scripts/check.sh                      # OVERALL PASS
python -m pytest -q tools/tests                   # all passed
python tools/forge.py validate                    # 0 errors
python tools/check_ownership.py --base origin/main --title "<PR title>" --branch <head-branch>   # PASS
```
- [ ] `blender/` PRs: `bash blender/scripts/check.sh` (setup `tools/setup/cloud-setup.sh --blender`), or record SKIPPED and cite FORGE-02's evidence until FL-0017's asset job exists.
- [ ] New specs/gates: the PR shows each can fail (negative test), or reproduce one.

## 4. Review
- [ ] Contracts (`roblox/src/shared/Contracts/`, `docs/architecture/interfaces.md`, `games/game-001/CONTRACTS.md`): additive is fine; breaking needs an approved `DECISIONS.md` entry.
- [ ] Server authority for anything valuable; remote arguments validated and rate-limited; idempotent grants (G4).
- [ ] Mocks used by new specs behave like Roblox (docs cited); no `game`, `task.wait`, `os.time` in services (use `env`).
- [ ] Visual work: a render/screenshot was opened and reviewed (G5); otherwise "unverified".

## 5. Merge
- [ ] Merge commit (never squash/rebase; keeps the worker's evidence shas reachable), with `expectedHeadSha` = the sha checked above.
- [ ] After the merge, `git ls-remote origin refs/heads/main` shows the new merge commit (the merge API also reports success for a merge into another base).

## 6. Bookkeeping (direct push to `main`, D-014)
- [ ] Tasks → ACCEPTED, or REVIEW when only G6 (Studio) is pending; evidence = merge sha + check summary + CI link.
- [ ] Line in `production/quality-gates/integration-log.md` (date · main sha · PR · tasks · checks · CI on main · artifact).
- [ ] CI on the merge commit green; artifact `forgeloop-main-<short sha>` listed with the BuildInfo sha from the CI log.
- [ ] PR comment with the new main sha; tell dependent workers (PR comment or handoff).
- [ ] `agents/forge-05/STATUS.md` updated.

If a merge turns `main` red: revert first (revert PR, merged by FORGE-05), investigate second.
