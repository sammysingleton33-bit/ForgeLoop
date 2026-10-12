---
id: FL-0003
title: "Shared Roblox skeleton: contracts, loader, harness, mocks, checks, CI"
track: infra
owner: forge-00
status: BUILDING
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [docs/architecture/interfaces.md]
estimate_h: 4
evidence: []
---

# Shared Roblox skeleton: contracts, loader, harness, mocks, checks, CI

## Outcome
Workers start from a green skeleton: Rojo project, Contracts (Env, Loader, GameEvents, Types), Core/Signal, Lune test harness + Roblox mocks, place-structure check, check.sh, CI workflow, Studio smoke test plan.

## Requirements
- Implements docs/architecture/interfaces.md sections 1-4 and 11
- Gates proven able to fail (negative tests)
- Hand over to FORGE-05 (FL-0028)

## Validation
bash roblox/scripts/check.sh (Lune tests, Selene, StyLua, Rojo build, place check); negative tests; CI run on GitHub

## Completion criteria
- [ ] check.sh green
- [ ] Adversarial review findings fixed or answered
- [ ] CI workflow green on GitHub

## Log
- 2026-10-12 forge-00: created (BUILDING).
