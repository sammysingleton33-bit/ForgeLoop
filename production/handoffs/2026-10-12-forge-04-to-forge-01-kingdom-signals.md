# Handoff: forge-04 → forge-01 · kingdom signals, client feed, citizen hooks · FL-0023/0024/0025 · 2026-10-12

## What I need / what I'm giving you
AI Kingdoms (Game #1, user directive 2026-10-12) needs gameplay signals that FORGE-04 turns into feedback, onboarding progress and analytics. I have coded against the proposal below with local doubles. Nothing breaks until you declare the events: my services subscribe through `Experience/Bus`, which skips undeclared names and logs once. Please (1) declare these as **additive** GameEvents through FORGE-05's contract PR, (2) add two client remotes, and (3) add a few instance hooks. Rename anything you like; tell me and I change one file (`roblox/src/shared/Experience/KingdomSignals.luau`).

## 1. Proposed server bus events (interfaces §4, additive)
All use **one payload shape**: `(player: Player?, info)`.
- `player` is the ruler of the acting kingdom, or `nil` for an AI kingdom.
- `info` always has `matchId` (= RoundService `roundId`) and `kingdomId`.
- `position` (Vector3) is where it happened.
- Events with a second party also carry that party's `userId`.

| Event | info (besides matchId, kingdomId) | Fire when (exactly once per successful action, §4 rule) |
|---|---|---|
| KingdomFounded | isAi, position | a kingdom is created at match start |
| CitizenTaskChanged | citizenId, task, previousTask?, position | a citizen's job changes (player order or AI) |
| ResourceProduced | resource ("Food" \| "Wood" \| "Stone" \| "Gold"), amount, total, buildingId?, position | resources are added to a kingdom's store (batch per building per tick is fine) |
| ConstructionStarted | buildingId, buildingType, position | a building is placed |
| BuildingCompleted | buildingId, buildingType, level, position | construction finishes |
| BuildingUpgraded | buildingId, buildingType, level, position | an upgrade finishes |
| KingdomUpgraded | tier | the kingdom tier rises |
| UnitsRecruited | unitType, count, position | units are recruited |
| BattleStarted | battleId, defenderKingdomId, defenderUserId?, position | armies engage |
| BattleEnded | battleId, defenderKingdomId, defenderUserId?, winnerKingdomId, attackerLosses, defenderLosses, position | a battle resolves |
| SiegeStarted | siegeId, defenderKingdomId, defenderUserId?, targetBuildingId?, position | siege begins |
| SiegeEnded | siegeId, defenderKingdomId, defenderUserId?, outcome ("Breached" \| "Repelled" \| "Abandoned"), position | siege resolves |
| TerritoryChanged | regionId, fromKingdomId?, fromUserId?, position | a region changes owner |
| MoraleChanged | morale (0–100), previous (0–100), reason | morale changes. Firing on every change is fine: I react only to band crossings (30/70) |
| KingdomEventStarted | eventId ("Festival" \| "Plague" \| "Drought" \| "Raid" \| …), severity (1–3) | a kingdom event begins |

Match lifecycle stays on the contract events:
- `RoundStateChanged` with `mode = "kingdoms"` and `roundId` = matchId;
- `RoundEnded(RoundResult)`, which my analytics uses per participant (placement, won, duration);
- `PlayerEliminated` with `cause = "Conquered"` when a kingdom falls.

Strings in `info` should be **display-ready or stable ids**. Toast templates show `{buildingType}` directly ("Farm complete"), so use "Farm", "TownHall", etc., or add a `buildingName` and tell me.

## 2. Client feed (two new remotes in `shared/Gameplay/Remotes.luau`)
| Remote | Kind | Payload | Why |
|---|---|---|---|
| `Gameplay.KingdomEvent` | serverEvent, to all clients | `(eventName: string, info)` mirroring the bus events above. Use `userId`s instead of Player objects; `kingdomColor: Color3?` is optional and tints effects. | `VFXController` (client) resolves cues per player: own kingdom, against me, or others |
| `Gameplay.SiegeImpact` | unreliableServerEvent, to all clients | `({ kingdomId, defenderKingdomId, position })` per projectile hit | high-frequency impact effects; dropping one is fine |

I already listen to the contract's `Gameplay.RoundState` and `Gameplay.RoundResult` for music and victory/defeat.

## 3. Instance hooks
- **Player attribute** `KingdomId` (string) on each player's `Player` instance, so clients know which kingdom is theirs.
- **Citizens:** tag `Citizen` (CollectionService) on each citizen model or part, with attributes `CitizenId`, `KingdomId`, and if possible `Task` and `Mood`. Models need a `PrimaryPart`.
- **Citizen emotes:** I set attribute `ForgeEmote` (one of `cheer`, `work`, `nod`, `slump`, `flee`) for about 2 s when a citizen reacts. If your citizen animator plays a matching animation, citizens visibly respond; otherwise only the speech bubble shows. Animations: request to FORGE-02.
- **Behaviour (living town):** during a `SiegeStarted` against their kingdom, citizens head to the keep; during a Festival, idle citizens gather in the square; at low morale (< 30) idle citizens slow down or sit. These are your systems. I only add bubbles and sounds.
- **Onboarding targets:** tags `OnboardingCastle` (the player's castle; the onboarding arrow and the "ReachedCastle" detector use it) and `OnboardingTownHall`. Tag only the local player's own buildings, or tag all of them and give each a `KingdomId` attribute; tell me which.
- **Camera shake:** `VFXController.shakeRequested: Signal (magnitude, duration)` (client). Please let your CameraController apply it. I never move the camera, and reduced motion is already filtered out before the signal fires.

## 4. Temporary seams I will remove when your code lands
- `roblox/src/shared/Experience/Validators.luau` mirrors the `Core/Validate` subset I need (string with UTF-8 check, enum, setting value). When FL-0007 lands I switch `Experience/Remotes.luau` to `Core/Validate` and delete the file.
- `roblox/src/shared/Experience/RemoteLink.luau` reaches remotes by the documented instance layout `ReplicatedStorage.ForgeRemotes.<Area>.<Action>`. When `Core/RemoteClient` lands I switch to it; only this file changes.
- Specs use local doubles of your APIs:
  - `roblox/tests/unit/experience/doubles/FakeDataService.luau` (§5: step-wise migrations, no downgrade, no partial write);
  - `roblox/tests/unit/experience/doubles/FakeRemoteService.luau` (§6: handle, fire, fireAll; drops invalid or extra arguments).
  If your real behaviour differs from these, tell me.

## 5. What my services assume about yours
- `SettingsService.new` calls `DataService:registerNamespace("experience", ...)`. It is the only registrant (§8). So SettingsService and OnboardingService **cannot boot until DataService exists**: FORGE-05 should merge my FL-0024/FL-0025 PRs after FL-0008.
- `DataService.loaded` fires per player after the profile loads. I push the settings snapshot then.
- `PlayerReady(player)` fires after the profile loads. My OnboardingService restores progress then, and AnalyticsService logs SessionStart; it reads `core.createdAt` for the day-2 funnel.
- `RemoteService:handle(name, fn(player, ...))` validates arguments against my declarations before `fn` runs.

## Done (with commits)
- `f04a61e` analytics bus rules (inert until the events exist); `9cc2e6b` feedback pipeline; `4bc54ec` onboarding (branch `forge/04-experience`).

## Evidence
- `bash roblox/scripts/check.sh` PASS (325 specs). The kingdom events are exercised in specs with `doubles/FakeBus.luau` (GameEvents + the proposal). On the real `GameEvents` bus, AnalyticsService logs `analytics: waiting for bus events not declared yet` and keeps working (spec "on the real GameEvents bus, kingdom rules wait without errors").

## Interfaces touched
Proposed additive changes to §4 (events) and §6 (two Gameplay remotes). Nothing edited outside FORGE-04 paths.

## Open issues and risks
- `ResourceProduced` frequency: I coalesce client-side (one sound per 1.5 s per resource) and analytics de-duplicates once-funnel steps. Still, please batch per building per production tick rather than per unit.
- Do AI kingdoms count as participants in `RoundResult`? Analytics only logs human participants still in the server.

## Next actions for the receiver
1. Agree or rename the events; open the additive contract PR with FORGE-05 (§4 table + `Contracts/GameEvents.luau`).
2. Declare `Gameplay.KingdomEvent` and `Gameplay.SiegeImpact`; set the `KingdomId` attribute and the `Citizen` tags.
3. Reply with a handoff when they are on `main`, so I can remove the doubles and seams.

## Files to read
- `roblox/src/shared/Experience/KingdomSignals.luau` — the names and payloads in code
- `roblox/src/shared/Experience/Cues.luau` — what each signal triggers for players
- `games/game-001/config/Onboarding.luau` — which signals complete tutorial steps
