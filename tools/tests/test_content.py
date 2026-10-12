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
    # free decision with a reputation sum above 6
    set_cell(lib, "dialogue/decisions.csv", 5, "cost", "")
    set_cell(lib, "dialogue/decisions.csv", 5, "rep_competence", "7")
    # a response that dominates: d_threaten becomes d_pay_bonus without the cost
    rows = read_rows(lib / "dialogue" / "decisions.csv")
    pay = next(r for r in rows if r[0] == "d_pay_bonus")
    idx = next(i for i, r in enumerate(rows) if r[0] == "d_threaten")
    rows[idx] = ["d_threaten", "threats", *pay[2:4], "", *pay[5:23], "", "", ""]
    write_rows(lib / "dialogue" / "decisions.csv", rows)
    # a risky consequence without a notice
    set_cell(lib, "dialogue/consequences.csv", 6, "notice_text", "")
    code, out = run(capsys, "lint", "--content", lib)
    assert code == 0, out
    assert "free decision 'd_buy_tools' gives +7 reputation in total (> 6)" in out
    assert "response 'r_sp_threat' (d_threaten) is at least as good as every other answer of 's_soldier_pay'" in out
    assert "chance 0.5 < 1 without notice_text" in out
    assert "consequence 'c_desert_risk' is not used by any decision" in out


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


def test_xlsx_roundtrip_is_byte_identical(lib, tmp_path, capsys):
    _xlsx_roundtrip(lib, tmp_path, capsys)


def test_xlsx_roundtrip_keeps_crlf_and_extra_quoting(lib, tmp_path, capsys):
    path = lib / "dialogue" / "scenarios.csv"
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\r\n", quoting=csv.QUOTE_ALL).writerows(read_rows(path))
    path.write_text(buf.getvalue(), encoding="utf-8", newline="")
    _xlsx_roundtrip(lib, tmp_path, capsys)


@real_only
def test_xlsx_roundtrip_real_content(tmp_path, capsys):
    lib = tmp_path / "content"
    for spec in content.SPECS:
        (lib / spec.path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REAL / spec.path, lib / spec.path)
    _xlsx_roundtrip(lib, tmp_path, capsys)


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


def test_cli_entry_point_runs():
    res = subprocess.run([sys.executable, str(ROOT / "tools" / "content" / "content.py"), "validate", "--content",
                          str(FIXTURE)], capture_output=True, text=True)
    assert res.returncode == 0, res.stdout + res.stderr
    assert "— 0 errors" in res.stdout
