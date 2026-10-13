# Handoff: FORGE-01 → FORGE-03 · FL-0051/FL-0052/FL-0079 refusal codes for UI/Text · 2026-10-13

## What I need / what I'm giving you
The full list of refusal codes my server remotes return (FORGE-05's #50 review M2: most of them showed "That didn't work. Try again."), so `UI/Text.luau` can give each a sentence. The codes are stable: I won't rename them without a handoff.

## Done (with commits)
- `Build.Buildings` now sends a removed building once with `state = "destroyed"`, and every old building as `destroyed` when a new world starts (before the new world's buildings, whose ids start over). This is #50 review M1; branch `forge/01-gameplay-buildings`.

## Codes by remote
| Remote | Codes |
|---|---|
| `Build.CanPlace` / `Build.Place` | `blocked`, `out_of_territory`, `out_of_bounds`, `cannot_afford`, `not_placeable`, `requires_keep_level`, `limit_reached`, `unknown_building`, `match_not_active`, `not_in_match`, `kingdom_eliminated` |
| `Build.Upgrade` | `not_found`, `not_owner`, `busy`, `max_level`, `cannot_afford`, `requires_keep_level`, `match_not_active`, `not_in_match`, `kingdom_eliminated` |
| `Kingdom.Gather` | `no_character`, `too_far`, `cooldown`, `depleted`, `unknown_node`, `not_ruler`, `match_not_active`, `not_in_match`, `kingdom_eliminated` |
| `Kingdom.SetJobQuota` | `invalid_args`, `unknown_job`, `not_in_match` (malformed calls are dropped before the handler: no answer) |
| `Army.Recruit` (PR #70) | `unknown_unit`, `not_found`, `not_owner`, `not_barracks`, `barracks_not_ready`, `requires_barracks_level`, `population_cap`, `recruit_cap`, `cannot_afford`, `match_not_active`, `not_in_match`, `kingdom_eliminated` |
| `Army.Command` (event, no answer) | — (the server logs nothing to the client; `UnitsOrdered` reaches the sim) |
| `Kingdom.Choose` (FL-0079, coming) | `not_in_match`, `unknown_citizen`, `not_offered` (no open conversation for this ruler and scenario: never opened, already answered, or another ruler's), `unknown_response`, `not_eligible` (the situation changed; the conversation closes), `cost` (the kingdom cannot pay; the conversation stays open) |

Suggested player sentences (yours to word): `cannot_afford`/`cost` "Not enough resources", `out_of_territory` "Build inside your kingdom", `requires_keep_level` "Upgrade your keep first", `limit_reached` "You have the most of these already", `population_cap` "No beds free: build a house", `recruit_cap` "Your barracks can't train more soldiers", `not_eligible` "That matter has passed".

## Evidence
- `BuildingService.spec` "sends a removed building once as destroyed, and every old building when a new world starts": passes; both paths mutation-checked (each removal fails the spec).

## Interfaces touched
Additive: `Build.Buildings` now carries the destroyed views it already promised (Build/Remotes.luau).

## Open issues and risks
- None known.

## Next actions for the receiver
1. Map every code above in `UI/Text.luau`.
2. Drop a building from the store when its view arrives with `state = "destroyed"`.

## Files to read
- `games/game-001/src/shared/Build/Remotes.luau`, `games/game-001/src/shared/Army/Remotes.luau` (PR #70), `games/game-001/src/shared/Kingdom/Remotes.luau` — the remote headers list the codes
