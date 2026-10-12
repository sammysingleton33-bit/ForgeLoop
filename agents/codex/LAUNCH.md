# Launching Codex for FORGELOOP-01 (task FL-0037)

Codex is the intelligence and strategy department. Claude workers do the heavy building; Codex spends its limited capacity on reviews, research and specs that change what gets built.

## Where
Codex connected to GitHub (Codex in ChatGPT, or the Codex CLI in a local clone). Repository: `sammysingleton33-bit/ForgeLoop`, starting branch `main`. Codex reads `AGENTS.md` automatically. Setup details and Plus-plan limits: `docs/research/ai-providers.md`.

## Paste this as the first Codex task
```
You are Codex, the intelligence and strategy lead of FORGELOOP-01, a Roblox game factory (this repository). Claude Code workers FORGE-01..05 build code and assets on their own branches; FORGE-00 (Claude) directs; main is the integrated build. Your capacity is limited, so do high-leverage work only.

Read first: AGENTS.md, agents/codex/MISSION.md, PROJECT_STATUS.md, DECISIONS.md, docs/workflows/team.md.

Do these tasks in order (task files in production/tasks/):
1. FL-0041 coordination round-trip test: write production/handoffs/FL-0041/request.md with a reward-table spec for the sandbox (5 rarity tiers, target drop frequency per tier per session, pity rule) and commit it.
2. FL-0040: review intelligence/game-opportunities/game-001-shortlist.md and its sources. Check evidence, recompute weighted scores, judge 7-day feasibility, challenge the recommendation. Write production/handoffs/<date>-codex-to-forge-00-shortlist-review.md with a verdict per concept and concrete changes, each with source, date and confidence.

Rules: never invent metrics; label observed vs inferred; work on a branch named codex/<task-id>-<slug>; open a PR into main; update the task status in its file (append a Log line). Do not edit roblox/ or blender/ code.
```

## After Codex finishes
- FORGE-03 finds `request.md` on your `codex/*` branch (or `main`), implements it and writes `production/handoffs/FL-0041/result.md` on `origin/forge/03-ui-economy` (a PR stacked on its FL-0018 work). Read it there (`git fetch origin && git show origin/forge/03-ui-economy:production/handoffs/FL-0041/result.md`), check the odds match your spec, and write `ack.md` citing the commit sha. That proves shared state works both ways.
- Later tasks for Codex are created by FORGE-00 with `owner: codex`. Any model (Codex, AreaAI, other) can run a task from a compiled prompt: `python tools/forge.py prompt FL-0040 --out prompt.md`.

## When Codex hits its usage limit
Keep working state in Git (task file + handoff). Run `python tools/forge.py prompt <ID>` and paste the result into the fallback model, then commit its output through a Claude worker. AreaAI's capabilities are being verified (`docs/research/ai-providers.md`); no automated integration is assumed.
