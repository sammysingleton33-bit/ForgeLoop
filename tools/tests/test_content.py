"""Tests for tools/content/content.py (game-001 content library). Run: python -m pytest -q tools/tests

Most tests run on the mini library in tools/tests/fixtures/content/valid, so they do not depend on the
starter content. Tests marked `real_only` also run against games/game-001/content when it exists.
"""
import csv
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location("content_tool", ROOT / "tools" / "content" / "content.py")
content = importlib.util.module_from_spec(SPEC)
sys.modules["content_tool"] = content
SPEC.loader.exec_module(content)

FIXTURE = HERE / "fixtures" / "content" / "valid"
BROKEN_CASES = json.loads((HERE / "fixtures" / "content" / "broken_cases.json").read_text(encoding="utf-8"))
REAL = ROOT / "games" / "game-001" / "content"
REAL_OUT = ROOT / "games" / "game-001" / "src" / "shared" / "Content"
HAS_REAL = all((REAL / s.path).is_file() for s in content.SPECS)
real_only = pytest.mark.skipif(not HAS_REAL, reason="starter content not present yet")
# Workbook tests need openpyxl. CI must install it (pip install pytest openpyxl) or these are skipped.
needs_openpyxl = pytest.mark.skipif(importlib.util.find_spec("openpyxl") is None,
                                    reason="openpyxl not installed (python3 -m pip install openpyxl)")
CSV_PATHS = [s.path for s in content.SPECS]


def run(capsys, *argv):
    code = content.main([str(a) for a in argv])
    return code, capsys.readouterr().out


def read_rows(path: Path) -> list[list[str]]:
    return list(csv.reader(io.StringIO(path.read_text(encoding="utf-8"), newline="")))


def write_rows(path: Path, rows: list[list[str]]) -> None:
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(rows)
    path.write_text(buf.getvalue(), encoding="utf-8", newline="")


def set_cell(lib: Path, rel: str, row: int, column: str, value: str) -> None:
    """row is the spreadsheet row (header = 1)."""
    path = lib / rel
    rows = read_rows(path)
    rows[row - 1][rows[0].index(column)] = value
    write_rows(path, rows)


def snapshot(directory: Path) -> dict[str, bytes]:
    return {p.relative_to(directory).as_posix(): p.read_bytes() for p in sorted(directory.rglob("*")) if p.is_file()}


def csv_bytes(lib: Path) -> dict[str, bytes]:
    return {rel: (lib / rel).read_bytes() for rel in CSV_PATHS}


@pytest.fixture
def lib(tmp_path):
    dst = tmp_path / "content"
    shutil.copytree(FIXTURE, dst)
    return dst


def find_tool(name: str) -> str | None:
    extra = [str(Path.home() / ".rokit" / "bin"), str(Path.home() / ".cargo" / "bin"), "/root/.cargo/bin"]
    return shutil.which(name, path=os.pathsep.join([os.environ.get("PATH", ""), *extra]))


# ----------------------------------------------------------------------------- validate
def test_fixture_library_validates(capsys):
    code, out = run(capsys, "validate", "--content", FIXTURE)
    assert code == 0, out
    assert "3 scenarios, 7 responses, 7 decisions, 6 consequences, 6 traits, 101 names, 4 occupations, " \
           "6 categories, 4 actions — 0 errors" in out


@real_only
def test_real_content_validates(capsys):
    code, out = run(capsys, "validate")
    assert code == 0, out
    assert out.strip().endswith("— 0 errors")


@real_only
def test_real_generated_luau_is_up_to_date(capsys):
    code, out = run(capsys, "check")
    assert code == 0, out + f"\n(run: python3 tools/content/content.py build)"


@pytest.mark.parametrize("case", BROKEN_CASES, ids=[c["name"] for c in BROKEN_CASES])
def test_broken_variant_fails_with_location(lib, tmp_path, capsys, case):
    set_cell(lib, case["file"], case["row"], case["column"], case["value"])
    for p in case.get("patch", []):
        set_cell(lib, p["file"], p["row"], p["column"], p["value"])
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 1, out
    for expected in case["expect"]:
        assert expected in out, f"missing {expected!r} in:\n{out}"
    # build refuses to write anything
    code, out = run(capsys, "build", "--content", lib, "--out", tmp_path / "out")
    assert code == 1
    assert not (tmp_path / "out").exists()


def test_missing_file_and_csv_syntax_errors(lib, capsys):
    (lib / "citizens" / "names.csv").unlink()
    (lib / "dialogue" / "responses.csv").write_text('scenario_id,response_id\n"unclosed,x\n', encoding="utf-8")
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 1
    assert "citizens/names.csv: missing file" in out
    assert "dialogue/responses.csv:2: a quoted cell is never closed" in out


