---
id: FL-0139
title: "Duel sprint clamp: RulerController holds Arena.ring.walkSpeed while champion"
track: build
owner: forge-04
status: READY
priority: P1
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Duel sprint clamp: RulerController holds Arena.ring.walkSpeed while champion

## Outcome
A champion in a Crown Arena duel moves at the ring's fixed walk speed and cannot sprint, so neither champion can outrun the other inside the ring. Outside a duel, sprint works as today.

## Context
- FORGE-07's review of #255 (M1): the server holds `WalkSpeed` to `Arena.ring.walkSpeed` (16), but `RulerController.luau:243` writes `humanoid.WalkSpeed` on every step, easing toward 24 when sprinting (`:42-43`). A client write on its own character wins for movement and the server cannot see it.
- `DuelController:isChampion()` (#249) tells the client it is a champion; config `Arena.ring.walkSpeed` (#255).
- Server half: #255 (FORGE-01). Pose speed bound on the server: B23 (FORGE-01).

## Requirements
- While `DuelController:isChampion()` is true, `RulerController` targets `Arena.ring.walkSpeed` and ignores the sprint input; it restores normal behaviour when the duel ends or is cancelled.
- No other movement change; read the speed from config, no literal.
- Spec or headless check where the controller allows one; otherwise say so.

## Validation
- Automated: `bash roblox/scripts/check.sh` green.
- Studio (user): two clients in a duel, one holds sprint: both move at the same speed; sprint works again after the crowning.

## Completion criteria
- [ ] PR into `main`, reviewed by FORGE-07, gated by FORGE-05.
- [ ] Studio row added to the B22.x checklist.

## Log
- 2026-10-19 FORGE-00: created from #255 review M1. Does not hold B22; lands in B22.1 or with #256 if ready before gate 8i.
