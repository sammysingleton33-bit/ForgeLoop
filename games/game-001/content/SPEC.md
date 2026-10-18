# AI Kingdoms content library — formal schema (v1.5, 2026-10-13)

Owner of the format and the importer: `tools/content/content.py`. Editor guide for writers: [`README.md`](README.md).
Model rules come from FORGE-00 (model decisions 1–7, 2026-10-12). The starter rows are a **DRAFT proposal**, not approved dialogue.

v1.1 applies the content review of 2026-10-12: model decision 6 guards in the validator, mechanics placeholders in notices, presentation columns (`thought_icon`, `reaction_tone`), unlock gating, kingdom-gain anti-farming, rules for several rulers per kingdom, the runtime meaning of `actions.csv`, and a safer workbook import. Items that need a contract change are marked **(contract: FORGE-00)**.

v1.2 applies the FORGE-05 review of PR #53 and the FORGE-00 decisions on it: `fireDecision` results are final (loyalty decayed and clamped, §6.5), a runtime loyalty clamp per decision (§6.3), `fireAction` as the one anti-farming point of `actions.csv` (§6.9), integer start loyalty (§6.2), citizen keys for the shown history (§6.8), frozen generated modules (§7), the contracted G13.4 events (§8), `reaction_text` ≤ 80, stricter text and number checks (§2), and a workbook import that refuses formulas and never reverts a newer CSV text (§10).

v1.3 applies the verification of the v1.2 follow-ups: `fireAction` decays each row before it sums them (§6.9), `fireDecision` checks every listener's traits and relation first (§6.5), deep freezing also reaches inside input frozen only at the top (§7), notes and `actions.direct` refuse formulas and a consequence kind without a param refuses one (§2, §5.4), every Unicode format character is refused (§2), bubble texts must fit the bubble with the longest names filled in (§3), the missing-history rule names its functions (§7), and the workbook import refuses error values and never replaces a CSV it cannot read (§10).

v1.4 applies the FORGE-00 rulings on the FORGE-05 review of PR #67: risk notices describe only the outcome and never write `{chance}`, because the conversation panel shows the chance (§3, §5.4); `choicePreview` returns exactly the G13.3 option extras and `choiceRisks` gives `{ text, chance }` with the text filled (§6.7); `fireAction` credits reputation to the credited rulers and applies kingdom conditions and listeners once (§6.8, §6.9); a full anti-farming window gives 0 (§6.5); each citizen is one listener (§6.5, §6.9); a listener's net change is decayed as one value (§6.5); more blank characters and blank texts are refused (§2); `raid_defended` and `phase_fed_*` tuning (§8). Follow-ups to that review: ConversationService pays `decisionEffects(...).cost`, and `choicePreview` requires `fillNames` (§6.5, §6.7); the full-window bound is stated only for a full window (§6.5); default-ignorable characters such as a lone variation selector are blank text (§2).

v1.5 adds **optional presentation metadata** for the cinematic conversations (D-035 (4), D-036), in FORGE-06's measured vocabulary (§5.10): scenario `urgency`, `delivery_mode`, `thought_bubble_s` and `question_*` tags; reaction tags and `reaction_bubble_s`; high- and low-loyalty reaction variants (`reaction_high_*`, `reaction_low_*`); and the optional table `dialogue/question_variants.csv`, which gives some citizens another question by trait or condition. Every new column may be absent or blank and the file may be absent, so existing CSVs stay valid unchanged, and the generated modules of a library without the new data are byte-identical. Ignoring the tags changes no gameplay. A reaction's emotion must fit its tone. ContentQuery gains `reactionFor`, `questionFor`, `presentation`, `GESTURE_CUE` and `LOYALTY_BANDS` (§5.10, §7) **(contract: CONTRACTS G13.1, v0.4-g10)**. The workbook offers the new columns as yellow EDIT columns and adds a `question_variants` sheet (§10). Two lint hints (§9).

## 1. Files and pipeline

