"""Tests for tools/forge.py. Run: python -m pytest -q tools/tests"""
import importlib.util
import sys
from pathlib import Path

import pytest

SPEC = importlib.util.spec_from_file_location("forge", Path(__file__).resolve().parents[1] / "forge.py")
forge = importlib.util.module_from_spec(SPEC)
sys.modules["forge"] = forge
SPEC.loader.exec_module(forge)

GOOD_BODY = "# T\n\n## Outcome\nx\n\n## Validation\ny\n\n## Completion criteria\n- [ ] z\n"


@pytest.fixture
def repo(tmp_path, monkeypatch):
    tasks = tmp_path / "production" / "tasks"
    tasks.mkdir(parents=True)
    monkeypatch.setattr(forge, "ROOT", tmp_path)
    monkeypatch.setattr(forge, "TASK_DIR", tasks)
    monkeypatch.setattr(forge, "STATUS_FILE", tmp_path / "PROJECT_STATUS.md")
    return tmp_path


def write_task(repo, tid="FL-0001", body=GOOD_BODY, **over):
    meta = {
        "id": tid, "title": "Do a thing", "track": "build", "owner": "forge-01", "status": "READY",
        "priority": "P1", "game": "factory", "created": "2026-10-12", "updated": "2026-10-12",
        "depends_on": [], "evidence": [],
    }
    meta.update(over)
    path = repo / "production" / "tasks" / f"{tid}-thing.md"
    path.write_text(forge.dump_frontmatter(meta, body), encoding="utf-8")
    return path


def test_frontmatter_roundtrip_keeps_values():
    meta = {"id": "FL-0001", "title": "Fix: colon title", "depends_on": ["FL-0002"], "evidence": ["pytest 5 passed"], "estimate_h": 2}
    text = forge.dump_frontmatter(meta, "body\n")
    parsed, body = forge.parse_frontmatter(text)
    assert parsed == meta
    assert body == "body\n"


def test_parse_rejects_missing_frontmatter():
    with pytest.raises(forge.ForgeError):
        forge.parse_frontmatter("# no frontmatter\n")


def test_parse_rejects_duplicate_keys():
    with pytest.raises(forge.ForgeError):
        forge.parse_frontmatter("---\nid: a\nid: b\n---\n")


def test_valid_task_passes(repo):
    write_task(repo)
    assert forge.validate_tasks(forge.load_tasks()) == []


@pytest.mark.parametrize(
    "over, needle",
    [
        ({"status": "DONE"}, "status 'DONE'"),
        ({"owner": "gpt"}, "owner 'gpt'"),
        ({"created": "12/10/2026"}, "created must be YYYY-MM-DD"),
        ({"status": "ACCEPTED"}, "requires at least one evidence"),
        ({"status": "BLOCKED"}, "requires 'blocked_by'"),
        ({"depends_on": ["FL-0099"]}, "unknown task FL-0099"),
        ({"context": ["nope/missing.md"]}, "context file not found"),
        ({"estimate_h": "two"}, "must be a number"),
    ],
)
def test_invalid_fields_are_reported(repo, over, needle):
    write_task(repo, **over)
    errors = forge.validate_tasks(forge.load_tasks())
    assert any(needle in e for e in errors), errors


def test_missing_validation_section_only_required_from_ready(repo):
    body = "# T\n\n## Outcome\nx\n\n## Completion criteria\n- [ ] z\n"
    write_task(repo, body=body, status="SPECIFIED")
    assert forge.validate_tasks(forge.load_tasks()) == []
    write_task(repo, body=body, status="READY")
    assert any("## Validation" in e for e in forge.validate_tasks(forge.load_tasks()))


def test_filename_must_match_id(repo):
    p = write_task(repo)
    p.rename(p.with_name("FL-0002-wrong.md"))
    assert any("filename must start with its id" in e for e in forge.validate_tasks(forge.load_tasks()))


