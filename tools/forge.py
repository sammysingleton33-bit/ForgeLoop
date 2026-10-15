#!/usr/bin/env python3
"""forge — FORGELOOP-01 task, dashboard and prompt tooling.

Standard library only, so it runs on any machine with Python 3.10+ (Linux CI,
Windows, any agent sandbox).

Commands
  validate                 check every task file (schema, ids, dependencies, evidence)
  list [--owner X] [--status S]
  show ID
  new --title T --track K --owner O [--priority P1] [--game factory] [--depends FL-0001,...]
  set-status ID STATUS --note TEXT [--evidence TEXT ...] [--blocked-by TEXT] [--actual-h N]
  dashboard [--check]      regenerate the auto section of PROJECT_STATUS.md (--check: fail if stale)
  prompt ID [--out PATH]   compile a self-contained, provider-neutral prompt for a task
  check                    run every automated gate that this machine can run
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # repository root
TASK_DIR = ROOT / "production" / "tasks"
STATUS_FILE = ROOT / "PROJECT_STATUS.md"
AUTO_START = "<!-- forge:auto:start -->"
AUTO_END = "<!-- forge:auto:end -->"

LIFECYCLE = ["RESEARCH", "SPECIFIED", "READY", "BUILDING", "TESTING", "REVIEW", "ACCEPTED", "REUSABLE"]
SIDE_STATES = ["BLOCKED", "REJECTED"]
STATUSES = LIFECYCLE + SIDE_STATES
OWNERS = ["forge-00", "forge-01", "forge-02", "forge-03", "forge-04", "forge-05", "forge-06", "forge-07", "codex", "user", "any"]
OWNER_LABELS = {
    "forge-00": "FORGE-00 Director",
    "forge-01": "FORGE-01 Gameplay",
    "forge-02": "FORGE-02 Blender",
    "forge-03": "FORGE-03 UI & Economy",
    "forge-04": "FORGE-04 Experience",
    "forge-05": "FORGE-05 Integration & QA",
    "forge-06": "FORGE-06 Dialogue & Content",
    "forge-07": "FORGE-07 Review & QA",
    "codex": "Codex (intelligence)",
    "any": "Unassigned",
}
TRACKS = ["infra", "research", "design", "build", "asset", "qa", "coordination", "release"]
PRIORITIES = ["P0", "P1", "P2", "P3"]
REQUIRED = ["id", "title", "track", "owner", "status", "priority", "game", "created", "updated"]
FIELD_ORDER = REQUIRED + ["depends_on", "context", "estimate_h", "actual_h", "branch", "blocked_by", "evidence"]
LIST_FIELDS = {"depends_on", "context", "evidence"}
ID_RE = re.compile(r"^FL-\d{4}$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# Sections every task body must have; READY and later also need a validation plan.
BASE_SECTIONS = ["## Outcome", "## Completion criteria"]
READY_SECTIONS = ["## Validation"]


class ForgeError(Exception):
    pass


# --------------------------------------------------------------------------- frontmatter
def _scalar(raw: str):
    raw = raw.strip()
    if raw == "" or raw == "null" or raw == "~":
        return None
    if (raw[0] == raw[-1]) and raw[0] in "\"'" and len(raw) >= 2:
        return raw[1:-1]
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw):
        return float(raw)
    return raw


def _split_inline_list(raw: str) -> list:
    inner = raw.strip()[1:-1].strip()
    if not inner:
        return []
    items, buf, quote = [], "", None
    for ch in inner:
        if quote:
            buf += ch
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            buf += ch
        elif ch == ",":
            items.append(_scalar(buf))
            buf = ""
        else:
            buf += ch
    items.append(_scalar(buf))
    return items


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Parse the small YAML subset used by task files: scalars, [a, b] lists and '- item' lists."""
    if not text.startswith("---\n"):
        raise ForgeError("file must start with '---' frontmatter")
    end = text.find("\n---", 4)
    if end == -1:
        raise ForgeError("frontmatter not closed with '---'")
    block = text[4:end]
    body = text[end + 4 :].lstrip("\n")
    meta: dict = {}
    current_list: str | None = None
    for lineno, line in enumerate(block.splitlines(), start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith((" ", "\t")) and line.strip().startswith("- "):
            if current_list is None:
                raise ForgeError(f"line {lineno}: list item without a key")
            meta[current_list].append(_scalar(line.strip()[2:]))
            continue
        m = re.match(r"^([a-z_][a-z0-9_]*):(.*)$", line)
        if not m:
            raise ForgeError(f"line {lineno}: cannot parse {line!r}")
        key, raw = m.group(1), m.group(2).strip()
        if key in meta:
            raise ForgeError(f"line {lineno}: duplicate key {key!r}")
        current_list = None
        if raw.startswith("["):
            if not raw.endswith("]"):
                raise ForgeError(f"line {lineno}: unterminated list")
            meta[key] = _split_inline_list(raw)
        elif raw == "" and key in LIST_FIELDS:
            meta[key] = []
            current_list = key
        else:
            meta[key] = _scalar(raw)
    return meta, body


def _fmt_scalar(v) -> str:
    if v is None:
        return ""
    s = str(v)
    if s == "" or s[0] in "[{'\"#&*!|>%@`-" or ":" in s or s != s.strip():
        return '"' + s.replace('"', "'") + '"'
    return s


def dump_frontmatter(meta: dict, body: str) -> str:
    keys = [k for k in FIELD_ORDER if k in meta] + sorted(k for k in meta if k not in FIELD_ORDER)
    lines = ["---"]
    for k in keys:
        v = meta[k]
        if isinstance(v, list):
            if not v:
                lines.append(f"{k}: []")
            elif k == "evidence" or any(len(str(x)) > 40 for x in v):
                lines.append(f"{k}:")
                lines.extend(f"  - {_fmt_scalar(x)}" for x in v)
            else:
                lines.append(f"{k}: [{', '.join(_fmt_scalar(x) for x in v)}]")
        else:
            lines.append(f"{k}: {_fmt_scalar(v)}".rstrip())
    lines.append("---")
    return "\n".join(lines) + "\n\n" + body.lstrip("\n")


def dump_frontmatter_preserving(original: str, meta: dict, body: str) -> str:
    """dump_frontmatter, but a scalar key whose value didn't change keeps its original line verbatim
    (e.g. a title with ':' and '"' is not re-quoted; check_ownership's task-status exception needs that)."""
    out = dump_frontmatter(meta, body)
    try:
        old_meta, _ = parse_frontmatter(original)
    except ForgeError:
        return out
    old_lines = {}
    for line in original[4 : original.find("\n---", 4)].splitlines():
        m = re.match(r"^([a-z_][a-z0-9_]*):", line)
        if m:
            old_lines[m.group(1)] = line
    head, sep, rest = out.partition("\n---\n")
    kept = []
    for line in head.splitlines():
        m = re.match(r"^([a-z_][a-z0-9_]*):", line)
        k = m.group(1) if m else None
        if k and k in old_lines and not isinstance(meta.get(k), list) and old_meta.get(k) == meta.get(k):
            line = old_lines[k]
        kept.append(line)
    return "\n".join(kept) + sep + rest


# --------------------------------------------------------------------------- tasks
@dataclass
class Task:
    path: Path
    meta: dict
    body: str
    errors: list = field(default_factory=list)

    @property
    def id(self) -> str:
        return str(self.meta.get("id", "?"))

    def get(self, key, default=None):
        v = self.meta.get(key, default)
        return default if v is None else v


def load_tasks(task_dir: Path | None = None) -> list[Task]:
    tasks = []
    for path in sorted((task_dir or TASK_DIR).glob("FL-*.md")):
        try:
            meta, body = parse_frontmatter(path.read_text(encoding="utf-8"))
            tasks.append(Task(path, meta, body))
        except ForgeError as e:
            t = Task(path, {"id": path.name[:7]}, "")
            t.errors.append(f"{path.name}: {e}")
            tasks.append(t)
    return tasks


def validate_tasks(tasks: list[Task]) -> list[str]:
    errors: list[str] = []
    ids: dict[str, Path] = {}
    for t in tasks:
        errors.extend(t.errors)
        if t.errors:
            continue
        name, m = t.path.name, t.meta
        for k in REQUIRED:
            if m.get(k) in (None, ""):
                errors.append(f"{name}: missing required field '{k}'")
        tid = str(m.get("id", ""))
        if not ID_RE.match(tid):
            errors.append(f"{name}: id {tid!r} must look like FL-0001")
        elif not name.startswith(tid):
            errors.append(f"{name}: filename must start with its id {tid}")
        if tid in ids:
            errors.append(f"{name}: duplicate id {tid} (also {ids[tid].name})")
        ids[tid] = t.path
        for key, allowed in (("status", STATUSES), ("owner", OWNERS), ("track", TRACKS), ("priority", PRIORITIES)):
            if m.get(key) is not None and m.get(key) not in allowed:
                errors.append(f"{name}: {key} {m.get(key)!r} not in {allowed}")
        for key in ("created", "updated"):
            if m.get(key) is not None and not DATE_RE.match(str(m[key])):
                errors.append(f"{name}: {key} must be YYYY-MM-DD")
        for key in LIST_FIELDS:
            if key in m and not isinstance(m[key], list):
                errors.append(f"{name}: {key} must be a list")
        for key in ("estimate_h", "actual_h"):
            if m.get(key) is not None and not isinstance(m[key], (int, float)):
                errors.append(f"{name}: {key} must be a number of hours")
        status = m.get("status")
        if status in ("ACCEPTED", "REUSABLE") and not m.get("evidence"):
            errors.append(f"{name}: status {status} requires at least one evidence entry")
        if status == "BLOCKED" and not m.get("blocked_by"):
            errors.append(f"{name}: status BLOCKED requires 'blocked_by'")
        needed = list(BASE_SECTIONS)
        if status in LIFECYCLE and LIFECYCLE.index(status) >= LIFECYCLE.index("READY"):
            needed += READY_SECTIONS
        for section in needed:
            if not re.search(rf"^{re.escape(section)}\s*$", t.body, re.M):
                errors.append(f"{name}: body is missing section '{section}'")
        for ref in m.get("context") or []:
            if not (ROOT / str(ref)).exists() and not (ROOT.parent / str(ref)).exists():
                errors.append(f"{name}: context file not found: {ref}")
    valid_ids = set(ids)
    graph = {}
    for t in tasks:
        deps = t.meta.get("depends_on") or []
        if not isinstance(deps, list):
            continue
        graph[t.id] = [str(d) for d in deps]
        for d in deps:
            if str(d) not in valid_ids:
                errors.append(f"{t.path.name}: depends_on unknown task {d}")
            elif str(d) == t.id:
                errors.append(f"{t.path.name}: task depends on itself")
    errors.extend(_find_cycles(graph))
    return errors


def _find_cycles(graph: dict[str, list[str]]) -> list[str]:
    state: dict[str, int] = {}
    found: list[str] = []

    def visit(node: str, stack: list[str]):
        state[node] = 1
        for nxt in graph.get(node, []):
            if nxt not in graph or nxt == node:
                continue
            if state.get(nxt) == 1:
                cycle = stack[stack.index(nxt) :] + [nxt]
                found.append("dependency cycle: " + " -> ".join(cycle))
            elif state.get(nxt) is None:
                visit(nxt, stack + [nxt])
        state[node] = 2

    for n in sorted(graph):
        if state.get(n) is None:
            visit(n, [n])
    return found


def allowed_transition(old: str, new: str) -> bool:
    if old == new:
        return False
    if new in SIDE_STATES:
        return old != "REJECTED"
    if old == "REJECTED":
        return new in ("RESEARCH", "SPECIFIED")  # reopened with a new spec
    if old == "BLOCKED":
        return True  # resumes wherever the work actually is
    oi, ni = LIFECYCLE.index(old), LIFECYCLE.index(new)
    if ni == oi + 1:
        return True
    # Skipping ahead is allowed only over planning states (e.g. RESEARCH -> READY) or
    # straight from BUILDING to REVIEW when testing is part of the build evidence.
    if ni > oi + 1:
        return ni <= LIFECYCLE.index("READY") or (old == "BUILDING" and new == "REVIEW")
    # Going back: review/testing can send work back to BUILDING; anything can return to SPECIFIED.
    return new in ("BUILDING", "SPECIFIED") or (old == "REUSABLE" and new == "ACCEPTED")


def find_task(tasks: list[Task], tid: str) -> Task:
    for t in tasks:
        if t.id == tid:
            return t
    raise ForgeError(f"no task {tid}")


def today() -> str:
    return dt.date.today().isoformat()


def append_log(body: str, line: str) -> str:
    if re.search(r"^## Log\s*$", body, re.M):
        return body.rstrip("\n") + "\n" + line + "\n"
    return body.rstrip("\n") + "\n\n## Log\n" + line + "\n"


def cmd_set_status(args) -> int:
    tasks = load_tasks()
    t = find_task(tasks, args.id)
    new = args.status.upper()
    if new not in STATUSES:
        raise ForgeError(f"unknown status {new}")
    old = t.meta["status"]
    if not allowed_transition(old, new) and not args.force:
        raise ForgeError(f"transition {old} -> {new} not allowed (use --force with a reason in --note)")
    if not args.note.strip():
        raise ForgeError("--note is required")
    t.meta["status"] = new
    t.meta["updated"] = today()
    if args.evidence:
        t.meta["evidence"] = list(t.meta.get("evidence") or []) + args.evidence
    if args.blocked_by:
        t.meta["blocked_by"] = args.blocked_by
    elif new != "BLOCKED":
        t.meta.pop("blocked_by", None)
    if args.actual_h is not None:
        t.meta["actual_h"] = args.actual_h
    who = os.environ.get("FORGE_AGENT", "unknown-agent")
    t.body = append_log(t.body, f"- {today()} {who}: {old} → {new}. {args.note.strip()}")
    errs = validate_tasks([t if x.id == t.id else x for x in tasks])
    if errs:
        raise ForgeError("refusing to write an invalid task:\n  " + "\n  ".join(errs))
    original = t.path.read_text(encoding="utf-8")
    t.path.write_text(dump_frontmatter_preserving(original, t.meta, t.body), encoding="utf-8")
    print(f"{t.id}: {old} -> {new}")
    return 0


TASK_TEMPLATE = """# {title}

## Outcome
What exists or is true when this is done (one paragraph, user-visible terms).

## Context
Relevant decisions, files and prior work. Link, don't paste.

## Requirements
-

## Validation
How the owner proves it works (commands, tests, renders, Studio steps). Distinguish automated from interactive.

## Completion criteria
- [ ]

## Log
"""


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:48]


