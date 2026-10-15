# AI Kingdoms content library: editor guide

Everything citizens say, every answer the ruler can give, and the numbers behind each choice live here, in plain spreadsheets.

You can rewrite any question, answer or reaction without touching how the game works. The text and the mechanics sit in different columns, and the dialogue rows point at the mechanics only by id.

> The starter rows are a **DRAFT proposal** written to exercise the system. They are not approved dialogue: rewrite freely. Known draft weaknesses: the tone is fairly uniform, and few lines use `{name}`, `{ruler}` or a relative's name yet.

## The quick way: edit the workbook
1. **Get the workbook.** Ask for it, or run this from the repository root:
   ```
   python3 tools/content/content.py export-xlsx
   ```
   It writes `games/game-001/content/AI_Kingdoms_Content.xlsx`. Open it in Excel or LibreOffice. Google Sheets works too: upload the file, edit it, then *File → Download → .xlsx*. Some dropdowns may not survive Google Sheets.
2. **Edit the YELLOW columns.** These are the text players see, plus dropdowns that set how it is shown: the bubble icon (`thought_icon`), the reaction's mood (`reaction_tone`) and the optional presentation tags (see *Presentation tags (optional)* below). Hover a header to see its note, its character limit and the placeholders it accepts. Over-long text is refused as you type.
3. **Leave the GREY columns alone** unless you mean to change gameplay. They hold ids, numbers, conditions and costs. White columns are your own notes and never reach the game. BLUE columns on the responses sheet (`info: question`, `info: effects`) only help you: they show the question being answered and what each answer does, and they are ignored when the workbook comes back.
4. **Sort and filter as you like** while you review. The import puts every row back in its original order.
5. **Never add, remove or rename columns or sheets.** Put your comments in the white `notes` columns (a note may not start with `=` or `@`). Add new rows at the bottom of a sheet.
6. **Hand it back.** Save it as `.xlsx` and return the file, or run:
   ```
   python3 tools/content/content.py import-xlsx path/to/AI_Kingdoms_Content.xlsx --text-only --build
   ```
   - `--text-only` (recommended for writing work) takes only the yellow and white columns. Mechanics can never change by accident, even if the developers changed the files after your export.
   - Without `--text-only`, grey columns are imported too, but only if nobody changed the CSV files since your export. Otherwise the import refuses those cells, names them, and asks you to export a fresh workbook.
   - If a developer changed a text in the CSV files after your export, your workbook never undoes it (with or without `--text-only`). A cell you did not edit keeps the developer's newer text, and the import lists it as `kept`. A cell you both changed is refused and named: export a fresh workbook and redo that one edit.
   - Formulas are refused (a cell starting with `=` that the spreadsheet calculates), and so are error values such as `#REF!` or `#N/A`. Type the value itself.
   - **After each import, export a fresh workbook before you edit again.** The old workbook still remembers the files as they were before your import, so editing a cell a second time there is refused (`… possibly by an earlier import of this same workbook`).
   - If a CSV file cannot be read (for example a developer saved it as *CSV (Comma delimited)* instead of *CSV UTF-8*), the import refuses that file and changes nothing: it never overwrites a file it cannot compare with your workbook.
   - The import checks the whole workbook first. If anything is wrong it changes **nothing** and names the sheet and cell, e.g. `responses!D5 [response_text]: text is 71 characters; the limit is 70`.
   - It always prints every change it made, marked `TEXT`, `MECHANICS` or `NOTES`, so you can see that only your text moved. Only the rows you changed are rewritten.

## Text you can edit, and the limits
| Sheet | Column | What it is | Max chars |
|---|---|---|---|
| scenarios | thought_text | thought bubble above the citizen | 48 |
| scenarios | question_text | what the citizen says when you select them | 160 |
| scenarios | thought_icon | bubble icon: request, concern or idea | dropdown |
| responses | response_text | one of the ruler's 2–4 answers | 70 |
| responses | reaction_text | the citizen's reaction to that answer (a speech bubble) | 80 |
| responses | reaction_tone | how the reaction looks: happy, angry, sad or neutral | dropdown |
| responses | reaction_high_text / reaction_low_text | optional: the reaction of a very loyal / disloyal citizen | 80 |
| question_variants | question_text | optional: another question for some citizens | 160 |
| consequences | notice_text | short notice when a consequence happens | 100 |
| actions | notice_text | history-log line explaining a reputation change | 100 |
| traits | name_text / description_text | personality trait name / one-line description | 24 / 100 |
| occupations | name_text | occupation name | 24 |
| categories | name_text / description_text / affects_text | reputation category texts | 24 / 160 / 300 |
| names | name | given or family name (medieval-fantasy, no real people) | 16 |

**Text rules.**
- Text must be one line, with no spaces at the start or end.
- Text may not be blank: a cell that holds only spaces (including wide spaces such as the em space) or invisible characters (also a lone variation selector such as U+FE0F, the invisible half of some emoji) is refused. Leave an optional cell truly empty instead. A wide space between words is fine.
- Text may not start with `=`, `+`, `-` or `@`: a spreadsheet would treat it as a formula. Start with a letter, a digit or a quote mark; for a dialogue dash use `—`.
- No invisible characters. Shift+Enter in Word, zero-width spaces, soft hyphens, right-to-left marks, blank "filler" characters (Hangul fillers, the Braille blank) and similar copy-paste leftovers are refused, with their position.
- **Placeholders** are filled in by the game. Use only the ones a column accepts (the header note lists them):
  - in scenarios and responses: `{name}` (the citizen), `{ruler}` (you), `{kingdom}`, `{occupation}` (the citizen's job), and `{family}`, `{friend}`, `{rival}` (a relative's, friend's or rival's name). The last three only work when the scenario's `trigger` requires that relation (`citizen.has_family`, `citizen.has_friend`, `citizen.has_rival`); otherwise the import refuses them, because the name could be missing in the game;
  - in consequence notices: `{name}`, `{ruler}`, `{kingdom}`, `{occupation}`, and the numbers `{magnitude}` (e.g. +5), `{magnitude_pct}` (e.g. 15%) and `{duration}` (e.g. 2 minutes);
  - in action notices: `{ruler}` and `{kingdom}`;
  - trait, occupation, category and name texts: none.