def test_dependency_cycle_detected(repo):
    write_task(repo, "FL-0001", depends_on=["FL-0002"])
    write_task(repo, "FL-0002", depends_on=["FL-0001"])
    assert any("dependency cycle" in e for e in forge.validate_tasks(forge.load_tasks()))


@pytest.mark.parametrize(
    "old, new, ok",
    [
        ("READY", "BUILDING", True),
        ("RESEARCH", "READY", True),        # planning states may be skipped
        ("READY", "ACCEPTED", False),       # cannot skip build/test/review
        ("BUILDING", "REVIEW", True),
        ("REVIEW", "BUILDING", True),       # changes requested
        ("BUILDING", "BLOCKED", True),
        ("BLOCKED", "TESTING", True),
        ("REJECTED", "BUILDING", False),
        ("REJECTED", "SPECIFIED", True),
        ("ACCEPTED", "REUSABLE", True),
        ("READY", "READY", False),
    ],
)
def test_transitions(old, new, ok):
    assert forge.allowed_transition(old, new) is ok


def test_set_status_logs_and_requires_evidence(repo, monkeypatch):
    write_task(repo, status="REVIEW")
    monkeypatch.setenv("FORGE_AGENT", "forge-01")
    # ACCEPTED without evidence is refused and the file is untouched.
    assert forge.main(["set-status", "FL-0001", "ACCEPTED", "--note", "looks good"]) == 2
    assert forge.load_tasks()[0].meta["status"] == "REVIEW"
    assert forge.main(["set-status", "FL-0001", "ACCEPTED", "--note", "looks good", "--evidence", "pytest 12 passed"]) == 0
    t = forge.load_tasks()[0]
    assert t.meta["status"] == "ACCEPTED"
    assert t.meta["evidence"] == ["pytest 12 passed"]
    assert "forge-01: REVIEW → ACCEPTED. looks good" in t.body


def test_set_status_rejects_illegal_jump(repo):
    write_task(repo, status="READY")
    assert forge.main(["set-status", "FL-0001", "ACCEPTED", "--note", "x", "--evidence", "e"]) == 2


def test_new_allocates_next_id(repo):
    write_task(repo, "FL-0007")
    assert forge.main(["new", "--title", "Build shop UI", "--track", "build", "--owner", "forge-03"]) == 0
    ids = [t.id for t in forge.load_tasks()]
    assert ids == ["FL-0007", "FL-0008"]
    assert forge.validate_tasks(forge.load_tasks()) == []


def test_dashboard_lists_user_and_blocked_and_check(repo):
    write_task(repo, "FL-0001", owner="user", title="Pick game one", status="REVIEW")
    write_task(repo, "FL-0002", status="BLOCKED", blocked_by="needs Studio")
    (repo / "PROJECT_STATUS.md").write_text("# Status\n\nManual notes stay.\n", encoding="utf-8")
    assert forge.main(["dashboard"]) == 0
    text = (repo / "PROJECT_STATUS.md").read_text(encoding="utf-8")
    assert "Manual notes stay." in text
    assert "Pick game one" in text and "needs Studio" in text
    assert forge.main(["dashboard", "--check"]) == 0
    write_task(repo, "FL-0003", title="New work")
    assert forge.main(["dashboard", "--check"]) == 1


def test_prompt_is_self_contained(repo):
    (repo / "AGENTS.md").write_text("RULE: never fabricate results.\n", encoding="utf-8")
    (repo / "notes.md").write_text("context body here\n", encoding="utf-8")
    write_task(repo, context=["notes.md"])
    text = forge.compile_prompt(forge.load_tasks()[0], forge.load_tasks())
    assert "RULE: never fabricate results." in text
    assert "context body here" in text
    assert "FL-0001" in text and "## When you finish" in text


def test_real_repository_tasks_are_valid():
    """The committed task queue must always validate."""
    real = forge.load_tasks(Path(__file__).resolve().parents[2] / "production" / "tasks")
    assert forge.validate_tasks(real) == []
