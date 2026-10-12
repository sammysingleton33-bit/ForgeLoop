# AI Kingdoms content library — formal schema (v1, 2026-10-12)

Owner of the format and the importer: `tools/content/content.py`. Editor guide for writers: [`README.md`](README.md).
Model rules come from FORGE-00 (model decisions 1–7, 2026-10-12). The starter rows are a **DRAFT proposal**, not approved dialogue.

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
| `validate` | Parses every CSV and checks types, ranges, lengths, ids, references and the condition vocabulary. Prints `N scenarios, M responses, … — 0 errors`, or one line per error, then exits 1. |
| `lint` | Prints design warnings (§9). It never fails. |
| `build` | Runs validate, then writes the generated modules. Output is deterministic: running it twice gives identical bytes. |
| `check` | Exits 1 if validation fails or a generated file is missing or differs from what `build` would write (CI). |
| `export-xlsx [path]` | Writes the editing workbook (default `games/game-001/content/AI_Kingdoms_Content.xlsx`). |
| `import-xlsx <path> [--build]` | Reads the workbook back. It validates first and writes the CSVs only when there are 0 errors. Rows you did not change keep their exact original bytes. `--build` regenerates the Luau too. |
| `fmt` | Rewrites every CSV in canonical form (Python `csv` minimal quoting, `\n` line ends). |

All commands take `--content DIR` (default `games/game-001/content`). `build` and `check` also take `--out DIR` (default `games/game-001/src/shared/Content`).

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
| `notes` | free text for designers | Multi-line is allowed. It is never exported to the game. |

Unknown columns are errors, and so are missing required columns. Column order inside a file is free, because the importer reads by header name. Fully blank rows are ignored.

