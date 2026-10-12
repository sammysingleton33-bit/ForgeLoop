# Handoff: FORGE-05 → User · FL-0029 · 2026-10-12

## What I need / what I'm giving you
A decision, then (optionally) five minutes in GitHub settings. Today `main` is protected only by
process (D-014) and CI. Whether GitHub itself can enforce "PR-only, CI green, no force-push" depends
on the repository's visibility, which is your call (D-015 says you want it private).

## The facts (checked 2026-10-12)
- The repository is **public right now**: GitHub API `GET /repos/sammysingleton33-bit/ForgeLoop` →
  `"visibility": "public"`, `"private": false`.
- GitHub docs (source `github/docs`, `data/reusables/gated-features/repo-rules.md`): *"Rulesets are
  available in public repositories with GitHub Free and GitHub Free for organizations, and in public
  and private repositories with GitHub Pro, GitHub Team, and GitHub Enterprise Cloud."* Protected
  branches (`.../gated-features/protected-branches.md`) have the same availability.
  Pages: [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets),
  [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
- GitHub Actions (`content/billing/concepts/product-billing/github-actions.md`): *"usage is free ...
  for public repositories that use standard GitHub-hosted runners"*; private repositories use the
  plan's monthly quota of free minutes, and usage beyond it is billed.

So, on the Free plan:

| Choice | `main` enforced by GitHub? | CI minutes |
|---|---|---|
| Stay **public** | Yes: a ruleset (below) works today | free, unmetered |
| Go **private** on Free (D-015 as written) | No: rulesets/branch protection unavailable; process + CI ownership gate only | metered quota |
| Private + **GitHub Pro** (paid) | Yes | Pro's quota |

Spending money and changing visibility are your decisions; I will not do either.

## Option A — keep it public and add a `main` ruleset (recommended if public is acceptable)
GitHub → **ForgeLoop** → **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**:
1. **Ruleset name:** `main`. **Enforcement status:** Active.
2. **Bypass list:** leave **empty** (every Claude session uses your account, so any bypass entry
   would let every session bypass).
3. **Target branches** → **Add target** → **Include default branch**.
4. **Rules:** tick
   - **Restrict deletions**
   - **Block force pushes**
   - **Require a pull request before merging** → Required approvals **0** (one shared identity
     cannot approve its own PRs); leave the other sub-options off.
   - **Require status checks to pass** → **Add checks**: `roblox (Lune, Selene, StyLua, Rojo, place check)`,
     `tools (pytest + forge validate)`, and — once FL-0029's PR is merged — `ownership (G8)`.
     Leave "Require branches to be up to date" off (FORGE-05 checks the merge result itself).
5. **Create**.

Consequence: FORGE-05's direct bookkeeping pushes to `main` (D-014) are then refused, so merge
bookkeeping moves into small PRs that FORGE-05 self-merges after CI. FORGE-00 needs to amend D-014 at
the same time; I'll switch as soon as the ruleset exists.

## Option B — go private on the Free plan
GitHub → **ForgeLoop** → **Settings** → **General** → **Danger Zone** → **Change visibility** →
**Make private**. Nothing to configure afterwards: process + CI remain the guard (D-014/D-015), and
the `ownership (G8)` CI job reports any PR that touches another worker's paths.

## Open issues and risks
- Neither option stops a session from pushing to *other* branches; worker branches stay
  process-guarded.
- Never put a token, password or key in a file or in the chat for any of this.

## Next actions for the receiver (you)
1. Choose A (public + ruleset) or B (private, process only), or Pro (paid).
2. Tell FORGE-05 in this chat; if A, say when the ruleset is active so I can verify it with a test
   push that must be refused.

## Files to read
- `DECISIONS.md` D-014, D-015 — current guard and the private-repo decision
- `production/quality-gates/merge-checklist.md` — what FORGE-05 checks on every merge
