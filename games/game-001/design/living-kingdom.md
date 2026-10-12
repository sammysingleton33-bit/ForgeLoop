# Living kingdom — citizens, conversations, reputation, construction, consequences (game-001)

_Status: **official requirements, user directive of 2026-10-12** (D-030). Author: FORGE-00. Numbers are PROVISIONAL balancing proposals that live in data (content library or config), never in code. The editable text and effects live in the content library (`games/game-001/content/`, spec in `content/SPEC.md`). Contracts: CONTRACTS G13._

**Order.** VS-1 (BRIEF §4) carries the smallest working version of each system: a generated population, one or more conversations with visible consequences, six reputation values with history, plot-based construction and upgrades. Everything else here lands in VS-2 and VS-3 in small increments. No worker restarts completed work for this: new requirements extend what exists.

## 1. Living citizens (FORGE-01 simulation; FORGE-02 looks; FORGE-03 card; FORGE-04 bubbles)
- **A new population every match, stable within it.** The match seed generates every citizen; nothing persists across matches (D-027). Occupational templates (blacksmith, healer, captain, provisioner, elder, merchant, and the base jobs) define roles; the people filling them are new each match. The earlier named NPCs are templates only.
- **Per citizen:**
  - name (given + family name; households share a family name);
  - appearance (skin, hair, clothing colours and a job prop, within the ≤ 8-part rig; FORGE-02 variation parameters);
  - 2–3 personality traits (no opposite pair);
  - occupation and routine (work, carry, eat; rest at VS-2 with day/night);
  - needs (hunger in VS-1; rest and safety in VS-2);
  - relationships: family (household), 1–3 friends, 0–1 rival;
  - chemistry with the ruler (−20..+20, fixed for the match);
  - loyalty (0–100, individual);
  - memories (≤ 8, existing G5 rule) with tags usable by conversations;
  - mood (0–100).
- **Opinion of the ruler** has two separate axes:
  - **loyalty**: affection. It is stored per citizen and changed by what the ruler does to them, their family and friends, and by reputation changes they value;
  - **obedience**: compliance. It is derived from the ruler's Authority and Fear, weighted by traits.

  Strikes, unrest and desertion read both.
- **Scale.** VS-1 has 12 citizens per kingdom with full detail. More citizens arrive only after the performance budget (BRIEF §14) is measured with them.

## 2. Structured conversations (user choice: multiple-choice, not free-text AI chat)
1. A citizen with something to say shows a **thought bubble**: a short line plus a "!" or "?" icon. The bubble comes from the scenario's `thought_text`.
2. Selecting the citizen opens a **conversation**: the question and 2–4 choices.
3. Choosing one plays the **reaction** line, applies the decision's effects and records a memory. The visible consequence follows at once: a resource change, a work boost or a strike, morale, or a follow-up later.
- **Scenario selection** is deterministic. FORGE-01 builds a context from the real state (occupation, resources, fed ratio, traits, memories, recent events, previous decisions; vocabulary in `content/SPEC.md`). `ContentQuery.eligibleScenarios` picks the highest-priority eligible scenario. Cooldowns and once-per-citizen rules stop repetition.
- **Editorial control.** Every question, answer and reaction is text in `content/dialogue/*.csv`, also exported as one spreadsheet. The user rewrites text without touching mechanics: text columns are separate from effect columns and keyed by ids. The importer validates and regenerates the game data (`tools/content/content.py`).
- **The 16-archetype / 48-response proposal** from an earlier conversation was not supplied. The starter set in the repo is a DRAFT. Send the files and they are imported as a proposal.

## 3. Reputation: six categories (FORGE-01 calculation; FORGE-03 screen)
**Compassion, Honor, Competence, Courage, Authority, Fear.** Each is 0–100 per ruler and visible on a reputation screen. Each has a history of changes with the cause in plain words, and an explanation of what affects it (`content/reputation/categories.csv`).

Rules (user):
- Attacking an enemy kingdom or fighting to win does **not** lower reputation by itself. Courage and Authority may rise. Atrocities such as burning farms or breaking truces change Fear and Honor.
- Peacekeeping is a strategy, not a virtue that scores by itself.
- Compassion-led and fear-led rule must both be viable, with different risks:
  - Compassion: loyalty, voluntary productivity and Crown Arena goodwill. Risks: slower militarisation, costly generosity, petitions that escalate.
  - Fear: obedience, cheap compliance and military discipline. Risks: hidden resentment that turns into strikes, desertion or riots when fear drops (a lost battle, a weak moment), and little goodwill.