def cmd_new(args) -> int:
    tasks = load_tasks()
    nums = [int(t.id[3:]) for t in tasks if ID_RE.match(t.id)]
    tid = f"FL-{(max(nums) + 1) if nums else 1:04d}"
    meta = {
        "id": tid,
        "title": args.title,
        "track": args.track,
        "owner": args.owner,
        "status": "SPECIFIED",
        "priority": args.priority,
        "game": args.game,
        "created": today(),
        "updated": today(),
        "depends_on": [d for d in (args.depends or "").split(",") if d],
        "evidence": [],
    }
    path = TASK_DIR / f"{tid}-{slugify(args.title)}.md"
    body = TASK_TEMPLATE.format(title=args.title)
    errs = validate_tasks(tasks + [Task(path, meta, body)])
    if errs:
        raise ForgeError("\n".join(errs))
    path.write_text(dump_frontmatter(meta, body), encoding="utf-8")
    print(path.relative_to(ROOT))
    return 0


# --------------------------------------------------------------------------- dashboard
def _git(*args: str) -> str:
    try:
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def render_dashboard(tasks: list[Task], include_git: bool = True) -> str:
    by_status = {s: [t for t in tasks if t.meta.get("status") == s] for s in STATUSES}
    out = [AUTO_START, "", "_Generated by `python tools/forge.py dashboard` from `production/tasks/`. Do not edit by hand._", ""]
    counts = " · ".join(f"{s} {len(by_status[s])}" for s in STATUSES if by_status[s])
    out += [f"**Tasks:** {len(tasks)} — {counts}", ""]

    def table(rows: list[Task], cols: list[str]) -> list[str]:
        if not rows:
            return ["_None._", ""]
        lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
        for t in rows:
            cells = []
            for c in cols:
                v = t.get(c, "")
                if c == "id":
                    v = f"[{t.id}](production/tasks/{t.path.name})"
                elif isinstance(v, list):
                    v = ", ".join(map(str, v))
                cells.append(str(v).replace("|", "\\|"))
            lines.append("| " + " | ".join(cells) + " |")
        return lines + [""]

    prio = {p: i for i, p in enumerate(PRIORITIES)}
    order = lambda t: (prio.get(t.get("priority"), 9), t.id)  # noqa: E731
    out += ["### Needs the user (decisions, approvals, local-machine steps)", ""]
    out += table(sorted([t for t in tasks if t.get("owner") == "user" and t.get("status") not in ("ACCEPTED", "REUSABLE", "REJECTED")], key=order), ["id", "title", "status", "priority"])
    out += ["### Blocked", ""]
    out += table(sorted(by_status["BLOCKED"], key=order), ["id", "title", "owner", "blocked_by"])
    for owner, label in OWNER_LABELS.items():
        active = [t for t in tasks if t.get("owner") == owner and t.get("status") not in ("ACCEPTED", "REUSABLE", "REJECTED", "BLOCKED")]
        if not active and owner == "any":
            continue
        out += [f"### {label} — open", ""]
        out += table(sorted(active, key=order), ["id", "title", "status", "priority", "track"])
    done = [t for t in tasks if t.get("status") in ("ACCEPTED", "REUSABLE")]
    out += ["### Accepted / reusable", ""]
    out += table(sorted(done, key=lambda t: t.id), ["id", "title", "status", "updated"])
    est = sum(float(t.get("estimate_h", 0) or 0) for t in done)
    act = sum(float(t.get("actual_h", 0) or 0) for t in done if t.get("actual_h") is not None)
    timed = [t for t in done if t.get("actual_h") is not None]
    out += ["### Estimate vs actual (accepted tasks with both recorded)", ""]
    if timed:
        out += [f"{len(timed)} tasks: estimated {est:.1f} h, actual {act:.1f} h.", ""]
    else:
        out += ["_No accepted task has an actual time recorded yet._", ""]
    if include_git:
        log = _git("log", "-8", "--format=%h %ad %s", "--date=short", "--", ".")
        out += ["### Recent commits", ""]
        out += ["```", log.strip() or "(git log unavailable)", "```", ""]
    out.append(AUTO_END)
    return "\n".join(out)