## 3. TEXT placeholders
TEXT cells may use these placeholders, which the game fills in at runtime: `{name}` (the citizen's given name), `{ruler}` (the ruler's display name), `{kingdom}` (the kingdom name), `{occupation}` (the citizen's occupation name), `{family}`, `{friend}` and `{rival}` (the given name of a related citizen; only use these when the trigger requires the relation, e.g. `citizen.has_rival`).
- An unknown placeholder or an unbalanced brace is an error.
- Length limits count the raw text, so a placeholder counts by how it is spelled. Leave room for long names.

## 4. Condition language (`trigger`, `condition`, `audience_condition`)
- AND-only: clauses are separated by `&`. The canonical spelling is ` & `.
- An empty cell means always true. There is no OR: write two scenarios or two action rows instead.
- Clause forms:
  - `<var> <op> <value>` with op `=` `!=` `<` `<=` `>` `>=`;
  - `<var> in a,b,c`;
  - `<var>` (boolean is true);
  - `!<var>` (boolean is false).
- `==` is rejected with a hint.

| Variable | Type | Range / values | Scope |
|---|---|---|---|
| `occupation` | enum | occupation ids | citizen |
| `phase` | enum | `Lobby Founding Expansion Conflict Endgame Arena Results` | kingdom |
| `kingdom.food` `kingdom.wood` `kingdom.stone` `kingdom.gold` | number | ≥ 0 | kingdom |
| `kingdom.fed_ratio` | number | 0–1 | kingdom |
| `kingdom.housing_ratio` | number | 0–10 (population / capacity) | kingdom |
| `kingdom.happiness` `kingdom.stability` `kingdom.morale` | number | 0–100 | kingdom |
| `kingdom.population` `kingdom.soldiers` | number | ≥ 0 | kingdom |
| `kingdom.count.<BuildingType>` | number | ≥ 0; BuildingType from CONTRACTS G2 (`keep house farm storehouse lumbercamp quarry barracks watchtower wall gate`, plus the VS-2 additions of G13.5: `mine blacksmith market infirmary granary shrine`) | kingdom |
| `kingdom.level.keep` | number | 0–10 | kingdom |
| `rep.<category>` | number | 0–100; six categories | kingdom |
| `citizen.loyalty` `citizen.mood` `citizen.obedience` | number | 0–100 | citizen |
| `citizen.chemistry` | number | −20 to +20 | citizen |
| `citizen.hunger` | number | 0–1 | citizen |
| `citizen.trait.<trait_id>` | bool | trait from `traits.csv` | citizen |
| `citizen.memory.<tag>` | bool | any tag (lint warns if nothing sets it) | citizen |
| `citizen.has_family` `citizen.has_rival` | bool | | citizen |
| `event.<tag>` | bool | `raid shortage keep_upgraded building_completed objective_captured soldiers_recruited strike riot` | kingdom |
| `decision.<decision_id>` | bool | decision from `decisions.csv` (this ruler chose it this match) | kingdom |

**Checks.**
- Number values must lie inside the variable's range, e.g. `kingdom.fed_ratio < 50` is rejected because fed_ratio is 0–1.
- Enum values must be known.
- Booleans only take `=`/`!=` with `true`/`false`, or the bare and `!` forms.
- Citizen-scoped variables are not allowed in `actions.csv` `condition`, which is evaluated for the kingdom. They are allowed in `audience_condition`, which is evaluated for each listener.

**Generated form.** `Clause = { var: string, op: string, value: number | boolean | string | { string } }`.
- Booleans are normalised to `op = "="` with `value = true/false`, so `!x` becomes `{ var = "x", op = "=", value = false }`.
- `in` keeps `op = "in"` with a `{ string }` value.
- The runtime ctx is a flat table keyed by variable name, e.g. `ctx["kingdom.fed_ratio"]`. The game never parses strings at runtime.
- **Missing variables at runtime** (`ContentQuery.evaluate`). A boolean clause treats an absent (nil) variable as `false`, so the runtime only sets the flags that are true (`citizen.memory.*`, `decision.*`, `event.*`, `citizen.trait.*`, `has_*`) and `!citizen.memory.x` holds for a citizen without that memory. Every other clause on an absent variable is false (including `!=` and `in`). Numbers never coerce from strings.

## 5. Tables

Legend: **K** key/id (mechanics) · **M** mechanics · **T** TEXT (edit freely) · **N** notes. A default is used when the cell is empty.

### 5.1 `dialogue/scenarios.csv`
| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | unique |
| occupation | M | occupation id or `any` | |
| trigger | M | cond | citizen scope |
| priority | M | int | 1–100 (higher is offered first) |
| cooldown_s | M | int | ≥ 0; per citizen, since this scenario was last shown to them |
| once_per_citizen | M | bool | default `false` |
| thought_text | T | ≤ 48 | thought bubble |
| question_text | T | ≤ 160 | the citizen's line when selected |
| notes | N | | |

### 5.2 `dialogue/responses.csv`
| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | must exist in scenarios |
| response_id | K | id | globally unique |
| order | M | int | 1–4, unique within the scenario; each scenario has **2–4** responses |
| response_text | T | ≤ 70 | the ruler's answer |
| reaction_text | T | ≤ 140 | the citizen's reaction |
| decision_id | M | id | must exist in decisions; the underlying mechanics |

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

### 5.4 `dialogue/consequences.csv`
| Column | | Type | Rules / default |
|---|---|---|---|
| consequence_id | K | id | unique |
| kind | M | enum | `productivity strike morale happiness stability loyalty resource_over_time unlock_scenario memory desertion_risk unrest_pressure cue` |
| target | M | `speaker` `family` `friends` `occupation:<id>` `soldiers` `civilians` `kingdom` | |
| magnitude | M | number | meaning and range per kind, below; default 0 |
| param | M | text (optional column) | per kind, below |
| duration_s | M | int ≥ 0 | default 0 (instant) |
| delay_s | M | int ≥ 0 | default 0 |
| chance | M | number (0, 1] | default 1. **Below 1 must be shown to the player as a risk** (model decision 7); lint warns without notice_text |
| cue_id | M | id | feedback cue for FORGE-04 |
| notice_text | T | ≤ 100 | optional player notice |
| notes | N | | |

| kind | magnitude | param | other rules |
|---|---|---|---|
| productivity | work-rate change, −1 to +1 (−0.2 = −20 %) | — | duration_s > 0 |
| strike | share of target workers who stop, 0–1 | — | duration_s > 0; target must not be `kingdom`, `civilians` or `soldiers` (no single decision may stop a whole kingdom, model decision 6) |
| morale / happiness / stability | points, −20 to +20 | — | kingdom-level condition |
| loyalty | points, −20 to +20 | — | per targeted citizen |
| resource_over_time | total signed amount over duration_s, −500 to +500 | resource id (required) | duration_s > 0 |
| unlock_scenario | ignored | scenario id (required) | the targets may now be offered that scenario |
| memory | ignored | memory tag (default: consequence_id) | adds the memory to the targets |
| desertion_risk | added risk, 0–1 | — | soldiers only make sense as targets |
| unrest_pressure | points, −20 to +20 | — | feeds the sustained-condition unrest model (model decision 6); never a riot by itself |
| cue | ignored | — | cue_id required |

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

### 5.6 `citizens/names.csv`
| Column | | Type | Rules |
|---|---|---|---|
| kind | M | `given_f` `given_m` `given_n` `family` | |
| name | T | ≤ 16 | letters, `'`, `-`, spaces; unique within its kind |

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

### 5.9 `reputation/actions.csv` (non-dialogue ruler actions)
| Column | | Type | Rules / default |
|---|---|---|---|
| action_id | K | id | rows may repeat an action_id; all its rows must have the same event |
| event | M | `EventName` or `EventName:arg` | lint warns on unknown names (§8); `Building*:<BuildingType>`, `ResourceGathered:<resource>`, `MatchPhaseChanged:<phase>` |
| condition | M | cond, kingdom scope | when the row applies (the **need condition** for construction, model decision 5) |
| direct | N | | what the mechanic already does (informational, not exported) |
| farm_key, repeat_decay, repeat_window_s | M | as decisions | shared by every row of one action_id: leave them empty on later rows, or repeat the same values; farm_key defaults to action_id |
| rep_compassion … rep_fear | M | int −10 to +10 | the ruler's reputation change when this row applies |
| audience | M | `soldiers` `civilians` `occupation:<id>` `kingdom` `speaker` | who hears of it |
| audience_condition | M | cond, citizen scope | filter on each listener |
| audience_loyalty | M | int −10 to +10 | explicit loyalty change for matching listeners |
| morale, happiness, stability | M | int −10 to +10 | kingdom-level deltas |
| notice_text | T | ≤ 100 | history-log explanation |
| notes | N | | |

Each row is an independent effect that fires when its event fires and its `condition` holds. The direct versus indirect split works by rows, for example:
- `fund_barracks, BuildingCompleted:barracks, audience soldiers, +3`
- `fund_barracks, BuildingCompleted:barracks, condition kingdom.fed_ratio < 0.6, audience civilians, -2`

## 6. Effect model (what the runtime does with the data; ContentQuery implements 3–5)
1. **Reputation.** Every ruler has six values, 0–100, starting from `categories.start`. Every change is a history entry `{ t, category, delta, cause_id, text }`. `cause_id` is the decision_id or action_id, and `text` is the action notice_text or the scenario/response text.
2. **Loyalty and obedience.**
   - Loyalty is affection. It is stored per citizen, 0–100, and starts at 50 + chemistry/4.
   - Obedience is compliance. It is derived from rep.authority and rep.fear, weighted by the citizen's traits' `obedience_bias`.
   - Unrest risk uses both, plus kingdom happiness and stability.
3. **Personality.** Listener loyalty change = Σ_c(`weight_c` of the listener's traits × dR_c) × reach × chemistry multiplier.
   - reach: speaker 1, family 0.6, friends 0.4, rivals −0.3, whole kingdom 0.2 for public acts.
   - Explicit `*_loyalty` columns and `trait_overrides` are added on top.
4. **Chemistry.** −20 to +20 per citizen, seeded. Gains are multiplied by (1 + chem/40) and losses by (1 − chem/40).
5. **Anti-farming.** The n-th firing of a farm_key within `repeat_window_s` multiplies every reputation and loyalty **gain** by `repeat_decay^(n−1)`. Losses are never reduced. Construction gives reputation only through rows whose `condition` measures a need.
6. **Unrest.** Rebellions, riots and kingdom strikes come only from sustained conditions (threshold + minimum duration + instigator), configured outside this library. Decisions can only add `unrest_pressure` or local consequences.
7. **No hidden rolls.** Dialogue outcomes are deterministic. A consequence with `chance` < 1 is shown to the player as a risk before they choose.

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
{ scenarios = { [scenario_id] = { id, occupation, trigger = { Clause }, priority, cooldown_s, once_per_citizen, thought, question,
      responses = { { id, order, text, reaction, decision } } } },   -- responses sorted by order
  order = { scenario_id } }                                           -- file order
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
      audience, audience_condition = { Clause }, audience_loyalty, kingdom = { happiness, stability, morale }, notice? } },  -- file order
  byEvent = { [event] = { index into actions } } }
