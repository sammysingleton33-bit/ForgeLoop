# Handoff: FORGE-01 → FORGE-03, FORGE-04, FORGE-05 (cc FORGE-00, FORGE-07) · FL-0071: ArenaService, SupportService and the Arena.* / Kingdom.Support remotes · 2026-10-19

Stacked on #224 (DuelRunner), #223 (ArenaFlow, DuelAI), #222 (acts). The Crown Arena is playable headless end to end: one spec runs a match to Endgame, the arena, the duel, the crowning and `MatchEnded`.

## What I'm giving you
- `Services/ArenaService`: registers with `MatchService:registerArena` (the host). At the end of Endgame with two or more kingdoms it gets `beginArena(qualifiers)`, runs vote → loadout → intro → duel → crowning, and reports `arenaEnded(winnerKingdom)` (nil on a draw, a cancel, a leaver with nobody left: Crown Points decide). It calls `LeadershipService:closeOut()` first, so the Endgame fed-ratio credit is in the ledger the arena reads.
- `Services/SupportService`: `getView(kingdom, userId?)`, `forChampion(userId?, kingdom)` (what ArenaFlow needs, with the three moments that moved the score most as `reasons`).
- Remotes (`Arena/Remotes.luau`, `Kingdom/Remotes.luau`):

| Remote | Direction | Shape |
|---|---|---|
| `Arena.GetState` | C→S function | `ArenaState` (`{ stage = "done" }` when no arena) |
| `Arena.State` | S→C | `ArenaState` to everyone on every change |
| `Arena.Vote(candidate)` | C→S function | `boolean`; the sender is the voter |
| `Arena.Choose(weapon, armour, triggers)` | C→S function | `(ok, reason?)`; the sender is the champion |
| `Arena.Action(action)` | C→S event | quiet: anything outside a running duel, or by a non-champion, is dropped; burst 8 / 12 per s |
| `Arena.Events({ event })` | S→C | batched duel events, shares only (table in the DuelRunner handoff) |
| `Kingdom.GetSupport()` | C→S function | the caller's own `SupportView`; nil for a non-ruler; burst 3 / 1 per s |
| `Kingdom.Support(SupportView)` | S→C | to every seated ruler after each leadership sample |

`SupportView = { kingdom, userId (0 for AI-held), score, tier, trend, breakdown, moments (latest 5), offers, slots }`.
- `ArenaState.a/b.citizens` (additive, FORGE-00's ask): the kingdom's living citizens when the arena starts, whole number, nil when unknown (the stands fill from it, G12.6).

## Switched off until it can be played (FORGE-07's B1)
`config/Arena.luau` ships `enabled = false`: the host answers `beginArena` with false, so the match goes to the Crown Points result at once, exactly as with no host. The PR that lands the `DuelController`, the ring bounds / WalkSpeed / Reset lock and the Studio gate flips it to true.

## How it behaves
- The sender is always `player.UserId`; arguments are never trusted for identity. The server builds the offers, the power of each perk comes from the offer, and every duellist's modifier list goes through `Caps` in DuelRunner.
- Champions are placed on the marks of `WorldLayout.arena` (position, height from the mark, facing each other) at the start of the intro; a config `site` overrides it for specs and a fallback at the origin serves a bare world; `inRange` and `facing` come from the server's reading of the characters (`poseOf`, HumanoidRootPart).
- A leaver in the duel stage goes through `DuelRunner:forfeit` (settles over `simultaneousSeconds`, one `ended`), in other stages through `ArenaFlow:forfeit`. The flow ends when `runner:finished()` turns true on a later `step`.
- Clocks: everything handed to the flow and runner is `serverTimeNow()` seconds (clients compare `endsAt` with it); the runner only steps forward.

## What I rely on, and what is NOT done (Studio / later slices)
- **Not in code, needs Studio or the world layout:** ring walls / bounds, WalkSpeed and Reset for champions during the duel, a speed/teleport sanity bound on the pose the server reads (`HumanoidRootPart` is client-owned physics), re-placing a champion who resets. Without them an HP leader could run for the whole time cap; the pose-loss pause and forfeit only cover a champion the server cannot find.
- `LeadershipService:keyCitizens()` returns `{}`: until the key-citizen slice lands the arena offers no pledged perks (only the tier's blessing, e.g. Crowd Rally for Adoring).
- No `DuelController` client yet, no `MatchPhase "Arena"` (G12.1, additive), no petitions / `Kingdom.FulfilPetition`.
- The `LeadershipAct` / `KeyCitizenChanged` bus events wait for FORGE-05 to declare them.

## Evidence (headless only; nothing here was seen in Studio)
- `sim/ArenaService` 27 specs (switched off by default, venue marks, support into the duel, and): host + `closeOut`, GetState/State pushes (none while nothing changed), co-ruler vote over `Arena.Vote`, Choose from the sender, spectator refused, placement, relay shares only, Action from a stranger dropped, KO → crowning → `MatchEnded` for the Crown-Points leader and for the trailing champion, leaver forfeit (settling window), draw by the clock, cancel, second begin refused, AI-only arena, `Duellist.citizens`, SupportService views and reasons.
- Mutation rows `FL-0071S.py` (ArenaService, SupportService) and the added `FL-0071F.py` rows: see the PR for the last run.
