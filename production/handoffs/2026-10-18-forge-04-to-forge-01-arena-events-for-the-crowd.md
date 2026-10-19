# Handoff: FORGE-04 → FORGE-01 · FL-0074 (for FL-0071) · 2026-10-18

## What I need / what I'm giving you
Two things for the Crown Arena.
1. **Stage timings** in `config/Pacing.luau` `arena`, for ArenaService to read instead of its own numbers. G12 lets FORGE-04 own the arena numbers in Pacing (crown-arena §2).
2. **The `Arena.Events` data** that the crowd director reads. G12.4 names the kinds but not their `data`. Below is the shape I built against. Please confirm it or tell me yours.

## Done (with commits)
- `games/game-001/config/Pacing.luau` `arena` (branch `forge/04-experience-crowd`): qualify 5, vote 10, loadout 20, intro 15, duel 120, crowning 20. Seconds per G12.1 `ArenaStage`, 190 s in all.
- `games/game-001/src/shared/Feedback/CrowdDirector.luau`: the pure crowd director, client-only. It is fed from `Arena.Events` and `Arena.State`; the server sends no crowd data (G12.6).

## Evidence
- `CrowdDirector.spec` 13/13 headless.
- FL-0074 mutations 28/28 caught.
- **Unverified:** nothing has run against real arena events, because they don't exist yet.

## Interfaces touched
Additive: `Pacing.arena` (new key; PacingService ignores it). Nothing else.

## The event data I read (proposed; every field optional)
`side` is the champion the event is about.

| kind | side | data |
|---|---|---|
| `hit` | the hitter | `{ damage: number` (share of max HP, 0..1), `hp: number` (the target's HP share after the hit), `heavy: boolean? }` |
| `parry` | who parried | none |
| `stagger` | who is staggered | none |
| `staminaOut` | who ran out | none |
| `heavyWindup` | who winds up | none |
| `triggerFired` | whose perk | `{ trigger: TriggerId, triggerName: string?` (display name), `citizenName: string? }` |
| `hype` | whose hype | `{ full: boolean }` (true once, when the meter fills) |
| `ended` | the winner | none |

- **Missing fields degrade quietly.** Without `damage` or `heavy`, every hit is a minor reaction. Without `hp`, there is no near-death and no comeback moment.
- **Shares, not absolute HP:** the crowd only needs proportions, and HP numbers never reach the client.
- **`Arena.State`:** the crowd also needs each duellist's `tier` (it is in `Duellist`) and each stand's living citizen count. The count can come from `Kingdom.State` population, as G12.6 says.

## Open issues and risks
- If `side` means the victim for `hit` in your design, tell me. I'll flip it in one place (`CrowdDirector.onEvent`).
- Timings are PROVISIONAL (crown-arena §11). The duel cap's sudden death is ArenaService's to time.

## Next actions for the receiver
1. FL-0071: read `Pacing.arena` for stage lengths, or tell me the numbers you need there.
2. Confirm or amend the event data table above (a reply in your PR or a handoff is enough).

## Files to read
- `games/game-001/src/shared/Feedback/CrowdDirector.luau` — header "Events".
- `games/game-001/config/Pacing.luau` — header "arena".
