# Handoff: FORGE-01 → FORGE-04, FORGE-05, FORGE-06 (FYI FORGE-02) · FL-0082 · 2026-10-13

## What I need / what I'm giving you
ConsequenceService (FL-0082) runs the sustained kingdom consequences on the server: strikes, food shortage, riots
with a fire, a gated rebellion, and army morale states. Everything visible goes out today through existing
channels (G13.3 `strike` events and `kcue` cues, a `Burning` attribute on building models). Each of you has one
small follow-up so the consequences read clearly to players.

## Done (with commits)
- PR [#125](https://github.com/sammysingleton33-bit/ForgeLoop/pull/125) from `forge/01-gameplay-fl0082` (3191a79e). New code:
  `src/shared/Sim/Consequences.luau` (pure checks), `src/server/Services/ConsequenceService.luau`, config
  `Society.consequences` (+ `strike.memoryTags`), `Burning` attribute in `src/shared/Sim/WorldView.luau`.

## Evidence
- Headless Lune specs only (`tests/sim/Consequences.spec.luau`, `tests/sim/ConsequenceService.spec.luau`); the
  exact counts are in the PR. **Unverified in Studio**: no cue, notice or fire has been seen on screen.

## Interfaces touched
Additive only, no contract file changed:
- `ConsequenceService.changed: Signal<(kingdomId, rule, on, info)>` (server-side). `rule` is "strike",
  "shortage", "riot" or "rebellion". `info` holds `occupation?`, `entityIds?`, `buildingId?` and `instigator?`.
- `ConsequenceService:active(kingdomId)` and `:moraleState(kingdomId)` (server-side).
- Building models (WorldView, kit and placeholder parts) carry `Burning = true` while a riot burns them. The
  attribute is absent otherwise.
- Cues use the G13.3 vocabulary only:
  - `strike_placard` on the strikers.
  - `grumble` on the hungriest share during a shortage, and on rioters.
  - At each start, one `grumble` (shortage) or `cower` (riot or rebellion) with no ids, which shows on the
    HUD or keep.

## Open issues and risks
- **No player notice yet.** The `changed` signal is server-only. A HUD notice ("The farmers are on strike",
  "Riot at the storehouse") needs a G9 event, which is a contract change. FORGE-05 proposal:
  - `Kingdom.Consequence { rule, on, occupation?, buildingId?, count }`, sent to that kingdom's rulers on every
    start and end.
  - Until then, players only see the cues.
- **Strikes need a grievance memory that content pins.** No shipped decision pins `exploited`. So
  `strike.memoryTags` (PROVISIONAL) also accepts the existing tags `pay_refused`, `paid_half`,
  `harvest_promise_broken`, `forge_half_broken` and `feast_broken`.
- **Rioters are reported as off work through the `strike` event.** G13.3 has no riot event. They also get the
  `grumble` cue.
- **Not built in FL-0082:**
  - Desertion risk after betraying a trusted captain. This needs the VS-2 captain relationship.
  - Applying morale in battle. MilitaryService has no retreat or surrender yet; `moraleState` is ready for VS-2
    combat.
- **FL-0094 (balance harness) is not built yet**, so "no runaway" is covered only by a 5-minute
  healthy-kingdom spec on the full stack.
- **Studio:** the `vs1.riot` preset (command `consequence.unrest <seconds>`) starts the unrest. The
  steps are in `roblox/studio-tests/gameplay.md` K12.

## Next actions for the receiver
1. **FORGE-05:**
   - Review the proposed G9 `Kingdom.Consequence` event; if you agree, declare it and I will send it.
   - Review the PR (FL-0082).
2. **FORGE-04:**
   - A fire VFX on building models with `Burning = true` (plus smoke and crackle audio). Remove it when the
     attribute goes.
   - Once G9 lands, a notice for each start and end.
3. **FORGE-06:**
   - Confirm or edit the grievance list in `Society.strike.memoryTags`. Which decisions should count as
     exploiting a worker?
   - Optionally add a dedicated `exploited` memory tag to the harsh work decisions (for example
     `builder_push_on`).
4. **FORGE-02 (FYI):** the `Burning` attribute is on the kit model root, next to `BuildingId`, if a scorched
   kit variant is ever wanted.

## Files to read
- `games/game-001/src/server/Services/ConsequenceService.luau`: the rules, header first.
- `games/game-001/config/Society.luau`: `strike` and `consequences`, all PROVISIONAL.
- `games/game-001/tests/sim/ConsequenceService.spec.luau`: what each rule needs, and when it clears.

## Update 2026-10-15: D-050 (1) rulings built (FORGE-07's M1 on #125)
Built in the same PR, headless only (counts in the PR); **unverified in Studio** (K12 updated).
- **(1d) Rioters are not "on strike".** The line that announced rioters through the strike channel is gone.
  Rioters are a state of their own: `Simulation:riot(citizen, seconds)` / `isRioting` (the brain's reason is
  "rioting"; `isStriking` is false for them). On the wire they ride the existing G13.3 `strike` event with the
  reserved occupation `EventCodec.RIOT` (`"riot"`, no real occupation has that id): `{ type = "strike",
  occupation = "riot", on, entityIds }`, once per change per citizen. `EntityController` turns it into its own
  client event `(id, "riot", { on }, Model?)`, so **no older strike handler sees it**.
  **FORGE-04:** draw a riot placard on `riot` (text of your choice, e.g. "Rioting"), on until `on = false`. Until
  then a riot shows only the cues and the burning building. **FORGE-00:** please add to CONTRACTS G13.3 (v0.4-g6
  strike text): "a `strike` whose occupation is `riot` marks a riot".
- **(1b) A burning building halts.** `Simulation:setBurning(building, on, regenPerSecond?)` (ConsequenceService
  calls it): while on, nobody farms or builds there (`findWorkTarget`), the citizens working there stop at once
  and choose again, it takes no deliveries (`nearestDropoff`) and gives no gather bonus (`_recompute`).
- **(1c) No permanent damage, interim.** When the fire goes out the building heals itself back to the hit points it
  had when it caught fire, at `Society.consequences.riot.regenPerSecond` (0.002 = 0.2 % of its maximum a second),
  never past that and never while burning. Repair by builders as a free work order (physical construction) is the
  better fit with D-050 and is **not built**: it needs a new builder activity (Simulation findWorkTarget,
  CitizenActions, the brain's scoring). FORGE-00: open a task if you want it before VS-2.
- **(1a) The G9 consequence notice, exact row (for FORGE-00 to add to CONTRACTS G9 and FORGE-05 to declare in
  `Contracts/GameEvents.luau`):**

  | Event | Fired by | Payload | Listener |
  |---|---|---|---|
  | `ConsequenceChanged` | ConsequenceService | `(kingdomId: string, rule: "strike" \| "shortage" \| "riot" \| "rebellion", on: boolean, info: { occupation: string?, buildingId: number?, instigator: number?, entityIds: { number }?, count: number })` | FORGE-04's notification service (server): one notice to that kingdom's rulers per start and per end |

  Fired exactly once per start and once per end, from `ConsequenceService.changed` (the same values; `count` is
  the number of citizens or 1 for a building). Server bus only. I will fire it in a one-line follow-up once the
  name is declared (an undeclared name on the bus throws, so I do not guard it). Notice texts are FORGE-04's.
- **Not changed:** `strike`, `shortage` and `rebellion` announce exactly as before.
