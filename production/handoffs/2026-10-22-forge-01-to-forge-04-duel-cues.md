# FORGE-01 → FORGE-04 (cc FORGE-00): the three Arena.Events cues for FL-0141

Additive; nothing existing changes. The snapshot stays as the fallback. CONTRACTS G12.4/G12.6 rows come at merge (FORGE-00).

| Event | side | data | When |
|---|---|---|---|
| `lightWindup` | the attacker | `{ impactIn }` seconds from this event to the strike | a light swing starts (the tick the input is read) |
| `dodgeStart` | the dodger | none | a dodge begins (accepted: stamina paid, not already dodging); it lasts `Duel.rules.dodgeTime` (0.35 s) |
| `hit` | the hitter | adds `blocked: boolean` | true when the target was guarding when the blow landed, also when the guard broke on that blow |

- `impactIn` is computed as for `heavyWindup` (the model's impact time less one tick), so the strike's `hit` event arrives at `t + impactIn` (pinned for 1/60, 1/30 and 0.05 s steps in `sim/DuelModel`).
- A swing that finds no one (out of range or facing away, or the target dodged) still announces `lightWindup`; `miss` and `dodged` stay inside as before. `lightWindup` does not reveal more than the snapshot's `light` state does, only earlier.
- Not added (FORGE-04: not needed): `blockStart` / `blockEnd`.
- Unknown kinds are ignored by `ArenaHudModel` and the crowd director today, so the server may ship before the client wiring.

Evidence (headless): `sim/DuelModel` 34/0, `sim/DuelRunner` 38/0, `sim/DuelAI` 11/0, fairness gate default size green; mutation rows `FL-0141C`.