def splice_dashboard(existing: str, auto: str) -> str:
    if AUTO_START in existing and AUTO_END in existing:
        pre = existing.split(AUTO_START)[0]
        post = existing.split(AUTO_END, 1)[1]
        return pre + auto + post
    return existing.rstrip("\n") + "\n\n" + auto + "\n"


def cmd_dashboard(args) -> int:
    tasks = load_tasks()
    errs = validate_tasks(tasks)
    if errs:
        raise ForgeError("fix task errors first:\n  " + "\n  ".join(errs))
    existing = STATUS_FILE.read_text(encoding="utf-8") if STATUS_FILE.exists() else "# Project status\n"
    if args.check:
        # Compare without the git section, which changes with every commit.
        cur = existing.split(AUTO_START)[-1].split("### Recent commits")[0] if AUTO_START in existing else ""
        new = render_dashboard(tasks, include_git=False).split(AUTO_START)[-1].split(AUTO_END)[0]
        if cur.strip() != new.strip():
            print("PROJECT_STATUS.md is stale: run `python tools/forge.py dashboard`", file=sys.stderr)
            return 1
        print("dashboard up to date")
        return 0
    STATUS_FILE.write_text(splice_dashboard(existing, render_dashboard(tasks)), encoding="utf-8")
    print(f"wrote {STATUS_FILE.relative_to(ROOT)}")
    return 0


