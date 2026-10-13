"""Tests for tools/check_ownership.py (quality gate G8). Run: python -m pytest -q tools/tests"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parents[1]
REPO = TOOLS.parent
RULES_FILE = REPO / "production" / "quality-gates" / "ownership.json"
SCRIPT = TOOLS / "check_ownership.py"
SPEC = importlib.util.spec_from_file_location("check_ownership", SCRIPT)
co = importlib.util.module_from_spec(SPEC)
sys.modules["check_ownership"] = co
SPEC.loader.exec_module(co)
forge = co.forge

OWNERS = ["forge-00", "forge-01", "forge-02", "forge-03", "forge-04", "forge-05", "forge-06", "forge-07", "codex"]
PR_ENV = ("PR_TITLE", "PR_BRANCH", "GITHUB_HEAD_REF")
GIT_ID = ["-c", "user.name=Forge Test", "-c", "user.email=forge-test@example.invalid", "-c", "commit.gpgsign=false"]


@pytest.fixture(scope="module")
def rules():
    return co.load_rules_file(RULES_FILE)


def make_rules(mapping, exceptions=()):
    doc = {"default_owner": "forge-00", "owners": OWNERS, "rules": mapping, "exceptions": list(exceptions)}
    return co.parse_rules(json.dumps(doc), "test-rules")


# --------------------------------------------------------------------------- the real rules file
def test_rules_file_loads_and_every_pattern_is_reachable(rules):
    assert rules.default_owner == "forge-00"
    assert rules.owners == OWNERS
    assert {r.owner for r in rules.rules} == set(OWNERS)
    assert co.unreachable_patterns(rules) == []
    ids = {e["id"] for e in rules.exceptions}
    assert ids == {"handoff-new", "task-own-status", "task-forge05-status", "own-status-file", "codex-intelligence"}
    assert all(e["description"].strip() for e in rules.exceptions)


@pytest.mark.parametrize(
    "path, owner",
    [
        # FORGE-00 (and the default owner for anything unlisted)
        ("PROJECT_STATUS.md", "forge-00"),
        ("DECISIONS.md", "forge-00"),
        ("production/tasks/FL-0001-x.md", "forge-00"),
        ("agents/forge-03/MISSION.md", "forge-00"),
        ("docs/workflows/team.md", "forge-00"),
        ("docs/research/a/b.md", "forge-00"),
        ("ROADMAP2.md", "forge-00"),
        ("tools/forge.py", "forge-00"),
        ("games/game-001/README.md", "forge-05"),
        ("games/game-002/README.md", "forge-00"),
        # FORGE-06 dialogue content (D-035); schema, tooling and ContentQuery stay FORGE-00
        ("games/game-001/content/dialogue/scenarios.csv", "forge-06"),
        ("games/game-001/content/citizens/traits.csv", "forge-06"),
        ("games/game-001/src/shared/Content/Dialogue.luau", "forge-06"),
        ("games/game-001/content/SPEC.md", "forge-00"),
        ("games/game-001/content/reputation/actions.csv", "forge-00"),
        ("games/game-001/src/shared/Content/ContentQuery.luau", "forge-00"),
        # FORGE-07 review reports (D-037)
        ("production/reviews/2026-10-13-queue.md", "forge-07"),
        ("production/quality-gates/integration-log.md", "forge-05"),
        # FORGE-01
        ("roblox/src/shared/Core/Signal.luau", "forge-01"),
        ("roblox/src/server/Services/DataService.luau", "forge-01"),
        ("roblox/src/client/Controllers/CameraController.luau", "forge-01"),
        ("roblox/tests/unit/gameplay/Round.spec.luau", "forge-01"),
        ("games/sandbox/config/Rounds.luau", "forge-01"),
        ("games/game-001/config/Hazards.luau", "forge-01"),
        # FORGE-02
        ("blender/anything/deep.py", "forge-02"),
        ("roblox/studio-tests/assets.md", "forge-02"),
        # FORGE-03
        ("roblox/src/server/Services/EconomyService.luau", "forge-03"),
        ("roblox/src/server/Services/RewardService.luau", "forge-03"),
        ("roblox/src/client/Controllers/UIController.luau", "forge-03"),
        ("roblox/src/client/UI/Shop.luau", "forge-03"),
        ("games/sandbox/config/Items.luau", "forge-03"),
        ("games/game-001/config/Shop.luau", "forge-03"),
        # FORGE-04
        ("roblox/src/client/Controllers/AudioController.luau", "forge-04"),
        ("roblox/src/server/Services/DailyRewardService.luau", "forge-04"),
        ("games/sandbox/config/Onboarding.luau", "forge-04"),
        ("analytics/events.md", "forge-04"),
        # FORGE-05
        ("games/sandbox/config/Game.luau", "forge-05"),
        ("games/sandbox/map/Lobby.model.json", "forge-05"),
        ("roblox/src/shared/Contracts/Env.luau", "forge-05"),
        ("roblox/tests/unit/contracts/Env.spec.luau", "forge-05"),
        ("roblox/tests/fixtures/identity/README.md", "forge-05"),
        ("roblox.yml", "forge-05"),
        (".gitattributes", "forge-05"),
        ("tools/check_ownership.py", "forge-05"),
        ("tools/tests/test_check_ownership.py", "forge-05"),
        ("production/quality-gates/ownership.json", "forge-05"),
        # Codex
        ("intelligence/x.md", "codex"),
        ("prompts/templates/claude-work-order.md", "codex"),
    ],
)
def test_owner_of_paths(rules, path, owner):
    assert rules.owner_of(path) == owner


def _team_md_samples():
    """(sample path, row owner) for every backticked path in the FORGE-0N / Codex rows of team.md."""
    out = []
    for line in (REPO / "docs" / "workflows" / "team.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\| (FORGE-0\d|Codex) \|[^|]*\|([^|]*)\|", line)
        if not m:
            continue
        owner = m.group(1).lower()
        for token in re.findall(r"`([^`]+)`", m.group(2)):
            if token == "integration-log.md":  # "(incl. `integration-log.md`)" inside production/quality-gates/
                continue
            brace = re.search(r"\{([^}]*)\}", token)
            names = [token.replace(brace.group(0), n) for n in brace.group(1).split(",")] if brace else [token]
            for name in names:
                path = name.rstrip("*") + ("zz" if name.endswith("*") and not name.endswith("**") else "")
                path = path.replace("/*/", "/forge-01/")
                out.append(((path + "zz-sample.luau") if path.endswith("/") else path, owner))
    return out


def test_rules_cover_every_path_in_team_md(rules):
    """The rules stay derived from team.md: every row path resolves to that row's owner."""
    samples = _team_md_samples()
    assert len(samples) > 60
    overrides = {"intelligence/zz-sample.luau": "codex"}  # Codex row supersedes FORGE-00's "until Codex is live"
    wrong = [(p, o, rules.owner_of(p)) for p, o in samples if rules.owner_of(p) != overrides.get(p, o)]
    assert wrong == []


