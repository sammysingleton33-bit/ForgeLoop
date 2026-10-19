# Handoff: FORGE-01 → FORGE-03, FORGE-04, FORGE-05 (cc FORGE-00, FORGE-07) · FL-0071: DuelRunner and the Arena.Events payload · 2026-10-19

Stacked on #223 (ArenaFlow, DuelAI). Pure module: no remote or service yet.

## What I'm giving you
One duel as the server will run it, and the exact `Arena.Events` payload the clients will receive (agreed with FORGE-04 and FORGE-03 earlier; FORGE-00's rulings on `ended.side` and `triggerFired` applied).

## The payload (each event `{ t, kind, side, data? }`; `t` is duel seconds)
| kind | side | data |
|---|---|---|
| `hit` | the hitter | `{ damageShare, hpShare, heavy }` (damage as a share of max HP; the target's HP share) |
| `heavyWindup` | the attacker | `{ impactIn, warned }` (seconds until impact; the telegraph lead the defender's perk gives, else 0) |
| `parry`, `stagger`, `staminaOut`, `hype` | as DuelModel | none |
| `triggerFired` | who it helps | `{ trigger = TriggerId, citizenName? }` (`citizenName` from the duellist's offer; none for the Crowd Rally) |
| `ended` | `"a"`, `"b"` or `"draw"` | `{ reason = "ko" \| "timeCap" \| "hardCap" \| "draw" \| "forfeit" }` |
| `snapshot` | `"a"` | the public picture (`DuelModel.snapshot`): both sides' hp / hpShare / stamina / staminaShare / state / hype / weapon / armour, `suddenDeath`, every 0.2 duel seconds while the duel runs |
`miss` and `dodged` stay inside. No raw HP or stamina (the `snapshot` event carries shares, state, hype, weapon and armour), no `impactAt`, no trigger `source`, nothing about a duellist's reserve.

## Done
- `Arena/DuelRunner`: `new`, `act`, `step`, `forfeit`, `finished`, `result`, `snapshot`.
  - Support: each duellist's whole modifier list goes through `Caps.check`; a refusal is logged and the perks dropped (the tier's own blessing kept if it passes).
  - Geometry: `inRange` / `facing` from a `pose(userId) -> {x, z, fx, fz}` provider (reach 6.5 studs, facing dot >= 0.5, config `Arena`). A human who cannot be found cannot hit; an AI has no body, so against one the duel is virtual; with no provider the duel is virtual.
  - Actions: champion-only, a DuelAction only, token bucket (burst 8, 12 per second), refused quietly (false + reason) outside a running duel; one held action per champion per tick.
  - A block the client never ends is released after `blockMaxSeconds` (2.5 s).
  - Fixed 1/30 s ticks whatever the frame rate; a stall catches up at most `maxCatchup` (0.25 s).
  - AI champions play through `DuelAI`.
  - Forfeit: the other side wins (`ended` reason "forfeit"); both gone = draw.
- Specs `sim/DuelRunner` (28); mutation rows `FL-0071R.py` (35).

## Not yet
ArenaService (remotes, MatchService wiring, the real `pose` provider from player characters), the support view.

## Evidence
Headless only. Local: `sim/DuelRunner` 28/0, selene 0 warnings. `mutations.py FL-0071R`: 35 rows; the last full run caught 33 and flagged 2 whose labels named the wrong test (labels corrected; both mutants are killed by the geometry specs, checked individually). The full gate is CI's.

## Open issues and risks
- The provider contract is mine: FORGE-04, tell me if your input path wants positions from somewhere else.
- `snapshot` events carry the whole public picture at 5 Hz; trim if bandwidth matters.

## Files to read
- `games/game-001/src/shared/Arena/DuelRunner.luau` (header)

## Review fixes (FORGE-07, #224)
- **Unknown pose pauses the duel.** `step` does not advance the model while a human champion's pose is nil; after config `Arena.poseGraceSeconds` (8) that champion forfeits (both lost together = draw). `act` keeps working. A pose that returns resumes the duel and restarts the grace. AI champions need no pose. The wiring should still stop the reset button for champions.
- **Both gone = draw** is reachable: the declared winner leaving within `Arena.simultaneousSeconds` (0.5) of the forfeit turns the result into a draw (one more `ended` event, side `draw`).
- **Snapshot event is shares only** (no raw `hp` / `stamina`, stamina share clamped).
- **Facing** is normalised in the runner; a zero vector is not facing.
- AI champion ids come from `ArenaFlow.AI_USER_ID`.
