# AI Kingdoms content library — formal schema (v1.1, 2026-10-12)

Owner of the format and the importer: `tools/content/content.py`. Editor guide for writers: [`README.md`](README.md).
Model rules come from FORGE-00 (model decisions 1–7, 2026-10-12). The starter rows are a **DRAFT proposal**, not approved dialogue.

v1.1 applies the content review of 2026-10-12: model decision 6 guards in the validator, mechanics placeholders in notices, presentation columns (`thought_icon`, `reaction_tone`), unlock gating, kingdom-gain anti-farming, rules for several rulers per kingdom, the runtime meaning of `actions.csv`, and a safer workbook import. Items that need a contract change are marked **(contract: FORGE-00)**.

## 1. Files and pipeline

```
games/game-001/content/            canonical source (CSV, UTF-8, RFC 4180, header row, one file per table)
  dialogue/scenarios.csv  responses.csv  decisions.csv  consequences.csv
  citizens/traits.csv  names.csv  occupations.csv
  reputation/categories.csv  actions.csv
        │  python3 tools/content/content.py build      (validate, then generate)
        ▼
games/game-001/src/shared/Content/ (ReplicatedStorage.Game.Content)
  Dialogue.luau  Decisions.luau  Consequences.luau  Traits.luau  Names.luau  Occupations.luau  Reputation.luau   (GENERATED)
  ContentQuery.luau                                                                                          (hand-written)
```

| Command | Does |
|---|---|
| `validate` | Parses every CSV and checks types, ranges, lengths, ids, references, the condition vocabulary and the model decision 6 guards. Prints `N scenarios, M responses, … — 0 errors`, or one line per error, then exits 1. |
| `lint` | Prints design warnings (§9). It never fails. |
| `build` | Runs validate, then writes the generated modules. Output is deterministic: running it twice gives identical bytes. |
| `check` | Exits 1 if validation fails or a generated file is missing or differs from what `build` would write (CI). |
| `export-xlsx [path]` | Writes the editing workbook (default `games/game-001/content/AI_Kingdoms_Content.xlsx`), stamped with the CSV versions it was made from (§10). |
| `import-xlsx <path> [--build] [--text-only]` | Reads the workbook back (§10). It validates first and writes the CSVs only when there are 0 errors. It always lists every change, split into TEXT, MECHANICS and NOTES. Rows you did not change keep their exact original bytes. `--build` regenerates the Luau too; `--text-only` takes only the TEXT, choice and notes columns. |
| `fmt` | Rewrites every CSV in canonical form (Python `csv` minimal quoting, `\n` line ends). |

All commands take `--content DIR` (default `games/game-001/content`). `build`, `check` and `import-xlsx` also take `--out DIR` (default `games/game-001/src/shared/Content`).

**Error format.** `path:row:column: [column_name] message`. Row is the spreadsheet row: the header is row 1, so the first data row is row 2. Column is 1-based. While importing a workbook, errors name the sheet cell instead, e.g. `AI_Kingdoms_Content.xlsx › scenarios!C7 [trigger]: …`.

## 2. Common value types

| Type | Syntax | Notes |
|---|---|---|
| `id` | `^[a-z][a-z0-9_]*$`, ≤ 40 chars | Lower-case snake case. Luau keywords are allowed (emitted as `["end"]`). |
| `tag` | `^[A-Za-z][A-Za-z0-9_]*$`, ≤ 40 chars | Memory tags; `rulerVisited` style is allowed. |
| `int` | `-3`, `+3`, `3` (`3.0` is accepted as 3) | Signed columns may use an explicit `+`. |
| `number` | decimal, e.g. `0.85`, `-1.5` | No `nan` or `inf`. |
| `bool` | `true` / `false` (any case) | Empty means the column default. |
| `list` | `a;b;c` | Spaces around items are ignored. A trailing `;` is allowed. |
| `kv list` | `food:-20;gold:5`, `greedy:+3;kind:-2` | Each key at most once. |
| `resource` | `food`, `wood`, `stone`, `gold` | CONTRACTS G2 (`iron` is VS-2). |
| `cond` | condition expression (§4) | Parsed at build time into `{ Clause }`. |
| `TEXT` | player-facing text, one line | It has a length limit. It may not have leading or trailing spaces or line breaks. Placeholders: §3. |
| `choice` | a value from a short list | Presentation, edited together with the text (`thought_icon`, `reaction_tone`). |
| `notes` | free text for designers | Multi-line is allowed. It is never exported to the game. |