def _game001_samples():
    """(sample path, owner) for every path in the 'game-001' section of team.md ('src/' and 'config' expanded)."""
    text = (REPO / "docs" / "workflows" / "team.md").read_text(encoding="utf-8")
    section = text.split("## game-001", 1)[1]
    out = []
    for line in section.splitlines():
        m = re.match(r"^\| (FORGE-0\d) \|(.*)\|\s*$", line)
        if not m:
            continue
        owner = m.group(1).lower()
        for token in re.findall(r"`([^`]+)`", m.group(2)):
            if token.startswith("src/"):
                token = "games/game-001/" + token
            elif token.startswith("{") and token.endswith(".luau"):
                token = "games/game-001/config/" + token
            if not token.startswith("games/game-001/"):
                continue  # e.g. FORGE-02's `blender/**`, covered by the main table
            brace = re.search(r"\{([^}]*)\}", token)
            names = [token.replace(brace.group(0), n) for n in brace.group(1).split(",")] if brace else [token]
            for name in names:
                path = name.rstrip("*") + ("Zz.luau" if name.endswith("*") and not name.endswith("**") else "")
                out.append(((path + "zz-sample.luau") if path.endswith("/") else path, owner))
    return out


def test_rules_cover_every_game001_path_in_team_md(rules):
    """The game-001 section of team.md (D-022) is mirrored in the rules, prefix ties included."""
    samples = _game001_samples()
    assert len(samples) > 50
    wrong = [(p, o, rules.owner_of(p)) for p, o in samples if rules.owner_of(p) != o]
    assert wrong == []