- Individual loyalty is separate from reputation. Kingdom **happiness**, **stability** and **army morale** are separate kingdom conditions.
- Different personalities respond differently to the same decision. Each trait weights the six categories −2..+2.
- No single decision causes a kingdom-wide rebellion (§5 gating).

**Direct vs indirect effects.**
- **Direct effects** are the mechanic itself: costs, buildings, units, productivity.
- **Indirect effects** are opinion. They are applied per audience and per condition (`content/reputation/actions.csv`).
- Example: funding a barracks costs gold and adds military readiness (direct). Soldiers' loyalty rises. Civilians lose loyalty **only while** the fed ratio is below 0.6 ("gold for soldiers while we starve").

**Anti-farming.**
- Every action has a farm key with diminishing returns inside a time window.
- Construction gives reputation only when it meets a measured need, e.g. a house while housing is ≥ 90 % full.
- Gains decay; losses do not.

## 4. Construction and upgrades (FORGE-01 logic; FORGE-02 models and stages; FORGE-03 menus)
**Flow in aerial management mode:**
1. Tap a free **plot**. Plots are predefined build slots per kingdom in the Layout, sized S, M or L.
2. Choose a structure from those that fit, with cost, build time and what it unlocks.
3. Confirm.
4. Builders walk there and work. The model rises through visible stages.
5. Tap the building to **upgrade**. Builders return, the model changes visibly, and the new level unlocks a real advantage.

**Catalogue.** PROVISIONAL; FORGE-03 owns costs (`Costs.luau`), FORGE-01 owns gameplay stats (`Buildings.luau`). New types are additive to G2.

| Building | Levels | What higher levels give | Phase |
|---|---|---|---|
| Keep | 1–3 | storage and population cap; unlocks building levels | VS-1 (level 2) |
| House | 1–2 | housing 4 → 8; happiness when housing is needed | VS-1 |
| Farm | 1–3 | food rate +0 / +50 / +100 % | VS-1 |
| Lumber mill (`lumbercamp`) | 1–3 | wood rate | VS-1 (level 1) |
| Quarry | 1–3 | stone rate | VS-1 (level 1) |
| Mine (`mine`, new) | 1–3 | gold rate | VS-2 |
| Barracks | 1–4 | build or upgrade time **8 / 18 / 35 / 60 s** (user proposal); recruit cap 5 / 10 / 15 / 20; training speed; level 4 veterans (+morale) | VS-1 (levels 1–2) |
| Blacksmith (`blacksmith`, new) | 1–3 | soldier weapons, then armour, then siege tools; key citizen | VS-2 |
| Market (`market`, new) | 1–2 | trade resources for gold; merchant; happiness | VS-2 |
| Infirmary (`infirmary`, new) | 1–2 | heals soldiers and citizens; fewer deaths; healer | VS-2 |
| Granary (`granary`, new) | 1–2 | food storage and less spoilage; provisioner | VS-2 |
| Watchtower | 1–2 | vision, then archers | VS-1 (objective) |
| Wall and gate | 1–3 | defence | VS-2 |
| Shrine (`shrine`, new) | 1–2 | happiness and morale; elder | VS-2 |

- **Duration.** Upgrades are fast because the match is short. Times scale with the builders working on site, up to a cap.
- **Construction changes the kingdom:**
  - new jobs (idle citizens take them; unemployment lowers mood);
  - productivity;
  - loyalty of the people it serves;
  - soldier morale (barracks, blacksmith);
  - Competence, when it meets a need;
  - stability (housing, food).

## 5. Consequences (FORGE-01 rules; FORGE-04 shows them)
Consequences are causal and contextual. Each is a data rule: condition, minimum duration, instigator where needed, then an effect with a visible cue (`content/dialogue/consequences.csv` for decision consequences; FORGE-01 config for the sustained kingdom rules).

| Situation | Condition (sustained) | Effect | Shown as |
|---|---|---|---|
| Helping a farmer | decision | loyalty up for the speaker and family; work boost | cheer, faster work |
| Exploited workers | low loyalty + low obedience in an occupation + exploit memories, for 60 s | **strike**: that occupation stops working until resolved | placards, idle crowd, notice |
| Barracks funded | action | readiness; soldiers' loyalty up; civilians resent it only during a shortage | salute; grumbles if hungry |
| Food neglected | fed ratio < 0.5 for 60 s | hunger, mood down, unrest pressure | hungry bubbles |
| Trusted general betrayed | decision + high-loyalty captain | desertion risk for soldiers loyal to the captain (shown as a risk) | warning |
| Influential citizen mistreated | decision on an influential citizen | resentment spreads to family and friends (gossip reach) | grumbles nearby |
| Prolonged instability | stability < 20 for 120 s + an instigator | riot: fire on a building, production halt | fire, alarm |
| Rebellion (VS-2/3) | stability < 10 for 180 s + ≥ 30 % disloyal + low obedience + instigator | rebels leave or seize a building | major event |
| Low army morale | morale < 30 in battle | retreat earlier; < 15: surrender (prisoners) or defection | banners drop |
| Strong relationships | loyalty ≥ 80 key citizens | Crown Arena triggers (G12) | arena moments |