```
games/game-001/content/            canonical source (CSV, UTF-8, RFC 4180, header row, one file per table)
  dialogue/scenarios.csv  responses.csv  decisions.csv  consequences.csv
           question_variants.csv   (optional: may be absent, §5.10)
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
| `validate` | Parses every CSV and checks types, ranges, lengths, ids, references, the condition vocabulary and the model decision 6 guards. Prints `N scenarios, M responses, … — 0 errors` (with `K question variants` after the responses when that optional file exists), or one line per error, then exits 1. |
| `lint` | Prints design warnings (§9). It never fails. |
| `build` | Runs validate, then writes the generated modules. Output is deterministic: running it twice gives identical bytes. |
| `check` | Exits 1 if validation fails or a generated file is missing or differs from what `build` would write (CI). |
| `export-xlsx [path]` | Writes the editing workbook (default `games/game-001/content/AI_Kingdoms_Content.xlsx`), stamped with the CSV versions it was made from (§10). |
| `import-xlsx <path> [--build] [--text-only]` | Reads the workbook back (§10). It validates first and writes the CSVs only when there are 0 errors. It always lists every change, split into TEXT, MECHANICS and NOTES, and the cells it kept as in the CSV. Rows you did not change keep their exact original bytes. `--build` regenerates the Luau too; `--text-only` takes only the TEXT, choice and notes columns. Formula cells, and text that a CSV edited after the export changed too, are refused. |
| `fmt` | Rewrites every CSV in canonical form (Python `csv` minimal quoting, `\n` line ends). |

All commands take `--content DIR` (default `games/game-001/content`). `build`, `check` and `import-xlsx` also take `--out DIR` (default `games/game-001/src/shared/Content`).

**Error format.** `path:row:column: [column_name] message`. Row is the spreadsheet row: the header is row 1, so the first data row is row 2. Column is 1-based. While importing a workbook, errors name the sheet cell instead, e.g. `AI_Kingdoms_Content.xlsx › scenarios!C7 [trigger]: …`.

## 2. Common value types

| Type | Syntax | Notes |
|---|---|---|
| `id` | `^[a-z][a-z0-9_]*$`, ≤ 40 chars | Lower-case snake case. Luau keywords are allowed (emitted as `["end"]`). |
| `tag` | `^[A-Za-z][A-Za-z0-9_]*$`, ≤ 40 chars | Memory tags; `rulerVisited` style is allowed. |
| `int` | `-3`, `+3`, `3` (`3.0` is accepted as 3) | Signed columns may use an explicit `+`. ASCII digits only, like `number`. |
| `number` | decimal, e.g. `0.85`, `-1.5`, `.5`, `1e3` | ASCII digits `0-9` only: no `_` separators, no Arabic-Indic, full-width or superscript digits, no `nan`, `inf` or hex (also inside conditions). |
| `bool` | `true` / `false` (any case) | Empty means the column default. |
| `list` | `a;b;c` | Spaces around items are ignored. A trailing `;` is allowed. |
| `kv list` | `food:-20;gold:5`, `greedy:+3;kind:-2` | Each key at most once. |
| `resource` | `food`, `wood`, `stone`, `gold` | CONTRACTS G2 (`iron` is VS-2). |
| `cond` | condition expression (§4) | Parsed at build time into `{ Clause }`. |
| `TEXT` | player-facing text, one line | It has a length limit. It may not have leading or trailing spaces or line breaks, and it may not **start** with `=`, `+`, `-` or `@`: a spreadsheet opening the CSV would run it as a formula (CSV injection). Start with a letter, a digit or a quote mark instead (a dialogue dash is `—`). Placeholders: §3. |
| `choice` | a value from a short list | Presentation, edited together with the text (`thought_icon`, `reaction_tone`, and the optional tags of §5.10). |
| `notes` | free text for designers | Multi-line is allowed. It is never exported to the game. Developers open the CSVs in spreadsheets too, so a note may not start with `=` or `@`, and a note that starts with `+` or `-` may not hold a function call or a `\|` link (`+HYPERLINK(…)`, `-2+3+cmd\|…`): a spreadsheet would run it (CSV injection). `+housing capacity` and `-gold, +military readiness` are fine. `actions.direct` follows the same rule. |

- Unknown columns are errors, and so are missing required columns. An optional column may be absent from the header or left blank: both mean "no value". Column order inside a file is free, because the importer reads by header name. Fully blank rows are ignored.
- **Invisible characters are errors in every cell**: control characters U+0000–U+001F (a notes cell may hold tabs and line breaks), U+007F–U+009F, the soft hyphen U+00AD, zero-width U+200B–U+200D and U+2060, U+FEFF, the line/paragraph separators U+2028/U+2029, the bidirectional controls U+200E/U+200F and U+061C (marks), U+202A–U+202E (embeddings and overrides) and U+2066–U+2069 (isolates), which reorder how a line is shown, every other Unicode format character (category Cf, e.g. the invisible operators U+2061–U+2064, U+180E and the tag characters U+E0000–U+E007F), and the characters that show as nothing or as blank space: the Hangul fillers U+115F, U+1160, U+3164 and U+FFA0, the Braille pattern blank U+2800, the combining grapheme joiner U+034F and the musical symbol null notehead U+1D159. The message names the character and its position, e.g. `invisible character U+202E (right-to-left override) at position 6`. A workbook cannot hold most of them, so this also keeps `export-xlsx` working.
- **Blank text.** A TEXT cell that is not empty but holds nothing visible is an error in every TEXT column, required or optional: only spaces (ASCII, no-break, U+2000–U+200A such as the em space, U+3000 …), the invisible characters above and the other Unicode **default-ignorable** characters (the variation selectors U+FE00–U+FE0F and U+E0100–U+E01EF, the Khmer inherent vowels U+17B4/U+17B5, the Mongolian free variation selectors U+180B–U+180D and U+180F, and the reserved U+2065, U+FFF0–U+FFF8 and U+E0000–U+E0FFF), e.g. `text is blank: it holds only spaces or invisible characters (U+2003 em space), which the game would show as an empty line; write the text`. Such a space between words is fine, and so is a variation selector after an emoji (`❤️` is U+2764 U+FE0F), so these default-ignorable characters are refused only as a text's whole content, not in every cell; only a text with nothing else is refused. An optional text is left empty instead.
- **Encoding.** Every CSV is UTF-8. A file that is not names the first bad byte, its byte offset, and the spreadsheet row and column it falls in, e.g. `dialogue/scenarios.csv:3: not UTF-8 text: byte 0xE9 at byte offset 538 (column 8)`.

## 3. TEXT placeholders
The game fills placeholders in at runtime. Which ones a column may use depends on whether a single citizen is speaking:

| Column | Allowed placeholders |
|---|---|
| scenarios `thought_text`, `question_text`; responses `response_text`, `reaction_text`, `reaction_high_text`, `reaction_low_text`; question_variants `question_text` | `{name}` (the citizen's given name), `{ruler}` (the ruler's display name), `{kingdom}`, `{occupation}` (the citizen's occupation name), and `{family}`, `{friend}`, `{rival}` (the given name of a related citizen) |
| consequences `notice_text` | `{name}`, `{ruler}`, `{kingdom}`, `{occupation}` (all of the citizen spoken to), plus the **mechanics placeholders** `{magnitude}`, `{magnitude_pct}`, `{duration}`; never `{chance}` (below) |
| actions `notice_text` | `{ruler}`, `{kingdom}`; also `{name}` and `{occupation}` when the row's audience is `speaker` |
| everything else (traits, names, occupations, categories) | none |

- **Relations are guaranteed, not hoped for.** `{family}`, `{friend}` and `{rival}` are errors unless the scenario's trigger requires `citizen.has_family`, `citizen.has_friend` or `citizen.has_rival` (a response uses its scenario's trigger; a question variant uses its scenario's trigger plus its own `cond:` selector, §5.10).
- **Mechanics placeholders** keep notices true when the numbers change: `{magnitude}` → `+5` / `-4` (signed), `{magnitude_pct}` → `15%` (absolute, for productivity and strike shares), `{duration}` → `45 s` / `2 minutes`. `ContentQuery.consequenceNotice` and `ContentQuery.choiceRisks` fill them.
- **Risks never write their odds** (FORGE-00 ruling on the FORGE-05 review of PR #67, item 2). The conversation panel shows a risk's real chance next to its text (CONTRACTS G13.3 `risks: { { text, chance } }`, model decision 7), so a notice never contains `{chance}`: it is an error in every notice (`do not write {chance}: the conversation panel already shows a risk's chance next to its text …`), and typed odds are a lint warning. A consequence with `chance` < 1 still **must** have a notice, and that notice describes only the outcome, e.g. `{name} may walk off the job for {duration}.`, not `Risk ({chance}): …`.
- An unknown placeholder, one not allowed in that column, or an unbalanced brace is an error.
- Length limits count the raw text, so a placeholder counts by how it is spelled. Leave room for long names.
- **Bubble texts** (`thought_text`, `reaction_text`, `reaction_high_text`, `reaction_low_text`) must also fit FORGE-04's bubble (`Feedback/Bubbles` `maxChars` 80, which cuts longer text with an ellipsis; FORGE-00 decision L7) **with every placeholder at its longest**: `{name}`, `{family}`, `{friend}`, `{rival}` 16 (a given name, §5.6), `{ruler}` 20 (a Roblox display name), `{occupation}` 24 (§5.7), `{kingdom}` 20 (config `Kingdoms.luau` display names, the longest today 15; **FORGE-01 to keep kingdom names ≤ 20**). `validate` names the length the text can reach.

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
| urgency | C | `low` `normal` `high` `critical` | optional column; presentation only (§5.10) |
| delivery_mode | C | `ambient` `direct` | optional column; presentation only (§5.10). **Reserved:** no remote carries it yet (the G13.3 `thought` event is unchanged) |
| thought_icon | C | `request` `concern` `idea` | optional column; default `request` (CONTRACTS G13.3 `thought.icon`) |
| thought_text | T | ≤ 48 | thought bubble; also ≤ 80 with the longest names filled in (§3) |
| thought_bubble_s | C | number 2.5–9, one decimal | optional column; seconds the thought bubble stays (§5.10). **Reserved:** no remote carries it yet (the G13.3 `thought` event is unchanged) |
| question_text | T | ≤ 160 | the citizen's line when selected |
| question_emotion, question_expression, question_gesture, question_delivery | C | §5.10 vocabulary | optional columns; how the question is said (§5.10) |
| notes | N | | |