def test_names_minimum_counts(lib, capsys):
    rows = read_rows(lib / "citizens" / "names.csv")
    write_rows(lib / "citizens" / "names.csv", [r for r in rows if r[0] != "given_n"])
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 1
    assert "only 41 given names; at least 60 are needed" in out


def test_action_rows_share_anti_farming_settings(lib, capsys):
    set_cell(lib, "reputation/actions.csv", 3, "repeat_decay", "0.9")
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 1
    assert "reputation/actions.csv:3:6: [repeat_decay] differs from row 2 of action 'fund_barracks'" in out


# ----------------------------------------------------------------------------- condition language
def vocab():
    return content.Vocab({"farmer", "soldier"}, {"greedy", "kind"}, {"d_one"})


@pytest.mark.parametrize("text, expected", [
    ("", []),
    ("kingdom.fed_ratio < 0.6", [{"var": "kingdom.fed_ratio", "op": "<", "value": 0.6}]),
    ("kingdom.count.farm>=2", [{"var": "kingdom.count.farm", "op": ">=", "value": 2}]),
    ("citizen.trait.greedy & !citizen.has_rival", [
        {"var": "citizen.trait.greedy", "op": "=", "value": True},
        {"var": "citizen.has_rival", "op": "=", "value": False}]),
    ("decision.d_one != true", [{"var": "decision.d_one", "op": "=", "value": False}]),
    ("phase in Founding, Expansion", [{"var": "phase", "op": "in", "value": ["Founding", "Expansion"]}]),
    ("occupation = farmer & rep.fear >= 40", [
        {"var": "occupation", "op": "=", "value": "farmer"}, {"var": "rep.fear", "op": ">=", "value": 40}]),
    ("citizen.memory.rulerVisited & citizen.chemistry > -5", [
        {"var": "citizen.memory.rulerVisited", "op": "=", "value": True},
        {"var": "citizen.chemistry", "op": ">", "value": -5}]),
    ("citizen.has_friend", [{"var": "citizen.has_friend", "op": "=", "value": True}]),
])
def test_condition_parses_into_typed_clauses(text, expected):
    clauses, _ = content.parse_condition(text, vocab(), "citizen")
    assert clauses == expected
    for c in clauses:
        assert type(c["value"]) is type(next(e for e in expected if e["var"] == c["var"])["value"])


@pytest.mark.parametrize("text, message", [
    ("kingdom.food <", "malformed"),
    ("kingdom.food < lots", "'lots' is not a number"),
    ("kingdom.food", "is a number; compare it"),
    ("phase = founding", "unknown phase 'founding' (did you mean 'Founding'?)"),
    ("phase > Founding", "use = != or in"),
    ("rep.fear in 1,2", "'in' only works with"),
    ("citizen.trait.greedy = maybe", "is true/false"),
    ("rep.mercy > 5", "unknown variable 'rep.mercy'"),
    ("event.flood", "unknown variable 'event.flood'"),
    ("kingdom.count.castle > 1", "unknown variable 'kingdom.count.castle'"),
    ("citizen.chemistry > 25", "outside the range of 'citizen.chemistry' (-20..20)"),
    ("rep.fear > 5 && rep.honor < 5", "single '&'"),
    ("rep.fear > 5 & ", "clause 2 is empty"),
    ("occupation in farmer,farmer", "appears twice"),
    # hints for the mistakes non-programmers make
    ("kingdom.food < 50 and citizen.hunger > 0.5", "join clauses with ' & ' (not 'and')"),
    ("Kingdom.Food < 50", "unknown variable 'Kingdom.Food' (did you mean 'kingdom.food'?)"),
    ("kingdom.food =< 50", "write '<=' instead of '=<'"),
    ("kingdom.food => 50", "write '>=' instead of '=>'"),
    ("kingdom.food ≤ 50", "write '<=' instead of '≤'"),
    ("not event.raid", "write '!event.raid' instead of 'not event.raid'"),
])
def test_condition_rejects_with_precise_message(text, message):
    with pytest.raises(content.CondError) as err:
        content.parse_condition(text, vocab(), "citizen")
    assert message in str(err.value)


def test_kingdom_scope_rejects_citizen_variables():
    with pytest.raises(content.CondError, match="describes a citizen"):
        content.parse_condition("occupation = farmer", vocab(), "kingdom")


