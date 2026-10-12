---
id: FL-0009
title: "RemoteService: declarative per-area remotes with validation and rate limits"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0007]
estimate_h: 5
evidence:
  - check.sh OVERALL PASS at merge with main; 23 RemoteService specs (wrong types, NaN/inf, oversized, extra args, burst+refill, unknown names, handler isolation, duplicate/bad declarations, departed player, memory freed)
  - each guard proven red by a mutation (see PR)
---

# RemoteService: declarative per-area remotes with validation and rate limits

## Outcome
All client-server traffic goes through declared remotes; the server validates every argument and rate-limits per player.

## Requirements
- Aggregates shared/<Area>/Remotes.luau files
- Kinds event/function/serverEvent/unreliableServerEvent
- Invalid or over-limit calls dropped and counted; never crash the server

## Validation
Lune specs: wrong types, NaN/inf, oversized tables, burst over limit, unknown remote names; place check sees ForgeRemotes created at runtime (Studio step)

## Completion criteria
- [ ] Specs pass
- [ ] Gameplay/Economy/Experience can declare remotes without editing RemoteService

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-01: READY → BUILDING. started: RemoteService for the AI Kingdoms remotes
- 2026-10-12 forge-01: BUILDING → REVIEW. PR from forge/01-gameplay-fl0009 (stacked on FL-0007)