```
`target` keeps the source spelling, e.g. `"occupation:farmer"`. `param` is a string, or `nil` when empty. For `memory` it is always set: it falls back to consequence_id.

## 8. Known action events
`BuildingPlaced` `BuildingCompleted` `BuildingUpgraded` `BuildingDestroyed` `KeepUpgraded` `UnitsRecruited` `ObjectiveCaptured` `ObjectiveLost` `RaidDefended` `RaidSuffered` `FoodShortage` `FoodRestored` `RulerVisited` `ResourceGathered` `MatchPhaseChanged` `KingdomEliminated` `CitizenDied` `SoldierDied` `FeastHeld` `WarDeclared` `PeaceMade` `ArenaWon` `ArenaLost`.
- They are the CONTRACTS G9 events plus game-001 reputation events, which FORGE-01 fires.
- A new name only triggers a lint warning: add it to `KNOWN_EVENTS` in `content.py` once the runtime fires it.

## 9. Lint (design warnings, non-fatal)
**Dialogue**
- A response weakly dominates every other response in its scenario on all reputation, loyalty and net-resource columns.
- Two responses in one scenario share a decision.
- A scenario is repeatable with `cooldown_s` 0.

**Decisions**
- A free decision (no cost) has a reputation sum above 6.
- farm_key is missing (decisions and actions).
- A decision or consequence is not referenced anywhere.

**Consequences**
- `chance` is below 1 without notice_text.

**Actions**
- A construction event gives positive reputation without a `condition`.
- An event name is unknown.

**Library**
- A `citizen.memory.<tag>` is used but no decision or memory consequence sets it (system memories `rulerVisited` and `raided` are known).
- A key_role is used by more than one occupation.

## 10. Workbook (`export-xlsx` / `import-xlsx`)
- There is one sheet per CSV, named like the file without `.csv`, plus `README` and a hidden `lists` sheet.
- The header row is frozen, along with the first column.
- Header colours and cell fills: TEXT columns are light yellow and their header comment says **EDIT** with the length limit; mechanics columns are grey with a **MECHANICS** comment; notes columns are white.
- Dropdowns cover:
  - occupation, decision_id (live from the decisions sheet) and scenario_id;
  - consequence kind and target, audience, job_id, key_role, names kind, opposite and once_per_citizen.
- Text-length validations reject over-long text.
- Every cell is stored as text (`@`), so Excel keeps `+3`, `true` and ids unchanged.
- Import:
  - It reads only the known sheets and columns. An unknown sheet or column is an error.
  - A missing table sheet leaves that CSV untouched.
  - It preserves row order and skips fully blank rows.
  - It validates the whole library before writing anything, and rewrites only the rows that changed.
