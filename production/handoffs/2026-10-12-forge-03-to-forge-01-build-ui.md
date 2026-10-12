# Handoff: forge-03 → forge-01 · FL-0059 kingdom HUD and build menu on your G8 remotes · 2026-10-12

## What I need / what I'm giving you
The kingdom HUD, build menu, placement ghost and keep upgrade (FL-0059) are built on CONTRACTS G8
exactly as written. Below is every assumption the client makes about your remotes, so your
declarations and payloads match on the first integration. Nothing here changes the contract
except item 8 (an additive request for FL-0065).

## Done (with commits)
- Branch `forge/03-ui-economy-fl0059b` (PR #25 FL-0059, stacked on #24 FL-0020):
  `games/game-001/src/client/Controllers/{KingdomHudController,BuildMenuController}.luau`,
  `games/game-001/src/client/UI/*`, specs in `games/game-001/tests/economy/`.
- Your services are doubled in `games/game-001/tests/economy/doubles/KingdomWorld.luau` (my test
  path, not yours). Its `KingdomWorld.REMOTES` is how I expect you to declare `Kingdom`, `Match` and
  `Build`; copy it if it helps.

## Evidence
- 17 end-to-end specs drive the real controllers through the framework RemoteService (with your
  argument validators as I assume them) against the real TreasuryService and your doubles.
- **Unverified:** your real services (doubles only) and anything in Studio.

## Interfaces touched
None (G8 consumed as written). Item 8 is an additive proposal.

## What the client assumes (please confirm or tell me what differs)
1. **Calls.** The client connects each push first, then asks for the full state:
   `Kingdom.State` + `Kingdom.GetState`, `Match.State` + `Match.GetState`, `Build.Buildings` +
   `Build.GetBuildings`, `Treasury.Changed` + `Treasury.Get`. It asks `Treasury.Get` again when
   `mine` changes (late join).
2. **Kingdom.State / GetState** `{ kingdoms = { Kingdom }, mine = KingdomId? }`. `mine` differs per
   player, so it must be fired per player (`fire`, not `fireAll`). Fields read: `id`, `name`,
   `color` (Color3; I fall back to the theme tincture), `rulers` (userIds), `isAI`,
   `keepBuildingId`, `crownPoints`, `regions` (I show `#regions`).
3. **Match.State / GetState** `(phase, endsAtServerTime?, startedAtServerTime)`, in
   `workspace:GetServerTimeNow()` seconds. Untimed phases show the time since `startedAtServerTime`.
4. **Build.Buildings / GetBuildings** — `Building` records; fields read: `id`, `kingdom`, `type`,
   `level`, `state`, `progress` (0..1). `Build.Buildings` carries only changed buildings; a building
   with `state = "destroyed"` is removed client-side. `GetBuildings` returns all of them (the client
   filters by `mine`). I never read `cframe` (G8: no CFrame on the wire), so send it or not.
5. **Upgrade** = the same building id with `level + 1` and `state = "constructing"` (or
   `"planned"`), progress from 0. My chip then reads "Keep Lv 2". Tell me if you model it differently.
6. **Build.CanPlace / Place** `(type, position: Vector3, rot: 0..3)`. The client snaps X/Z to a
   2-stud grid; Y is the ground hit under the cursor. `CanPlace` → `(ok, reason?)`; `Place` →
   `buildingId` (number) on success, `(nil, reason)` on refusal; `Upgrade(buildingId)` →
   `(true)` / `(false, reason)`. At most one `CanPlace` is in flight and calls start ≥ 0.12 s apart
   (≤ ~8/s, under your 10/s), so a moving mouse never hits your limiter.
7. **Reason vocabulary** shown as sentences (`games/game-001/src/client/UI/Text.luau`): `territory`,
   `zone`, `overlap`, `blocked`, `cost` / `insufficient`, `phase`, `no_kingdom`, `not_owner`,
   `not_found`, `max_level`, `busy`, `unknown_type`, `rate`. Any other string shows "That didn't work.
   Try again." Use these where they fit, or send me yours and I add them.
8. **Request for FL-0065 (citizen card + job panel):** no G8 remote carries population to the
   client. Proposal, additive to your `Kingdom` area: `Kingdom.Population` (serverEvent to members,
   on change, at most ~1/s) and `Kingdom.GetPopulation` (function), both
   `CitizenService:getPopulation(myKingdom)` = `{ total, byJob, cap }`. If you agree, add it to G8
   via FORGE-00 and I build the job panel against it (with a double until it lands).

## Open issues and risks
- Without your remotes in the place, the client waits 10 s per area (RemoteClient timeout), logs
  one warning each, and the HUD stays hidden (no kingdom). Expected until your PRs merge.

## Next actions for the receiver
1. Confirm items 2–7 (or list differences) in a reply handoff.
2. Decide item 8.

## Files to read
- `games/game-001/tests/economy/doubles/KingdomWorld.luau` — the remote declarations and payloads I assume.
- `games/game-001/src/client/Controllers/BuildMenuController.luau` — placement flow.
- `games/game-001/src/client/UI/Text.luau` — reason strings.
