# Handoff: FORGE-00 → all workers · D-030 production priorities, VS-1 v2, CONTRACTS G13 · 2026-10-12

## What I need / what I'm giving you
The user's directive: **get AI Kingdoms playable in Roblox Studio as fast as possible, and make living citizens, conversations and reputation its defining mechanics.** VS-1 is now the user's nine items (BRIEF §4). Temporary assets and simplified mechanics are fine; improve them once the loop works.

Do not restart or discard work: extend what you have. Your current PRs stay valid.

## Done (with commits on `main`)
- `games/game-001/design/living-kingdom.md`: the full requirements (citizens, conversations, six reputation categories, construction, consequences, Crown Arena integration, balancing).
- BRIEF §4 is VS-1 v2. §16.10–13 hold the open user decisions, including the recorded conflict on match length.
- CONTRACTS v0.4-g4 adds G13. It is additive, and its VS-1 rows take effect now.
- DECISIONS D-030.
- team.md and `ownership.json` rows for the new paths.
- Tasks FL-0078 to FL-0096.
- The §0 note in every PROMPT.md.
- The content library (FL-0083, FORGE-00) lands in the next commit. Until then, code against the module shapes in `content/SPEC.md` and CONTRACTS G13.1.

## Your work (VS-1 first, in this order)
| Worker | Now | Then |
|---|---|---|
| FORGE-01 | Push the boot PR so a running kingdom exists in game-001. Then FL-0078 population → FL-0080 reputation → FL-0079 conversations → FL-0081 plots, upgrade times and throne seat | FL-0082 consequences, FL-0084 policy hook |
| FORGE-02 | PRs #27 and #28 to merge (FORGE-05). Then FL-0085: throne seat, build slots, citizen looks, visible levels with barracks L1–4 | FL-0086 new building types; Blender batch |
| FORGE-03 | PRs #13 and #19 to merge. Then FL-0087 plot picker and upgrade panel, FL-0088 conversation panel and citizen card v2, FL-0089 reputation screen | Crown Arena UI (FL-0073) |
| FORGE-04 | FL-0090: aerial management camera as the default, selection signal, walk mode kept. FL-0091: citizen bubbles and reactions | FL-0092 `match30` profile and onboarding v2 |
| FORGE-05 | Merge in dependency order (#27 → #28, FORGE-01's boot PR, #13 → #19). FL-0093: a fresh `.rbxl` to the user after every merge that changes what can be seen or played, playtest rows 1–9, G13.7 debug presets, `Lighting.Technology = Future` | FL-0094 balance harness |

## Interfaces touched
These additions are all in CONTRACTS G13:
- **Content:** Content modules and ContentQuery.
- **Citizens:** `CitizenView` and `CitizenLook`.
- **Conversations:** `Kingdom.Converse` / `Kingdom.Choose`, plus the `thought`, `reaction` and `strike` events.
- **Reputation:** ReputationService, `Kingdom.Reputation` / `Kingdom.GetReputation`, and kingdom happiness, stability and morale.
- **Construction:** `buildSlots` and `Build.PlaceSlot` / `Build.Slots`, and the new BuildingTypes (VS-2).
- **Throne and selection:** the `Throne` seat and `InputModeController.selected`.
- **Debug:** the debug presets.

Nothing breaking.

## Open issues and risks
- **FORGE-01 is the critical path.** Reduce it by using subagents for the pure modules (population generator, reputation model). FORGE-00 owns ContentQuery (selection, effects, loyalty reach, repeat decay), so FORGE-01 only builds the context and applies the effects.
- **Camera and controls.** The aerial camera with the ruler on the throne replaces the third-person default. Walk mode stays for the Crown Arena duel.
- **Match length is unresolved** (user): about 30 minutes, or the current 38–44 before the arena. Do not change the `match` profile.

## Next actions for the receiver
1. Merge `origin/main`. Read §0 of your PROMPT.md, `design/living-kingdom.md` and CONTRACTS G13.
2. Move your new tasks to BUILDING when you start them, and update STATUS.md with an honest hours-to-VS-1 estimate.
