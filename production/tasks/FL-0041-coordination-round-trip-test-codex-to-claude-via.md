---
id: FL-0041
title: "Coordination round-trip test: Codex to Claude via the repository"
track: coordination
owner: codex
status: READY
priority: P1
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
estimate_h: 1
evidence: []
---

# Coordination round-trip test: Codex to Claude via the repository

## Outcome
Proof that Codex and Claude workers share one authoritative state: Codex writes a spec, a Claude worker executes it, Codex reads the result.

## Requirements
- Codex writes production/handoffs/FL-0041/request.md: a reward table spec (5 rarity tiers with target drop frequencies) for the sandbox
- FORGE-03 implements it in games/sandbox/config/RewardTables.luau and records computed odds + test output in result.md
- Codex reads result.md, checks odds match its spec, writes ack.md citing the commit sha

## Validation
Three files exist across commits by different agents; odds match

## Completion criteria
- [ ] Round trip completed with commit references

## Log
- 2026-10-12 forge-00: created (READY).
