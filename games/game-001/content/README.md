# AI Kingdoms content library: editor guide

Everything citizens say, every answer the ruler can give, and the numbers behind each choice live here, in plain spreadsheets.

You can rewrite any question, answer or reaction without touching how the game works. The text and the mechanics sit in different columns, and the dialogue rows point at the mechanics only by id.

> The starter rows are a **DRAFT proposal** written to exercise the system. They are not approved dialogue: rewrite freely.

## The quick way: edit the workbook
1. **Get the workbook.** Ask for it, or run this from the repository root:
   ```
   python3 tools/content/content.py export-xlsx
   ```
   It writes `games/game-001/content/AI_Kingdoms_Content.xlsx`. Open it in Excel or LibreOffice. Google Sheets works too: upload the file, edit it, then *File → Download → .xlsx*. Some dropdowns may not survive Google Sheets.
2. **Edit the YELLOW columns.** These are the text players see. Hover a header to see its note and character limit. Over-long text is refused as you type.
3. **Leave the GREY columns alone** unless you mean to change gameplay. They hold ids, numbers, conditions and costs. White columns are your own notes and never reach the game.
4. **Hand it back.** Save it as `.xlsx` and return the file, or run:
   ```
   python3 tools/content/content.py import-xlsx path/to/AI_Kingdoms_Content.xlsx --build
   ```
   The import checks the whole workbook first. If anything is wrong it changes **nothing** and names the sheet and cell, e.g. `responses!D5 [response_text]: text is 71 characters; the limit is 70`. Only the rows you changed are rewritten.

## Text you can edit, and the limits
| Sheet | Column | What it is | Max chars |
|---|---|---|---|
| scenarios | thought_text | thought bubble above the citizen | 48 |
| scenarios | question_text | what the citizen says when you select them | 160 |
| responses | response_text | one of the ruler's 2–4 answers | 70 |
| responses | reaction_text | the citizen's reaction to that answer | 140 |
| consequences | notice_text | short notice when a consequence happens | 100 |
| actions | notice_text | history-log line explaining a reputation change | 100 |
| traits | name_text / description_text | personality trait name / one-line description | 24 / 100 |
| occupations | name_text | occupation name | 24 |
| categories | name_text / description_text / affects_text | reputation category texts | 24 / 160 / 300 |
| names | name | given or family name (medieval-fantasy, no real people) | 16 |

**Text rules.**
- Text must be one line, with no spaces at the start or end.
- These placeholders are filled in by the game:
  - `{name}`: the citizen's name;
  - `{ruler}`: your name;
  - `{kingdom}`: the kingdom's name;
  - `{occupation}`: the citizen's job;
  - `{family}`, `{friend}`, `{rival}`: a relative's, friend's or rival's name.
- Keep room for long names: a placeholder counts by how it is spelled.

## How a conversation is put together
- `scenarios`: one row per situation. It says who can raise it (`occupation`), when (`trigger`), how important it is (`priority`) and how often (`cooldown_s`, `once_per_citizen`).
- `responses`: 2–4 rows per scenario. Each one is an answer plus the citizen's reaction, and it points to a `decision_id`.
- `decisions`: the mechanics of an answer. They cover what it costs, how each reputation category moves, whose loyalty changes, its anti-farming settings, and which `consequences` follow.
- `actions`: reputation effects of things the ruler *does* rather than says, such as building a barracks or defending a raid. One row per audience, so soldiers can approve while hungry civilians resent it.

Two answers may share one decision. Changing a decision changes every answer that uses it.

## Editing the CSV files directly
The `.csv` files in this folder are the master copy, and the workbook is only a working copy. Developers may edit the CSVs in any text editor. Afterwards, run:
```
python3 tools/content/content.py validate   # errors as file:row:column
python3 tools/content/content.py lint       # design warnings (e.g. an answer that is best in every way)
python3 tools/content/content.py build      # regenerates games/game-001/src/shared/Content/*.luau
```
Never edit the generated `.luau` files: `build` overwrites them, and CI (`check`) fails if they are stale.

The full schema covers every column, the condition language and the effect model. It is in [`SPEC.md`](SPEC.md).