- Unknown columns are errors, and so are missing required columns. Column order inside a file is free, because the importer reads by header name. Fully blank rows are ignored.
- **Invisible characters are errors in every cell**: control characters U+0000–U+001F (a notes cell may hold tabs and line breaks), U+007F–U+009F, zero-width U+200B–U+200D and U+2060, U+FEFF, and the line/paragraph separators U+2028/U+2029. The message names the character and its position, e.g. `invisible character U+000B (vertical tab (Shift+Enter in Word)) at position 11`. A workbook cannot hold most of them, so this keeps `export-xlsx` working.

## 3. TEXT placeholders
The game fills placeholders in at runtime. Which ones a column may use depends on whether a single citizen is speaking:

| Column | Allowed placeholders |
|---|---|
| scenarios `thought_text`, `question_text`; responses `response_text`, `reaction_text` | `{name}` (the citizen's given name), `{ruler}` (the ruler's display name), `{kingdom}`, `{occupation}` (the citizen's occupation name), and `{family}`, `{friend}`, `{rival}` (the given name of a related citizen) |
| consequences `notice_text` | `{name}`, `{ruler}`, `{kingdom}`, `{occupation}` (all of the citizen spoken to), plus the **mechanics placeholders** `{chance}`, `{magnitude}`, `{magnitude_pct}`, `{duration}` |
| actions `notice_text` | `{ruler}`, `{kingdom}`; also `{name}` and `{occupation}` when the row's audience is `speaker` |
| everything else (traits, names, occupations, categories) | none |

- **Relations are guaranteed, not hoped for.** `{family}`, `{friend}` and `{rival}` are errors unless the scenario's trigger requires `citizen.has_family`, `citizen.has_friend` or `citizen.has_rival` (a response uses its scenario's trigger).
- **Mechanics placeholders** keep notices true when the numbers change: `{chance}` → `50%`, `{magnitude}` → `+5` / `-4` (signed), `{magnitude_pct}` → `15%` (absolute, for productivity and strike shares), `{duration}` → `45 s` / `2 minutes`. A consequence with `chance` < 1 **must** have a notice that contains `{chance}` (model decision 7: the real odds are shown, never typed). `ContentQuery.consequenceNotice` fills them.
- An unknown placeholder, one not allowed in that column, or an unbalanced brace is an error.
- Length limits count the raw text, so a placeholder counts by how it is spelled. Leave room for long names.

## 4. Condition language (`trigger`, `condition`, `audience_condition`)
- AND-only: clauses are separated by `&`. The canonical spelling is ` & `.
- An empty cell means always true. There is no OR: write two scenarios or two action rows instead.
- Clause forms:
  - `<var> <op> <value>` with op `=` `!=` `<` `<=` `>` `>=`;
  - `<var> in a,b,c`;
  - `<var>` (boolean is true);
  - `!<var>` (boolean is false).
- Common mistakes get a hint: `==` → `=`; `and` → ` & `; `=<`, `=>`, `≤`, `≥`, `≠`, `<>` → the right operator; `not x` → `!x`; a mistyped or wrongly capitalised name gets a "did you mean" (case-insensitive).

| Variable | Type | Range / values | Scope |
|---|---|---|---|
| `occupation` | enum | occupation ids | citizen |
| `phase` | enum | `Lobby Founding Expansion Conflict Endgame Arena Results` | kingdom |
| `kingdom.food` `kingdom.wood` `kingdom.stone` `kingdom.gold` | number | ≥ 0 | kingdom |
| `kingdom.fed_ratio` | number | 0–1 | kingdom |
| `kingdom.housing_ratio` | number | 0–10 (population / capacity) | kingdom |
| `kingdom.happiness` `kingdom.stability` `kingdom.morale` | number | 0–100 | kingdom |
| `kingdom.population` `kingdom.soldiers` | number | ≥ 0 | kingdom |
| `kingdom.count.<BuildingType>` | number | ≥ 0; BuildingType from CONTRACTS G2 (`keep house farm storehouse lumbercamp quarry barracks watchtower wall gate`, plus the VS-2 additions of G13.5: `mine blacksmith market infirmary granary shrine`). **Absent = 0** | kingdom |
| `kingdom.level.keep` | number | 0–10 | kingdom |
| `rep.<category>` | number | 0–100; six categories | ruler (§6.8) |
| `citizen.loyalty` `citizen.mood` | number | 0–100 | citizen |
| `citizen.obedience` | number | 0–100, derived from the ruler's authority and fear (§6.2) | citizen × ruler (§6.8) |
| `citizen.chemistry` | number | −20 to +20 | citizen |
| `citizen.hunger` | number | 0–1 | citizen |
| `citizen.trait.<trait_id>` | bool | trait from `traits.csv` | citizen |
| `citizen.memory.<tag>` | bool | any tag (lint warns if nothing sets it) | citizen |
| `citizen.has_family` `citizen.has_friend` `citizen.has_rival` | bool | | citizen |
| `event.<tag>` | bool | `raid shortage keep_upgraded building_completed objective_captured soldiers_recruited strike riot` | kingdom |
| `decision.<decision_id>` | bool | decision from `decisions.csv` (chosen this match) | ruler (§6.8) |

