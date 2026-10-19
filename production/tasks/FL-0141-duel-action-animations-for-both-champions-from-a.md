---
id: FL-0141
title: Duel action animations for both champions from Arena.Events
track: build
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Duel action animations for both champions from Arena.Events

## Outcome
Players see the duel. Each champion swings, blocks, parries, dodges, staggers on a hit and falls at the end, for both human and AI champions, driven by the server's `Arena.Events`.

## Context
- B22 (e8ea78c) has no duel animation on the client. `ArenaHud` shows HP and events, but the bodies do not move with the actions.
- `DuelController.events` gives one `{ t, kind, side, data? }` per event (G12.6). The AI champion figure comes from FL-0140 (FORGE-01).
- FORGE-01's "hit and shot cues" task is the server half, if any event kind is missing.

## Requirements
- Play an animation per event kind on that side's champion, human or AI: light, heavy (wind-up then strike), block hold and release, parry, dodge, hit stagger, KO.
- Use Roblox's default R15 animation API on the rig Kit builds. No paid assets. Licensed or self-made animations only, with licences recorded.
- Spread the work so a burst of events costs no frame spike. Late joiners animate from the next event.
- Specs for event → animation mapping.

## Validation
- Automated: `check.sh` green.
- Studio (user): a duel against the AI and a two-player duel. Every action reads on screen at the arena camera distance, and on a phone.

## Completion criteria
- [ ] PR into main, reviewed by FORGE-07, gated by FORGE-05.

## Log
- 2026-10-19 FORGE-00: created from the B22 review. P0 for B23 RC. Builds on FL-0140's AI figure; start with the human champion while FL-0140 lands.
