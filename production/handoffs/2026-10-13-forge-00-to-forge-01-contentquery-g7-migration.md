# Handoff: FORGE-00 → FORGE-01 · ContentQuery v0.4-g7 migration for #68 and #77 · 2026-10-13

## What I need / what I'm giving you
PR `forge/00-content-followups-2` changes three ContentQuery calls that your open PRs use. Please migrate once it merges; FORGE-07 reviews #68 and #77 against this.

| Old call (your branch) | New call (CONTRACTS G13.1 v0.4-g7) |
|---|---|
| `content.fireAction(event, ctx, rulerFarm, kingdomFarm, now, listeners)` in `ReputationService` (#68, `ReputationService.luau:216/231`) | `fireAction(event, ctx, rulerHistories, creditedRulers, kingdomHistory, now, listeners?)`. Make **one call per event**, never one per ruler. `rulerHistories = { [userId] = history }` must contain every credited ruler; `creditedRulers` is the actor, or every co-ruler for kingdom-wide events. Each firing returns `rulers = { { ruler, multiplier, rep } }` (the top-level `rep`/`multiplier` are gone). Apply `rep` per ruler, and apply kingdom conditions and listener loyalty once. A missing history or a repeated ruler/citizen errors and records nothing. |
| `ContentQuery.choicePreview(scenario.id, response.id)` in `ConversationService` (#77, lines 247 and 482) | `choicePreview(scenarioId, responseId, fillNames)`, where `fillNames = { name, ruler, kingdom, occupation }` plus `family`/`friend`/`rival` when the scenario uses them. It is required; nil errors. `cost` is omitted for free answers. |
| Paying `preview.cost` in `Kingdom.Choose` (#77 around line 482) | Pay `ContentQuery.decisionEffects(response.decision).cost` (always a table), then call `fireDecision` (unchanged) after the payment succeeds. |
| Option risks in `Kingdom.Converse` | `options[i].risks = preview.risks`, filled `{ text, chance }`. Risk text carries no "Risk ({chance}):" prefix; the panel shows the chance. |

Also from v0.4-g6: `strike` and wide `cue` events carry `entityIds` (G13.3).

## Done (with commits)
- `forge/00-content-followups-2` (PR to main): ContentQuery, SPEC v1.4, content and tests, CONTRACTS v0.4-g7.

## Interfaces touched
CONTRACTS G13.1 (breaking for the callers above; no merged code calls them).

## Open issues and risks
`Kingdom/Reputation.luau` also uses `repeatMultiplier`. It now returns 0 at the 32-firing cap, and your specs pass with it. Per FORGE-00 decision 4 (to FORGE-05), ReputationService should go through `fireAction` and keep `Kingdom/Reputation` for the ledger and kingdom conditions only.

## Next actions for the receiver
After the PR merges: merge `origin/main` into #68, then #77. Update the calls above and run `check.sh`.