# ----------------------------------------------------------------------------- build / check
def test_build_is_deterministic_and_check_passes(lib, tmp_path, capsys):
    out1, out2 = tmp_path / "out1", tmp_path / "out2"
    assert run(capsys, "build", "--content", lib, "--out", out1)[0] == 0
    assert run(capsys, "build", "--content", lib, "--out", out2)[0] == 0
    first = snapshot(out1)
    assert first == snapshot(out2)
    assert sorted(first) == ["Consequences.luau", "Decisions.luau", "Dialogue.luau", "Names.luau",
                             "Occupations.luau", "Reputation.luau", "Traits.luau"]
    code, out = run(capsys, "build", "--content", lib, "--out", out1)
    assert code == 0 and "(0 changed)" in out
    assert snapshot(out1) == first
    assert run(capsys, "check", "--content", lib, "--out", out1)[0] == 0
    for text in first.values():
        lines = text.decode("utf-8").splitlines()
        assert lines[0] == "--!strict"
        assert lines[1].startswith("-- GENERATED by tools/content/content.py from ")
        assert lines[1].endswith(" — do not edit")


def test_real_header_names_the_canonical_source():
    _, model, _ = content.load_and_validate(FIXTURE)
    files = content.generate(model, "games/game-001/content")
    assert files["Dialogue.luau"].splitlines()[1] == \
        "-- GENERATED by tools/content/content.py from games/game-001/content — do not edit"


def test_check_detects_stale_and_missing_files(lib, tmp_path, capsys):
    out = tmp_path / "out"
    run(capsys, "build", "--content", lib, "--out", out)
    (out / "Traits.luau").write_text("-- edited by hand\n", encoding="utf-8")
    code, text = run(capsys, "check", "--content", lib, "--out", out)
    assert code == 1 and "Traits.luau (differs)" in text
    (out / "Names.luau").unlink()
    code, text = run(capsys, "check", "--content", lib, "--out", out)
    assert code == 1 and "Names.luau (missing)" in text


def test_generated_shapes(lib):
    _, model, report = content.load_and_validate(lib)
    assert not report.errors
    files = content.generate(model, "x")
    dialogue = files["Dialogue.luau"]
    assert '{ var = "phase", op = "in", value = { "Founding", "Expansion" } },' in dialogue
    assert '{ var = "event.raid", op = "=", value = false },' in dialogue
    assert "'We bled at the wall, {ruler}. The men say \"a crown that cannot pay cannot rule.\"'" in dialogue
    decisions = files["Decisions.luau"]
    assert "rep = { compassion = 3, honor = 1, competence = 0, courage = 0, authority = 0, fear = 0 }," in decisions
    assert 'consequences = { "c_remember_kindness", "c_cheer" },' in decisions
    assert 'memory_tag = "fed_by_ruler",' in decisions
    assert "notes" not in decisions  # notes never reach the game
    assert 'farm_key = "d_grain_gift",' in decisions  # empty farm_key falls back to the decision id
    consequences = files["Consequences.luau"]
    assert 'param = "shown_kindness",' in consequences
    assert 'target = "occupation:farmer",' in consequences
    reputation = files["Reputation.luau"]
    assert '["BuildingCompleted:barracks"] = { 1, 2 },' in reputation
    assert 'audience_condition = { { var = "citizen.hunger", op = ">=", value = 0.5 } },' in reputation
    names = files["Names.luau"]
    assert '"D\'Arcy-Mae",' in names
    # presentation (CONTRACTS G13.3) and unlock gating (SPEC §5.4)
    assert dialogue.count("locked = true,") == 1  # s_smith_tools, opened by c_unlock_followup
    assert 'icon = "request",' in dialogue and 'tone = "neutral",' in dialogue


def test_generated_luau_passes_stylua_and_selene(lib, tmp_path, capsys):
    stylua, selene = find_tool("stylua"), find_tool("selene")
    if not stylua or not selene:
        pytest.skip("stylua/selene not installed")
    # awkward strings: both quote kinds, a backslash, non-ASCII letters, a Luau keyword as a trait id
    set_cell(lib, "dialogue/responses.csv", 2, "reaction_text", "It's \"fine\", he says \\ shrugs. Ça va.")
    set_cell(lib, "citizens/names.csv", 2, "name", "Ébrel")
    rows = read_rows(lib / "citizens" / "traits.csv")
    rows.append(["end", "Final", "Thinks every day is the last.", "", "0", "0", "0", "1", "0", "0", "0", "1", "1",
                 "1", "1"])
    write_rows(lib / "citizens" / "traits.csv", rows)
    out = tmp_path / "out"
    code, text = run(capsys, "build", "--content", lib, "--out", out)
    assert code == 0, text
    assert '["end"] = {' in (out / "Traits.luau").read_text(encoding="utf-8")
    files = sorted(str(p) for p in out.glob("*.luau"))
    res = subprocess.run([stylua, "--config-path", str(ROOT / "stylua.toml"), "--check", *files],
                         capture_output=True, text=True)
    assert res.returncode == 0, res.stdout + res.stderr
    res = subprocess.run([selene, str(out)], capture_output=True, text=True, cwd=ROOT)
    assert res.returncode == 0 and "0 errors" in res.stdout, res.stdout + res.stderr