- **Never type a number that the mechanics decide** (odds, durations, amounts, costs). Write the placeholder instead, so the text stays right when someone tunes the numbers.
- **Risks: describe only what may happen.** A risk (a consequence that may or may not happen) must have a notice, and the conversation panel shows its odds right next to that notice. So never write the odds yourself and never write `{chance}`: write `{name} may walk off the job for {duration}.`, not `Risk ({chance}): {name} may walk off the job.`
- Keep room for long names: a placeholder counts by how it is spelled. A thought or a reaction must also fit its 80-character bubble with the longest names filled in (`{name}`, `{family}`, `{friend}`, `{rival}` 16, `{ruler}` 20, `{occupation}` 24, `{kingdom}` 20); the import names the length it can reach.
- Notes may start with `+` or `-` (`+housing capacity`), but never with `=` or `@`.

## Presentation tags (optional)
The cinematic conversation shows the citizen's portrait, so a line can say *how* it is said. All of these columns are optional: leave a cell empty for the default look, and nothing about gameplay changes either way. In the workbook they are yellow columns at the right end of the scenarios and responses sheets; a CSV only gains such a column once you fill one in on a row the import takes (`--text-only` skips new rows, so a tag on a new row adds nothing until a full import brings in the row).

- **How a line is said** (scenario questions, reactions, question variants): `emotion`, `expression`, `gesture`, `delivery`, picked from dropdowns. The full lists are in [`SPEC.md`](SPEC.md) §5.10, for example emotion `gratitude`, expression `raised_brow`, gesture `hand_on_heart`, delivery `deadpan`.
- **A reaction's emotion must fit its tone.** A `happy` reaction can be joy, gratitude, pride, relief, hope, amusement, excitement or determination; an `angry` one frustration, anger, contempt, defiance or suspicion; a `sad` one sadness, grief, worry, fear or embarrassment; a `neutral` one neutral, determination, curiosity, suspicion, amusement, worry, hope, frustration or relief. An empty `reaction_tone` counts as neutral, so set the tone first.
- **Gestures with a cue.** `bow`, `salute`, `step_back` (cowers), `fist_pump` (celebrates) and `cross_arms` (grumbles) also play that feedback animation.
- **Scenario feel:** `urgency` (low, normal, high, critical) and `delivery_mode`: `ambient` (a thought bubble the ruler may notice) or `direct` (the citizen comes to the ruler). A direct scenario with low urgency gets a lint hint.
- **Bubble time:** `thought_bubble_s` and `reaction_bubble_s` are seconds from 2.5 to 9 with at most one decimal, e.g. `4.5`.
- **Reactions by loyalty:** `reaction_high_text` is said instead of the normal reaction by a citizen with loyalty 70 or more, `reaction_low_text` by one with 30 or less (both thresholds provisional). Each needs its own tone (`reaction_high_tone`, `reaction_low_tone`) and follows the same rules as `reaction_text`. Tags for a band without its text are refused.
- **Question variants** (`question_variants` sheet, file `dialogue/question_variants.csv`): another question for some citizens of a scenario. `selector` says who: `trait:brave` (the citizen is brave) or `cond:citizen.loyalty >= 70` (any trigger condition). When several match, the lowest `order` wins; a citizen no variant matches hears the scenario's own question. `selector`, `order` and the ids are grey mechanics: a new variant row needs an import without `--text-only` (a developer can do it).
- Props are not a column: describe them in `notes`.

## How a conversation is put together
- `scenarios`: one row per situation. It says who can raise it (`occupation`), when (`trigger`), how important it is (`priority`) and how often (`cooldown_s`, `once_per_citizen`).
- `responses`: 2–4 rows per scenario. Each one is an answer plus the citizen's reaction, and it points to a `decision_id`.
- `decisions`: the mechanics of an answer. They cover what it costs, how each reputation category moves, whose loyalty changes, its anti-farming settings, and which `consequences` follow.
- `consequences`: what happens after an answer (a work boost, unrest, a follow-up conversation). A follow-up scenario (for example a promise that comes due) only appears for the citizen it was unlocked for.
- `actions`: reputation effects of things the ruler *does* rather than says, such as building a barracks or defending a raid. One row per audience, so soldiers can approve while hungry civilians resent it. The `event` must be one the game fires (CONTRACTS G9 or G13.4); `lint` warns about any other.

Two answers may share one decision. Changing a decision changes every answer that uses it.

## Editing the CSV files directly
The `.csv` files in this folder are the master copy, and the workbook is only a working copy. Developers may edit the CSVs in any text editor. Afterwards, run:
```
python3 tools/content/content.py validate   # errors as file:row:column
python3 tools/content/content.py lint       # design warnings (e.g. a free answer nearly everyone prefers)
python3 tools/content/content.py build      # regenerates games/game-001/src/shared/Content/*.luau
```
Never edit the generated `.luau` files: `build` overwrites them, and CI (`check`) fails if they are stale. A workbook exported before a CSV change can no longer bring back old mechanics: export a fresh one.

The full schema covers every column, the condition language and the effect model. It is in [`SPEC.md`](SPEC.md).
