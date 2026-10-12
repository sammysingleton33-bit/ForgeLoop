---
id: FL-0009
title: "RemoteService: declarative per-area remotes with validation and rate limits"
track: build
owner: forge-01
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0007]
estimate_h: 5
evidence: []
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