# ----------------------------------------------------------------------------- lint
def test_lint_reports_design_warnings(lib, capsys):
    code, out = run(capsys, "lint", "--content", lib)
    assert code == 0
    assert "[farm_key] no farm_key: repeats of 'd_grain_gift'" in out
    # free decision with a reputation sum above 6 (fear does not count as a gain)
    set_cell(lib, "dialogue/decisions.csv", 5, "cost", "")
    set_cell(lib, "dialogue/decisions.csv", 5, "rep_competence", "7")
    # a response that dominates: d_threaten becomes d_pay_bonus without the cost
    rows = read_rows(lib / "dialogue" / "decisions.csv")
    pay = next(r for r in rows if r[0] == "d_pay_bonus")
    idx = next(i for i, r in enumerate(rows) if r[0] == "d_threaten")
    rows[idx] = ["d_threaten", "threats", *pay[2:4], "", *pay[5:23], "", "", ""]
    write_rows(lib / "dialogue" / "decisions.csv", rows)
    code, out = run(capsys, "lint", "--content", lib)
    assert code == 0, out
    assert "free decision 'd_buy_tools' gives +7 reputation in total, fear aside (> 6)" in out
    assert "response 'r_sp_threat' (d_threaten) is at least as good as every other answer of 's_soldier_pay'" in out
    assert "consequence 'c_desert_risk' is not used by any decision" in out
    set_cell(lib, "dialogue/decisions.csv", 8, "rep_fear", "9")  # a big fear gain is not "better"
    code, out = run(capsys, "lint", "--content", lib)
    assert "response 'r_sp_threat' (d_threaten) is at least as good" in out


def test_lint_scores_answers_with_the_personality_reaction(lib, capsys):
    """The explicit columns alone hide a free answer that most citizens prefer (review finding: drill/inspect)."""
    code, out = run(capsys, "lint", "--content", lib)
    assert "free answer" not in out
    set_cell(lib, "dialogue/decisions.csv", 6, "rep_honor", "0")  # d_promise_later: free, ...
    set_cell(lib, "dialogue/decisions.csv", 6, "rep_competence", "3")  # ... as much reputation as buying tools
    set_cell(lib, "dialogue/decisions.csv", 6, "speaker_loyalty", "8")
    code, out = run(capsys, "lint", "--content", lib)
    assert ("free answer 'r_st_later' (d_promise_later) is the best speaker-loyalty choice for 100% of sampled "
            "citizens of 's_smith_tools'") in out
    # deterministic: the sample is seeded by the scenario id
    assert run(capsys, "lint", "--content", lib)[1] == out


def test_lint_contract_memory_cue_and_number_warnings(lib, capsys):
    set_cell(lib, "dialogue/consequences.csv", 2, "notice_text", "Farmers work 20% slower for 2 minutes.")
    code, out = run(capsys, "lint", "--content", lib)
    assert code == 0
    # one warning per event name that is not on the CONTRACTS G9 bus
    assert "event 'RaidDefended' (rows 5) is not a CONTRACTS G9 bus event" in out
    assert out.count("is not a CONTRACTS G9 bus event") == 1
    assert "memory 'fed_by_ruler' is set but no trigger reads it" in out
    assert "memory 'promised_tools' is set but" not in out  # s_smith_tools reads it
    assert "cue 'cue_grumble' is not in the cue vocabulary" in out
    assert "consequences.csv:2:10: [notice_text] the notice types a number" in out


def test_lint_flags_a_locked_scenario_that_nothing_unlocks(lib, capsys):
    set_cell(lib, "dialogue/decisions.csv", 5, "consequences", "")  # d_buy_tools no longer unlocks s_smith_tools
    code, out = run(capsys, "lint", "--content", lib)
    assert "scenario 's_smith_tools' is locked, but no decision uses a consequence that unlocks it" in out


def test_notes_may_hold_tabs_and_line_breaks(lib, capsys):
    set_cell(lib, "dialogue/decisions.csv", 2, "notes", "line one\nline\ttwo")
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 0, out


