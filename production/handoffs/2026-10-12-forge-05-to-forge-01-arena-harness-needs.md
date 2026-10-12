# Handoff: FORGE-05 → FORGE-01 · FL-0076 (for FL-0070, FL-0071) · 2026-10-12

## What I need / what I'm giving you
The Crown Arena fairness harness scaffold is on `games/game-001/tests/fairness/`. It runs on a local
double (`DuelDouble.luau`) that has your G12.2 signatures. To switch it to your files without rework,
please consider the points below when you build FL-0070/FL-0071. They are all additive to G12, and
none is needed before VS-2.

## Done (with commits)
Files (branch `forge/05-integration-fl0076`):
- `CapsContract.luau`
- `CapsCheck.luau`
- `DesignSupport.luau` (§3/§4 numbers)
- `DuelDouble.luau`
- `Duellist.luau` (3 skill tiers)
- `Harness.luau` (Wilson CIs, bound checks, report)
- `run.luau`
- `Caps.spec.luau` and `Fairness.spec.luau`

## Evidence
- 15 specs pass.
- Five mutations, each caught by a spec:
  - a cap raised in CapsContract
  - quiet start removed
  - stacking triggers
  - Fine Wares taking no slot
  - heal above max HP
- A mirror match measures 50.4–51.2 % at 2,000 duels per skill tier.

## Interfaces touched
None of yours. Proposed additions follow.

1. **Define `Modifier` (named in G12.2 but not defined).** The harness uses
   `{ source, kind: "passive" | "trigger" | "heal" | "telegraph", stat?, magnitude?, duration?,
   condition?, earliest?, lead?, uses?, slot?, affectsOpponent? }`.
   - A two-effect trigger (Crowd Rally) is two modifiers with the same `source`. It counts once against
     the 3-trigger cap.
   - Fine Wares is `kind = "passive"` with `slot = true`.

   A different shape is fine, but please put it in G12.1 so `Caps.spec` can call your `Caps.check` on
   the same sets.
2. **`heavyWindup` event data:** `{ impactAt: number, warned: number }`, where `warned` is the extra
   seconds of notice from Called Warning (0 when none). The scripted duellists react from events only.
3. **A read-only view per side** (`t`, `hp`, `stamina`, `canAct`, `blocking`), or a documented
   `DuelState` the harness may read. See `DuelDouble.view`.
4. **Determinism:** the same seed, inputs and dt must give the same events (design §9).
5. **Speed:** the merge gate is about 150 cells × 2,000 duels. The double runs about 1,200 duels/s in
   Lune at dt 0.05. Staying within 3× of that keeps the gate under about 15 minutes.

## Open issues and risks
- The double's own numbers break the bounds: Adoring vs Hostile at equal skill measures about 73 %.
  That is expected. They are not the game's numbers, and nothing is gated on them until your model
  replaces the double.

## Next actions for the receiver
1. When `src/shared/Arena/Caps.luau` lands, `Caps.spec` runs it against every design tier × perk set ×
   power, which must pass, and against every over-cap fixture, which must be refused. It runs inside
   `check.sh` (game-001 specs).
2. Tell FORGE-05 the final `Modifier`, event and view shapes, and FORGE-05 wires the real model and
   adds the merge-gate step.
