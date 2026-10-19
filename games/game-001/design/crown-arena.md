# Crown Arena — final phase and citizen support (game-001)

_Status: **official game design, adopted by the user on 2026-10-12** (D-029). Author: FORGE-00. Numbers marked PROVISIONAL are starting values in config; the caps in §6 are the fairness contract (CONTRACTS G12) and change only with a DECISIONS entry. Open points are the user's (§11; BRIEF §16.9)._

**Not part of VS-1.** VS-1 stays the only milestone that matters now (BRIEF §4). Crown Arena is the centrepiece of VS-2 (BRIEF §4, VS-2 row 10). Workers with VS-1 slack may do the prep listed in §10; FORGE-01 starts arena code only after its VS-1 rows are integrated.

## 1. Intent
The match ends in the **Crown Arena**: surviving rulers fight a final duel while their own citizens fill the stands behind them. The crowd is not decoration. It is the visible, mechanical result of how each ruler led for the previous 30–40 minutes. The ruler walks into the arena with the consequences of their leadership standing behind them.

**Design rule (user, 2026-10-12).** Support is meaningful but never overpowering. The duel still rewards skill: support gives moderate buffs, clutch moments and emotional payoff, and never a predetermined result.

Derived rules (from "earned through actual gameplay decisions and relationships, not random assignment"):
- Every support effect comes from recorded match events. There is no random roll anywhere in the support chain.
- Nothing purchasable changes support, perks, loyalty or arena stats. (How cosmetics are sold is still the user's decision, BRIEF §16.1.)
- Both duellists and the audience can see each side's support tier and chosen perks. Nothing is hidden.

## 2. Where it sits in the match (PROVISIONAL timings; FORGE-04 owns the numbers in `Pacing.luau`)
| Phase | Time | Notes |
|---|---|---|
| Founding | 0–8 min | unchanged |
| Expansion | 8–20 min | unchanged |
| Conflict | 20–32 min | raids and armies; ruler deeds start to count (valour, protection) |
| Endgame | 32–38 min | sieges; standings decide who reaches the arena |
| **Crown Arena** | 38–44 min | qualification → loadout and perk pick (20 s) → intro (≤ 15 s) → duel (≤ 120 s) → crowning (≤ 20 s) |
| Results | 44–45 min | standings plus the **Leadership recap** (§8) |

- **Qualification (PROVISIONAL default, user decision §11.1):** the two kingdoms with the most Crown Points at the end of Endgame each send one champion to a single final duel. Opposite stands hold those two kingdoms' citizens. Rulers of other kingdoms watch from neutral seats.
- **Last keep standing.** If only one kingdom survives, there is no duel: the arena hosts a coronation with that kingdom's crowd. The emotional payoff still plays.
- **Champion choice (PROVISIONAL default, §11.2):** co-rulers have 10 s to vote. A tie or no vote picks the co-ruler with the highest personal leadership (valour + conduct, §3). The other co-rulers stand at the front of their kingdom's stand and can trigger crowd chants (presentation only).
- **AI kingdoms** that qualify field an AI champion. Its skill follows the governor difficulty (BRIEF §16.3).
- **Winner rule (PROVISIONAL default, §11.3):** the duel winner's kingdom wins the match. Crown Points decide qualification and the order of the rest.

## 3. Support score (FORGE-01; deterministic; PROVISIONAL weights in `Support.luau`)
Each component is normalised to 0–100 and sampled every 30 s during the match. The score uses a time-weighted average over the whole match, with later samples weighted more (PROVISIONAL: 40 % of the weight for the whole match, 60 % for the last 15 minutes). One good deed in the final minute cannot buy support, and an early mistake can be repaired.

| Component | Weight | Kingdom or ruler | Built from (recorded by LeadershipService) |
|---|---|---|---|
| Public reputation | 15 | kingdom, with a ruler share | public acts: celebrated upgrades, feasts, defended objectives, kept truces (VS-3); broken truces and betrayal lower it (VS-3, §16.2) |
| Happiness | 15 | kingdom | average citizen mood |
| Stability | 15 | kingdom | fed ratio history, housing vs population, buildings lost to raids, unrest events |
| Army morale | 10 | kingdom | soldiers fed and housed, battles won or lost, ruler fought alongside them |
| Citizen loyalty | 20 | kingdom | average loyalty across citizens (§4) |
| Conduct | 15 | ruler | key decisions and protect-vs-exploit acts (table below) |
| Personal valour | 10 | ruler | the ruler personally fought for the kingdom: defended own land under raid, captured objectives in person, fought beside own troops. Capped per minute, so fighting nonstop is not required |

**Conduct acts** (each act has a signed weight in config; the list grows with VS-2/VS-3 systems):

| Protect (+) | Exploit (−) |
|---|---|
| kept the fed ratio ≥ 0.9 through a phase | starvation: fed ratio < 0.5 for more than 60 s |
| defended citizens during a raid (ruler present in the region) | abandoned a raided region with the ruler nearby |
| fulfilled a citizen petition (§4) | refused or ignored petitions until they expired |
| sheltered citizens: houses before barracks expansion | overwork: job quotas above capacity with low mood for more than 90 s |
| rebuilt raid damage | conscripted beyond the soldier share of the population |
| decree choices tagged protective (VS-3 decrees) | decree choices tagged exploitative (VS-3 decrees) |

In multi-ruler kingdoms, kingdom components are shared and ruler components are personal. The champion's own conduct and valour are what count.

**Tiers** (shown as text and colour, never as a hidden number only):

| Tier | Score | Crowd (presentation, §7) | Mechanics (within §6 caps) |
|---|---|---|---|
| Adoring | 85–100 | chants the ruler's name, banners, roars on every good hit | passive blessing +1 % damage reduction and +1 % stamina regeneration (the same as Loyal since trim C, FL-0076; the tier stands out through the Crowd Rally and the crowd); 3 trigger slots; may slot the **Crowd Rally** |
| Loyal | 65–84 | strong cheering | passive blessing +1 % and +1 %; 3 trigger slots |
| Divided | 40–64 | mixed: half cheer, half mutter | no passive blessing; 2 trigger slots |
| Restless | 20–39 | quiet, some seats empty, scattered boos | no passive; 1 trigger slot |
| Hostile | 0–19 | boos, turned backs, people leave | no passive; no trigger slots |

- **Floor:** weak support removes buffs. It never pushes the ruler below baseline stats (PROVISIONAL, §11.4). Booing is presentation only.
- **Trigger slots** hold key-citizen perks (§4). The usable count is the lower of the tier's slots and the number of pledged key citizens.
- **Crowd Rally** (Adoring only, takes one slot): when the ruler's HP first drops below 20 %, the whole stand roars: damage reduction +5 % and stamina regeneration +10 % for 5 s. It is the tier's clutch moment, so an Adoring ruler with three pledged citizens chooses between a third perk and the Rally.

## 4. Key citizens and loyalty perks
Every citizen has **loyalty 0–100** (starting 50). It rises with ruler visits (capped per interval, as in VS-1 `rulerVisited`), being fed and housed, protection during raids and fulfilled petitions. It falls with hunger, raids suffered without defence, overwork and ignored petitions.

**Key citizens** are named citizens who appear when the kingdom builds the matching building. At most one exists per role per kingdom. Building the building is the first gameplay decision; earning their loyalty is the relationship.

| Role | Appears with | Petition example (raises loyalty when fulfilled) | Perk (one trigger per duel) | Trigger condition | Effect at Pledged (loyalty 80–94) / Empowered (95–100) |
|---|---|---|---|---|---|
| Blacksmith | Smithy | "Bring 40 stone to reinforce the forge" | **Reforge** — runs to the rail and hammers the ruler's armour | ruler's HP first drops below 50 % | damage reduction +6 % / **+10 %** for 6 s (the user's example) |
| Healer | Infirmary | "Herbs from the forest edge" | **Field Remedy** | ruler's HP first drops below 35 % | regenerate 3 % / 5 % of max HP over 4 s (trim C, FL-0076) |
| Captain | Barracks (the first veteran soldier) | "Drill the recruits with me" (ruler visits the yard) | **Called Warning** — shouts the opponent's heavy attack early | opponent's first two heavy attacks | heavy-attack telegraph shown 0.15 s / 0.25 s earlier |
| Provisioner (farmer or cook) | Granary or Kitchen | "Keep the granary above 100 food" | **Hearty Rations** | ruler's stamina first hits zero | stamina regeneration +6 % / +10 % for 8 s |
| Elder or Priest | Chapel or Shrine | "Hold a feast" (food spend at the keep) | **Rallying Hymn** — the stand sings | crowd hype reaches full (after a parry or a combo) | cleanse one slow or stagger, and damage +3 % / +5 % for 5 s |
| Merchant | Market | "Protect the trade road" | **Fine Wares** | before the duel | chosen weapon damage or armour damage reduction +2 % / +3 % for the whole duel (counts against the passive cap) |

- A key citizen offers a perk only when their loyalty is ≥ 80 **and they are alive**. A key citizen killed in a raid is mourned (crowd moment) and offers no perk; a successor appears with loyalty 50.
- Before the duel, the champion fills their trigger slots (§3) from the offers, within 20 s. The picker shows each citizen's name, loyalty, effect, trigger condition and why they are loyal (their top memories).
- Triggers are deterministic and readable. Each fires at most once per duel, and both players see the trigger (announcer line, the citizen animates at the rail, an icon on the HUD).
- The Merchant role needs trade (VS-3). VS-2 ships Blacksmith, Healer, Captain and Provisioner; Elder and Merchant follow when their buildings exist.

## 5. Duel (FORGE-01 combat core; FORGE-04 input; FORGE-03 HUD)
- **Readable melee.** Light attack, heavy attack (telegraphed), block, parry window, dodge, stamina, HP. Best of one round, 120 s cap; at the cap the ruler with the higher HP percentage wins (ties → sudden death, both take +20 % damage).
- **Server-authoritative.** Hits are resolved on the server from validated, rate-limited actions. The client predicts animation only.
- **Loadout (chosen armour and weapons).** Weapons: sword and shield, greatsword, spear, mace. Armour: light, medium, heavy (mobility vs damage reduction). Every option is a **sidegrade** with equal expected value in the fairness harness (§9). Appearance takes kingdom colours; cosmetic variants never change stats.
- **Pure core.** `src/shared/Arena/DuelModel.luau` is a deterministic step function (state, inputs, dt → state, events) with injected RNG and no Roblox API, so the fairness harness and Lune specs simulate thousands of duels headless.
- **Rating.** No blood or gore. Defeat is a kneel and yield, not a death. This keeps the 13+ Mild/Moderate fantasy-violence target (BRIEF §16.7).

## 6. Fairness caps (contract; CONTRACTS G12.3)
Mechanical caps, enforced in code by `src/shared/Arena/Caps.luau` and asserted by FORGE-05 specs:
1. Passive blessing (tier plus Fine Wares) ≤ **+5 %** on any single stat and ≤ **+8 %** combined.
2. At most **3** support triggers per duel (perks plus the Crowd Rally). Each fires at most once, lasts ≤ **8 s**, and has magnitude ≤ **+10 %** (damage reduction, damage, stamina regeneration) or ≤ **8 %** max HP healed.
3. The total support bonus on one stat at any moment (passive plus active triggers) ≤ **+15 %**.
4. Total healing from support ≤ **10 %** of max HP per duel.
5. No support trigger in the first **10 s** of a duel. Two active triggers on the same stat do not stack; the stronger applies.
6. Support never stuns, roots, disarms, damages or reveals the position of the opponent, never acts without the duel's own events, and never auto-wins.
7. Weak support never lowers stats below baseline (§3 floor).

Outcome caps, measured by the fairness harness (§9) with simulated duellists (PROVISIONAL bounds, user decision §11.4):
- **Support matters.** Equal skill, Adoring vs Hostile: the Adoring side wins **55–65 %** of duels. Below 55 % support is too weak to feel; above 65 % it is too strong.
- **Skill still wins.** A duellist one skill tier better (about +15 % hit and parry accuracy) with Hostile support beats an Adoring opponent at least **60 %** of the time.
- **No auto-win.** No combination of tier, perks and loadout exceeds **70 %** win rate against an equal-skill baseline.

## 7. Crowd and presentation (FORGE-04, with FORGE-02 assets and FORGE-03 UI)
- **The crowd is the population.** Each stand shows the kingdom's living citizens, scaled (PROVISIONAL: one figure per two citizens, ≤ 60 figures per stand). Citizens lost in raids are missing. Key citizens stand at the front rail with their role props, so the player recognises them when their perk fires.
- **Reactions** follow the tier (§3 table) and duel events: a big hit, parry, near-death, perk trigger, comeback, finish. Chants are pre-written lines in kingdom style, never user text. Boos and turned backs are the strongest negative reaction; no insults.
- **Timing.** A crowd director rations reactions: at most one major reaction every 3 s, and perk moments always win priority. Crowd volume ducks under announcer lines and perk stingers.
- **Intro.** Two-sided versus card: champion, loadout, support tier with the top three reasons ("Kept the granary full through the Conflict", "Defended the mill at 22:14"), and chosen triggers with their citizens' portraits. Camera passes over both stands so each side sees its own crowd's mood.
- **Emotional payoff.**
  - Win with high support: the stand floods the arena and crowns the ruler.
  - Win with low support: a thin, quiet crowning. The player feels the cost.
  - Loss with high support: the stand still salutes ("They fought for us").
  - Loss with low support: the stand empties.
- **Accessibility.** Subtitles for chants and announcer lines; every perk and tier change has an icon and text, not only sound or colour.
- **Performance.** Crowd figures are client-only, ≤ 4 primitive parts each (Kit), animated by client CFrame bobbing. No server entities and no Humanoids. Phones with a low graphics level get billboard crowds. Budget: ≤ 120 crowd figures, < 2 ms client frame time for the crowd.

## 8. Before the arena: making support visible during the match (FORGE-03, FORGE-04)
Support must never surprise the player at the arena gate.
- **HUD support meter.** Current tier and score with a trend arrow. Tapping it opens a breakdown per component with the latest moments that moved it.
- **Citizen card.** Shows loyalty, key-citizen role, perk preview ("At 80 loyalty, Bram will reinforce your armour in the arena"), and open petitions.
- **Moments.** A short toast when an act moves support noticeably, for example "The farmers saw you defend the mill (+Conduct)". Rate-limited by the existing notification system.
- **Leadership recap** at Results: the five moments that most raised or lowered support, the perks that fired, and how the crowd reacted.

## 9. Verification (FORGE-05; nothing is "fair" until measured)
- **Caps spec:** every value in `Caps.luau` and `Support.luau` is within the §6 contract caps. Changing a cap needs a DECISIONS entry.
- **Fairness harness** (`games/game-001/tests/fairness/`): Monte Carlo runs of DuelModel with scripted duellists at three skill tiers and every support tier, perk set and loadout. It reports win rates with 95 % confidence intervals and fails the build when an outcome cap (§6) is broken. It runs headless in CI, at ≥ 2 000 duels per cell for the merge gate.
- **Determinism:** the same seed and inputs give the same duel, and the same match event log gives the same support score.
- **Studio:** a two-client Local Server arena run with debug presets (Adoring vs Hostile, perk triggers forced through `DebugCommands`). It needs screenshots or video of the crowd states and perk moments. The user's playtest accepts the feel; headless numbers accept only the caps.

## 10. Work split and order
VS-1 first. In VS-1 slack: FORGE-02 arena blockout and crowd figure; FORGE-03 HTML prototypes of the meter, perk picker and intro card; FORGE-04 crowd director design and chant list; FORGE-05 caps spec and harness scaffold against the G12 stubs. After FORGE-01's VS-1 rows: LeadershipService and loyalty → SupportModel and perks → arena phase and DuelModel. Tasks FL-0069 to FL-0077 hold the details.

| Worker | Owns |
|---|---|
| FORGE-01 | LeadershipService (act ledger, sampling), citizen loyalty and key citizens with petitions, SupportModel and SupportService (score, tiers, perk offers, trigger conditions, caps), ArenaService (qualification, champion vote, loadout, phase flow), DuelModel and DuelService (combat core, modifier hooks), AI champion |
| FORGE-02 | Arena venue (two stands in kingdom colours, royal boxes, gate), crowd figure rigs with role props, armour and weapon sets in the Kit, visual review (D-019) |
| FORGE-03 | Support meter and breakdown, citizen card loyalty and perk previews, petitions UI, loadout and perk picker, arena intro card, arena HUD (HP, stamina, perk icons), leadership recap |
| FORGE-04 | Crowd director (tiers, reactions, timing), chants and boos, perk-moment staging, intro camera, music and stingers, emotional-payoff endings, duel input mode (PC, touch, gamepad), announcer lines, pacing numbers |
| FORGE-05 | Caps spec, fairness harness and CI gate, arena integration in the game-001 build, Studio arena playtest script and debug presets |

## 11. Open decisions (the user's; BRIEF §16.9)
1. **Format:** top-2 kingdoms, one final duel (default) / bracket of every surviving kingdom / something else.
2. **Champion:** co-ruler vote with leadership fallback (default) / automatic highest leadership / co-rulers duel in sequence.
3. **What the duel decides:** the match winner (default) / a large Crown Points bonus.
4. **Support strength:** the §6 outcome caps (55–65 % equal-skill win rate for Adoring vs Hostile; default), and whether weak support may ever debuff (default: no).