@pytest.mark.parametrize(
    "path, owner",
    [
        ("games/game-001/src/server/Services/MatchAnalyticsService.luau", "forge-04"),
        ("games/game-001/src/server/Services/MatchService.luau", "forge-01"),
        ("games/game-001/src/server/Services/.gitkeep", "forge-05"),
        ("games/game-001/src/shared/Sim/.gitkeep", "forge-01"),
        ("games/game-001/world/.gitkeep", "forge-05"),
        ("games/game-001/src/server/Services/DebugPresetService.luau", "forge-05"),
        ("games/game-001/world/Layout.luau", "forge-02"),
        ("games/game-001/config/Game.luau", "forge-05"),
        ("games/game-001/src/server/Services/UnlistedService.luau", "forge-00"),
    ],
)
def test_game001_prefix_and_scaffold_rules(rules, path, owner):
    assert rules.owner_of(path) == owner


def test_codex_intelligence_exception_is_backed_by_rules(rules):
    exc = next(e for e in rules.exceptions if e["id"] == "codex-intelligence")
    assert all(rules.owner_of(p.replace("**", "x.md")) == "codex" for p in exc["paths"])
    with pytest.raises(co.OwnershipError, match="codex-intelligence"):
        make_rules({"intelligence/**": "forge-00"}, [exc])


# --------------------------------------------------------------------------- matching and specificity
@pytest.mark.parametrize(
    "pattern, path, ok",
    [
        ("a/**", "a/b/c/d.luau", True),
        ("a/**/d.luau", "a/d.luau", True),       # '**' matches zero segments
        ("a/**/d.luau", "a/b/c/d.luau", True),
        ("a/*/c", "a/b/c", True),
        ("a/*/c", "a/b/x/c", False),            # '*' is exactly one segment
        ("a/*", "a/b/c", False),
        ("a/Data*", "a/DataService.luau", True),
        ("a/Data*", "a/DataService/init.luau", False),
        ("a/?.md", "a/x.md", True),
        ("a/?.md", "a/xy.md", False),
        ("README.md", "readme.md", False),      # case-sensitive, like git paths
    ],
)
def test_glob_matching(pattern, path, ok):
    assert co.glob_match(pattern, path) is ok


def test_exact_file_beats_directory_pattern():
    r = make_rules({"docs/x/**": "forge-01", "docs/x/file.md": "forge-02", "docs/x/y/**": "forge-03"})
    assert r.owner_of("docs/x/file.md") == "forge-02"
    assert r.owner_of("docs/x/other.md") == "forge-01"
    assert r.owner_of("docs/x/y/file.md") == "forge-03"


def test_more_literal_segments_beat_fewer(rules):
    r = make_rules({"a/**": "forge-01", "a/*/c/**": "forge-02"})
    assert r.owner_of("a/b/c/d.luau") == "forge-02"
    assert r.owner_of("a/b/d.luau") == "forge-01"
    # Real rules: games/*/config/Rounds.luau (3 literal segments) beats games/sandbox/** (2).
    assert rules.resolve("games/sandbox/config/Rounds.luau").pattern == "games/*/config/Rounds.luau"


