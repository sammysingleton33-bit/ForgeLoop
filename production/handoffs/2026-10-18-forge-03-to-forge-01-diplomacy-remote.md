# Handoff: FORGE-03 → FORGE-01 · FL-0129 (Operation Crownfall) · 2026-10-18

## What I need / what I'm giving you
**Update 2026-10-18: FORGE-01 accepted this as the D-054 (1) contract, with these final changes, which
the client now follows:** `seniors = { [KingdomId] = UserId? }` (not `senior`); the senior ruler gets
`Kingdom.WarAsk(requesterUserId, requesterName, target)`; codes `not_senior` / `newcomer_lock` are final;
FORGE-01 owns M2 (the state signature). Recruit gains `army_cap` (D-055), mapped in ArmyText.

The war and peace panel (Kingdom → Rivals) is built and tested against a proposed diplomacy contract.
It stays hidden until the server declares the remote. Please serve these two rows (or tell me your
names and I'll switch; it is one constant and one store field on my side).

## Done (with commits)
- `8df0c78f` phase bar: the full match's phase track and "Next: <phase>" on the HUD timer (Match.State, on main)
- `d1611a24` Rivals tab: UI/DiplomacyModel, UI/RivalsList, KingdomHudController wiring, doubles/DiplomacyDoubles
  (branch `forge/03-ui-economy-crownfall`)

## Evidence
- `economy/Diplomacy.spec` 9/0 and `sim/Diplomacy.spec` 15/0 (Lune, headless; not a Studio play test).
- `tests/economy/mutations/FL-0129.py` → 20/20 caught.
- Renders `kingdom-rivals(-confirm)-{desktop,phone-se}.png`, looked at by eye.

## Interfaces touched
Additive, proposed (not on main). Client → server, my area's caller, your server:

| Row | Shape |
|---|---|
| `Kingdom.Diplomacy` (RemoteFunction) | `(action: "declareWar" \| "proposePeace" \| "acceptPeace", target: KingdomId) -> (ok: boolean, reason: string?)`; reasons = Sim/Diplomacy codes: `invalid_args`, `unknown_kingdom`, `grace_period`, `already_at_war`, `peace_cooldown`, `not_at_war`, `no_proposal` |
| `Kingdom.State` payload, new field `diplomacy` | `{ relations = {{ a, b, relation = "Peace" \| "War" }}, proposals = {{ from, to, expiresAt }}, cooldowns = {{ a, b, untilAt }}, graceEndsAt?, senior?, lockedUntil? }`; times in server time (the G3 `endsAt` scale); unlisted pairs are at Peace |
| D-054 fields (per receiving player) | `senior: UserId?` = my kingdom's senior ruler now (idle rule (6) included); `lockedUntil: number?` = when my newcomer lock ends (absent for Lobby-seated rulers, (7)) |
| War result tag (FORGE-07 M1 on #180) | a successful `declareWar` returns `(true, "declared")` or `(true, "asked")`; the client's toast comes only from this tag ("War declared on <name>" / "Asked your senior ruler for war on <name>"; no tag → "War request sent: <name>"), never from its own copy of the senior |
| D-054 behaviour | a non-senior's `declareWar` returns `(true, "asked")` and the server notices the senior ruler; a non-senior's `acceptPeace` → `(false, "not_senior")`; while locked, `declareWar` / `acceptPeace` → `(false, "newcomer_lock")`; `proposePeace` is open to every ruler |

The client only explains why a button is off (before Conflict per D-053 (2), grace, truce, my open
offer); the server stays the authority and every refusal is shown in words.

## Open issues and risks
- **Replication (FORGE-07 M2 on #180, server side):** `Kingdom.State` is re-sent only when
  `MatchHost._stateSignature` changes, and that signature has no diplomacy in it and is shared by all
  players. A declared war, an offer, a truce or a seniority flip would not reach the client. Put
  relations, proposals, cooldowns and each kingdom's senior (and the newcomer lock) in the signature,
  per player where it is per player, or give diplomacy its own server event. Tell me which; the client
  only needs `KingdomStore:applyKingdoms` (or one new handler) to receive it.
- **Always send the field while the remote is served** (FORGE-07 L3): the client now treats a
  `Kingdom.State` without `diplomacy` as "no wars" and clears what it had.
- **G8 text (FORGE-07 L4):** confirm `not_senior` / `newcomer_lock` (or send yours) and use the same
  words in G8 so the client's Text.REASONS and the contract agree.
- The D-054 codes `not_senior` and `newcomer_lock` are my names; send yours if they differ (Text.REASONS).
- If you'd rather replicate relations another way (a `Kingdom.Diplomacy` event, a `Sim` snapshot
  field), say which; `KingdomStore:diplomacy()` is the only reader.
- Rate: the double uses burst 3, 1/s. Your call.

## Next actions for the receiver
1. Serve `Kingdom.Diplomacy` and the `diplomacy` payload field (or reply with your shape).
2. Tell me when it's on a branch; I'll run `economy/Diplomacy.spec` against your service instead of the double.

## Files to read
- `games/game-001/tests/economy/doubles/DiplomacyDoubles.luau` — the server behaviour the UI expects
- `games/game-001/src/client/UI/DiplomacyModel.luau` — the rules the buttons follow