**Checks.**
- Number values must lie inside the variable's range, e.g. `kingdom.fed_ratio < 50` is rejected because fed_ratio is 0–1.
- Enum values must be known.
- Booleans only take `=`/`!=` with `true`/`false`, or the bare and `!` forms.
- Citizen-scoped variables are not allowed in `actions.csv` `condition`, which is evaluated for the kingdom. They are allowed in `audience_condition`, which is evaluated for each listener.

**Generated form.** `Clause = { var: string, op: string, value: number | boolean | string | { string } }`.
- Booleans are normalised to `op = "="` with `value = true/false`, so `!x` becomes `{ var = "x", op = "=", value = false }`.
- `in` keeps `op = "in"` with a `{ string }` value.
- The runtime ctx is a flat table keyed by variable name, e.g. `ctx["kingdom.fed_ratio"]`. The game never parses strings at runtime.
- **Missing variables at runtime** (`ContentQuery.evaluate`).
  - A boolean clause treats an absent (nil) variable as `false`, so the runtime only sets the flags that are true (`citizen.memory.*`, `decision.*`, `event.*`, `citizen.trait.*`, `has_*`) and `!citizen.memory.x` holds for a citizen without that memory.
  - An absent `kingdom.count.<type>` is 0, so `kingdom.count.blacksmith < 1` ("no smithy yet") works before the type exists. FORGE-01 should still set every count it knows.
  - Every other clause on an absent variable is false (including `!=` and `in`). Numbers never coerce from strings.

## 5. Tables

Legend: **K** key/id (mechanics) · **M** mechanics · **T** TEXT (edit freely) · **C** choice (edit with the text) · **N** notes. A default is used when the cell is empty.

### 5.1 `dialogue/scenarios.csv`
| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | unique |
| occupation | M | occupation id or `any` | |
| trigger | M | cond | citizen scope |
| priority | M | int | 1–100 (higher is offered first) |
| cooldown_s | M | int | ≥ 0; per citizen, since this scenario was last shown to them |
| once_per_citizen | M | bool | default `false` |
| thought_icon | C | `request` `concern` `idea` | optional column; default `request` (CONTRACTS G13.3 `thought.icon`) |
| thought_text | T | ≤ 48 | thought bubble |
| question_text | T | ≤ 160 | the citizen's line when selected |
| notes | N | | |

A scenario named by an `unlock_scenario` consequence is generated with `locked = true` (§5.4).

### 5.2 `dialogue/responses.csv`
| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | must exist in scenarios |
| response_id | K | id | globally unique |
| order | M | int | 1–4, unique within the scenario; each scenario has **2–4** responses |
| response_text | T | ≤ 70 | the ruler's answer |
| reaction_text | T | ≤ 140 | the citizen's reaction |
| reaction_tone | C | `happy` `angry` `sad` `neutral` | optional column; default `neutral` (CONTRACTS G13.3 `reaction.tone`) |
| decision_id | M | id | must exist in decisions; the underlying mechanics |
| notes | N | | optional column |

Rewriting text never touches mechanics: the text lives here, and the mechanics live in `decisions.csv`.

### 5.3 `dialogue/decisions.csv`
| Column | | Type | Rules / default |
|---|---|---|---|
| decision_id | K | id | unique |
| farm_key | M | id | anti-farming group; default = decision_id (lint warns when empty) |
| repeat_decay | M | number | (0, 1]; default 1 (no decay) |
| repeat_window_s | M | int | ≥ 0; default 0 |
| cost | M | kv list resource:int | amounts **paid**, each > 0; empty = free |
| resource_effects | M | kv list resource:int | signed, non-zero (gains or further losses) |
| rep_compassion … rep_fear | M | int | each −10 to +10; default 0 |
| speaker_loyalty, speaker_chemistry, family_loyalty, friends_loyalty, rivals_loyalty, audience_loyalty | M | int | −10 to +10; default 0 |
| audience | M | `none` `occupation` `kingdom` | default `none`; audience_loyalty ≠ 0 needs an audience |
| happiness, stability, morale | M | int | −10 to +10 kingdom-level deltas; default 0 |
| trait_overrides | M | kv list trait:int | −10 to +10 extra loyalty for listeners with that trait |
| consequences | M | list of consequence ids | each must exist |
| memory_tag | M | tag | stored on the speaker; usable as `citizen.memory.<tag>` |
| notes | N | | |

