# Handoff: FORGE-05 → FORGE-00 · FL-0029, FL-0046 · 2026-10-12

## What I need / what I'm giving you
Four small decisions or doc edits in files you own, found while wiring game-001.

## Done (with commits)
- PR #1 skeleton merged (`f9e9b0a`); FL-0029 ownership gate + PR template + merge checklist merged
  (PR #3, `3a7b983`), including the game-001 rows of team.md; FL-0046 wiring + G9 events in PR #6.
- Closed my PR #2 (sandbox AI Kingdoms map) as superseded by your brief.

## Open issues and risks (decisions for you)
1. **team.md rows missing** (the rules file assigns them to forge-05 with a note; please confirm in
   team.md): `.gitattributes`; `games/game-001/config/Game.luau` (game id, read by S1); empty-folder
   placeholders `games/game-001/**/.gitkeep` (Rojo fails on a missing `$path`).
2. **interfaces.md §1/§3 are stale** (your file): §1 still says `@game` reaches only
   `ReplicatedStorage/Forge`; D-022 and PR #6 also allow `ReplicatedStorage/Game` and forbid framework
   → game requires. §3: `Loader.boot(env, folder | {folders})`, `Loader.discoverAll`, both trees booted
   as one graph. §2: `env.sharedModules` spans Forge + Game.
3. **Remote area names collide across trees**: CONTRACTS G1 lists game areas `Economy` and
   `Experience`, which are also framework area names (FORGE-03/04). `env.sharedModules` keys by area
   name, so only one tree may declare `Remotes` per area; PR #6 makes that an error (place check +
   boot gate). Either keep framework Economy/Experience remote-free in game-001, or rename the game
   areas (e.g. `Treasury`, `Feedback`). Your call; I enforce whichever you record.
4. **Branch protection**: the repo is still public; see
   `production/handoffs/2026-10-12-forge-05-to-user-branch-protection.md`. If the user keeps it public
   and adds the ruleset, D-014's direct bookkeeping pushes must move into small PRs.
5. Interface/workflow docs mention FL-0044/FL-0030 sandbox work; both are REJECTED — nothing for you
   unless you want to prune the references.

## Next actions for the receiver
1. Decide 3; record it in DECISIONS.md or CONTRACTS.md.
2. Update team.md (1) and interfaces.md (2) when convenient.

## Files to read
- `games/game-001/README.md`, `production/quality-gates/ownership.json` notes
