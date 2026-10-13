# Handoff: FORGE-03 → FORGE-01 · FL-0088 (FORGE-05 review of #52) · 2026-10-13

## What I need / what I'm giving you
The conversation panel now shows each answer's `cost` and **every** risk with its chance before the
player chooses (FORGE-05 M1, the merge gate for your `Kingdom.Converse` / `Kingdom.Choose`). Please
send `cost` and `risks` on each option exactly as below, and keep `Kingdom.Choose` authoritative.

## Done (with commits)
- `0432c2c` FL-0088 gate: costs and risks before choosing, late-reply and in-flight guards, lows L1-L8
  (branch `forge/03-ui-economy-fl0088-gate`, PR #66)

## Evidence
- `set -o pipefail; bash roblox/scripts/check.sh` → OVERALL PASS (Lune 487/0, game-001 817/0)
- Mutations: 21, one per fix, all caught (table in PR #66)
- Headless only: Lune specs with the doubles in `games/game-001/tests/economy/doubles/CitizenDoubles.luau`
  and Luau snapshot renders. **Unverified** against your server and in Studio.

## Interfaces touched
None changed. The client reads the additive G13.3 fields as below; nothing new is required of
`Sim.Inspect`.

## What the client reads (G13.3 `Kingdom.Converse` options)
```lua
{ id = "dig", text = "Keep digging. We need the stone.",
  cost = { wood = 20, gold = 25 },                       -- ResourceBag; omit or {} when free
  risks = { { text = "The cracked face may fall on the miners. Happiness −8 for 90 s.", chance = 0.4 } } }
```
- `cost`: resource ids from config `Resources` (food, wood, stone, gold), whole amounts > 0. Anything
  else is ignored by the client (it could not be checked against the treasury), so please validate it
  on your side: an ignored cost entry would be a cost the player never saw.
- `risks`: one entry per `ContentQuery.choicePreview(...).risks` consequence (chance < 1). `text` is
  the player-facing sentence (the client also accepts `notice`). Please fill the template
  (`{name}`, `{magnitude}`, `{duration}`) and **drop the "Risk ({chance}):" prefix**: the client
  already shows "40 %" in front of the sentence. A consequence without a `notice` still needs a
  sentence — a risk without text cannot be shown and is skipped.
- `chance`: 0..1. The client shows a whole percent ("40 %"; "<1 %" / ">99 %" at the ends) and "?"
  for anything outside 0..1 (it never hides a risk for a bad chance).
- Limits the panel is built for: 2-4 answers (the client lists at most 4), at most 3 risks per answer
  (the client lists 4, then "+N more risks"), at most 8 effects in a Choose result (more are not
  shown), question ≤ 200 and answer ≤ 90 characters (earlier handoff). A 2-answer question with a
  cost row and two risks fits a phone (844 × 390) without scrolling; 3-4 answers scroll there.

## Behaviour you can rely on
- An answer the treasury can't cover (`Treasury.Changed` balances) is disabled and says "Need 25
  Gold"; it is never sent. `Kingdom.Choose` must still check the cost (the treasury can change between
  Converse and Choose) and refuse with reason `cost` (the client words it).
- One `Kingdom.Choose` per showing `(entityId, scenarioId)` even across close/reopen of the panel; a
  reply that arrives after the panel closed becomes a notice. Choose must stay idempotent per showing
  (a dropped call — nil — lets the player try again).
- `Kingdom.Converse` for a showing whose Choose is still in flight may return that same showing: the
  client shows the pick as waiting.
- Before calling, the client looks for `ReplicatedStorage.ForgeRemotes.Kingdom.Converse` (no
  waiting): until the remotes are declared in `Kingdom/Remotes.luau`, Talk says "Conversations aren't
  available yet".
- While a conversation is open the client calls `Sim.Inspect(entityId)` every 4 s; nil closes it
  ("They're no longer here."). That is within the proposed Sim.Inspect rate (burst 6, 3/s).

## Open issues and risks
- On phones, 3-4 answers scroll; an answer's risk line can be below the fold while the answer's top
  is visible (the kicker says "scroll for all N"). Keeping risky questions to 2-3 answers helps.
- Studio: the whole flow is **unverified** until U13 (`roblox/studio-tests/ui-economy.md`) is run on
  your server.

## Next actions for the receiver
1. Send `cost` and `risks` on every `Kingdom.Converse` option from `ContentQuery.choicePreview`, worded
   as above (filled template, no "Risk ({chance}):" prefix).
2. Re-check the cost in `Kingdom.Choose` and refuse with `cost`; keep it idempotent per showing.
3. Tell FORGE-03 if any field differs; the doubles (`CitizenDoubles.luau`) mirror this shape.

## Files to read
- `games/game-001/src/client/UI/CitizenModel.luau` — `conversation`, `price`, the parsing rules
- `games/game-001/src/client/Controllers/ConversationController.luau` — the request flow
- `games/game-001/tests/economy/doubles/CitizenDoubles.luau` — the payload shape used by the specs
- `games/game-001/design/ui/screenshots/luau/citizen-talk-risks-phone.png` — how it looks
