---
id: FL-0069
title: Leadership ledger, citizen loyalty and key citizens (Crown Arena support inputs)
track: build
owner: forge-01
status: SPECIFIED
priority: P1
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0052]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 14
evidence: []
---

# Leadership ledger, citizen loyalty and key citizens (Crown Arena support inputs)

## Outcome
Every ruler decision that matters for the Crown Arena is recorded as it happens, citizens carry loyalty, and each kingdom grows named key citizens whose loyalty the player can raise with visits, protection and fulfilled petitions (design §3–§4).

## Context
D-029; design `games/game-001/design/crown-arena.md` §3–§4; CONTRACTS G12.1, G12.2 (`LeadershipService`), G12.4 (`Kingdom.FulfilPetition`), G12.5 (`LeadershipAct`, `KeyCitizenChanged`), G5 memory. **Start after your VS-1 rows (FL-0052) are integrated.**

## Requirements
- `LeadershipService` (`src/server/Services/LeadershipService.luau`): `record`, `getMoments`; act ids, components and signed weights in config `Support.luau`; samples kingdom stats (happiness, stability, morale, loyalty) every 30 s with an injected clock.
- Act producers call `registry:find("LeadershipService")`: fed-ratio thresholds (ProductionService via its existing hook), raids defended or abandoned, ruler present in combat, objectives captured in person, rebuilds, overwork quotas, conscription share.
- Citizen loyalty 0–100 (start 50) driven by memory events (G5); `inspect` gains `loyalty`, `role`, `petition` (G12.1).
- Key citizens: one per role per kingdom, spawned when the matching building completes (Smithy, Infirmary, Barracks captain, Granary or Kitchen; Elder and Merchant when their buildings exist). Named, persistent for the match; on death a successor appears at loyalty 50.
- Petitions: config-driven, pre-authored text, expiry; `Kingdom.FulfilPetition` spends through TreasuryService and raises loyalty; expiry lowers it and records a conduct act.
- Every moment text is pre-authored (no user text). Deterministic with injected clock and RNG.

## Validation
Lune specs: act recording and sampling with a fake clock; loyalty rises and falls per event; key-citizen spawn, death and successor; petition fulfil and expiry (treasury double); determinism (same event log → same ledger). Studio: inspect a key citizen and fulfil a petition.

## Completion criteria
- [ ] `bash roblox/scripts/check.sh` OVERALL PASS with the new specs
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (SPECIFIED).