A scenario named by an `unlock_scenario` consequence is generated with `locked = true` (§5.4).

### 5.2 `dialogue/responses.csv`
| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | must exist in scenarios |
| response_id | K | id | globally unique |
| order | M | int | 1–4, unique within the scenario; each scenario has **2–4** responses |
| response_text | T | ≤ 70 | the ruler's answer |
| reaction_text | T | ≤ 80 | the citizen's reaction, shown in a speech bubble (FORGE-04's reaction bubble `maxChars` is 80; FORGE-00 decision L7); also ≤ 80 with the longest names filled in (§3) |
| reaction_tone | C | `happy` `angry` `sad` `neutral` | optional column; default `neutral` (CONTRACTS G13.3 `reaction.tone`) |
| reaction_emotion, reaction_expression, reaction_gesture, reaction_delivery | C | §5.10 vocabulary | optional columns; the emotion must fit `reaction_tone` (§5.10) |
| reaction_bubble_s | C | number 2.5–9, one decimal | optional column; seconds the reaction bubble stays |
| reaction_high_text, reaction_low_text | T | ≤ 80 | optional columns: the reaction at high / low loyalty (§5.10); the rules of `reaction_text` |
| reaction_high_tone, reaction_low_tone | C | `happy` `angry` `sad` `neutral` | required when that band's text is set, refused without it |
| reaction_high_emotion … reaction_low_bubble_s | C | §5.10 vocabulary / number 2.5–9 | optional; a band's tags need that band's text, and its emotion must fit that band's tone |
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
| chance | M | number (0, 1] | default 1. **Below 1 needs a notice_text** that describes the outcome; the panel shows the chance beside it (model decision 7, §3) |
| cue_id | M | id | feedback cue (vocabulary below) |
| notice_text | T | ≤ 100 | optional player notice (required for a risk); may use the mechanics placeholders (§3), never `{chance}` |
| notes | N | | |

