# Launching Codex for FORGELOOP-01 (task FL-0037)

Codex is the intelligence and strategy department. Claude workers do the heavy building; Codex spends its limited capacity on reviews, research and specs that change what gets built.

## Where
Use Codex connected to GitHub (Codex in ChatGPT, or the Codex CLI in a local clone). Repository: `sammysingleton33-bit/DLS`. Branch to start from: `forge/integration`. Working folder: `forgeloop/`. Codex reads `AGENTS.md` files automatically; `forgeloop/AGENTS.md` holds the shared rules.
Exact current setup steps and Plus-plan limits: see `docs/research/ai-providers.md` (verified research).

## Paste this as the first Codex task
```
You are Codex, the intelligence and strategy lead of FORGELOOP-01, a Roblox game factory in the folder forgeloop/ of this repository (branch forge/integration). Claude Code workers FORGE-01..05 build code and assets; FORGE-00 (Claude) directs. Your capacity is limited, so do high-leverage work only.

Read first: forgeloop/AGENTS.md, forgeloop/agents/codex/MISSION.md, forgeloop/PROJECT_STATUS.md, forgeloop/DECISIONS.md, forgeloop/docs/workflows/team.md.

Do these tasks in order (task files in forgeloop/production/tasks/):
1. FL-0041 coordination round-trip test: write forgeloop/production/handoffs/FL-0041/request.md with a reward-table spec for the sandbox (5 rarity tiers, target drop frequency per tier per session, pity rule) and commit it.
2. FL-0040: review forgeloop/intelligence/game-opportunities/game-001-shortlist.md and its sources. Check evidence, recompute weighted scores, judge 7-day feasibility, challenge the recommendation. Write forgeloop/production/handoffs/<date>-codex-to-forge-00-shortlist-review.md with a verdict per concept and concrete changes, each with source, date and confidence.

Rules: never invent metrics; label observed vs inferred; work on a branch named codex/<task-id>-<slug>; open a PR into forge/integration; update the task status in its file (append a Log line). Do not edit roblox/ or blender/ code.
```

## After Codex finishes
- FORGE-03 picks up FL-0041 `request.md`, implements it, writes `result.md`; Codex then writes `ack.md` citing the commit sha. That proves shared state works both ways.
- Later tasks for Codex are created by FORGE-00 with `owner: codex`. Any model (Codex, AreaAI, other) can run a task from a compiled prompt: `python forgeloop/tools/forge.py prompt FL-0040 --out prompt.md`.

## When Codex hits its usage limit
Keep working state in Git (task file + handoff). Run `python forgeloop/tools/forge.py prompt <ID>` and paste the result into the fallback model (AreaAI or another), then commit its output through a Claude worker. AreaAI's capabilities are still being verified (`docs/research/ai-providers.md`); no automated integration is assumed.