def test_thought_icon_and_reaction_tone_columns(lib, tmp_path, capsys):
    rows = read_rows(lib / "dialogue" / "scenarios.csv")
    rows[0].insert(6, "thought_icon")
    for r, icon in zip(rows[1:], ("concern", "", "idea")):
        r.insert(6, icon)
    write_rows(lib / "dialogue" / "scenarios.csv", rows)
    rows = read_rows(lib / "dialogue" / "responses.csv")
    rows[0].insert(5, "reaction_tone")
    for r in rows[1:]:
        r.insert(5, "happy" if r[1] == "r_hf_share" else "")
    write_rows(lib / "dialogue" / "responses.csv", rows)
    out = tmp_path / "out"
    code, text = run(capsys, "build", "--content", lib, "--out", out)
    assert code == 0, text
    dialogue = (out / "Dialogue.luau").read_text(encoding="utf-8")
    assert 'icon = "concern",' in dialogue and 'icon = "idea",' in dialogue and 'icon = "request",' in dialogue
    assert 'tone = "happy",' in dialogue and 'tone = "neutral",' in dialogue
    set_cell(lib, "dialogue/scenarios.csv", 2, "thought_icon", "shout")
    code, text = run(capsys, "validate", "--content", lib)
    assert code == 1 and "dialogue/scenarios.csv:2:7: [thought_icon] 'shout' is not allowed" in text


# ----------------------------------------------------------------------------- CSV round trip helpers
def test_csv_parser_keeps_raw_bytes_for_unchanged_rows():
    text = '﻿a,b\r\n"x, y","say ""hi"""\r\n"quoted",plain\r\n'
    doc = content.parse_csv(text)
    assert [r.fields for r in doc.records] == [["a", "b"], ["x, y", 'say "hi"'], ["quoted", "plain"]]
    assert doc.newline == "\r\n" and doc.bom and doc.trailing_newline
    rows = [list(r.fields) for r in doc.records]
    assert content.render_csv(rows, doc) == text
    rows[2][1] = "changed"
    assert content.render_csv(rows, doc) == '﻿a,b\r\n"x, y","say ""hi"""\r\nquoted,changed\r\n'


# ----------------------------------------------------------------------------- workbook
def _xlsx_roundtrip(lib: Path, tmp_path: Path, capsys) -> None:
    before = csv_bytes(lib)
    book = tmp_path / "book.xlsx"
    code, out = run(capsys, "export-xlsx", "--content", lib, book)
    assert code == 0, out
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0, out
    assert "0 CSV file(s) updated" in out
    assert csv_bytes(lib) == before


@needs_openpyxl
def test_xlsx_roundtrip_is_byte_identical(lib, tmp_path, capsys):
    _xlsx_roundtrip(lib, tmp_path, capsys)


@needs_openpyxl
def test_xlsx_roundtrip_keeps_crlf_and_extra_quoting(lib, tmp_path, capsys):
    path = lib / "dialogue" / "scenarios.csv"
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\r\n", quoting=csv.QUOTE_ALL).writerows(read_rows(path))
    path.write_text(buf.getvalue(), encoding="utf-8", newline="")
    _xlsx_roundtrip(lib, tmp_path, capsys)


@real_only
@needs_openpyxl
def test_xlsx_roundtrip_real_content(tmp_path, capsys):
    lib = tmp_path / "content"
    for spec in content.SPECS:
        (lib / spec.path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REAL / spec.path, lib / spec.path)
    _xlsx_roundtrip(lib, tmp_path, capsys)