| kind | magnitude | param | other rules |
|---|---|---|---|
| productivity | work-rate change, −1 to +1 (−0.2 = −20 %) | — | duration_s > 0. On a group (`occupation:<id>`, `soldiers`, `civilians`, `kingdom`) at least **−0.5**: only `speaker`/`family`/`friends` may stop work entirely (−1 = one citizen's walk-out). **A walk-out (≤ −1) is a state, not a sum (D-042):** the citizen stops working for the duration and shows a strike placard, and no boost cancels it. Boosts and smaller penalties add up only on working citizens |
| strike | share of the occupation's workers who stop, 0–**0.5** | — | duration_s 1–**120**. Target must be one **civilian** `occupation:<id>` (CONTRACTS G13.3 sends `strike { occupation, on }`); never `kingdom`, `civilians`, `soldiers` or an occupation whose job is soldier (model decision 6). Kingdom-wide strikes come only from the sustained unrest rules (§6.6) |
| morale / happiness / stability | points, −20 to +20 | — | kingdom-level condition |
| loyalty | points, −20 to +20 | — | per targeted citizen |
| resource_over_time | total signed amount over duration_s, −500 to +500 | resource id (required) | duration_s > 0 |
| unlock_scenario | ignored | scenario id (required) | that scenario is generated `locked = true` and is offered to a citizen only after this consequence reached them (`CitizenState.unlocked[scenarioId] = true`) |
| memory | ignored | memory tag (default: consequence_id) | adds the memory to the targets |
| desertion_risk | added risk, 0–1 | — | soldiers only make sense as targets |
| unrest_pressure | points, −20 to +20 | — | feeds the sustained-condition unrest model (model decision 6); never a riot by itself |
| cue | ignored | — | cue_id required |

A kind whose param is — refuses a non-empty param: it would reach the generated module unchecked.

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

### 5.10 Presentation metadata (optional; D-035 (4), D-036)
How a line is shown in the cinematic conversation (CONTRACTS G13.8): the portrait's emotion, expression and gesture, how the line is said, how long a bubble stays, and how pressing a scenario is. FORGE-06 measured the vocabulary on the draft lines.

- **Everything here is optional.** A column may be absent from the CSV or blank, and `dialogue/question_variants.csv` may be absent (no variants). Existing CSVs stay valid without these columns, and a library without this data generates byte-identical modules.
- **Presentation only.** Ignoring every tag changes no gameplay: eligibility, priorities, decisions and every effect stay the same. A tag that is not in the content is nil at runtime, never a default (except `tone`, which keeps its `neutral` default).
- **Props are not modelled.** Writers keep them in `notes`.

**Columns.**

| Table | Columns | Rules |
|---|---|---|
| scenarios | `urgency`, `delivery_mode` | enums below |
| scenarios | `thought_bubble_s` | number 2.5–9, at most one decimal (seconds) |
| scenarios | `question_emotion`, `question_expression`, `question_gesture`, `question_delivery` | enums below; the question has no tone, so any emotion is allowed. There is no `question_bubble_s`: the question waits for the answer |
| responses | `reaction_emotion`, `reaction_expression`, `reaction_gesture`, `reaction_delivery`, `reaction_bubble_s` | enums below; the emotion must fit `reaction_tone` (an empty tone is `neutral`, so a happy emotion needs `reaction_tone` happy) |
| responses | `reaction_<band>_text`, `reaction_<band>_tone`, `reaction_<band>_emotion`, `_expression`, `_gesture`, `_delivery`, `_bubble_s` for band `high` and `low` | the loyalty variants below |

**Vocabulary** (an unknown value is an error naming the allowed ones, with a "did you mean"):

| Tag | Values |
|---|---|
| emotion (20) | `determination` `frustration` `gratitude` `relief` `joy` `excitement` `worry` `suspicion` `anger` `fear` `contempt` `sadness` `neutral` `hope` `amusement` `curiosity` `defiance` `pride` `embarrassment` `grief` |
| expression (13) | `smile` `frown` `smirk` `beam` `neutral` `grin` `raised_brow` `scowl` `eye_roll` `wide_eyed` `downcast` `teary` `sheepish` |
| gesture (21) | `nod` `shrug` `hand_on_heart` `cross_arms` `none` `point` `fist_pump` `head_down` `throw_up_hands` `wring_hands` `salute` `scratch_head` `lean_in` `hold_up` `glance_around` `hands_on_hips` `rub_neck` `bow` `wave` `step_back` `raise_hand` |
| delivery (15) | `warm` `blunt` `deadpan` `cheerful` `excited` `grumbling` `sarcastic` `solemn` `urgent` `proud` `hushed` `nervous` `formal` `pleading` `playful` (there is no `defiant`: use emotion `defiance`) |
| urgency (4) | `low` `normal` `high` `critical` |
| delivery_mode (2) | `ambient` (the scenario reaches the ruler as a thought bubble to notice) · `direct` (the citizen seeks the ruler out) |

**Emotion fits tone** (validate error otherwise: `emotion 'anger' does not fit tone 'happy': a happy line takes …`):

| Tone | Emotions that fit |
|---|---|
| `happy` | `joy` `gratitude` `pride` `relief` `hope` `amusement` `excitement` `determination` |
| `neutral` | `neutral` `determination` `curiosity` `suspicion` `amusement` `worry` `hope` `frustration` `relief` |
| `angry` | `frustration` `anger` `contempt` `defiance` `suspicion` |
| `sad` | `sadness` `grief` `worry` `fear` `embarrassment` |

**Gesture cues.** A gesture that has a feedback cue (§5.4 vocabulary) also plays it: `bow` → `bow`, `salute` → `salute`, `step_back` → `cower`, `fist_pump` → `celebrate`, `cross_arms` → `grumble`; every other gesture has none. The mapping is data: `ContentQuery.GESTURE_CUE`.

**Bubble seconds.** `thought_bubble_s`, `reaction_bubble_s` and `reaction_<band>_bubble_s` are numbers from 2.5 to 9 with at most one decimal (`3.5`, not `3.25`). Empty = the presentation default (FORGE-04).

**Loyalty variants of a reaction.** `reaction_high_text` is shown instead of `reaction_text` when the citizen's loyalty is at least `ContentQuery.LOYALTY_BANDS.high` (70, **PROVISIONAL**), `reaction_low_text` when it is at most `LOYALTY_BANDS.low` (30, **PROVISIONAL**).
- A band's text follows every `reaction_text` rule: TEXT, ≤ 80 characters and ≤ 80 with the longest names filled in, the same placeholders, and `{family}`/`{friend}`/`{rival}` only when the scenario's trigger guarantees the relation (§3).
- `reaction_<band>_tone` is required when the band's text is set.
- The band's tags are optional, and its emotion must fit **that band's** tone.
- A band's tone or tags without its text are an error (`reaction_low_tone is set but reaction_low_text is empty …`).

**`dialogue/question_variants.csv`** (optional file): another question for some citizens of a scenario.

| Column | | Type | Rules |
|---|---|---|---|
| scenario_id | K | id | must exist in scenarios |
| variant_id | K | id | unique (id rules, §2) |
| order | M | int ≥ 1 | unique within the scenario; the lowest matching order wins |
| selector | M | `trait:<trait_id>` or `cond:<condition>` | `trait:` = the citizen has that trait (it must exist in traits.csv); `cond:` = a condition in the language and vocabulary of triggers (§4, citizen scope), e.g. `cond:citizen.loyalty >= 70` |
| question_text | T | ≤ 160 | the rules of `scenarios.question_text`; `{family}`/`{friend}`/`{rival}` need the relation in the scenario's trigger or in this variant's `cond:` |
| question_emotion, question_expression, question_gesture, question_delivery | C | vocabulary above | optional |
| notes | N | | optional column |

A bad selector (`'traits:greedy' is not a selector (did you mean 'trait'?)`), an unknown scenario or trait, an empty `cond:`, a duplicate variant id or a repeated order within a scenario is an error. Memories read by a `cond:` selector count as reads for lint (§9).

**Runtime** (`ContentQuery`, pure; full API in its header):
- `reactionFor(responseId, loyalty?) -> { text, tone, emotion?, expression?, gesture?, delivery?, bubble_s?, band }`: `band` is `"high"` when loyalty ≥ `LOYALTY_BANDS.high` and the response has a high text, `"low"` when loyalty ≤ `LOYALTY_BANDS.low` and it has a low text, else `"base"` (the reaction, its tone and tags). A nil, NaN or infinite loyalty gives `"base"`; an unknown response gives nil.
- `questionFor(scenarioId, citizen, ctx) -> { text, emotion?, expression?, gesture?, delivery?, variantId? }`: the first variant by `order` whose selector matches (`trait:<id>`: `citizen.traits` contains the id; `cond:`: `evaluate(cond, ctx)`, the same rules as triggers, §4), else the scenario's `question_text` with its `question_*` tags and no `variantId`. An unknown scenario gives nil; a citizen that is not a table is an error.
- `presentation(scenarioId) -> { urgency?, delivery_mode?, thought_bubble_s? }`; nil for an unknown scenario.
- `GESTURE_CUE` (above) and `LOYALTY_BANDS = { high = 70, low = 30 }` (PROVISIONAL).
- Texts are returned raw: the caller fills their placeholders as for the base question and reaction.
- **(contract: FORGE-00)** CONTRACTS G13.1 (v0.4-g10) gains `reactionFor`, `questionFor`, `presentation`, `GESTURE_CUE` and `LOYALTY_BANDS`. The functions are additive: nothing existing changes behaviour.

## 6. Effect model (what the runtime does with the data; ContentQuery implements 3–5, 7 and 9)
1. **Reputation.** Every ruler has six values, 0–100, starting from `categories.start`. Every change is a history entry `{ t, category, delta, source, text }` (the field names of CONTRACTS G13.4). `source` is the decision_id or action_id, and `text` is the action notice_text or the scenario/response text.
2. **Loyalty and obedience.**
   - Loyalty is affection. It is stored per citizen, 0–100, and starts at the integer `ContentQuery.startLoyalty(chemistry)` = `math.floor(50 + chemistry/4 + 0.5)` (45–55, halves round up; FORGE-00 decision L12). CitizenService uses this function for every citizen it generates, so the formula lives in one place.
   - Obedience is compliance. It is derived from rep.authority and rep.fear, weighted by the citizen's traits' `obedience_bias`.
   - Unrest risk uses both, plus kingdom happiness and stability.
3. **Personality.** Listener loyalty change = Σ_c(`weight_c` of the listener's traits × dR_c) × reach × chemistry multiplier.
   - reach: speaker 1, family 0.6, friends 0.4, rivals −0.3, whole kingdom 0.2 for public acts.
   - Explicit `*_loyalty` columns and `trait_overrides` are added on top.
   - **Clamp (FORGE-00 decision M3).** The change one decision, or one action firing, applies to one listener is clamped at runtime, after the personality term, chemistry and anti-farming decay: speaker ±25, family, friends and rivals ±10, kingdom/audience listeners ±5 (`ContentQuery.LOYALTY_CLAMP`). The cap therefore includes the personality term, which the validator cannot see. The validator still checks the explicit columns (`*_loyalty` −10..+10, and the kingdom-wide floor of §5.3). Loyalty **consequences** are separate effects with their own magnitude (validated −20..+20 and by the §5.3 floor); they are not part of this clamp, so one decision can move a listener further than it: on the draft content `promise_sacks_keep` gives a friend up to 10 from the decision plus 2 from `friends_hear_kept_word`. **FORGE-00 ruling (2026-10-13):** loyalty consequences stay outside the clamp. They are separate, visible follow-up effects bounded by the validator, not a headroom cap.
4. **Chemistry.** −20 to +20 per citizen, rolled at generation (seeded). Gains are multiplied by (1 + chem/40) and losses by (1 − chem/40). `speaker_chemistry` may move it by at most **±5** from the rolled value over a whole match (`ContentQuery.driftChemistry`), and its gains decay like loyalty (6.5). **FORGE-00 ruling (2026-10-12):** the ±5 drift is confirmed. living-kingdom.md §1 and CONTRACTS G13.2 say so.
5. **Anti-farming.** The n-th firing of a farm_key within `repeat_window_s` multiplies gains by `repeat_decay^(n−1)`. Losses are never reduced.
   - **A full window gives 0** (FORGE-00 ruling on the PR #67 review, item 8). A FarmHistory keeps the newest `ContentQuery.MAX_FARM_HISTORY` (32) firings per farm_key. Once the window holds that many, every further gain gets multiplier **0**, not `repeat_decay^32`. So while the window stays full, the total of a farmed gain stays below one firing / (1 − repeat_decay): e.g. RaidDefended once a second for 30 minutes (decay 0.5, window 300 s) gives at most 2 × one firing. The bound needs a full window. A player who spaces the firings so the window holds 31 of them gets `repeat_decay^31` on every further firing, which is small but not 0: 0.8^31 ≈ 0.001 of one firing (about +0.2 firings an hour at decay 0.8 and a 600 s window), 0.5^31 ≈ 5 × 10⁻¹⁰. That is negligible for decay ≤ 0.8. A decay of 1 or a window of 0 still means no anti-farming at all.
   - Reputation gains use the **ruler's** firing history.
   - Loyalty gains, kingdom happiness/stability/morale gains, chemistry gains and gain consequences (loyalty, morale, happiness, stability > 0; unrest_pressure < 0) use the **kingdom's** firing history. This extends model decision 5 so repeated cheap construction and free answers cannot farm the conditions that gate riots and the Crown Arena (**confirmed by FORGE-00**, CONTRACTS G13.1).
   - `ContentQuery.fireDecision(id, rulerHistory, kingdomHistory, now, listeners?)` is the single anti-farming point of a choice (CONTRACTS G13.1). It computes both multipliers, records the firing and returns the final bundle, which the runtime applies **as given**: no second decay and no second clamp, in ReputationService or anywhere else.
     - Order in ConversationService: re-check eligibility; pay the cost through TreasuryService and stop if that fails; then call `fireDecision` once. The cost to pay is `decisionEffects(response.decision).cost` (the response's `decision` in `Dialogue.scenarios[scenarioId].responses`): always a table, `{}` for a free answer, and it never errors. Do not pay `choicePreview(...).cost`: that is the G13.3 option extra, nil for a free answer. The result's `cost` is informational: it is already paid.
     - Reputation `rep` is decayed with the ruler's multiplier. Kingdom happiness/stability/morale, `speaker.chemistry`, gain consequences and the explicit loyalty columns are decayed with the kingdom's. Losses are never decayed.
     - `speaker.loyalty`, `family_loyalty`, `friends_loyalty`, `rivals_loyalty`, `audience_loyalty` are what a listener with no personality reaction gets: the column, decayed, clamped (§6.3). The raw columns are in `loyalty_raw`, the raw reputation vector in `rep_raw` (both for logs and previews).
     - `listeners`: pass `{ { citizen, relation, traits, chemistry? } }` (the speaker, their family, friends, rivals and the decision's audience, each once under its closest relation) and the result holds `{ citizen, relation, loyalty }` per listener: personality, trait overrides, chemistry, decay and clamp included. A listener's change is that `loyalty`, never `loyalty` plus a column. `ContentQuery.decisionLoyalty(id, traits, relation, chemistry, e.kingdom_multiplier)` gives the same number one listener at a time. Every listener is checked before anything is recorded, as `fireAction` does: it needs a `citizen` key, its traits must be known trait ids and its relation one of the five, or the call errors naming it (`ContentQuery.fireDecision: listener #2 has an unknown trait 'x'`).
     - **Each citizen is one listener** (FORGE-00 ruling on the PR #67 review, item 9). A citizen given twice, across relations too (the speaker who is also in the audience, a friend who is also family), would be counted twice, so the call errors and records nothing: `listener #3 repeats citizen 7 (listener #1): pass each citizen once, under its closest relation (speaker > family > friends > rivals > kingdom)`. Keys compare like the shown-history: `7` and `"7"` are different citizens.
     - **A listener's net change is decayed as one value** (FORGE-00 ruling on the PR #67 review, item 11: intended). For one decision, a listener's personality term, the relation's column and its trait overrides are summed first; then only a net **gain** is multiplied by the kingdom multiplier, and a net loss stays whole. Example (a decision with compassion +3, authority −1 and `speaker_loyalty` +6, on a repeat with kingdom multiplier 0.5): a brave speaker (authority weight 1) has personality −1, net +5, a gain, and gets 5 × 0.5 = **2.5**, not 6 × 0.5 − 1 = 2; a cruel speaker (compassion −1, authority 1, override −3) has personality −4, net −1, a loss, and gets **−1** on every repeat, not 6 × 0.5 − 4 − 3 = −4. Actions differ on purpose: each `actions.csv` row is decayed on its own before the rows are summed (§6.9), because rows are separate effects for separate audiences.
   - Construction gives reputation only through rows whose `condition` measures a need.
6. **Unrest.** Rebellions, riots and kingdom strikes come only from sustained conditions (threshold + minimum duration + instigator), configured outside this library. A decision can only add `unrest_pressure` or local consequences, within the caps of §5.3 and §5.4: no strike of soldiers or of more than half an occupation, no group stoppage below −50 %, no consequence longer than 600 s, kingdom-wide loyalty and stability each ≥ −5 per decision.
7. **No hidden rolls.** Dialogue outcomes are deterministic. A consequence with `chance` < 1 is shown to the player as a risk before they choose, with its real odds.
   - **Options** (CONTRACTS G13.3): Kingdom.Converse sends each option as `{ id, text, cost?, risks? }`. The server builds the extras with `ContentQuery.choicePreview(scenarioId, responseId, fillNames)`, which returns exactly `{ cost: ResourceBag?, risks: { { text: string, chance: number } }? }`: `cost` is what the answer costs (nil when it is free), `risks` the answer's risks (nil when there are none). No decision id and no consequence records reach the client. **`fillNames` is required**: always pass the conversation's `{ name, ruler, kingdom, occupation }`, because risk texts name the citizen (`{name} may walk off the job …`). A nil `fillNames` is an error on every call, not only on the answers whose risk names someone, so a server that forgets it fails at once. For the cost to pay, see §6.5.
   - **Risks.** `ContentQuery.choiceRisks(decisionId, fillNames)` lists `{ text, chance }` for each of the decision's consequences with `chance` < 1, in the decision's order. `text` is the notice **fully filled**: `fillNames = { name, ruler, kingdom, occupation }` of the conversation, then the mechanics placeholders (`consequenceNotice`). A placeholder that fillNames does not cover is an error, never a half-filled text.
   - The panel shows `chance` itself, next to the text (e.g. "50%"), so content never repeats it (§3).
8. **Several rulers in one kingdom** (G2 `rulers: { number }`; G3 parties share a kingdom).
   - Reputation and `decision.*` belong to each ruler.
   - **Conversations** (`Kingdom.Converse` / `Kingdom.Choose`): the ctx uses the acting ruler's `rep.*`, `decision.*` and the citizen's obedience towards that ruler.
   - **Thought bubbles** (kingdom-wide, refreshed every 20 s): `rep.<c>` is the highest value among the kingdom's current rulers, `decision.<id>` is true when any of them chose it, and obedience is computed from those values. When a ruler opens the conversation, Converse re-checks with that ruler's own values and offers the next eligible scenario, or nil.
   - **Credit for actions** (FORGE-00 ruling on the PR #67 review, item 3). Reputation from an `actions.csv` event goes to the **credited rulers**: the attributed actor when the event has one (e.g. `Building.placedBy` for construction, the capturing or acting player), otherwise every current co-ruler (kingdom-wide events such as `FoodShortage`). ReputationService passes them to `fireAction` as `creditedRulers`, with each one's FarmHistory in `rulerHistories`. Each credited ruler gets the firing's reputation decayed by **their own** history; kingdom conditions and listener loyalty are computed and returned **once per firing**, however many rulers are credited.
   - **Histories.** `FarmHistory`: one per ruler (reputation) and one per kingdom (loyalty and kingdom conditions), so co-rulers cannot each farm the same citizens. `ShownHistory` (cooldowns, once_per_citizen) is one per kingdom, keyed by `ContentQuery.citizenKey(citizen)`: the citizen's `id`, else `entityId` (G13.2 `CitizenView`), else `key` (FORGE-01 `Population.Citizen`). `eligibleScenarios` errors when it gets a history for a citizen with none of the three, and `markShown` takes the same key.
   - **Memories set by content** (`memory_tag` and `memory` consequences) are **pinned**: they are kept apart from, or never evicted by, the G5 rule of at most 8 memories, so a promise always comes due and `!citizen.memory.quarry_shored` stays false once the quarry is shored **(contract: FORGE-00 to note this in G5/G13.2)**.
   - **(contract: FORGE-00)** Record these rules in CONTRACTS G13.1.
9. **Actions at runtime** (`reputation/actions.csv`).
   - **`ContentQuery.fireAction(event, kingdomCtx, rulerHistories, creditedRulers, kingdomHistory, now, listeners?)` is the single anti-farming point of `actions.csv`** and mirrors `fireDecision`. ReputationService calls it once per event and applies every result **as given**. `rulerHistories = { [rulerKey]: FarmHistory }`; `creditedRulers = { rulerKey }` (§6.8): each credited ruler must have a FarmHistory there and appear once, or the call errors and records nothing; an empty list credits nobody, and the kingdom conditions and listeners still apply.
   - It reads `actionFirings(event, kingdomCtx)`: the rows whose `condition` holds. `Name:arg` also matches rows written for the bare `Name`. Rows are grouped per action_id: **one event = one firing of that action's farm_key**, recorded once in each credited ruler's FarmHistory and in the kingdom's (a table passed for two of them is recorded once) before the next firing is computed.
   - A firing's `rulers` holds `{ ruler, multiplier, rep }` per credited ruler, in `creditedRulers` order: `rep` is the sum over the firing's rows of each row's vector with gains × that ruler's multiplier. Its `kingdom` (happiness, stability, morale) is the same with the kingdom's multiplier, **once** per firing. Each row is decayed on its own, then summed, so a loss is never decayed together with another row's gain (e.g. `keep_upgraded` while starving: +3 and −1 happiness give 3 × 0.5 − 1 = 0.5 on the second upgrade, not (3 − 1) × 0.5 = 1). The listeners use the same rule. The raw sums are in `rep_raw` and `kingdom_raw`; `rows` are the shared, frozen content rows (for notices).
   - Each citizen hears a row when `inActionAudience(row, listener, listenerCtx)` holds: `kingdom` = everyone; `soldiers` = occupations whose job is soldier (the captain too); `civilians` = everyone else; `occupation:<id>`; `speaker` = the one citizen the event is about (e.g. the visited citizen). Then the row's `audience_condition` must hold for that listener.
   - A listener reacts to **that row's own** rep vector: personality at reach 1 for `speaker` and 0.2 for every group, plus `audience_loyalty`, then gains × the kingdom's multiplier. Pass `listeners = { { citizen, occupation?, speaker?, traits, chemistry?, ctx? } }`, each citizen once (a repeated citizen is an error, as in §6.5), and each firing returns `listeners = { { citizen, relation, loyalty } }` for every listener who hears at least one row: the rows it hears are summed, then clamped once (§6.3) as `speaker` when it hears a speaker row, else as `kingdom`. `actionLoyalty(row, …)` is the same for one row.
10. **Not in this library.** Thresholds, rates and windows of the sustained rules live in FORGE-01 config `Society.luau`, including a **fear relaxation rate** (fear drifts back towards its start when nothing feeds it), so fear-led rule keeps its risk "when fear drops" **(request: FORGE-01)**.

## 7. Generated Luau (`games/game-001/src/shared/Content/`)
Every file starts with:
```
--!strict
-- GENERATED by tools/content/content.py from games/game-001/content — do not edit
```
- Every module is **deeply frozen** when it is required (a local `deepFreeze` helper the generator writes into each file): the tables are shared by every consumer, so writing into one is an error, never a silent change for everybody. `ContentQuery.new(data)` freezes the tables it is given the same way (also inside a table that was frozen only at the top, e.g. `table.freeze({ ... })`, and each table once, so a cycle is safe), so nothing ContentQuery returns is a mutable shared record; everything else it returns (effects, previews, firings) is a fresh table the caller owns.
- Map keys are sorted, except resources (G2 order) and categories (canonical order).
- Lists keep file order.
- Empty optional values are **omitted** (nil), never `""`.
- Notes columns are not exported.
- The output passes `stylua --check` and `selene`.

```lua
-- Dialogue.luau
{ scenarios = { [scenario_id] = { id, occupation, trigger = { Clause }, priority, cooldown_s, once_per_citizen,
      locked, icon, thought, question,
      urgency?, delivery_mode?, thought_bubble_s?,                            -- §5.10, only when present
      question_emotion?, question_expression?, question_gesture?, question_delivery?,
      responses = { { id, order, text, reaction, tone,
          emotion?, expression?, gesture?, delivery?, bubble_s?,             -- the reaction's tags (§5.10)
          decision,
          bands = { high = Band?, low = Band? }? } },                         -- responses sorted by order
      variants = { { id, order, trait? | cond = { Clause }?, text,           -- question_variants.csv, sorted
          emotion?, expression?, gesture?, delivery? } }? } },                --   by order; nil when none
  order = { scenario_id } }                                                   -- file order
-- Band = { text, tone, emotion?, expression?, gesture?, delivery?, bubble_s? }
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
**Reading trait weights.** A trait's value weight for a category is `Traits[traitId].weights[category]` (e.g. `Traits.kind.weights.compassion`); the CSV columns `weight_<category>` are not flat fields of the record. `ContentQuery.loyaltyDelta` reads them this way; any consumer that scores a decision for a citizen must too.

The presentation fields of §5.10 are emitted only when present, so a library without them generates the same bytes as v1.4; `Dialogue.luau` names `dialogue/question_variants.csv` in its `Source:` line only when that file exists.

`target` keeps the source spelling, e.g. `"occupation:farmer"`. `param` is a string, or `nil` when empty. For `memory` it is always set: it falls back to consequence_id. `icon` and `tone` are always set (defaults `request`, `neutral`); `locked` is always a boolean.

**ContentQuery** (hand-written, pure; full API in its header): `evaluate`, `eligibleScenarios` (respects `locked` via `CitizenState.unlocked`), `reactionFor`, `questionFor`, `presentation` (§5.10), `citizenKey`, `markShown`, `choicePreview`, `choiceRisks`, `decisionEffects`, `fireDecision`, `fireAction`, `loyaltyDelta`, `decisionLoyalty`, `actionFirings`, `inActionAudience`, `actionLoyalty`, `repeatMultiplier`, `recordFire`, `scaleGain`, `scaleGains`, `clampLoyalty`, `applyChemistry`, `startLoyalty`, `driftChemistry`, `noticeValues`, `fill`, `consequenceNotice` (the mechanics values are filled last, so a name can never replace them), `durationText`, `REACH`, `LOYALTY_CLAMP`, `LOYALTY_BANDS`, `GESTURE_CUE`, `CATEGORIES`, `OPS`, `GAIN_SIGN`. A nil citizen or a nil/NaN/infinite `now` is an error with a clear message, never a silent "no decay"; so is a missing history where one is required: both histories of `fireDecision` and `fireAction`, and the history of `recordFire` and `markShown`. The two lookups take an optional history: `eligibleScenarios` (nil = nothing shown yet) and the `repeatMultiplier` building block (nil = no earlier firings, multiplier 1).

## 8. Action events
**Bus events (CONTRACTS G9, on `Contracts/GameEvents`).** `KingdomJoined` `MatchPhaseChanged` `BuildingPlaced` `BuildingCompleted` `BuildingUpgraded` `BuildingDestroyed` `ResourceGathered` `UnitsRecruited` `ObjectiveCaptured` `KingdomEliminated` `MatchEnded`. A keep upgrade is `BuildingUpgraded:keep` (there is no separate KeepUpgraded event, so it is never counted twice).

**Reputation action events (CONTRACTS G13.4).** FORGE-01 produces them and appends them to the GameEvents bus as D-024 did. Lint treats every G9 and G13.4 event as known and warns once per name on any other.

| Event | Stage | Fired when | Suggested payload |
|---|---|---|---|
| `FoodShortage` | VS-1 | fed ratio falls below 0.5 (also sets `event.shortage`) | (KingdomId, fedRatio) |
| `RulerVisited` | VS-1 | a ruler talks to a citizen (the G5 `rulerVisited` memory); audience `speaker` | (rulerUserId, entityId) |
| `ObjectiveLost` | VS-1 | an objective owned by the kingdom is captured by another (derived from `ObjectiveCaptured`) | (objectiveId, KingdomId lost, by: KingdomId) |
| `PhaseEndedWellFed` | VS-1 | a phase ends and the lowest fed ratio during it was ≥ 0.9; at most once per phase end; replaces the interim `MatchPhaseChanged:<phase>` rows of `phase_fed_*` once FORGE-01 fires it | (KingdomId, phase) |
| `RaidDefended` / `RaidAbandoned` | VS-2 | a raid on the kingdom ends: driven off / not stopped while the ruler was nearby | (KingdomId, raidId, rulerUserId?) |
| `EnemyAttacked` | VS-2 | the kingdom's army engages an enemy kingdom | (KingdomId, target: KingdomId) |
| `EnemyFarmsBurned` | VS-2 | the kingdom burns enemy farms | (KingdomId, target: KingdomId) |
| `TruceBroken` | VS-2 | the kingdom breaks a truce | (KingdomId, target: KingdomId) |
| `DeserterExecuted` / `DeserterForgiven` | VS-2 | the ruler's choice about a caught deserter (player-facing text stays 13+: "faced the ruler's justice") | (rulerUserId, entityId) |

**Tuning rulings** (FORGE-00 on the PR #67 review, item 7). `raid_defended` decays by 0.5 per repeat inside its 300 s window. The `phase_fed_*` rows decay by 0.8 inside 60 s: **`PhaseEndedWellFed` fires at most once per phase end** (FORGE-01), so the decay only bites when phases end in quick succession (skipped phases, debug presets), and the interim `MatchPhaseChanged:<phase>` rows fire once per phase change the same way.

**Not contracted.** `RaidSuffered` (a raid ends not stopped while the ruler was elsewhere) is used by `raid_suffered` but is **not** in G13.4. It is not the same as `RaidAbandoned` (the ruler was nearby and left), so the row is kept rather than re-pointed, and lint warns once **(contract: FORGE-00 to add it to G13.4, producer FORGE-01; until then nothing fires the row)**.

Arena results are not reputation events: the Crown Arena ends the match, so nothing could follow from them.

## 9. Lint (design warnings, non-fatal)
**Dialogue**
- A response weakly dominates every other response in its scenario on all non-fear reputation, loyalty, chemistry, kingdom (happiness, stability, morale) and net-resource columns. Fear is a tool, so more of it is not "better".
- **Sampled personality check.** Lint generates a seeded sample of the citizens who can raise each scenario (occupation, its trait affinities, 2–3 traits without opposite pairs, chemistry −20..+20; trait and chemistry clauses of the trigger respected) and scores each answer's speaker loyalty with ContentQuery's formula. It warns when a **free** answer is the best for more than 80 % of them and also has the highest reputation sum (fear aside).
- Two responses in one scenario share a decision.
- A scenario is repeatable with `cooldown_s` 0.
- A locked scenario that no used consequence unlocks.
- A `direct` scenario with urgency `low` (a citizen who seeks the ruler out should have a pressing reason, or the scenario is `ambient`; §5.10).
- A reaction (base, high or low band) with presentation tags but no emotion: the portrait and the world rig key on the emotion (§5.10).

**Decisions**
- A free decision (no cost) has a reputation sum, fear aside, above 6.
- farm_key is missing (decisions and actions).
- A decision or consequence is not referenced anywhere.

**Consequences and text**
- A cue_id outside the cue vocabulary (§5.4).
- A notice_text that types a number (use the mechanics placeholders; a risk's chance is never written, §3).

**Actions**
- A construction event gives positive reputation without a `condition`.
- An event name that is neither a CONTRACTS G9 bus event nor a G13.4 reputation event (once per name; today only `RaidSuffered`, §8).

**Library**
- A `citizen.memory.<tag>` is used (in a trigger, a condition or a `cond:` selector) but no decision or memory consequence sets it (system memories `rulerVisited` and `raided` are known).
- A memory is set but no trigger reads it (fine as flavour for the citizen card; a promise needs a follow-up that reads it).
- A key_role is used by more than one occupation.

Former lint "chance < 1 without notice_text" is now a validate error (§5.4).

## 10. Workbook (`export-xlsx` / `import-xlsx`)
- There is one sheet per CSV, named like the file without `.csv`, plus `README` and a hidden `lists` sheet (dropdown lists and the export stamp). The `question_variants` sheet is there even when `dialogue/question_variants.csv` does not exist yet (header only).
- **Offered columns.** Every optional TEXT and presentation column a CSV lacks (`thought_icon`, `reaction_tone`, the §5.10 tags and the loyalty-variant texts) is offered in its sheet after the CSV's own columns, so existing cells keep their letters. An import adds such a column to the CSV only when a row it imports holds a value in it, right after the nearest column before it in the schema; an offered column left empty never reaches the CSV, so the round trip stays byte-identical. A value the import does not take adds nothing either: one only in a row `--text-only` ignores (a new row, or a row whose id changed), or one kept as in the CSV (a stale workbook, below).
- The header row is frozen, along with the first column.
- Header colours and cell fills: TEXT and choice columns are light yellow and their header comment says **EDIT** (with the length limit and the placeholders that column accepts); mechanics columns are grey with a **MECHANICS** comment; notes columns are white; read-only help columns are blue.
- **Read-only help columns.** The responses sheet ends with `info: question` (the scenario's question) and `info: effects` (cost, reputation, loyalty and consequences of the decision); the question_variants sheet ends with `info: question` (the scenario's own question). Import ignores them.
- Dropdowns cover:
  - occupation, decision_id (live from the decisions sheet) and scenario_id;
  - consequence kind and target, audience, job_id, key_role, names kind, opposite, once_per_citizen, thought_icon and reaction_tone;
  - the §5.10 tags: emotion, expression, gesture, delivery, urgency, delivery_mode and the band tones (strict lists). The bubble seconds are numbers without a dropdown, and `selector` is a grey MECHANICS column.
- Text-length validations reject over-long text.
- Every cell is stored as text (`@`), so Excel keeps `+3`, `true` and ids unchanged.
- **Export stamp.** The hidden `lists` sheet records the SHA-256 of every CSV at export time (`stamp_file`, `stamp_sha256`), and a short hash of every editable cell (text, choice and notes) keyed `table|row|column` (`stamp_cell`, `stamp_cell_sha256`; the row is the id, or `row N` in names and actions).
- Import:
  - **Formulas are refused.** The workbook is read with formulas as formulas (openpyxl `data_only=False`), and any cell holding one is an error naming the cell, e.g. `consequences!J2: this cell is a formula ('=…')`. Reading cached values instead would silently blank a formula that has no cached value and take whatever value another one last showed. TEXT that starts with `=`, `+`, `-` or `@` is refused by validation, and so is a note that would run as a formula (§2). A cell holding a spreadsheet **error value** without a formula (`#REF!`, `#N/A`, e.g. after *Paste values*) is refused the same way: `responses!E3: this cell shows a spreadsheet error ('#REF!'); type the value itself`.
  - It reads only the known sheets and columns. An unknown sheet or column is an error: never add or remove columns.
  - A missing table sheet leaves that CSV untouched.
  - **A CSV the import cannot read** (not UTF-8, e.g. saved as Excel's *CSV (Comma delimited)*, or a broken header) is never replaced from the workbook, with or without `--text-only`: the import cannot tell which of its cells changed after the export, so it names the file and the problem and writes nothing. Fix the file, then import again. Only a missing CSV, or one byte-identical to the export, is written from the workbook as a whole.
  - **Order.** Rows go back to their CSV order (by id; new ids at the end, in workbook order). A table without an id (names, actions) is restored when its rows are only re-sorted. Sorting and filtering are therefore safe, and the priority tie-break (file order) cannot change from the workbook.
  - **Stale workbooks: mechanics.** If a CSV changed after the export (or the workbook has no stamp), any MECHANICS difference from the current CSV is refused with the cell, the old and new value and the reason. Export a fresh workbook, or use `--text-only`.
  - **Stale workbooks: text, choice and notes (review finding M4), with or without `--text-only`.** For every editable cell where the workbook and the current CSV differ:
    - the CSV cell is as exported (its file is unchanged, or the cell stamp matches the CSV): the workbook value is taken;
    - the workbook cell is as exported (the cell stamp matches the workbook): only the CSV changed, so the newer CSV value is **kept** and listed as `kept`;
    - both changed, or the workbook has no cell stamp and the file changed: the cell is **refused**, named with both values (`… refused: it was also changed in dialogue/responses.csv after this workbook was exported, possibly by an earlier import of this same workbook …`), and nothing is written. Export a fresh workbook and redo that edit.
    - An earlier import of the same workbook counts as a CSV change: its stamps still describe the CSV before that import, so editing an imported cell a second time in the old workbook is refused. **Export a fresh workbook after every import** before editing again.
  - **`--text-only`** takes only TEXT, choice and notes cells, matched by id (by position for names and actions, where moved rows are refused); every mechanics difference is listed as ignored. The §5.10 tags and bubble seconds are presentation, not mechanics, so `--text-only` takes them, and it adds an offered column that a row it imports fills in (the report lists those columns as a TEXT header change, apart from the column changes it ignores, e.g. a removed column). New `question_variants` rows are mechanics (id, order, selector): `--text-only` lists them as ignored, and a full import creates `dialogue/question_variants.csv` from them.
  - Adding offered TEXT or presentation columns is listed as a TEXT change (`responses › (header): columns added: reaction_emotion`), so a stale workbook may still add one; the cells themselves follow the rules above. Removing a column is a MECHANICS change, refused from a stale workbook like any other.
  - It always prints every change as `TEXT`, `MECHANICS` or `NOTES` lines, plus the `kept` cells.
  - It validates the whole library before writing anything, and rewrites only the rows that changed.