**Per-decision caps (model decision 6, validate errors).**
- Kingdom-wide loyalty: `audience_loyalty` (when audience is `kingdom`) plus the magnitudes of its `loyalty` consequences on `kingdom`, `civilians` or `soldiers` must be ≥ **−5**.
- Stability: the `stability` column plus its `stability` consequences must be ≥ **−5**.

**Promises.** A decision that promises something gives its honor only when a follow-up scenario keeps the promise. The promise sets a memory and unlocks the follow-up; the follow-up reads the memory and offers keep / delay / break (e.g. `farmer_promise_due`).

### 5.4 `dialogue/consequences.csv`
| Column | | Type | Rules / default |
|---|---|---|---|
| consequence_id | K | id | unique |
| kind | M | enum | `productivity strike morale happiness stability loyalty resource_over_time unlock_scenario memory desertion_risk unrest_pressure cue` |
| target | M | `speaker` `family` `friends` `occupation:<id>` `soldiers` `civilians` `kingdom` | |
| magnitude | M | number | meaning and range per kind, below; default 0 |
| param | M | text (optional column) | per kind, below |
| duration_s | M | int | 0–**600**; default 0 (instant) |
| delay_s | M | int ≥ 0 | default 0 |
| chance | M | number (0, 1] | default 1. **Below 1 needs a notice_text containing `{chance}`** (model decision 7) |
| cue_id | M | id | feedback cue (vocabulary below) |
| notice_text | T | ≤ 100 | optional player notice; may use the mechanics placeholders (§3) |
| notes | N | | |

