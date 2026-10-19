---
id: FL-0140
title: "Arena champions visible: AI champion body, loadout gear, venue dress"
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: []
evidence: []
---

# Arena champions visible: AI champion body, loadout gear, venue dress

## Outcome
In a Crown Arena duel both champions are visible and dressed for the fight. An AI champion appears as a figure on its mark, not as an invisible opponent. Every champion carries the weapon and armour picked in the loadout, and the venue wears the two qualifiers' colours.

## Context
- Found by FORGE-00's CONTRACTS v0.4-g11k pass on B22 (e8ea78c, headless).
- `ArenaService` places only human champions. An AI champion has no body (`ArenaService.luau:237`), so DuelRunner runs that side as virtual: always in range and facing (`DuelRunner.luau:16-17, 189`). A solo player duels an invisible opponent.
- Nothing calls `Kit.weapon`, `Kit.armour` or `Kit.arenaDress` (FORGE-02's #217 functions). Champions fight in their own avatars on the neutral venue.
- `ArenaService` never calls `MatchHost:snapRuler` after a placement, so the sim's copy of a champion walks 9 to 14 s from the plot at `rulerMaxSpeed`.
- Design: `design/crown-arena.md` §2 (an AI kingdom fields an AI champion). D-057 (15)/(16) budgets and crest.

## Requirements
- Spawn a server-owned AI champion figure: `Kit.character` with the AI kingdom's governor look, on its mark, anchored or humanoid-driven. Give DuelRunner a real pose for it, so range and facing stop being virtual. Remove it at the crowning, on a cancel and on destroy.
- Equip each champion, human and AI, with `Kit.weapon` and `Kit.armour` from the loadout, in the kingdom colour. Remove them after the crowning and on a cancel.
- Call `Kit.arenaDress` with the two qualifiers' colours at arena begin. Reset it to neutral afterwards.
- Call `snapRuler` after each placement.
- Add specs for each item. No change to fairness numbers: G12.3 caps stay, and the fairness sweep must stay green.

## Validation
- Automated: `check.sh` green, fairness sweep green.
- Studio (user): play solo into the arena. The AI champion stands on its mark in armour with a weapon; you can walk out of its reach; both stands show the kingdom colours; after the crowning, nothing is left behind.

## Completion criteria
- [ ] PR into main, reviewed by FORGE-07, gated by FORGE-05. CONTRACTS G12.2 row drafted in the PR.

## Log
- 2026-10-19 FORGE-00: created from the v0.4-g11k pass. P0 for B23 RC: the arena cannot be called finished while the AI opponent is invisible.
