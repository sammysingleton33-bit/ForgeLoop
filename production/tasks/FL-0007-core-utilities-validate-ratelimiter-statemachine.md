---
id: FL-0007
title: "Core utilities: Validate, RateLimiter, StateMachine, Trove, RemoteClient"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 4
evidence:
  - "check.sh OVERALL PASS at merge with main 3a7b983: Lune 261 passed/0 failed, Selene 0, StyLua 79 files, Rojo build, place check"
  - 82 new specs in roblox/tests/unit/core; each module proven red by a mutation (see PR)
  - "FORGE-05 integration 2026-10-12: merged PR #4 (merge commit 1e27297). PR CI run 38298796034 green on 73da45a; merge result = head: check.sh OVERALL PASS (Lune 261/0, 21 files; Selene 0; StyLua 79; Rojo; place check); pytest 139; forge validate 0 errors; ownership PASS. CI on main run 38300347646 green, artifact forgeloop-main-1e27297. Independent security review: no crash in 517 hostile Validate calls; follow-ups on the PR."
---

# Core utilities: Validate, RateLimiter, StateMachine, Trove, RemoteClient

## Outcome
Robust shared primitives other systems depend on, fully unit-tested.

## Requirements
- Validate per interfaces.md section 6 (finite numbers only; size caps on strings/arrays)
- RateLimiter token bucket per key with injected clock
- StateMachine with declared transitions, guards, enter/exit hooks
- Trove/cleanup helper
- RemoteClient (invoke/send/on) per section 6

## Validation
Lune specs in roblox/tests/unit/core/ incl. NaN/inf/oversized payloads, clock-driven refill, illegal transitions; check.sh green

## Completion criteria
- [ ] All specs pass in check.sh
- [ ] Public API documented in module headers

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-01: READY → BUILDING. started: Core utilities for the AI Kingdoms remotes
- 2026-10-12 forge-01: BUILDING → REVIEW. PR from forge/01-gameplay-fl0007: Validate, RateLimiter, StateMachine, Trove, RemoteClient with failure-path specs
- 2026-10-12 forge-05: merged PR #4 as 1e27297 (FORGE-05). Stays REVIEW: G6 (RemoteClient replication in Studio, with FL-0047) and review follow-ups on PR #4 (validator result == true before the first Remotes declaration; RateLimiter epsilon; StateMachine/RemoteClient docs; CFrame + record validators for G8).