def test_longer_literal_prefix_breaks_a_tie():
    r = make_rules({"a/b/*": "forge-01", "a/b/UI*": "forge-03"})
    assert r.owner_of("a/b/UIController.luau") == "forge-03"
    assert r.owner_of("a/b/Other.luau") == "forge-01"


def test_remaining_tie_is_a_rules_error():
    with pytest.raises(co.OwnershipError, match="equally specific"):
        make_rules({"a/*.luau": "forge-01", "a/*Service*": "forge-03"})
    make_rules({"a/*.luau": "forge-01", "a/*.md": "forge-03"})  # same specificity but disjoint: fine


@pytest.mark.parametrize(
    "text, needle",
    [
        ('{"default_owner": "forge-00", "owners": ["forge-00", "forge-01"], "rules": {"a/**": "forge-00", "a/**": "forge-01"}}', "duplicate key"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/{X,Y}*": "forge-00"}}', "expand brace sets"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/": "forge-00"}}', "trailing '/'"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/x**": "forge-00"}}', "whole segment"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/**": "forge-09"}}', "not in owners"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/**": "forge-00"}, "exceptions": [{"id": "x", "kind": "magic", "paths": ["a"], "description": "d"}]}', "kind must be"),
        ('{"default_owner": "forge-00", "owners": ["forge-00"], "rules": {"a/**": "forge-00"}', "invalid JSON"),
    ],
)
def test_malformed_rules_are_rejected(text, needle):
    with pytest.raises(co.OwnershipError, match=re.escape(needle)):
        co.parse_rules(text, "bad-rules")


# --------------------------------------------------------------------------- task edits (unit level)
TASK_BODY = "# Do a thing\n\n## Outcome\nx\n\n## Requirements\n- keep it small\n\n## Validation\ny\n\n## Completion criteria\n- [ ] z\n\n## Log\n- 2026-10-12 forge-00: created (READY).\n"
FIELDS = ["status", "updated", "evidence", "blocked_by", "actual_h"]


def task_text(body=TASK_BODY, **over):
    meta = {"id": "FL-0001", "title": "Do a thing", "track": "build", "owner": "forge-01", "status": "READY", "priority": "P1",
            "game": "factory", "created": "2026-10-12", "updated": "2026-10-12", "depends_on": [], "evidence": []}
    meta.update(over)
    return forge.dump_frontmatter(meta, body)


def status_edit(text, status="BUILDING", who="forge-01", evidence=None):
    """What `forge.py set-status` does: status, updated, evidence, and one appended Log line."""
    meta, body = forge.parse_frontmatter(text)
    old = meta["status"]
    meta.update(status=status, updated="2026-10-13")
    if evidence:
        meta["evidence"] = list(meta.get("evidence") or []) + [evidence]
    return forge.dump_frontmatter(meta, forge.append_log(body, f"- 2026-10-13 {who}: {old} → {status}. note"))


def test_task_status_edit_is_accepted_and_other_edits_are_not():
    base = task_text()
    assert co.task_edit_problems(base, status_edit(base, evidence="pytest 9 passed"), FIELDS) == []
    retitled = task_text(title="Do another thing")
    assert "title" in co.task_edit_problems(base, retitled, FIELDS)[0]
    reworded = task_text(body=TASK_BODY.replace("keep it small", "make it big"))
    assert "outside an append" in co.task_edit_problems(base, reworded, FIELDS)[0]
    rewritten_log = task_text(body=TASK_BODY.replace("created (READY)", "created (BUILDING)"))
    assert co.task_edit_problems(base, rewritten_log, FIELDS)
    new_heading = task_text(body=TASK_BODY + "## Extra\nmore\n")
    assert "heading" in co.task_edit_problems(base, new_heading, FIELDS)[0]


def test_task_log_section_may_be_created_when_missing():
    body = TASK_BODY.split("## Log")[0]
    base = task_text(body=body)
    assert co.task_edit_problems(base, status_edit(base), FIELDS) == []
    assert co.task_edit_problems(base, task_text(body=body + "\nstray line\n"), FIELDS)


# --------------------------------------------------------------------------- CLI on throwaway git repos
TASK_FILES = {
    "production/tasks/FL-0001-gameplay-thing.md": task_text(),
    "production/tasks/FL-0002-economy-thing.md": task_text(id="FL-0002", owner="forge-03", title="Economy thing"),
}
BASE_FILES = {
    "README.md": "# repo\n",
    "roblox/src/shared/Core/Signal.luau": "-- Signal: a small event class shared by every area.\nlocal Signal = {}\nreturn Signal\n",
    "roblox/src/shared/Economy/Wallet.luau": "-- Wallet: currency balances for one player profile.\nlocal Wallet = {}\nreturn Wallet\n",
    "games/sandbox/config/Game.luau": "return { name = 'sandbox' }\n",
    "production/handoffs/2026-10-12-forge-01-to-forge-03-remotes.md": "# Handoff: forge-01 → forge-03\n",
    "agents/forge-01/STATUS.md": "# FORGE-01 status\n",
    "agents/forge-03/STATUS.md": "# FORGE-03 status\n",
    "intelligence/notes.md": "notes\n",
    **TASK_FILES,
}


def git(repo, *args):
    return subprocess.run(["git", *GIT_ID, *args], cwd=repo, check=True, capture_output=True, text=True).stdout


def write(repo, rel, text):
    path = repo / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def commit(repo, msg="change"):
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--no-verify", "-m", msg)


@pytest.fixture
def repo(tmp_path, monkeypatch):
    """A git repo with the real ownership.json committed on main, checked out on a worker branch."""
    for key in PR_ENV:
        monkeypatch.delenv(key, raising=False)
    root = tmp_path / "repo"
    root.mkdir()
    git(root, "init", "-q")
    git(root, "symbolic-ref", "HEAD", "refs/heads/main")
    for rel, text in BASE_FILES.items():
        write(root, rel, text)
    (root / "production" / "quality-gates").mkdir(parents=True)
    shutil.copy(RULES_FILE, root / "production" / "quality-gates" / "ownership.json")
    commit(root, "base")
    git(root, "checkout", "-q", "-b", "forge/03-ui-economy-fl0018")
    monkeypatch.chdir(root)
    return root


def run(capsys, *args):
    """Run the checker in-process in the current directory; (exit code, stdout + stderr)."""
    code = co.main(list(args))
    out = capsys.readouterr()
    return code, out.out + out.err


def check(capsys, owner, *extra):
    return run(capsys, "--base", "main", "--head", "HEAD", "--owner", owner, *extra)


def test_proven_failure_forge03_edits_shared_core(repo):
    """End to end through the real CLI: a forge-03 PR touching FORGE-01's Core/Signal.luau fails."""
    write(repo, "roblox/src/shared/Core/Signal.luau", "local Signal = { changed = true }\nreturn Signal\n")
    commit(repo)
    env = {k: v for k, v in os.environ.items() if k not in PR_ENV}
    env["PYTHONIOENCODING"] = "utf-8"
    proc = subprocess.run([sys.executable, str(SCRIPT), "--base", "main", "--head", "HEAD", "--owner", "forge-03"],
                          cwd=repo, capture_output=True, env=env)
    out = proc.stdout.decode("utf-8")
    assert proc.returncode == 1, out + proc.stderr.decode("utf-8")
    assert "NOT ALLOWED  roblox/src/shared/Core/Signal.luau  (owner: forge-01, change: M)" in out
    assert "ownership: FAIL — 1 of 1 changed file(s) not owned by forge-03" in out


def test_own_files_pass_and_base_changes_since_the_branch_point_are_ignored(repo, capsys):
    write(repo, "roblox/src/shared/Economy/Items.luau", "return {}\n")
    write(repo, "roblox/src/shared/Economy/Wallet.luau", "-- Wallet v2\nreturn {}\n")
    write(repo, "games/sandbox/config/Items.luau", "return {}\n")
    commit(repo, "economy")
    git(repo, "checkout", "-q", "main")
    write(repo, "roblox/src/shared/Core/Signal.luau", "-- changed on main by FORGE-01\nreturn {}\n")
    commit(repo, "forge-01 work merged to main")
    git(repo, "checkout", "-q", "forge/03-ui-economy-fl0018")
    code, out = check(capsys, "forge-03")
    assert code == 0, out
    assert "ownership: PASS — 3 changed file(s), all owned by forge-03 or allowed by exceptions" in out


def test_working_tree_is_checked_when_head_is_omitted(repo, capsys):
    write(repo, "roblox/src/shared/Economy/Wallet.luau", "-- uncommitted edit\nreturn {}\n")
    write(repo, "roblox/src/shared/Core/New.luau", "return {}\n")  # untracked
    code, out = run(capsys, "--base", "main", "--owner", "forge-03")
    assert code == 1, out
    assert "NOT ALLOWED  roblox/src/shared/Core/New.luau  (owner: forge-01, change: A)" in out
    assert "1 of 2 changed file(s)" in out


def test_explain_names_the_deciding_rule(repo, capsys):
    write(repo, "games/sandbox/config/Rounds.luau", "return {}\n")
    write(repo, "games/sandbox/config/Items.luau", "return {}\n")
    commit(repo)
    code, out = check(capsys, "forge-03", "--explain")
    assert code == 1
    assert "allowed      games/sandbox/config/Items.luau  (change: A, rule games/*/config/Items.luau -> forge-03)" in out
    assert "NOT ALLOWED  games/sandbox/config/Rounds.luau  (owner: forge-01, change: A)" in out
    assert "             rule games/*/config/Rounds.luau -> forge-01" in out
    assert "owner forge-03 (from --owner)" in out


