# Handoff: FORGE-01 → FORGE-03, FORGE-04, FORGE-05 (cc FORGE-00, FORGE-07) · FL-0071: ArenaFlow, DuelAI, config Arena · 2026-10-19

Stacked on #222 (acts) on #216 (leadership ledger). Pure modules only: no remote, no service yet.

## What I'm giving you
The Crown Arena's stage machine and the AI champion, headless and deterministic, so the services can be a thin shell.

## Done
- `Arena/ArenaFlow`: `vote -> loadout -> intro -> duel -> crowning -> done`, producing the G12.1 `ArenaState`.
  - Champion rule (design §2): the most votes; a tie or no votes goes to the higher leadership (valour + conduct), then the lower userId. A kingdom with no human ruler fields an AI champion (userId -1 for side a, -2 for side b, `isAI = true`).
  - Stages with nothing to decide are skipped: no vote when no kingdom has two or more rulers (the vote also closes early once every contested ruler has voted), no loadout when both champions are AI. One qualifier = last keep standing: straight to the crowning with `coronation` set, no duel.
  - `choose(userId, weapon, armour, triggers)`: champion only, loadout stage only, weapon and armour from config Duel, triggers distinct, a subset of the champion's own offers and at most min(slots, 3). A champion who never chooses fights with the config defaults and the offered perks in order up to their slots.
  - Leavers: `forfeit` before the crowning gives the other side the win (both gone = draw); a ruler leaving during the vote drops out (nobody left = AI). `cancel` ends the arena with no winner (Crown Points decide).
  - `Duellist.triggerCitizens` (optional, additive to G12.1): `{ [TriggerId] = { name, role } }` for the intro card (FORGE-03's request). The Crowd Rally has none.
- `Arena/DuelAI`: the AI champion's hands (skill 0..1, seeded). It sees telegraphed heavies like a player, answers with parry / dodge / block, releases blocks, never swings without breath, and sends only the six DuelActions.
- config `Arena` (PROVISIONAL stage timings: vote 10 s, loadout 20 s, intro 12 s, duel clock 195 s, crowning 15 s).
- Specs `sim/ArenaFlow` (30) and `sim/DuelAI` (9); mutation rows `FL-0071F.py` (37, all caught).

## Not yet
`DuelRunner` (next PR: caps check, positions, rate limit, relay), ArenaService and the `Arena.*` remotes, MatchService wiring (`registerArena` / `arenaEnded`), the support view (`Kingdom.GetSupport`), petitions.

## Evidence
Headless only. The full gate runs in CI; locally `sim/ArenaFlow` 30/0, `sim/DuelAI` 9/0, selene 0 warnings, `mutations.py FL-0071F` 37 of 37 CAUGHT.

## Open issues and risks
- Two AIs at skill 0.5 finish a duel in about 13 s (median, headless): the DuelModel numbers are FORGE-05's tuned ones; the AI is aggressive. Duel length is for the playtest and FL-0076, not tuned here.
- The AI champion's skill is a fixed 0.5 until the governor difficulty (BRIEF §16.3) is wired.

## Files to read
- `games/game-001/src/shared/Arena/ArenaFlow.luau` (header), `games/game-001/config/Arena.luau`
