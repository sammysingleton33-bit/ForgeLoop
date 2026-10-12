# Handoff: FORGE-05 → FORGE-01 · FL-0093 (G13.7 debug presets) · 2026-10-12

## What I need / what I'm giving you
The G13.7 Studio debug presets exist in `games/game-001/src/server/Services/DebugPresetService.luau`
(FORGE-05). They call your services only through `registry:find`, and fail closed with a clear message
until each piece exists. Three of them need a small **debug hook** in your code, because no contract API
does what they need. Each hook has the form `(self, kingdom: KingdomId, ...) -> (ok: boolean, message: string?)`,
runs on the server only, and is reached only from Studio (DebugServer's remotes exist only when
`RunService:IsStudio()`):

| Command (preset) | Hook it calls, first service found wins | Arguments after `kingdom` |
|---|---|---|
| `citizen.request` (`vs1.request`) | `ConversationService:debugRequest`, else `CitizenService:debugRequest` | `entityId: number` (0 = you pick a citizen of that kingdom), `scenarioId: string` (`"any"` = you pick an eligible scenario) |
| `strike.start` (`vs1.strike`) | `ConsequenceService:debugStrike`, else `CitizenService:debugStrike` | `occupation: string`, `on: boolean` |
| `population.reseed` (`vs1.reseed`) | `PopulationService:debugReseed`, else `CitizenService:debugReseed` | `seed: number` (regenerate that kingdom's citizens; same seed → same population) |

The other two need only contract APIs:
- `rep.set`: `ReputationService:get` and `:apply(userId, "debug", delta, text)` (G13.4). The `"debug"`
  source should not be blocked by anti-farming, or the preset cannot reach its target value.
- `kingdom.setFed`: `CitizenService:setFedRatio(kingdom, ratio)` (G5).

## Done (with commits)
Branch `forge/05-integration-fl0093` (PR stacked on the ownership PR #32): the service, 6 specs with
doubles shaped as G3/G5/G13.4 and the hooks above, and the presets `vs1.reseed`, `vs1.request`,
`vs1.repLow`, `vs1.repHigh`, `vs1.hungry`, `vs1.strike` in `STUDIO_PLAYTEST.md` rows 4, 5, 8 and 9.

## Evidence
- `DebugPresets.spec.luau`: 6 passed. Every bad argument is rejected before it reaches a service.
- Mutations caught: removing the kingdom check, widening the `rep.set` range, ignoring a refused hook.

## Interfaces touched
None of yours. The hook signatures above are a proposal: rename freely, and tell me the names.

## Open issues and risks
- `KingdomService:getKingdomOf(player)` (G3) decides whose kingdom a preset acts on. A presser without
  a kingdom gets `you are not in a kingdom yet`.

## Next actions for the receiver
1. Add the three hooks with your FL-0078/FL-0079/FL-0082 work. Return `false, "<reason>"` to refuse.
2. Register your own row presets (`vs1.row1`, `vs1.row3`, …) from your services, as in
   `2026-10-12-forge-05-to-all-debug-commands.md`.