def test_rules_are_read_from_the_merge_base(repo, capsys):
    """A PR cannot grant itself paths by editing ownership.json."""
    rules_path = repo / "production" / "quality-gates" / "ownership.json"
    data = json.loads(rules_path.read_text(encoding="utf-8"))
    data["rules"]["roblox/src/shared/Core/**"] = "forge-03"
    rules_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    write(repo, "roblox/src/shared/Core/Signal.luau", "return {}\n")
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert "NOT ALLOWED  roblox/src/shared/Core/Signal.luau  (owner: forge-01, change: M)" in out
    assert "NOT ALLOWED  production/quality-gates/ownership.json  (owner: forge-05, change: M)" in out


# --- exception: handoff-new
HANDOFF = "production/handoffs/2026-10-12-forge-01-to-forge-03-remotes.md"


def test_handoff_add_is_allowed_for_anyone(repo, capsys):
    write(repo, "production/handoffs/2026-10-13-forge-03-to-forge-01-reply.md", "# reply\n")
    commit(repo)
    code, out = check(capsys, "forge-03", "--explain")
    assert code == 0, out
    assert "exception handoff-new" in out


def test_handoff_modify_or_delete_by_non_author_fails(repo, capsys):
    write(repo, HANDOFF, "# Handoff: edited by forge-03\n")
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert f"NOT ALLOWED  {HANDOFF}  (owner: forge-00, change: M)" in out
    (repo / HANDOFF).unlink()
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert f"NOT ALLOWED  {HANDOFF}  (owner: forge-00, change: D)" in out


