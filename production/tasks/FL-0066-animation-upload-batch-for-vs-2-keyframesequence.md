---
id: FL-0066
title: Animation upload batch for VS-2 (KeyframeSequence files, user publishes)
track: asset
owner: forge-02
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0056]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Animation upload batch for VS-2 (KeyframeSequence files, user publishes)

## Outcome
Citizens, soldiers and rulers can use authored keyframe animations (walk, chop, mine, hammer, carry, fight) in live servers, replacing or layering on the VS-1 procedural poses (D-026).

## Requirements
- Author KeyframeSequences for the Kit.character rigs (≤ 8 parts, named Motor6Ds) and commit them as `.rbxm` files with a manifest (name, rig, length, loop).
- A handoff to the user: publish the batch from the account or group that owns the experience (animations play only after they are published, and asset privacy applies). The user returns the asset ids.
- Asset ids go into a config file owned by FORGE-01's EntityController work; procedural poses remain the fallback.
- No uploads by agents (user approval gate).

## Validation
Studio: the published animations play on pooled rigs in a Server & Clients test; procedural fallback when an id is missing.

## Completion criteria
- [ ] Ids published by the user and playing in Studio on the integrated build

## Log
- 2026-10-12 forge-00: created for VS-2 (D-026) (SPECIFIED).
