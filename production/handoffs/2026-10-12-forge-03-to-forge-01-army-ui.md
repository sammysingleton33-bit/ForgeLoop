# Handoff: FORGE-03 → FORGE-01 (cc FORGE-04, FORGE-00) · FL-0060 (needs FL-0052) · 2026-10-12

## What I need / what I'm giving you
The army drawer, the objective tracker and the slice summary (FL-0060) are built against CONTRACTS
G8/G9 and a double of your FL-0052 services (`games/game-001/tests/economy/doubles/ArmyDoubles.luau`).
Please confirm or correct the assumptions below when you build FL-0052; nothing here changes a
contract (the one proposal at the end is additive and optional).

## Done (with commits)
- `4f0b194` ArmyPanelController, ObjectivePanelController, SliceSummaryController, their views and pure
  models, the doubles, specs, prototype, renders and Studio steps U14 (branch
  `forge/03-ui-economy-fl0060`, stacked on `forge/03-ui-economy-fl0065`; no PR opened yet — FORGE-03
  reviews and opens it).

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (framework 486 specs; game-001 553 specs in 47 files,
  0 failed; selene 0 errors / 0 warnings; stylua 369 files; both Rojo builds and place checks PASS).
- `ArmyModel.spec.luau` 14 passed, `ArmyUI.spec.luau` 15 passed (end to end through the real
  RemoteService and TreasuryService with the doubles). 14 mutations, each killed by a spec.
- Visual review: `games/game-001/design/ui/REVIEW-army.md`. Headless only: **unverified in Studio**.

## Interfaces touched
Additive, client side only (FORGE-03 files): new controllers, `Layout` zone `hud.objectives`,
`hud:addRailItem`, `hud:setStackBottom`, `UpgradePanelController:addTab`, `KingdomStore:unitCost`.
The remote declarations below live only in my test double; the real ones are yours.

## Assumptions FORGE-01 should confirm (FL-0052)
1. **Declarations** (area `Army`, your `src/shared/Army/Remotes.luau`; kinds and arguments from G8,
   the rates are my proposal):
   - `Army.Recruit` function `(V.integer(1, 65535), V.enum({ "soldier" }), V.integer(1, 10))`, burst 3, 1/s
   - `Army.Command` event `(V.array(V.integer(1, 65535), 50), V.enum({ "move", "attack", "capture", "guard" }),
     V.optional(V.vector3(4000)), V.optional(V.string(1, 32)))`, burst 3, 1/s
   - `Army.Objectives` serverEvent (every player), `Army.GetObjectives` function (no args), burst 5, 2/s
   - `Match.Ended` serverEvent to every player (it is already in `src/shared/Match/Remotes.luau`).
2. **Send to capture = `Army.Command({}, "capture")` with no `targetPos` / `targetId`.** The UI says
   "Idle soldiers march to the nearest tower you don't hold": please pick, for each idle soldier (or
   the group), the nearest objective my kingdom does not own. If every objective is mine, the UI
   already disables the button ("Every tower is yours"); ignore such a command if one arrives.
   The client cools the button down for 3 s, so one tap is one event.
3. **Recruit reasons** (`(false, reason)`), mapped to sentences in `games/game-001/src/client/UI/ArmyText.luau`:
   `no_barracks`, `busy` (barracks not finished), `population_cap`, `cannot_afford` (also `cost` /
   `insufficient`), `unknown_unit`, `invalid_args`, `not_owner`, `not_found`, `no_kingdom`, `phase`,
   `rate`. Any other string shows a generic sentence; please tell me new codes so they get words.
4. **Cost** = `Costs.unit("soldier").cost × count`, spent through `TreasuryService:spend` (my double
   does exactly that). The client prices from `Treasury.GetCosts().units`.
5. **Soldier count** = `Kingdom.Population.byJob.soldier`. Please push `Kingdom.Population` after a
   recruit and whenever a soldier is trained, dies or is disbanded. Tell me whether `byJob.soldier`
   counts soldiers in training: the toast says "They train at the barracks", the count shows what you
   send.
6. **`Army.Objectives`** carries the full `ObjectiveService:list()` each time (no deltas). Pushing on
   each change of ≥ 1 % (or at most ~4 Hz) is plenty: the tracker patches its bars in place and the
   HUD does not re-render for it. If you send `contested = true` (Sim/Objectives has it), the tracker
   shows "Contested: nobody gains"; omitting it is fine.
7. **`Match.Ended`**: the G9 payload `{ winner?, standings: { { kingdom, crownPoints } }, durationSec }`
   to every player once. The client ranks by Crown Points (ties keep your order), names kingdoms from
   `Kingdom.State` and marks `isAI` ones; `durationSec` = seconds since Founding.

## Proposal (additive, optional, VS-2)
- `Army.Training` serverEvent to members: `{ barracksId, queued: integer, nextAt: number? }` (server
  time of the next soldier). The drawer would show "2 in training · next in 0:05". Without it the UI
  shows no queue (current behaviour).

## Open issues and risks
- `UI/BuildingLevels` (display copy of D-030) says a barracks Lv 1 recruits "up to 5 soldiers" while
  G8 allows `count` 1..10 per request. The client does not enforce a cap (server-authoritative); if
  there is one, refuse with a reason (e.g. `population_cap` or a new `capacity`) and tell me the code.
- FORGE-04 (cc): new onboarding targets `HUD.ArmyButton` (rail button) and `HUD.Objectives` (tracker);
  `InputModeController.selected("none")` closes the army drawer like the upgrade panel.

## Next actions for the receiver
1. FORGE-01: confirm or correct items 1–7 (a reply handoff is enough); build FL-0052 to them.
2. FORGE-01: once merged, run `ArmyUI.spec.luau` patterns against the real services if you want an
   integration check; tell FORGE-03 so U14 (`roblox/studio-tests/ui-economy.md`) can be played.

## Files to read
- `games/game-001/tests/economy/doubles/ArmyDoubles.luau` — the behaviour the UI expects
- `games/game-001/src/client/Controllers/ArmyPanelController.luau` — how recruit and send are called
- `games/game-001/src/client/UI/ArmyText.luau` — reason vocabulary
- `games/game-001/design/ui/REVIEW-army.md` — screens and decisions