# --- exceptions: task-own-status and task-forge05-status
TASK1 = "production/tasks/FL-0001-gameplay-thing.md"  # owner forge-01


def test_task_owner_may_edit_status_evidence_and_log(repo, capsys):
    write(repo, TASK1, status_edit(TASK_FILES[TASK1], "BUILDING", "forge-01", evidence="lune 12 passed"))
    commit(repo)
    code, out = check(capsys, "forge-01", "--explain")
    assert code == 0, out
    assert "exception task-own-status" in out


def test_task_owner_editing_requirements_fails(repo, capsys):
    edited = status_edit(TASK_FILES[TASK1]).replace("- keep it small", "- keep it small\n- and also add a shop")
    write(repo, TASK1, edited)
    commit(repo)
    code, out = check(capsys, "forge-01", "--explain")
    assert code == 1
    assert f"NOT ALLOWED  {TASK1}  (owner: forge-00, change: M)" in out
    assert "outside an append to the '## Log' section" in out


def test_task_owner_editing_title_or_owner_fails(repo, capsys):
    meta, body = forge.parse_frontmatter(TASK_FILES[TASK1])
    meta.update(title="Something else", owner="forge-03")
    write(repo, TASK1, forge.dump_frontmatter(meta, body))
    commit(repo)
    code, out = check(capsys, "forge-01", "--explain")
    assert code == 1
    assert "changed front-matter field(s) owner, title" in out