Negative choices are not always bad, and generous ones are not always optimal. Harsh options save resources or time. Generous options cost resources or Authority.

## 6. Crown Arena integration
- The established design stays (`design/crown-arena.md`, D-029, caps G12.3).
- **To be revised for VS-2 (FL-0070):** support is rebuilt on this model. Each spectator's stance comes from their loyalty and obedience:
  - devoted;
  - dutiful;
  - restless;
  - hostile.

  A fear-led ruler fills the stand with dutiful spectators. Obedience-based triggers (captain, provisioner) still work, while goodwill triggers (blacksmith, healer) need loyalty. The fairness caps stay as they are.
- **Timing conflict (recorded, unresolved).**
  - User preference: about 25 minutes of kingdom play, then a 5-minute final phase, ending around minute 30.
  - Current documents: BRIEF §3 and crown-arena §2 put the arena at 38–44 min. `Pacing.luau` `match` runs 45 minutes of kingdom phases with no Arena phase.
  - Nothing changes until the user decides. FORGE-04 adds an **evaluation profile `match30`** to `Pacing.luau`, which is not the default: Lobby 20 s, Founding 5 min, Expansion 7 min, Conflict 8 min, Endgame 5 min, Arena 4.5 min, Results 30 s (≈ 30 min).
  - Arena format, champion choice and what the duel decides remain the user's (FL-0077).

## 7. Balancing and simulation (FORGE-01 hooks; FORGE-05 harness)
- **Tuning lives in data:**
  - decision and action effects: content library;
  - thresholds, rates and windows: FORGE-01 config `Society.luau`;
  - costs: FORGE-03 `Costs.luau`;
  - building stats: FORGE-01 `Buildings.luau`;
  - arena caps: G12.3.
- **Strategy simulation** (`games/game-001/tests/balance/`): headless full matches over many seeds, driven by scripted ruler policies through a FORGE-01 policy hook:
  - compassionate;
  - authoritarian/fear;
  - honorable;
  - pragmatic/competent;
  - exploitative;
  - neglectful.
- **The harness reports:**
  - Crown Points;
  - economy and army strength;
  - unrest events;
  - the loyalty and obedience distribution;
  - arena support.
- **Acceptance (PROVISIONAL):**
  - each of the four intended strategies reaches ≥ 85 % of the best one's median Crown Points;
  - their risk profiles differ measurably;
  - exploitative and neglectful play falls clearly behind;
  - exploit probes stay bounded: repeated cheap construction, repeated dialogue, flip-flopping.
- **Runaway checks:** no stat reaches 0 or 100 in under 3 minutes without sustained cause, and loyalty gains per minute are capped.

## 8. Ownership (team.md, game-001)
- **FORGE-01:**
  - population generation, needs, relationships, chemistry, loyalty, memories, obedience;
  - ConversationService (context, selection through ContentQuery, applying effects);
  - ReputationService (six categories, history, anti-farming);
  - consequence rules, construction and production effects, army morale;
  - the policy hook for balancing.
- **FORGE-02:**
  - building models with level variants and construction stages;
  - throne in the keep;
  - citizen appearance variation;
  - new building types;
  - environment.
- **FORGE-03:**
  - plot picker and build menu, upgrade panel;
  - conversation panel;
  - citizen inspection card (traits, loyalty, relationships, memories);
  - reputation screen with history;
  - economy displays.
- **FORGE-04:**
  - aerial management camera (default) with the ruler seated on the throne; walk mode kept for later and for the arena;
  - thought and speech bubbles, NPC reactions, emotional feedback, relationship cues, onboarding;
  - the `match30` evaluation profile.
- **FORGE-05:**
  - integration, Studio builds, debug presets (force a scenario, set reputation, trigger a strike);
  - the balance harness;
  - performance and testing.
- **FORGE-00:**
  - this document and the content library: CSV sources, importer, generated `src/shared/Content/`, ContentQuery, `tests/content/`.

## 9. Open decisions (the user's)
1. Match length: about 30 minutes (25 + 5) or the current 38–44 minutes before the arena. Evaluate `match30` in a playtest.
2. Approve or rewrite the DRAFT dialogue, and supply the 16-archetype / 48-response files.
3. The balancing acceptance bounds in §7.
4. Whether walk mode (third person) stays available outside the arena.