# --------------------------------------------------------------------------- prompt compiler
MAX_CONTEXT_BYTES = 60_000


def compile_prompt(task: Task, tasks: list[Task]) -> str:
    owner = task.get("owner")
    mission = ROOT / "agents" / str(owner) / "MISSION.md"
    parts = [
        f"# FORGELOOP-01 work order {task.id}: {task.get('title')}",
        "",
        "You are working on FORGELOOP-01, a repository-based Roblox game factory. The repository is the only",
        "shared memory: read the files named below, do the task, and write results back as files + commits.",
        "",
        "## Your role",
        mission.read_text(encoding="utf-8").strip() if mission.exists() else f"Owner: {owner}.",
        "",
        "## Shared rules (from AGENTS.md)",
        (ROOT / "AGENTS.md").read_text(encoding="utf-8").strip() if (ROOT / "AGENTS.md").exists() else "(AGENTS.md missing)",
        "",
        "## The task",
        dump_frontmatter(task.meta, task.body).strip(),
    ]
    deps = [find_task(tasks, d) for d in task.get("depends_on", []) if any(x.id == d for x in tasks)]
    if deps:
        parts += ["", "## Dependencies (current state)"]
        parts += [f"- {d.id} {d.get('title')} — {d.get('status')} ({d.path.relative_to(ROOT)})" for d in deps]
    budget = MAX_CONTEXT_BYTES
    ctx = task.get("context", [])
    if ctx:
        parts += ["", "## Context files"]
        for ref in ctx:
            p = ROOT / str(ref)
            if not p.exists():
                p = ROOT.parent / str(ref)
            text = p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""
            if len(text.encode()) > budget:
                parts += [f"### {ref}", f"(omitted: {len(text.encode())} bytes exceeds remaining budget — open it in the repo)"]
                continue
            budget -= len(text.encode())
            parts += [f"### {ref}", "```", text.rstrip(), "```"]
    handoff = ROOT / "production" / "handoffs" / "TEMPLATE.md"
    parts += [
        "",
        "## When you finish",
        "1. Update the task file status with `python tools/forge.py set-status` (or edit the frontmatter by hand and append a Log line).",
        "2. Write a handoff using the template below to `production/handoffs/`.",
        "3. Commit on your own branch (worker branch `forge/0N-<area>` or `codex/<task-id>-<slug>`) and open a PR into `main` (see docs/workflows/git-and-integration.md). Never claim checks you did not run.",
    ]
    if handoff.exists():
        parts += ["", "```", handoff.read_text(encoding="utf-8").strip(), "```"]
    return "\n".join(parts) + "\n"


