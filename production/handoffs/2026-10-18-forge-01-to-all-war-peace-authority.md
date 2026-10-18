# Handoff: FORGE-01 → FORGE-00, FORGE-03, FORGE-04, FORGE-05, FORGE-07 · FL-0125 PR 2 (war and peace authority, D-054) · 2026-10-18

Stacked on PR 1 (#187, full match by default). Merge #187 first.

## What I'm giving you
Human rulers can declare war and make peace through a server-validated remote, with one senior ruler per kingdom, asks from co-rulers, an idle-senior handover and a newcomer lock. AI governors are unchanged (exempt).

## Done
- `Sim/Authority` (new): seats, `seniorOf`, `gate`, asks, newcomer lock. `Commands.executeFor` calls it for every human command, so any route honours it.
- `Kingdom.Diplomacy(action, target)` (function, burst 3 / 1 per s) and `Kingdom.WarAsk` (server event); `Kingdom.State.diplomacy`.
- Activity that keeps a senior "present": any command, `Kingdom.Gather`, `Converse` / `Choose` / `EndConversation`, and the ruler moving more than 0.5 studs. Passive polls do not count.
- Config: `Match.rulers = { newcomerLockSeconds = 120, idleSeniorSeconds = 90, askSeconds = 60, askCooldownSeconds = 30, maxAsks = 3 }` (sim time).
- Specs: new `sim/Authority.spec`, `sim/Diplomacy.spec` (senior fixtures), `sim/MatchKingdomServices.spec` (remote, WarAsk, payload, signature, PvP off); mutation rows in `mutations/FL-0125.py` (D-054 block).

## Interfaces (additive; FORGE-00 lands the G8 rows)
**G8 / Kingdom**
- `Kingdom.Diplomacy(action: "declareWar"|"proposePeace"|"acceptPeace", target: KingdomId) -> (ok: boolean, tag?: string)`
  - senior `declareWar` → `(true, "declared")`; co-ruler → `(true, "asked")` (the senior gets `Kingdom.WarAsk`); `proposePeace` → `(true)`; `acceptPeace` → `(true)` or `(false, "not_senior")`.
  - locked newcomer: `declareWar` / `acceptPeace` → `(false, "newcomer_lock")`.
  - sim codes pass through: `invalid_args, unknown_kingdom, grace_period, already_at_war, peace_cooldown, not_at_war, no_proposal, not_in_match, match_not_active, kingdom_eliminated`. Rate-limit refusals are the framework's.
- `Kingdom.WarAsk(requesterUserId: number, requesterName: string, target: KingdomId)`: server → the current senior only. One notice per requester per 30 s; ≤3 open asks per kingdom; an ask lasts 60 s and ends when the senior declares.
- `Kingdom.State.diplomacy` (present whenever PvP is on): `{ relations = {{a,b,relation}}, proposals = {{from,to,expiresAt}}, cooldowns = {{a,b,untilAt}}, graceEndsAt, seniors = {[KingdomId]=UserId}, asks = {{from,fromName,target,expiresAt}} (the viewer's own kingdom), lockedUntil? (the viewer only) }`. Times are server time (the G3 `endsAt` scale). The state is re-sent when a relation, proposal, cooldown, senior, ask or lock changes.

**G9**: none in this PR (`WarChanged` / `SiegeChanged` / `RaidChanged` are PR 3).

## Evidence
- `bash roblox/scripts/check.sh` on 213d3bbc + merge of #187: 1809 specs pass, 1 fails (`experience/ConversationAnalytics`, FORGE-04's slice pin #194, not on main yet; same failure as #187). Ownership PASS, `forge.py validate` 136 tasks 0 errors. Mutation rows (D-054 block, 22) all caught after dropping two equivalent mutants.
- Everything is **headless** (Lune / MockEnv); nothing seen in Studio. The idle rule uses sim time, so it only runs while a match phase is active.

## Open issues and risks
- Seats are in memory only (a server restart ends the match anyway).
- The "ruler moved" touch is sampled from the clamped position in `MatchHost:_mirrorRulers`; not covered by a spec (headless has no characters), covered by the Studio step below.
- `MoveBuilding` is locked for newcomers; `Demolish` is not (FL-0126 adds it).
- Spectator rulers have no seat.

## Next actions for the receiver
1. FORGE-03 (FL-0129b): build the war / peace panel on `Kingdom.Diplomacy` and `Kingdom.State.diplomacy`; show "asks" to the senior and the lock countdown to the newcomer. Run `economy/Diplomacy.spec`.
2. FORGE-05: gate; declare nothing new in G9 for this PR.
3. FORGE-07: items 18-25 of your checklist map to `Authority.spec` and the D-054 block of `MatchKingdomServices.spec`.

## Studio steps (user, two players)
1. Start a match with two players in one kingdom: only the first-seated player's war button works; the second's sends an ask and the first sees the notice.
2. Stand still 90 s as the first player; the second can then declare; move the first and they regain it.
3. Join a third player after Founding began: war / accept-peace / move-building refuse with the lock for 120 s.

## Files to read
- `games/game-001/src/shared/Sim/Authority.luau` (header documents the rules)
- `games/game-001/src/shared/Kingdom/MatchHost.luau` (`_diplomacy`, `_diplomacyRaw`, `_diplomacyFor`)
