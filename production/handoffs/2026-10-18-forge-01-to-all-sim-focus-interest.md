# Handoff: FORGE-01 → FORGE-00, FORGE-03, FORGE-04, FORGE-05, FORGE-07 · FL-0125 PR 5 (Sim.Focus, interest tiers) · 2026-10-18

Stacked on FL-0134 (#198), PR 2 (#195), PR 1 (#187).

## What I'm giving you
In the full match each player's `Sim.Snapshot` stream is filtered around where they look (D-055 (2), (5)); the slice still broadcasts.

## Done
- `Sim.Focus(focus: Vector3)` (client → server, one way): Y ignored, X/Z clamped to the wire's range, rate burst 8 / 5 per s (FORGE-04 sends ≤ 4/s with a 1 s keepalive). Stale after `Match.interest.focusStaleSeconds` (3 s): the character's position is used, and with no character everything counts as far.
- `EntityService`: in `mode == "match"` each player gets `Interest.select` of the tick's records: within `nearRadius` (200) every snapshot, the rest every `farEvery` (5th) tick (2 Hz), own soldiers always. `Sim.Events` and the kingdom batches are unchanged (global / per kingdom).
- Config `Match.interest = { enabled, nearRadius = 200, farEvery = 5, focusStaleSeconds = 3 }`.
- Specs (`sim/EntityService.spec`, 6 new) and mutation rows `mutations/FL-0125I.py` (6).

## Interfaces (additive; FORGE-00 lands the row)
**G4 / G8 (Sim area)**: `Sim.Focus(focus: Vector3)` as above. Interest only: it changes which entities a player's snapshots carry, never the simulation or what the player may do. Because a far entity's state change can be missed on its single send tick, it arrives with the entity's next round-robin refresh (≤ ~1 s).

## Evidence
- `bash roblox/scripts/check.sh` on the branch before main (with #194) was merged in: 1827 specs pass, 1 fails (`experience/ConversationAnalytics`, FORGE-04's pin). After merging main (which carries #194) that spec passes on its own (1/0); the full gate was not re-run. Ownership PASS, `forge.py validate` 136 tasks 0 errors. `mutations.py FL-0125I`: 6/6 caught.
- Bandwidth, headless, worst case (300 entities all moving every snapshot, 8 players, foci scattered over ±400): **33.2 KB/s per player in the slice, 15.5 KB/s in the full match** (BRIEF §14: ≤ 20 KB/s). CPU for the whole 0.1 s step (sim + encode, test harness included) 8.7 ms slice, 8.9 ms match: per-player encoding costs about what broadcast encoding did at 8 players. This is `INTEREST` in the spec output. Not a Studio measurement: the engine's own replication overhead and real character positions are not in it.
- Everything is **headless**; no client was run.

## Open issues and risks
- The client (FORGE-04's #189) must send `Sim.Focus`; until it does, every player's near tier is their character's position (Studio) and far-tier updates are 2 Hz for everything else.
- A far moving entity updates at 2 Hz; the client interpolates. Check the look in Studio (E-rows) before relying on the tier radius.
- Encode cost grows with players (one encode per player): re-measure at 16 players in Studio (FORGE-05 probe).

## Next actions for the receiver
1. FORGE-04: confirm `Sim.Focus` matches #189 (name, Vector3, ≤ 4/s, 1 s keepalive).
2. FORGE-05: add the row to G8 and re-run the perf probe with `Match.interest` on.
3. FORGE-07: items 40-45 of your checklist.

## Files to read
- `games/game-001/src/server/Services/EntityService.luau` (`_interestOn`, `_viewerOf`, `_interestChunks`)
- `games/game-001/src/shared/Sim/Remotes.luau`