def cmd_prompt(args) -> int:
    tasks = load_tasks()
    text = compile_prompt(find_task(tasks, args.id), tasks)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
        print(f"wrote {args.out} ({len(text.encode())} bytes)")
    else:
        sys.stdout.write(text)
    return 0


# --------------------------------------------------------------------------- checks
def _tool(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    cargo = Path.home() / ".cargo" / "bin" / name
    return str(cargo) if cargo.exists() else None


def cmd_check(args) -> int:
    results: list[tuple[str, str, str]] = []
    errs = validate_tasks(load_tasks())
    results.append(("tasks: validate", "PASS" if not errs else "FAIL", f"{len(errs)} errors" if errs else ""))
    for e in errs:
        print("  " + e)
    gates = [
        ("roblox: check.sh", ROOT / "roblox" / "scripts" / "check.sh", ["rojo", "selene", "stylua", "lune"]),
        ("blender: check.sh", ROOT / "blender" / "scripts" / "check.sh", []),
    ]
    for name, script, tools in gates:
        if not script.exists():
            results.append((name, "SKIP", "script not present"))
            continue
        missing = [t for t in tools if not _tool(t)]
        if missing:
            results.append((name, "SKIP", "missing tools: " + ", ".join(missing)))
            continue
        env = dict(os.environ, PATH=os.environ.get("PATH", "") + os.pathsep + str(Path.home() / ".cargo" / "bin"))
        proc = subprocess.run(["bash", str(script)], cwd=script.parent.parent, env=env)
        results.append((name, "PASS" if proc.returncode == 0 else "FAIL", f"exit {proc.returncode}"))
    print("\nGate summary")
    for name, res, note in results:
        print(f"  {res:5} {name} {note}")
    return 1 if any(r == "FAIL" for _, r, _ in results) else 0


# --------------------------------------------------------------------------- cli
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="forge", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate")
    ls = sub.add_parser("list")
    ls.add_argument("--owner")
    ls.add_argument("--status")
    sh = sub.add_parser("show")
    sh.add_argument("id")
    nw = sub.add_parser("new")
    nw.add_argument("--title", required=True)
    nw.add_argument("--track", required=True, choices=TRACKS)
    nw.add_argument("--owner", required=True, choices=OWNERS)
    nw.add_argument("--priority", default="P2", choices=PRIORITIES)
    nw.add_argument("--game", default="factory")
    nw.add_argument("--depends")
    ss = sub.add_parser("set-status")
    ss.add_argument("id")
    ss.add_argument("status")
    ss.add_argument("--note", required=True)
    ss.add_argument("--evidence", action="append")
    ss.add_argument("--blocked-by")
    ss.add_argument("--actual-h", type=float)
    ss.add_argument("--force", action="store_true")
    db = sub.add_parser("dashboard")
    db.add_argument("--check", action="store_true")
    pr = sub.add_parser("prompt")
    pr.add_argument("id")
    pr.add_argument("--out")
    sub.add_parser("check")
    args = p.parse_args(argv)
    try:
        if args.cmd == "validate":
            tasks = load_tasks()
            errs = validate_tasks(tasks)
            for e in errs:
                print(e)
            print(f"{len(tasks)} tasks, {len(errs)} errors")
            return 1 if errs else 0
        if args.cmd == "list":
            for t in load_tasks():
                if args.owner and t.get("owner") != args.owner:
                    continue
                if args.status and t.get("status") != args.status.upper():
                    continue
                print(f"{t.id}  {str(t.get('status')):9} {str(t.get('owner')):7} {str(t.get('priority'))}  {t.get('title')}")
            return 0
        if args.cmd == "show":
            t = find_task(load_tasks(), args.id)
            print(t.path.read_text(encoding="utf-8"))
            return 0
        return {"new": cmd_new, "set-status": cmd_set_status, "dashboard": cmd_dashboard, "prompt": cmd_prompt, "check": cmd_check}[args.cmd](args)
    except ForgeError as e:
        print(f"forge: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