def test_forge05_may_edit_any_task_status(repo, capsys):
    write(repo, TASK1, status_edit(TASK_FILES[TASK1], "BUILDING", "forge-05", evidence="merged as abc1234"))
    commit(repo)
    code, out = check(capsys, "forge-05", "--explain")
    assert code == 0, out
    assert "exception task-forge05-status" in out


def test_forge03_editing_forge01_task_status_fails(repo, capsys):
    write(repo, TASK1, status_edit(TASK_FILES[TASK1], "BUILDING", "forge-03"))
    commit(repo)
    code, out = check(capsys, "forge-03", "--explain")
    assert code == 1
    assert f"NOT ALLOWED  {TASK1}  (owner: forge-00, change: M)" in out
    assert "the task's owner is forge-01" in out


def test_creating_a_task_file_is_forge00s(repo, capsys):
    write(repo, "production/tasks/FL-0003-new.md", task_text(id="FL-0003", owner="forge-03"))
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert "NOT ALLOWED  production/tasks/FL-0003-new.md  (owner: forge-00, change: A)" in out


# --- exception: own-status-file
def test_own_status_file_allowed_and_someone_elses_fails(repo, capsys):
    write(repo, "agents/forge-03/STATUS.md", "# FORGE-03 status\nbranch: forge/03-ui-economy\n")
    commit(repo)
    code, out = check(capsys, "forge-03", "--explain")
    assert code == 0, out
    assert "exception own-status-file" in out
    write(repo, "agents/forge-01/STATUS.md", "# FORGE-01 status\nedited by forge-03\n")
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert "NOT ALLOWED  agents/forge-01/STATUS.md  (owner: forge-00, change: M)" in out


# --- exception: codex-intelligence (an ownership row)
def test_codex_owns_intelligence_and_prompts(repo, capsys):
    write(repo, "intelligence/notes.md", "notes v2\n")
    write(repo, "prompts/templates/review.md", "# review\n")
    commit(repo)
    code, out = check(capsys, "codex")
    assert code == 0, out
    code, out = check(capsys, "forge-00")
    assert code == 1
    assert "NOT ALLOWED  intelligence/notes.md  (owner: codex, change: M)" in out


# --- renames and deletions
def test_rename_within_own_area_passes(repo, capsys):
    git(repo, "mv", "roblox/src/shared/Economy/Wallet.luau", "roblox/src/shared/Economy/Purse.luau")
    commit(repo)
    code, out = check(capsys, "forge-03", "--explain")
    assert code == 0, out
    assert "rename roblox/src/shared/Economy/Wallet.luau -> roblox/src/shared/Economy/Purse.luau" in out
    assert "1 changed file(s)" in out


