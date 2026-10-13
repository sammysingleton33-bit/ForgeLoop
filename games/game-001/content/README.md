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
2. **Edit the YELLOW columns.** These are the text players see, plus two dropdowns that set how it is shown: the bubble icon (`thought_icon`) and the reaction's mood (`reaction_tone`). Hover a header to see its note, its character limit and the placeholders it accepts. Over-long text is refused as you type.
3. **Leave the GREY columns alone** unless you mean to change gameplay. They hold ids, numbers, conditions and costs. White columns are your own notes and never reach the game. BLUE columns on the responses sheet (`info: question`, `info: effects`) only help you: they show the question being answered and what each answer does, and they are ignored when the workbook comes back.
4. **Sort and filter as you like** while you review. The import puts every row back in its original order.
5. **Never add, remove or rename columns or sheets.** Put your comments in the white `notes` columns. Add new rows at the bottom of a sheet.
6. **Hand it back.** Save it as `.xlsx` and return the file, or run:
   ```
   python3 tools/content/content.py import-xlsx path/to/AI_Kingdoms_Content.xlsx --text-only --build
   ```
   - `--text-only` (recommended for writing work) takes only the yellow and white columns. Mechanics can never change by accident, even if the developers changed the files after your export.
   - Without `--text-only`, grey columns are imported too, but only if nobody changed the CSV files since your export. Otherwise the import refuses those cells, names them, and asks you to export a fresh workbook.
   - If a developer changed a text in the CSV files after your export, your workbook never undoes it (with or without `--text-only`). A cell you did not edit keeps the developer's newer text, and the import lists it as `kept`. A cell you both changed is refused and named: export a fresh workbook and redo that one edit.
   - Formulas are refused (a cell starting with `=` that the spreadsheet calculates). Type the value itself.
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
| consequences | notice_text | short notice when a consequence happens | 100 |
| actions | notice_text | history-log line explaining a reputation change | 100 |
| traits | name_text / description_text | personality trait name / one-line description | 24 / 100 |
| occupations | name_text | occupation name | 24 |
| categories | name_text / description_text / affects_text | reputation category texts | 24 / 160 / 300 |
| names | name | given or family name (medieval-fantasy, no real people) | 16 |

**Text rules.**
- Text must be one line, with no spaces at the start or end.
- Text may not start with `=`, `+`, `-` or `@`: a spreadsheet would treat it as a formula. Start with a letter, a digit or a quote mark; for a dialogue dash use `—`.
- No invisible characters. Shift+Enter in Word, zero-width spaces, soft hyphens, right-to-left marks and similar copy-paste leftovers are refused, with their position.
- **Placeholders** are filled in by the game. Use only the ones a column accepts (the header note lists them):
  - in scenarios and responses: `{name}` (the citizen), `{ruler}` (you), `{kingdom}`, `{occupation}` (the citizen's job), and `{family}`, `{friend}`, `{rival}` (a relative's, friend's or rival's name). The last three only work when the scenario's `trigger` requires that relation (`citizen.has_family`, `citizen.has_friend`, `citizen.has_rival`); otherwise the import refuses them, because the name could be missing in the game;
  - in consequence notices: `{name}`, `{ruler}`, `{kingdom}`, `{occupation}`, and the numbers `{chance}` (e.g. 50%), `{magnitude}` (e.g. +5), `{magnitude_pct}` (e.g. 15%) and `{duration}` (e.g. 2 minutes);
  - in action notices: `{ruler}` and `{kingdom}`;
  - trait, occupation, category and name texts: none.
- **Never type a number that the mechanics decide** (odds, durations, amounts, costs). Write the placeholder instead, so the text stays right when someone tunes the numbers. A risk (a consequence that may or may not happen) must show its odds with `{chance}`.
- Keep room for long names: a placeholder counts by how it is spelled.

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