| kind | magnitude | param | other rules |
|---|---|---|---|
| productivity | work-rate change, −1 to +1 (−0.2 = −20 %) | — | duration_s > 0. On a group (`occupation:<id>`, `soldiers`, `civilians`, `kingdom`) at least **−0.5**: only `speaker`/`family`/`friends` may stop work entirely (−1 = one citizen's walk-out) |
| strike | share of the occupation's workers who stop, 0–**0.5** | — | duration_s 1–**120**. Target must be one **civilian** `occupation:<id>` (CONTRACTS G13.3 sends `strike { occupation, on }`); never `kingdom`, `civilians`, `soldiers` or an occupation whose job is soldier (model decision 6). Kingdom-wide strikes come only from the sustained unrest rules (§6.6) |
| morale / happiness / stability | points, −20 to +20 | — | kingdom-level condition |
| loyalty | points, −20 to +20 | — | per targeted citizen |
| resource_over_time | total signed amount over duration_s, −500 to +500 | resource id (required) | duration_s > 0 |
| unlock_scenario | ignored | scenario id (required) | that scenario is generated `locked = true` and is offered to a citizen only after this consequence reached them (`CitizenState.unlocked[scenarioId] = true`) |
| memory | ignored | memory tag (default: consequence_id) | adds the memory to the targets |
| desertion_risk | added risk, 0–1 | — | soldiers only make sense as targets |
| unrest_pressure | points, −20 to +20 | — | feeds the sustained-condition unrest model (model decision 6); never a riot by itself |
| cue | ignored | — | cue_id required |

**Cue vocabulary** (lint warns on others): `celebrate` (the CONTRACTS G4 cue), `grumble`, `salute`, `bow`, `cower`, `strike_placard`, `work_fast`, `rest`, `hammer`. **(contract: FORGE-00)** No Sim.Events kind carries a cue yet (G4 has `celebrate`; G13.3 has `thought`, `reaction`, `strike`). Until a `cue { entityId | occupation | kingdom, cueId }` event is contracted, the runtime shows a cue through the speaker's `reaction.tone`: celebrate, salute, bow → `happy`; grumble, strike_placard → `angry`; cower → `sad`; the rest → `neutral`.

### 5.5 `citizens/traits.csv`
| Column | | Type | Rules / default |
|---|---|---|---|
| trait_id | K | id | unique |
| name_text | T | ≤ 24 | |
| description_text | T | ≤ 100 | |
| opposite | M | trait id or empty | must be symmetric (A↔B) and never the trait itself; the generator never gives a citizen both |
| weight_compassion … weight_fear | M | number −2 to +2 | value weight per category (model decision 3); default 0 |
| obedience_bias | M | number −2 to +2 | default 0 |
| productivity | M | number 0.8–1.2 | default 1 |
| hunger_sensitivity | M | number 0.5–1.5 | default 1 |
| gossip | M | number 0–2 | spread strength; default 1 |
| volatility | M | number 0.5–1.5 | default 1 |
| notes | N | | optional column |

Every category should have traits that dislike it, or one decision pleases everybody (lint does not check this; the content review does).

### 5.6 `citizens/names.csv`
| Column | | Type | Rules |
|---|---|---|---|
| kind | M | `given_f` `given_m` `given_n` `family` | |
| name | T | ≤ 16 | letters, `'`, `-`, spaces; unique within its kind |
| notes | N | | optional column |

At least 60 given names across the given kinds, and at least 40 family names. Use medieval-fantasy names only: no real people and no trademarks.

### 5.7 `citizens/occupations.csv`
| Column | | Type | Rules |
|---|---|---|---|
| occupation_id | K | id | unique; not `any` |
| name_text | T | ≤ 24 | |
| job_id | M | `farmer woodcutter miner builder hauler soldier` | the CONTRACTS G2 JobId it runs |
| key_role | M | `blacksmith healer captain provisioner elder merchant` or empty | Crown Arena key citizen |
| needs | M | list of ids | personal needs, most important first. Suggested ids: `food shelter rest safety tools health pay faith company respect` |
| trait_affinity | M | kv list trait:number | likelihood multiplier 0–5 when rolling traits (1 = normal, 0 = never) |
| notes | N | | |

### 5.8 `reputation/categories.csv`
| Column | | Type | Rules |
|---|---|---|---|
| category_id | K | the six ids | exactly one row each: compassion, honor, competence, courage, authority, fear |
| name_text | T | ≤ 24 | |
| description_text | T | ≤ 160 | |
| affects_text | T | ≤ 300 | plain-language list of what raises or lowers it |
| start | M | int 0–100 | config start (50, fear 20) |
| notes | N | | optional column |

### 5.9 `reputation/actions.csv` (non-dialogue ruler actions)
| Column | | Type | Rules / default |
|---|---|---|---|
| action_id | K | id | rows may repeat an action_id; all its rows must have the same event |
| event | M | `EventName` or `EventName:arg` | §8; `Building*:<BuildingType>`, `ResourceGathered:<resource>`, `MatchPhaseChanged:<phase>` |
| condition | M | cond, kingdom scope | when the row applies (the **need condition** for construction, model decision 5) |
| direct | N | | what the mechanic already does (informational, not exported) |
| farm_key, repeat_decay, repeat_window_s | M | as decisions | shared by every row of one action_id: leave them empty on later rows, or repeat the same values; farm_key defaults to action_id |
| rep_compassion … rep_fear | M | int −10 to +10 | the ruler's reputation change when this row applies |
| audience | M | `soldiers` `civilians` `occupation:<id>` `kingdom` `speaker` | who hears of it (§6.9) |
| audience_condition | M | cond, citizen scope | filter on each listener |
| audience_loyalty | M | int −10 to +10 | explicit loyalty change for matching listeners |
| morale, happiness, stability | M | int −10 to +10 | kingdom-level deltas |
| notice_text | T | ≤ 100 | history-log explanation (§3 for placeholders) |
| notes | N | | |

Each row is an independent effect that fires when its event fires and its `condition` holds. The direct versus indirect split works by rows, for example:
- `fund_barracks, BuildingCompleted:barracks, condition kingdom.count.barracks <= 2, audience soldiers, +3` (no reputation: a peacetime barracks is a choice)
- `fund_barracks, BuildingCompleted:barracks, condition kingdom.count.barracks <= 2 & phase in Conflict,Endgame, courage +1, authority +1` (the measured need)
- `fund_barracks, BuildingCompleted:barracks, condition kingdom.fed_ratio < 0.6, audience civilians, -3`

## 6. Effect model (what the runtime does with the data; ContentQuery implements 3–5 and 9)
1. **Reputation.** Every ruler has six values, 0–100, starting from `categories.start`. Every change is a history entry `{ t, category, delta, source, text }` (the field names of CONTRACTS G13.4). `source` is the decision_id or action_id, and `text` is the action notice_text or the scenario/response text.
2. **Loyalty and obedience.**
   - Loyalty is affection. It is stored per citizen, 0–100, and starts at 50 + chemistry/4.
   - Obedience is compliance. It is derived from rep.authority and rep.fear, weighted by the citizen's traits' `obedience_bias`.
   - Unrest risk uses both, plus kingdom happiness and stability.
3. **Personality.** Listener loyalty change = Σ_c(`weight_c` of the listener's traits × dR_c) × reach × chemistry multiplier.
   - reach: speaker 1, family 0.6, friends 0.4, rivals −0.3, whole kingdom 0.2 for public acts.
   - Explicit `*_loyalty` columns and `trait_overrides` are added on top.
4. **Chemistry.** −20 to +20 per citizen, rolled at generation (seeded). Gains are multiplied by (1 + chem/40) and losses by (1 − chem/40). `speaker_chemistry` may move it by at most **±5** from the rolled value over a whole match (`ContentQuery.driftChemistry`), and its gains decay like loyalty (6.5). living-kingdom.md §1 says "fixed for the match": **FORGE-00 to confirm the ±5 drift or rule chemistry fixed** (then validate speaker_chemistry as 0).
5. **Anti-farming.** The n-th firing of a farm_key within `repeat_window_s` multiplies gains by `repeat_decay^(n−1)`. Losses are never reduced.
   - Reputation gains use the **ruler's** firing history.
   - Loyalty gains, kingdom happiness/stability/morale gains, chemistry gains and gain consequences (loyalty, morale, happiness, stability > 0; unrest_pressure < 0) use the **kingdom's** firing history. This extends model decision 5 so repeated cheap construction and free answers cannot farm the conditions that gate riots and the Crown Arena **(FORGE-00 to confirm)**.
   - `ContentQuery.fireDecision(id, rulerHistory, kingdomHistory, now)` computes both multipliers, records the firing and returns the decayed bundle. The runtime applies it **as given**: ReputationService must not decay it again **(contract: FORGE-00 — the G13.4 comment "anti-farming per content farm_key" should read "delta already decayed by ContentQuery")**.
   - Construction gives reputation only through rows whose `condition` measures a need.
6. **Unrest.** Rebellions, riots and kingdom strikes come only from sustained conditions (threshold + minimum duration + instigator), configured outside this library. A decision can only add `unrest_pressure` or local consequences, within the caps of §5.3 and §5.4: no strike of soldiers or of more than half an occupation, no group stoppage below −50 %, no consequence longer than 600 s, kingdom-wide loyalty and stability each ≥ −5 per decision.
7. **No hidden rolls.** Dialogue outcomes are deterministic. A consequence with `chance` < 1 is shown to the player as a risk before they choose, with its real odds (`{chance}`). The Kingdom.Converse options carry only `{ id, text }`, so the conversation panel reads cost and risks client-side from the replicated content: `ContentQuery.choicePreview(scenarioId, responseId)` → `{ decision, cost, risks }`, and `ContentQuery.consequenceNotice(risk, names)` for the text **(contract: FORGE-00 may instead extend G13.3 options with `cost?` and `risks?`)**.
8. **Several rulers in one kingdom** (G2 `rulers: { number }`; G3 parties share a kingdom).
   - Reputation and `decision.*` belong to each ruler.
   - **Conversations** (`Kingdom.Converse` / `Kingdom.Choose`): the ctx uses the acting ruler's `rep.*`, `decision.*` and the citizen's obedience towards that ruler.
   - **Thought bubbles** (kingdom-wide, refreshed every 20 s): `rep.<c>` is the highest value among the kingdom's current rulers, `decision.<id>` is true when any of them chose it, and obedience is computed from those values. When a ruler opens the conversation, Converse re-checks with that ruler's own values and offers the next eligible scenario, or nil.
   - **Histories.** `FarmHistory`: one per ruler (reputation) and one per kingdom (loyalty and kingdom conditions), so co-rulers cannot each farm the same citizens. `ShownHistory` (cooldowns, once_per_citizen) is one per kingdom.
   - **Memories set by content** (`memory_tag` and `memory` consequences) are **pinned**: they are kept apart from, or never evicted by, the G5 rule of at most 8 memories, so a promise always comes due and `!citizen.memory.quarry_shored` stays false once the quarry is shored **(contract: FORGE-00 to note this in G5/G13.2)**.
   - **(contract: FORGE-00)** Record these rules in CONTRACTS G13.1.
9. **Actions at runtime** (`reputation/actions.csv`).
   - When an event fires, `ContentQuery.actionFirings(event, kingdomCtx)` returns the rows whose `condition` holds. `Name:arg` also matches rows written for the bare `Name`. Rows are grouped per action_id: **one event = one firing of that action's farm_key**.
   - A firing's reputation and kingdom deltas are the sums of its rows, decayed with `scaleGains(…, multiplier)` (gains only).
   - Each citizen hears a row when `inActionAudience(row, listener, listenerCtx)` holds: `kingdom` = everyone; `soldiers` = occupations whose job is soldier (the captain too); `civilians` = everyone else; `occupation:<id>`; `speaker` = the one citizen the event is about (e.g. the visited citizen). Then the row's `audience_condition` must hold for that listener.
   - A listener reacts to **that row's own** rep vector: `actionLoyalty(row, traits, chemistry, multiplier)` = personality at reach 1 for `speaker` and 0.2 for every group, plus `audience_loyalty`. A listener who matches several rows of one firing adds them up.
10. **Not in this library.** Thresholds, rates and windows of the sustained rules live in FORGE-01 config `Society.luau`, including a **fear relaxation rate** (fear drifts back towards its start when nothing feeds it), so fear-led rule keeps its risk "when fear drops" **(request: FORGE-01)**.

## 7. Generated Luau (`games/game-001/src/shared/Content/`)
Every file starts with:
```
--!strict
-- GENERATED by tools/content/content.py from games/game-001/content — do not edit
```
- Map keys are sorted, except resources (G2 order) and categories (canonical order).
- Lists keep file order.
- Empty optional values are **omitted** (nil), never `""`.
- Notes columns are not exported.
- The output passes `stylua --check` and `selene`.

```lua
-- Dialogue.luau
{ scenarios = { [scenario_id] = { id, occupation, trigger = { Clause }, priority, cooldown_s, once_per_citizen,
      locked, icon, thought, question,
      responses = { { id, order, text, reaction, tone, decision } } } },   -- responses sorted by order
  order = { scenario_id } }                                                   -- file order
-- Decisions.luau
{ [decision_id] = { id, farm_key, repeat_decay, repeat_window_s, cost = { [resource] = n }, resources = { [resource] = n },
    rep = { compassion, honor, competence, courage, authority, fear },          -- all six, zeros included
    speaker = { loyalty, chemistry }, family_loyalty, friends_loyalty, rivals_loyalty, audience, audience_loyalty,
    kingdom = { happiness, stability, morale }, trait_overrides = { [trait_id] = n }, consequences = { id }, memory_tag? } }
-- Consequences.luau
{ [consequence_id] = { id, kind, target, magnitude, duration_s, delay_s, chance, param?, cue_id?, notice? } }
-- Traits.luau
{ [trait_id] = { id, name, description, opposite?, weights = { compassion, honor, competence, courage, authority, fear },
    obedience_bias, productivity, hunger_sensitivity, gossip, volatility } }
-- Names.luau
{ given_f = { string }, given_m = { string }, given_n = { string }, family = { string } }   -- file order
-- Occupations.luau
{ [occupation_id] = { id, name, job, key_role?, needs = { string }, trait_affinity = { [trait_id] = number } } }
-- Reputation.luau
{ categories = { [category_id] = { id, name, description, affects, start } }, order = { category_id },
  actions = { { id, event, condition = { Clause }, farm_key, repeat_decay, repeat_window_s, rep = { six },
      audience?, audience_condition = { Clause }, audience_loyalty, kingdom = { happiness, stability, morale }, notice? } },  -- file order
  byEvent = { [event] = { index into actions } } }
```
`target` keeps the source spelling, e.g. `"occupation:farmer"`. `param` is a string, or `nil` when empty. For `memory` it is always set: it falls back to consequence_id. `icon` and `tone` are always set (defaults `request`, `neutral`); `locked` is always a boolean.

**ContentQuery** (hand-written, pure; full API in its header): `evaluate`, `eligibleScenarios` (respects `locked` via `CitizenState.unlocked`), `markShown`, `choicePreview`, `decisionEffects`, `fireDecision`, `loyaltyDelta`, `decisionLoyalty`, `actionFirings`, `inActionAudience`, `actionLoyalty`, `repeatMultiplier`, `recordFire`, `scaleGain`, `scaleGains`, `applyChemistry`, `startLoyalty`, `driftChemistry`, `noticeValues`, `fill`, `consequenceNotice`, `durationText`, `REACH`, `CATEGORIES`, `OPS`, `GAIN_SIGN`.

## 8. Action events
**Bus events (CONTRACTS G9, on `Contracts/GameEvents`).** `KingdomJoined` `MatchPhaseChanged` `BuildingPlaced` `BuildingCompleted` `BuildingUpgraded` `BuildingDestroyed` `ResourceGathered` `UnitsRecruited` `ObjectiveCaptured` `KingdomEliminated` `MatchEnded`. A keep upgrade is `BuildingUpgraded:keep` (there is no separate KeepUpgraded event, so it is never counted twice).

**Proposed reputation triggers (no contract yet).** These are not bus events: `GameEvents` throws on an undeclared name. ReputationService (FORGE-01) would raise them internally from its own state, or FORGE-00 adds them to G13 with these payloads **(contract: FORGE-00; producer: FORGE-01)**. Lint warns once per name until then.

| Event | Fired when | Suggested payload |
|---|---|---|
| `ObjectiveLost` | an objective owned by the kingdom is captured by another (derived from `ObjectiveCaptured`) | (objectiveId, KingdomId lost, by: KingdomId) |
| `RaidDefended` / `RaidSuffered` / `RaidAbandoned` | a raid on the kingdom ends: driven off / not stopped / not stopped while the ruler was nearby (VS-2 raids) | (KingdomId, raidId, rulerUserId?) |
| `FoodShortage` | fed ratio falls below 0.5 (also sets `event.shortage`) | (KingdomId, fedRatio) |
| `RulerVisited` | a ruler talks to a citizen (the G5 `rulerVisited` memory); audience `speaker` | (rulerUserId, entityId) |
| `EnemyAttacked` | the kingdom's army engages an enemy kingdom | (KingdomId, target: KingdomId) |
| `EnemyFarmsBurned` | the kingdom burns enemy farms (VS-2) | (KingdomId, target: KingdomId) |
| `TruceBroken` | the kingdom breaks a truce (VS-3) | (KingdomId, target: KingdomId) |
| `DeserterExecuted` / `DeserterForgiven` | the ruler's choice about a caught deserter (VS-2) | (rulerUserId, entityId) |
| `PhaseEndedWellFed` (requested) | a phase ends and the lowest fed ratio during it was ≥ 0.9; would replace the interim `MatchPhaseChanged:<phase>` rows of `phase_fed_*` | (KingdomId, phase) |

Arena results are not reputation events: the Crown Arena ends the match, so nothing could follow from them.

## 9. Lint (design warnings, non-fatal)
**Dialogue**
- A response weakly dominates every other response in its scenario on all non-fear reputation, loyalty, chemistry, kingdom (happiness, stability, morale) and net-resource columns. Fear is a tool, so more of it is not "better".
- **Sampled personality check.** Lint generates a seeded sample of the citizens who can raise each scenario (occupation, its trait affinities, 2–3 traits without opposite pairs, chemistry −20..+20; trait and chemistry clauses of the trigger respected) and scores each answer's speaker loyalty with ContentQuery's formula. It warns when a **free** answer is the best for more than 80 % of them and also has the highest reputation sum (fear aside).
- Two responses in one scenario share a decision.
- A scenario is repeatable with `cooldown_s` 0.
- A locked scenario that no used consequence unlocks.

**Decisions**
- A free decision (no cost) has a reputation sum, fear aside, above 6.
- farm_key is missing (decisions and actions).
- A decision or consequence is not referenced anywhere.

**Consequences and text**
- A cue_id outside the cue vocabulary (§5.4).
- A notice_text that types a number (use the mechanics placeholders).

**Actions**
- A construction event gives positive reputation without a `condition`.
- An event name that is not a CONTRACTS G9 bus event (once per name).

**Library**
- A `citizen.memory.<tag>` is used but no decision or memory consequence sets it (system memories `rulerVisited` and `raided` are known).
- A memory is set but no trigger reads it (fine as flavour for the citizen card; a promise needs a follow-up that reads it).
- A key_role is used by more than one occupation.

Former lint "chance < 1 without notice_text" is now a validate error (§5.4).

## 10. Workbook (`export-xlsx` / `import-xlsx`)
- There is one sheet per CSV, named like the file without `.csv`, plus `README` and a hidden `lists` sheet (dropdown lists and the export stamp).
- The header row is frozen, along with the first column.
- Header colours and cell fills: TEXT and choice columns are light yellow and their header comment says **EDIT** (with the length limit and the placeholders that column accepts); mechanics columns are grey with a **MECHANICS** comment; notes columns are white; read-only help columns are blue.
- **Read-only help columns.** The responses sheet ends with `info: question` (the scenario's question) and `info: effects` (cost, reputation, loyalty and consequences of the decision). Import ignores them.
- Dropdowns cover:
  - occupation, decision_id (live from the decisions sheet) and scenario_id;
  - consequence kind and target, audience, job_id, key_role, names kind, opposite, once_per_citizen, thought_icon and reaction_tone.
- Text-length validations reject over-long text.
- Every cell is stored as text (`@`), so Excel keeps `+3`, `true` and ids unchanged.
- **Export stamp.** The hidden `lists` sheet records the SHA-256 of every CSV at export time.
- Import:
  - It reads only the known sheets and columns. An unknown sheet or column is an error: never add or remove columns.
  - A missing table sheet leaves that CSV untouched.
  - **Order.** Rows go back to their CSV order (by id; new ids at the end, in workbook order). A table without an id (names, actions) is restored when its rows are only re-sorted. Sorting and filtering are therefore safe, and the priority tie-break (file order) cannot change from the workbook.
  - **Stale workbooks.** If a CSV changed after the export (or the workbook has no stamp), any MECHANICS difference from the current CSV is refused with the cell, the old and new value and the reason; text-only differences are still taken. Export a fresh workbook, or use `--text-only`.
  - **`--text-only`** takes only TEXT, choice and notes cells, matched by id (by position for names and actions, where moved rows are refused); every mechanics difference is listed as ignored.
  - It always prints every change as `TEXT`, `MECHANICS` or `NOTES` lines.
  - It validates the whole library before writing anything, and rewrites only the rows that changed.