def test_rename_needs_both_paths(repo, capsys):
    git(repo, "mv", "roblox/src/shared/Core/Signal.luau", "roblox/src/shared/Economy/Signal.luau")
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert "NOT ALLOWED  roblox/src/shared/Core/Signal.luau  (owner: forge-01, change: R)" in out
    assert "Economy/Signal.luau  (owner" not in out
    git(repo, "mv", "roblox/src/shared/Economy/Wallet.luau", "roblox/src/shared/Core/Wallet.luau")
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert "NOT ALLOWED  roblox/src/shared/Core/Wallet.luau  (owner: forge-01, change: R)" in out
    assert "2 of 2 changed file(s)" in out


def test_deletions(repo, capsys):
    (repo / "roblox/src/shared/Economy/Wallet.luau").unlink()
    commit(repo)
    assert check(capsys, "forge-03")[0] == 0
    (repo / "roblox/src/shared/Core/Signal.luau").unlink()
    commit(repo)
    code, out = check(capsys, "forge-03")
    assert code == 1
    assert "NOT ALLOWED  roblox/src/shared/Core/Signal.luau  (owner: forge-01, change: D)" in out


# --- owner resolution
@pytest.mark.parametrize(
    "owner, title, branch, env, expected",
    [
        ("forge-03", None, None, {}, "forge-03"),
        (None, "[FORGE-03] FL-0018 economy core", None, {}, "forge-03"),
        (None, "[codex] FL-0040 shortlist review", None, {}, "codex"),
        (None, None, None, {"PR_TITLE": "[Forge-04] FL-0024 audio"}, "forge-04"),
        (None, None, "forge/03-ui-economy-fl0018", {}, "forge-03"),
        (None, None, None, {"PR_BRANCH": "codex/FL-0040-review"}, "codex"),
        (None, None, None, {"GITHUB_HEAD_REF": "forge/05-integration-fl0029"}, "forge-05"),
        (None, "[FORGE-01] FL-0008 data", "forge/03-ui-economy", {}, "forge-01"),  # title beats branch
        (None, "Fix typo", "forge/02-blender-fl0013", {}, "forge-02"),          # no prefix: use the branch
    ],
)
def test_owner_resolution(owner, title, branch, env, expected):
    assert co.resolve_owner(owner, title, branch, env, OWNERS)[0] == expected


def test_owner_from_title_and_branch_on_the_cli(repo, capsys):
    write(repo, "roblox/src/shared/Economy/Items.luau", "return {}\n")
    commit(repo)
    code, out = run(capsys, "--base", "main", "--head", "HEAD", "--title", "[FORGE-03] FL-0018 Economy core")
    assert code == 0, out
    code, out = run(capsys, "--base", "main", "--head", "HEAD", "--branch", "forge/01-gameplay-fl0007")
    assert code == 1
    assert "not owned by forge-01" in out


def test_cannot_determine_owner_exits_2(repo, capsys):
    code, out = run(capsys, "--base", "main", "--head", "HEAD", "--title", "Some change", "--branch", "feature/x")
    assert code == 2
    assert "cannot determine owner" in out


@pytest.mark.parametrize(
    "args, needle",
    [
        (["--base", "main", "--owner", "forge-09"], "unknown owner 'forge-09'"),
        (["--base", "no-such-ref", "--owner", "forge-03"], "merge-base"),
        (["--base", "main", "--owner", "forge-03", "--rules", "missing.json"], "cannot read rules file"),
    ],
)
def test_usage_and_config_errors_exit_2(repo, capsys, args, needle):
    code, out = run(capsys, *args)
    assert code == 2
    assert needle in out


def test_whois_prints_owner_and_pattern(repo, capsys):
    code, out = run(capsys, "--whois", "games/sandbox/config/Rounds.luau", "ROADMAP2.md", "agents/forge-01/STATUS.md")
    assert code == 0
    assert "games/sandbox/config/Rounds.luau: forge-01  (pattern: games/*/config/Rounds.luau)" in out
    assert "ROADMAP2.md: forge-00  (default owner: no pattern matches)" in out
    assert "exception own-status-file" in out