@needs_openpyxl
def test_workbook_layout(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    assert wb.sheetnames == ["README", "lists", *[s.key for s in content.SPECS]]
    assert wb["lists"].sheet_state == "hidden"
    ws = wb["scenarios"]
    assert ws.freeze_panes == "B2"
    header = [c.value for c in ws[1]]
    q = header.index("question_text") + 1
    trig = header.index("trigger") + 1
    assert ws.cell(1, q).comment.text.startswith("EDIT")
    assert "160" in ws.cell(1, q).comment.text
    assert ws.cell(2, q).fill.fgColor.rgb.endswith(content.FILL["text"])
    assert ws.cell(1, trig).comment.text.startswith("MECHANICS")
    assert ws.cell(2, trig).fill.fgColor.rgb.endswith(content.FILL["mech"])
    assert ws.cell(2, trig).number_format == "@"
    kinds = {(dv.type, str(dv.formula1)) for dv in ws.data_validations.dataValidation}
    assert ("textLength", "160") in kinds and ("textLength", "48") in kinds
    assert any(t == "list" and f.startswith("lists!") for t, f in kinds)  # occupation dropdown
    rv = {(dv.type, str(dv.formula1)) for dv in wb["responses"].data_validations.dataValidation}
    assert ("list", "decisions!$A$2:$A$2000") in rv  # decision_id dropdown, live from the decisions sheet
    cv = {str(dv.formula1) for dv in wb["consequences"].data_validations.dataValidation if dv.type == "list"}
    assert len(cv) == 2  # kind and target


@needs_openpyxl
def test_editing_text_in_the_workbook_changes_only_that_text(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    out1, out2 = tmp_path / "out1", tmp_path / "out2"
    assert run(capsys, "build", "--content", lib, "--out", out1)[0] == 0
    before_csv = csv_bytes(lib)
    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    ws = wb["scenarios"]
    header = [c.value for c in ws[1]]
    new_text = 'Pay us, {ruler}, or the "men" will walk.'
    ws.cell(4, header.index("question_text") + 1).value = new_text
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, "--out", out2, book, "--build")
    assert code == 0, out
    after_csv = csv_bytes(lib)
    changed = [rel for rel in CSV_PATHS if before_csv[rel] != after_csv[rel]]
    assert changed == ["dialogue/scenarios.csv"]
    old_lines = before_csv[changed[0]].decode().splitlines()
    new_lines = after_csv[changed[0]].decode().splitlines()
    assert len(old_lines) == len(new_lines)
    diff = [i for i, (a, b) in enumerate(zip(old_lines, new_lines)) if a != b]
    assert diff == [3]
    old_row = next(csv.reader([old_lines[3]]))
    new_row = next(csv.reader([new_lines[3]]))
    q = header.index("question_text")
    assert new_row[q] == new_text
    assert [v for i, v in enumerate(old_row) if i != q] == [v for i, v in enumerate(new_row) if i != q]
    # generated Luau: only the question line of Dialogue.luau changed
    a, b = snapshot(out1), snapshot(out2)
    assert [k for k in a if a[k] != b[k]] == ["Dialogue.luau"]
    la, lb = a["Dialogue.luau"].decode().splitlines(), b["Dialogue.luau"].decode().splitlines()
    assert len(la) == len(lb)
    changed_lines = [(x, y) for x, y in zip(la, lb) if x != y]
    assert len(changed_lines) == 1
    assert changed_lines[0][1].strip() == "question = 'Pay us, {ruler}, or the \"men\" will walk.',"


@needs_openpyxl
def test_import_refuses_unknown_sheets_and_columns(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    before = csv_bytes(lib)
    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    wb.create_sheet("Sheet2")
    wb["decisions"].cell(1, 1).value = "decision"
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 1
    assert "unknown sheet 'Sheet2'" in out
    assert "decisions!A1 [decision]: unknown column 'decision' (did you mean 'decision_id'?)" in out
    assert "no CSV was changed" in out
    assert csv_bytes(lib) == before


@needs_openpyxl
def test_import_validates_before_writing_and_names_the_cell(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    before = csv_bytes(lib)
    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    ws = wb["responses"]
    header = [c.value for c in ws[1]]
    ws.cell(5, header.index("response_text") + 1).value = "x" * 71
    ws.cell(9, 1).value = None  # a blank row at the end is ignored
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 1
    assert "book.xlsx › responses!D5 [response_text]: text is 71 characters; the limit is 70" in out
    assert csv_bytes(lib) == before


@needs_openpyxl
def test_import_converts_typed_cells_back_to_text(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    ws = wb["scenarios"]
    header = [c.value for c in ws[1]]
    ws.cell(2, header.index("priority") + 1).value = 81  # typed as a number, as Excel would
    ws.cell(2, header.index("once_per_citizen") + 1).value = True
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0, out
    row = read_rows(lib / "dialogue" / "scenarios.csv")[1]
    assert row[3] == "81" and row[5] == "true"


def _sheet_cell(wb, sheet: str, row: int, column: str):
    ws = wb[sheet]
    header = [c.value for c in ws[1]]
    return ws.cell(row, header.index(column) + 1)


@needs_openpyxl
def test_import_refuses_mechanics_from_a_stale_workbook(lib, tmp_path, capsys):
    """Review finding: an old workbook silently reverted a cost changed in the CSV after the export."""
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    set_cell(lib, "dialogue/decisions.csv", 2, "cost", "food:30")  # a developer edit after the export
    after_dev = csv_bytes(lib)
    wb = load_workbook(book)  # the editor only rewrote two lines of text
    _sheet_cell(wb, "responses", 2, "reaction_text").value = "Bless you, truly!"
    _sheet_cell(wb, "scenarios", 3, "thought_text").value = "My hammer is cracked."
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 1, out
    assert "decisions!E2 [cost]: decisions › d_share_grain [cost]: 'food:30' → 'food:20'" in out
    assert "dialogue/decisions.csv changed after this workbook was exported" in out
    assert "--text-only" in out and "no CSV was changed" in out
    assert csv_bytes(lib) == after_dev
    # --text-only takes the two texts and keeps the developer's cost
    code, out = run(capsys, "import-xlsx", "--content", lib, book, "--text-only")
    assert code == 0, out
    assert "2 change(s) from the workbook: TEXT 2, MECHANICS 0, NOTES 0" in out
    assert "1 mechanics change(s) in the workbook were NOT imported" in out
    assert "ignored   decisions › d_share_grain [cost]: 'food:30' → 'food:20'" in out
    assert read_rows(lib / "dialogue" / "decisions.csv")[1][4] == "food:30"
    assert read_rows(lib / "dialogue" / "responses.csv")[1][4] == "Bless you, truly!"
    now = csv_bytes(lib)
    assert [rel for rel in CSV_PATHS if now[rel] != after_dev[rel]] == ["dialogue/scenarios.csv",
                                                                         "dialogue/responses.csv"]


@needs_openpyxl
def test_import_lists_every_change_and_takes_mechanics_from_a_fresh_workbook(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    _sheet_cell(wb, "scenarios", 2, "priority").value = "81"
    _sheet_cell(wb, "scenarios", 2, "notes").value = "my note"
    _sheet_cell(wb, "responses", 3, "response_text").value = "Rations for all. Me too."
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0, out
    assert "3 change(s) from the workbook: TEXT 1, MECHANICS 1, NOTES 1" in out
    assert "MECHANICS scenarios › s_hungry_farmer [priority]: '80' → '81'" in out
    assert "NOTES     scenarios › s_hungry_farmer [notes]: \"\" → 'my note'" in out
    assert "TEXT      responses › r_hf_ration [response_text]:" in out
    assert read_rows(lib / "dialogue" / "scenarios.csv")[1][3] == "81"


@needs_openpyxl
def test_reimporting_one_workbook_after_more_text_edits(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    _sheet_cell(wb, "responses", 2, "reaction_text").value = "First pass."
    wb.save(book)
    assert run(capsys, "import-xlsx", "--content", lib, book)[0] == 0
    wb = load_workbook(book)  # the same, now older, workbook: more text only
    _sheet_cell(wb, "responses", 3, "reaction_text").value = "Second pass."
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0, out
    assert "TEXT 1, MECHANICS 0" in out
    rows = read_rows(lib / "dialogue" / "responses.csv")
    assert rows[1][4] == "First pass." and rows[2][4] == "Second pass."


@needs_openpyxl
def test_import_without_an_export_stamp_takes_text_but_not_mechanics(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    lists = wb["lists"]
    header = [c.value for c in lists[1]]
    lists.delete_cols(header.index("stamp_file") + 1, 2)
    _sheet_cell(wb, "scenarios", 2, "priority").value = "81"
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 1 and "this workbook has no export stamp" in out
    wb = load_workbook(book)
    _sheet_cell(wb, "scenarios", 2, "priority").value = "80"
    _sheet_cell(wb, "scenarios", 2, "thought_text").value = "Still hungry."
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0, out
    assert read_rows(lib / "dialogue" / "scenarios.csv")[1][6] == "Still hungry."


@needs_openpyxl
def test_sorting_the_workbook_never_reorders_the_csv(lib, tmp_path, capsys):
    """Review finding: sorting the scenarios sheet changed Dialogue.order, the priority tie-break."""
    from openpyxl import load_workbook

    out1, out2 = tmp_path / "out1", tmp_path / "out2"
    assert run(capsys, "build", "--content", lib, "--out", out1)[0] == 0
    before = csv_bytes(lib)
    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    for sheet in ("scenarios", "responses", "names", "actions"):  # keyed and keyless tables
        ws = wb[sheet]
        values = [[c.value for c in row] for row in ws.iter_rows(min_row=2)]
        for r, row in enumerate(reversed(values), 2):
            for c, v in enumerate(row, 1):
                ws.cell(r, c).value = v
    wb.save(book)
    code, out = run(capsys, "import-xlsx", "--content", lib, "--out", out2, book, "--build")
    assert code == 0, out
    assert "0 CSV file(s) updated" in out
    assert csv_bytes(lib) == before
    assert snapshot(out1) == snapshot(out2)
    # sorted and edited: only the edited text changes
    wb = load_workbook(book)
    ws = wb["scenarios"]
    header = [c.value for c in ws[1]]
    row = next(r for r in range(2, ws.max_row + 1) if ws.cell(r, 1).value == "s_smith_tools")
    ws.cell(row, header.index("thought_text") + 1).value = "My tools are worn to nothing."
    wb.save(book)
    assert run(capsys, "import-xlsx", "--content", lib, book)[0] == 0
    old, new = before["dialogue/scenarios.csv"].decode().splitlines(), csv_bytes(lib)["dialogue/scenarios.csv"].decode()
    assert [i for i, (a, b) in enumerate(zip(old, new.splitlines())) if a != b] == [2]


@needs_openpyxl
def test_text_only_refuses_rows_moved_in_a_table_without_a_key(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    wb["names"].delete_rows(2)
    wb.save(book)
    before = csv_bytes(lib)
    code, out = run(capsys, "import-xlsx", "--content", lib, book, "--text-only")
    assert code == 1
    assert "rows were added, removed or moved in sheet 'names'" in out
    assert csv_bytes(lib) == before


@needs_openpyxl
def test_responses_sheet_has_read_only_help_columns(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    ws = wb["responses"]
    header = [c.value for c in ws[1]]
    assert header[-2:] == ["info: question", "info: effects"]
    assert ws.cell(1, len(header)).comment.text.startswith("READ ONLY")
    assert ws.cell(2, len(header) - 1).value.startswith("{ruler}, the granary is low")
    effects = ws.cell(2, len(header)).value
    assert effects.startswith("cost food:20 | rep compassion +3, honor +1 | speaker +4")
    assert "then c_remember_kindness, c_cheer" in effects
    ws.cell(2, len(header)).value = "edited help text"  # ignored on import
    wb.save(book)
    before = csv_bytes(lib)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 0 and "0 CSV file(s) updated" in out, out
    assert csv_bytes(lib) == before


def test_export_names_the_cell_with_an_invisible_character(lib, tmp_path, capsys):
    pytest.importorskip("openpyxl")
    set_cell(lib, "dialogue/responses.csv", 2, "reaction_text", "Bless you!\x0bWe'll work those fields.")
    book = tmp_path / "x.xlsx"
    code, out = run(capsys, "export-xlsx", "--content", lib, book)
    assert code == 1
    assert "dialogue/responses.csv:2:5: [reaction_text] cannot export: invisible character U+000B" in out
    assert not book.exists()


@needs_openpyxl
def test_import_rejects_invisible_characters(lib, tmp_path, capsys):
    from openpyxl import load_workbook

    book = tmp_path / "book.xlsx"
    run(capsys, "export-xlsx", "--content", lib, book)
    wb = load_workbook(book)
    _sheet_cell(wb, "scenarios", 2, "question_text").value = "Ruler\u200bword, we starve."
    _sheet_cell(wb, "responses", 2, "reaction_text").value = "line\u2028sep"
    wb.save(book)
    before = csv_bytes(lib)
    code, out = run(capsys, "import-xlsx", "--content", lib, book)
    assert code == 1
    assert "scenarios!H2 [question_text]: invisible character U+200B (zero-width space) at position 6" in out
    assert "responses!E2 [reaction_text]: invisible character U+2028 (line separator)" in out
    assert csv_bytes(lib) == before


# ----------------------------------------------------------------------------- real content regressions
@real_only
def test_real_content_keeps_the_balance_review_fixes(capsys):
    code, out = run(capsys, "lint")
    assert code == 0
    for rid in ("captain_drill_drill_myself", "miner_rockfall_inspect"):
        assert f"free answer '{rid}'" not in out  # finding: free 'ruler present' answers dominated
    for tag in ("feast_promised", "forge_half_promise", "promised_harvest", "promised_pay", "inspected_face"):
        assert f"memory '{tag}' is set but no trigger reads it" not in out  # every promise comes due
    _, model, report = content.load_and_validate(REAL)
    assert not report.errors
    assert any(t["weights"]["courage"] < 0 for t in model.traits.values())  # someone dislikes courage
    assert any((a["rep"]["fear"] or 0) < 0 for a in model.actions)  # setbacks lower fear
    mercy = [d for d in model.decisions.values() if (d["rep"]["fear"] or 0) < 0 and d["farm_key"] == "mercy"]
    assert mercy  # a repeatable fear-lowering answer
    assert "KeepUpgraded" not in {(a["event"] or "").split(":")[0] for a in model.actions}
    for a in model.actions:  # construction reputation only through a measured need
        if (a["event"] or "").startswith(content.CONSTRUCTION_EVENTS) and any(v > 0 for v in a["rep"].values()):
            assert a["condition"], a


@real_only
def test_real_content_rejects_a_strike_by_the_captains(tmp_path, capsys):
    lib = tmp_path / "content"
    for spec in content.SPECS:
        (lib / spec.path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REAL / spec.path, lib / spec.path)
    rows = read_rows(lib / "dialogue" / "consequences.csv")
    row = next(i for i, r in enumerate(rows, 1) if r[0] == "speaker_refuses_work")
    set_cell(lib, "dialogue/consequences.csv", row, "kind", "strike")
    set_cell(lib, "dialogue/consequences.csv", row, "magnitude", "0.3")
    set_cell(lib, "dialogue/consequences.csv", row, "target", "occupation:captain")
    code, out = run(capsys, "validate", "--content", lib)
    assert code == 1
    assert f"dialogue/consequences.csv:{row}:3: [target] 'captain' are soldiers" in out


def test_cli_entry_point_runs():
    res = subprocess.run([sys.executable, str(ROOT / "tools" / "content" / "content.py"), "validate", "--content",
                          str(FIXTURE)], capture_output=True, text=True)
    assert res.returncode == 0, res.stdout + res.stderr
    assert "— 0 errors" in res.stdout
