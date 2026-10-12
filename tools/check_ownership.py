#!/usr/bin/env python3
"""check_ownership — quality gate G8: a PR changes only paths its author owns (or an exception allows).

Standard library only, Python 3.10+. Rules: production/quality-gates/ownership.json, derived from
docs/workflows/team.md (the source of truth: change team.md first, then the rules file).

Usage
  check_ownership.py --base origin/main [--head HEAD] [--owner forge-03] [--title T] [--branch B]
                     [--rules PATH] [--explain]
  check_ownership.py --whois PATH [PATH ...]       owner of a path and the pattern that decides it

Changed files  git diff --name-status -M <merge-base(base, head)> <head>, so commits on the base since
               the branch point are not counted. Without --head the working tree is compared (tracked
               changes plus untracked, non-ignored files): check your work before committing.
Owner          --owner; else the PR title prefix [FORGE-0N] / [CODEX] (--title or $PR_TITLE); else the
               branch forge/0N-... / codex/... (--branch, $PR_BRANCH or $GITHUB_HEAD_REF); else exit 2.
Rules          --rules; else the merge base's ownership.json (a PR cannot loosen the rules that judge
               it); else the working tree's copy (the PR that introduces the file).
Matching       '*' and '?' match within one path segment, '**' matches zero or more segments. The most
               specific pattern wins: exact file > more literal segments > longer literal prefix; a
               remaining tie is a rules error. Unmatched paths belong to the default owner.
Exit codes     0 pass, 1 violations, 2 usage or configuration error.
"""
from __future__ import annotations

import argparse
import fnmatch
import importlib.util
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent  # the repository that ships this script
RULES_REL = "production/quality-gates/ownership.json"
CHANGE_LETTERS = ("A", "M", "D", "R")
EXCEPTION_KINDS = ("add-only", "task-status", "own-file", "rule")
WILDCARD_CHARS = "*?["
WILD_TOKEN = re.compile(r"\*|\?|\[[^\]]*\]")
HEADING_RE = re.compile(r"^#{1,6}\s")
TITLE_RE = re.compile(r"^\s*\[(forge-\d+|codex)\]", re.IGNORECASE)
BRANCH_RE = re.compile(r"^(?:refs/heads/)?(?:forge/(\d+)-|(codex)/)", re.IGNORECASE)


class OwnershipError(Exception):
    """Usage or configuration error (exit 2)."""


def _import_forge():
    """Load the sibling tools/forge.py, so task files are parsed by the same front-matter parser."""
    path = TOOLS_DIR / "forge.py"
    mod = sys.modules.get("forge")
    if mod is not None and Path(getattr(mod, "__file__", None) or "").resolve() == path:
        return mod
    spec = importlib.util.spec_from_file_location("forge", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["forge"] = mod  # forge.py's dataclasses look their module up here
    spec.loader.exec_module(mod)
    return mod


forge = _import_forge()


# --------------------------------------------------------------------------- globs
def is_literal(segment: str) -> bool:
    return not any(c in segment for c in WILDCARD_CHARS)


def match_segments(pattern: tuple[str, ...], path: tuple[str, ...]) -> bool:
    """Segment-wise glob match: fnmatch within a segment, '**' = zero or more whole segments."""
    if not pattern:
        return not path
    head, rest = pattern[0], pattern[1:]
    if head == "**":
        return any(match_segments(rest, path[i:]) for i in range(len(path) + 1))
    return bool(path) and fnmatch.fnmatchcase(path[0], head) and match_segments(rest, path[1:])


def glob_match(pattern: str, path: str) -> bool:
    return match_segments(tuple(pattern.split("/")), tuple(path.split("/")))


def segments_overlap(a: str, b: str) -> bool:
    """Can one path segment match both? Exact when either is literal; conservative (prefix/suffix) otherwise."""
    if is_literal(a):
        return fnmatch.fnmatchcase(a, b)
    if is_literal(b):
        return fnmatch.fnmatchcase(b, a)
    ta, tb = WILD_TOKEN.split(a), WILD_TOKEN.split(b)
    prefix_ok = ta[0].startswith(tb[0]) or tb[0].startswith(ta[0])
    suffix_ok = ta[-1].endswith(tb[-1]) or tb[-1].endswith(ta[-1])
    return prefix_ok and suffix_ok


def globs_overlap(a: tuple[str, ...], b: tuple[str, ...]) -> bool:
    """Can some path match both patterns (given as segment tuples)?"""
    if not a or not b:
        return all(s == "**" for s in a + b)
    if a[0] == "**":
        return globs_overlap(a[1:], b) or globs_overlap(a, b[1:])
    if b[0] == "**":
        return globs_overlap(a, b[1:]) or globs_overlap(a[1:], b)
    return segments_overlap(a[0], b[0]) and globs_overlap(a[1:], b[1:])


def pattern_problems(pattern) -> list[str]:
    """Why a pattern is malformed ([] when it is fine)."""
    if not isinstance(pattern, str) or not pattern:
        return ["pattern must be a non-empty string"]
    problems = []
    if pattern.startswith("/") or pattern.endswith("/"):
        problems.append(f"{pattern!r}: no leading or trailing '/' (directories end in '/**')")
    if "\\" in pattern:
        problems.append(f"{pattern!r}: use '/' separators")
    if "{" in pattern or "}" in pattern:
        problems.append(f"{pattern!r}: expand brace sets into one pattern per name")
    for seg in pattern.split("/"):
        if seg in ("", ".", ".."):
            problems.append(f"{pattern!r}: empty, '.' or '..' segment")
        elif "**" in seg and seg != "**":
            problems.append(f"{pattern!r}: '**' must be a whole segment")
    return problems


def sample_paths(pattern: str) -> list[str]:
    """Concrete paths a pattern matches ('**' as zero, one and two segments), for reachability checks."""

    def fill(token: re.Match) -> str:
        t = token.group()
        if t in ("*", "?"):
            return "zz" if t == "*" else "z"
        inner = t[1:-1]
        return "~" if inner[:1] in ("!", "^") else inner[:1]

    out: list[str] = []
    for fillers in ([], ["zz-sample"], ["zz-sample", "zz-deep"]):
        parts: list[str] = []
        for seg in pattern.split("/"):
            parts.extend(fillers if seg == "**" else [WILD_TOKEN.sub(fill, seg)])
        path = "/".join(parts)
        if path and path not in out:
            out.append(path)
    return out


# --------------------------------------------------------------------------- rules
@dataclass(frozen=True)
class Rule:
    pattern: str
    owner: str

    @property
    def segments(self) -> tuple[str, ...]:
        return tuple(self.pattern.split("/"))

    @property
    def specificity(self) -> tuple[int, int, int]:
        """(exact file, literal segments, literal prefix length); the highest wins."""
        literal = sum(1 for s in self.segments if is_literal(s))
        cut = next((i for i, c in enumerate(self.pattern) if c in WILDCARD_CHARS), len(self.pattern))
        return (int(literal == len(self.segments)), literal, cut)

    def matches(self, path: str) -> bool:
        return match_segments(self.segments, tuple(path.split("/")))


@dataclass
class Rules:
    default_owner: str
    owners: list[str]
    rules: list[Rule]
    exceptions: list[dict]
    source: str = ""

    def resolve(self, path: str) -> Rule | None:
        """The winning rule for a path, or None when only the default owner applies."""
        hits = [r for r in self.rules if r.matches(path)]
        if not hits:
            return None
        best = max(r.specificity for r in hits)
        top = [r for r in hits if r.specificity == best]
        if len(top) > 1:
            raise OwnershipError(f"{self.source}: patterns tie for {path}: " + ", ".join(r.pattern for r in top))
        return top[0]

    def owner_of(self, path: str) -> str:
        rule = self.resolve(path)
        return rule.owner if rule else self.default_owner


def _reject_duplicate_keys(pairs: list) -> dict:
    out: dict = {}
    for key, value in pairs:
        if key in out:
            raise OwnershipError(f"duplicate key {key!r}")
        out[key] = value
    return out


def _exception_problems(exc, owners: list[str], rules: dict, seen: set) -> list[str]:
    """Validate one entry of the 'exceptions' list."""
    if not isinstance(exc, dict):
        return ["each exception must be an object"]
    eid = exc.get("id")
    where = f"exception {eid!r}"
    errors = []
    if not isinstance(eid, str) or not eid:
        errors.append("exception without an 'id'")
    elif eid in seen:
        errors.append(f"{where}: duplicate id")
    seen.add(eid)
    if not isinstance(exc.get("description"), str) or not exc["description"].strip():
        errors.append(f"{where}: needs a 'description'")
    kind, who, paths = exc.get("kind"), exc.get("who"), exc.get("paths")
    if kind not in EXCEPTION_KINDS:
        return errors + [f"{where}: kind must be one of {list(EXCEPTION_KINDS)}"]
    if not isinstance(paths, list) or not paths:
        return errors + [f"{where}: needs a non-empty 'paths' list"]
    for p in paths:
        errors += [f"{where}: {e}" for e in pattern_problems(p)]
    if kind != "rule":
        changes = exc.get("changes")
        if not isinstance(changes, list) or not changes or any(c not in CHANGE_LETTERS for c in changes):
            errors.append(f"{where}: 'changes' must list letters from {list(CHANGE_LETTERS)}")
    allowed_who = {
        "add-only": set(owners) | {"any"},
        "task-status": set(owners) | {"task-owner"},
        "own-file": {"agent-in-path"},
        "rule": set(owners),
    }[kind]
    if who not in allowed_who:
        errors.append(f"{where}: 'who' must be one of {sorted(allowed_who)}")
    if kind == "task-status":
        if not isinstance(exc.get("fields"), list) or not all(isinstance(f, str) for f in exc["fields"]):
            errors.append(f"{where}: 'fields' must be a list of front-matter keys")
        if not isinstance(exc.get("log_section"), str) or not exc["log_section"].startswith("## "):
            errors.append(f"{where}: 'log_section' must be a '## ' heading")
    if kind == "own-file":
        for p in paths:
            segs = p.split("/")
            if segs.count("*") != 1 or "**" in segs:
                errors.append(f"{where}: {p!r} needs exactly one '*' segment (the agent id) and no '**'")
    if kind == "rule":
        for p in paths:
            if rules.get(p) != who:
                errors.append(f"{where}: rules must map {p!r} to {who} (found {rules.get(p)!r})")
    return errors


def parse_rules(text: str, source: str) -> Rules:
    """Parse and validate ownership.json text; raises OwnershipError listing every problem."""
    try:
        data = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except json.JSONDecodeError as e:
        raise OwnershipError(f"{source}: invalid JSON: {e}") from None
    except OwnershipError as e:
        raise OwnershipError(f"{source}: {e}") from None
    if not isinstance(data, dict):
        raise OwnershipError(f"{source}: top level must be an object")
    errors: list[str] = []
    owners = data.get("owners")
    if not isinstance(owners, list) or not owners or not all(isinstance(o, str) for o in owners):
        raise OwnershipError(f"{source}: 'owners' must be a non-empty list of ids")
    default = data.get("default_owner")
    if default not in owners:
        errors.append(f"default_owner {default!r} is not in owners")
    raw_rules = data.get("rules")
    if not isinstance(raw_rules, dict) or not raw_rules:
        raise OwnershipError(f"{source}: 'rules' must be a non-empty object of pattern -> owner")
    for pattern, owner in raw_rules.items():
        errors += pattern_problems(pattern)
        if owner not in owners:
            errors.append(f"{pattern!r}: owner {owner!r} is not in owners")
    rules = [Rule(p, o) for p, o in raw_rules.items()]
    for i, a in enumerate(rules):
        for b in rules[i + 1 :]:
            if a.specificity == b.specificity and globs_overlap(a.segments, b.segments):
                errors.append(f"{a.pattern!r} ({a.owner}) and {b.pattern!r} ({b.owner}) are equally specific and can match the same path")
    exceptions = data.get("exceptions", [])
    if not isinstance(exceptions, list):
        errors.append("'exceptions' must be a list")
        exceptions = []
    seen: set = set()
    for exc in exceptions:
        errors += _exception_problems(exc, owners, raw_rules, seen)
    if errors:
        raise OwnershipError(f"{source}: invalid rules:\n  " + "\n  ".join(errors))
    return Rules(default, owners, rules, exceptions, source)


def load_rules_file(path: Path, label: str | None = None) -> Rules:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        raise OwnershipError(f"cannot read rules file {path}: {e}") from None
    return parse_rules(text, label or str(path))


def unreachable_patterns(rules: Rules) -> list[str]:
    """Patterns that win for none of their sample paths, i.e. are fully shadowed by other patterns."""
    return [r.pattern for r in rules.rules if not any(rules.resolve(p) is r for p in sample_paths(r.pattern))]


# --------------------------------------------------------------------------- git
def git(repo: Path, *args: str) -> str:
    try:
        proc = subprocess.run(["git", *args], cwd=repo, capture_output=True)
    except OSError as e:
        raise OwnershipError(f"cannot run git: {e}") from None
    if proc.returncode != 0:
        raise OwnershipError(f"git {' '.join(args)}: {proc.stderr.decode('utf-8', 'replace').strip()}")
    return proc.stdout.decode("utf-8", "replace")


def git_show(repo: Path, rev: str, path: str) -> str | None:
    """A file's text at a revision, or None if it does not exist there."""
    proc = subprocess.run(["git", "show", f"{rev}:{path}"], cwd=repo, capture_output=True)
    return proc.stdout.decode("utf-8", "replace") if proc.returncode == 0 else None


def repo_root(cwd: Path) -> Path | None:
    try:
        return Path(git(cwd, "rev-parse", "--show-toplevel").strip())
    except OwnershipError:
        return None


@dataclass(frozen=True)
class Change:
    letter: str  # A, M, D or R (T and U count as M, a copy as A)
    path: str  # the new path of a rename
    old: str | None = None  # the old path of a rename


def parse_name_status(raw: str) -> list[Change]:
    """Parse `git diff --name-status -z` output."""
    parts, out, i = raw.split("\0"), [], 0
    while i < len(parts) and parts[i]:
        letter = parts[i][0]
        if letter in "RC":
            old, new = parts[i + 1], parts[i + 2]
            out.append(Change("R", new, old) if letter == "R" else Change("A", new))
            i += 3
        else:
            out.append(Change({"T": "M", "U": "M"}.get(letter, letter), parts[i + 1]))
            i += 2
    return out


def changed_files(repo: Path, merge_base: str, head: str | None) -> list[Change]:
    """Changes from the merge base to head (a commit), or to the working tree when head is None."""
    if head:
        return parse_name_status(git(repo, "diff", "--name-status", "-z", "-M", "--no-ext-diff", merge_base, head, "--"))
    changes = parse_name_status(git(repo, "diff", "--name-status", "-z", "-M", "--no-ext-diff", merge_base, "--"))
    untracked = git(repo, "ls-files", "--others", "--exclude-standard", "-z")
    changes += [Change("A", p) for p in untracked.split("\0") if p]
    return sorted(changes, key=lambda c: c.path)


@dataclass
class Versions:
    """Reads a file's text at the merge base and at the head (a commit, or the working tree when None)."""

    repo: Path
    base_rev: str
    head_rev: str | None

    def base(self, path: str) -> str | None:
        return git_show(self.repo, self.base_rev, path)

    def head(self, path: str) -> str | None:
        if self.head_rev is not None:
            return git_show(self.repo, self.head_rev, path)
        p = self.repo / path
        return p.read_bytes().decode("utf-8", "replace") if p.is_file() else None


# --------------------------------------------------------------------------- exceptions
def _lines(body: str) -> list[str]:
    body = body.replace("\r\n", "\n").strip("\n")
    return body.split("\n") if body else []


def log_append_problem(base_body: str, head_body: str, section: str = "## Log") -> str | None:
    """None if head_body is base_body plus lines appended to its Log section (created at the end if missing)."""
    b, h = _lines(base_body), _lines(head_body)
    start = next((i for i, line in enumerate(b) if line.rstrip() == section), None)
    if start is None:
        prefix, suffix = b, []
    else:
        end = next((j for j in range(start + 1, len(b)) if HEADING_RE.match(b[j])), len(b))
        k = end
        while k > start + 1 and not b[k - 1].strip():
            k -= 1  # blank lines that close the section may be followed by new Log lines
        prefix, suffix = b[:k], b[end:]
    tail = len(h) - len(suffix)
    if tail < len(prefix) or h[: len(prefix)] != prefix or h[tail:] != suffix:
        first = next((i for i, (x, y) in enumerate(zip(b, h)) if x != y), min(len(b), len(h)))
        return f"body changed outside an append to the '{section}' section (first difference at body line {first + 1})"
    added = [line for line in h[len(prefix) : tail] if line.strip()]
    if start is None and added:
        if added[0].rstrip() != section:
            return f"text appended after the body must start a '{section}' section"
        added = added[1:]
    if any(HEADING_RE.match(line) for line in added):
        return f"appended lines add a heading; only '{section}' lines may be appended"
    return None


def task_edit_problems(base_text: str, head_text: str, fields: list[str], section: str = "## Log") -> list[str]:
    """Why head_text is not base_text with only `fields` and Log appends changed ([] when it is)."""
    try:
        base_meta, base_body = forge.parse_frontmatter(base_text.replace("\r\n", "\n"))
    except forge.ForgeError as e:
        return [f"base version: {e}"]
    try:
        head_meta, head_body = forge.parse_frontmatter(head_text.replace("\r\n", "\n"))
    except forge.ForgeError as e:
        return [f"head version: {e}"]
    problems = []
    changed = sorted(k for k in set(base_meta) | set(head_meta) if k not in fields and base_meta.get(k) != head_meta.get(k))
    if changed:
        problems.append(f"changed front-matter field(s) {', '.join(changed)} (allowed: {', '.join(fields)})")
    body_problem = log_append_problem(base_body, head_body, section)
    if body_problem:
        problems.append(body_problem)
    return problems


def task_owner(text: str | None) -> str | None:
    """The 'owner' front-matter field of a task file's text (None if absent or unparseable)."""
    try:
        owner = forge.parse_frontmatter((text or "").replace("\r\n", "\n"))[0].get("owner")
    except forge.ForgeError:
        return None
    return None if owner is None else str(owner)


def exception_allows(exc: dict, owner: str, path: str, letter: str, versions: Versions) -> tuple[bool, str]:
    """(allowed, why not) for one exception; 'why not' is '' when the exception does not cover this path."""
    kind = exc["kind"]
    hit = next((p for p in exc["paths"] if glob_match(p, path)), None)
    if kind == "rule" or hit is None:
        return False, ""
    if letter not in exc["changes"]:
        return False, f"covers change {'/'.join(exc['changes'])} only, not {letter}"
    who = exc["who"]
    if kind == "add-only":
        return (True, "") if who in ("any", owner) else (False, f"only {who} may add here")
    if kind == "own-file":
        agent = path.split("/")[hit.split("/").index("*")]
        return (True, "") if agent == owner else (False, f"this is {agent}'s file")
    base_text, head_text = versions.base(path), versions.head(path)
    if base_text is None or head_text is None:
        return False, "base or head version not readable"
    if who == "task-owner":
        actual = task_owner(base_text)
        if actual != owner:
            return False, f"the task's owner is {actual}"
    elif who != owner:
        return False, f"only {who} may use it"
    problems = task_edit_problems(base_text, head_text, exc["fields"], exc["log_section"])
    return (not problems), "; ".join(problems)


# --------------------------------------------------------------------------- check
@dataclass
class Verdict:
    path: str
    letter: str
    owner: str  # who owns the path
    allowed: bool
    reason: str  # the rule, default or exception that decided it
    details: list[str] = field(default_factory=list)  # why exceptions did not apply


def judge(rules: Rules, owner: str, path: str, letter: str, versions: Versions) -> Verdict:
    """Is `owner` allowed to make change `letter` to `path`?"""
    rule = rules.resolve(path)
    path_owner = rule.owner if rule else rules.default_owner
    reason = f"rule {rule.pattern} -> {rule.owner}" if rule else f"default owner {rules.default_owner}: no pattern matches"
    if path_owner == owner:
        return Verdict(path, letter, path_owner, True, reason)
    details = [reason]
    for exc in rules.exceptions:
        ok, why = exception_allows(exc, owner, path, letter, versions)
        if ok:
            return Verdict(path, letter, path_owner, True, f"exception {exc['id']}; {reason}")
        if why:
            details.append(f"exception {exc['id']}: {why}")
    return Verdict(path, letter, path_owner, False, reason, details)


def check_changes(rules: Rules, owner: str, changes: list[Change], versions: Versions) -> list[tuple[Change, list[Verdict]]]:
    """One verdict per path; a rename is judged on both its old and its new path."""
    out = []
    for ch in changes:
        sides = [ch.old, ch.path] if ch.old is not None else [ch.path]
        out.append((ch, [judge(rules, owner, p, ch.letter, versions) for p in sides]))
    return out


def report(results: list[tuple[Change, list[Verdict]]], owner: str, explain: bool) -> int:
    bad = 0
    for ch, verdicts in results:
        bad += any(not v.allowed for v in verdicts)
        rename = f"rename {ch.old} -> {ch.path}" if ch.old is not None else ""
        for v in verdicts:
            if not v.allowed:
                print(f"NOT ALLOWED  {v.path}  (owner: {v.owner}, change: {v.letter})")
                if explain:
                    for line in ([rename] if rename else []) + v.details:
                        print(f"             {line}")
            elif explain:
                print(f"allowed      {v.path}  (change: {v.letter}, {v.reason}{', ' + rename if rename else ''})")
    n = len(results)
    if bad:
        print(f"ownership: FAIL — {bad} of {n} changed file(s) not owned by {owner}")
        return 1
    print(f"ownership: PASS — {n} changed file(s), all owned by {owner} or allowed by exceptions")
    return 0


def resolve_owner(owner: str | None, title: str | None, branch: str | None, env, owners: list[str]) -> tuple[str, str]:
    """(owner id, where it came from): --owner, else the PR title prefix, else the branch name."""
    found = source = None
    if owner:
        found, source = owner.strip().lower(), "--owner"
    else:
        title_src = "--title" if title is not None else "$PR_TITLE"
        title = title if title is not None else env.get("PR_TITLE", "")
        m = TITLE_RE.match(title or "")
        if m:
            found, source = m.group(1).lower(), f"{title_src} prefix"
        else:
            branch = (branch or env.get("PR_BRANCH") or env.get("GITHUB_HEAD_REF") or "").strip()
            m = BRANCH_RE.match(branch)
            if m:
                found, source = (f"forge-{m.group(1)}" if m.group(1) else "codex"), f"branch {branch}"
    if not found:
        raise OwnershipError(
            "cannot determine owner: pass --owner, a PR title starting with [FORGE-0N] or [CODEX] "
            "(--title or $PR_TITLE), or a branch forge/0N-... or codex/... (--branch, $PR_BRANCH or $GITHUB_HEAD_REF)"
        )
    if found not in owners:
        raise OwnershipError(f"unknown owner {found!r} (from {source}); known owners: {', '.join(owners)}")
    return found, source


def cmd_check(args) -> int:
    repo = repo_root(Path.cwd())
    if repo is None:
        raise OwnershipError("not inside a git repository")
    merge_base = git(repo, "merge-base", args.base, args.head or "HEAD").strip()
    if args.rules:
        rules = load_rules_file(Path(args.rules))
    else:
        text = git_show(repo, merge_base, RULES_REL)
        if text is not None:
            rules = parse_rules(text, f"{RULES_REL} at merge base {merge_base[:7]}")
        else:
            rules = load_rules_file(repo / RULES_REL, f"{RULES_REL} (working tree; not on the merge base)")
    owner, source = resolve_owner(args.owner, args.title, args.branch, os.environ, rules.owners)
    changes = changed_files(repo, merge_base, args.head)
    results = check_changes(rules, owner, changes, Versions(repo, merge_base, args.head))
    if args.explain:
        print(f"owner {owner} (from {source}); base {args.base} (merge base {merge_base[:7]}); "
              f"head {args.head or 'working tree'}; rules {rules.source}")
    return report(results, owner, args.explain)


def cmd_whois(args) -> int:
    repo = repo_root(Path.cwd()) or ROOT
    rules = load_rules_file(Path(args.rules) if args.rules else repo / RULES_REL)
    for raw in args.whois:
        p = Path(raw)
        if p.is_absolute():
            try:
                raw = str(p.resolve().relative_to(repo.resolve()))
            except ValueError:
                pass
        path = raw.replace("\\", "/").removeprefix("./")
        rule = rules.resolve(path)
        if rule:
            print(f"{path}: {rule.owner}  (pattern: {rule.pattern})")
        else:
            print(f"{path}: {rules.default_owner}  (default owner: no pattern matches)")
        for exc in rules.exceptions:
            if exc["kind"] != "rule" and any(glob_match(x, path) for x in exc["paths"]):
                print(f"  exception {exc['id']}: {exc['description']}")
    return 0


# --------------------------------------------------------------------------- cli
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="check_ownership", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base", help="base revision, e.g. origin/main (the merge base with head is used)")
    p.add_argument("--head", help="head revision (default: the working tree, including untracked files)")
    p.add_argument("--owner", help="owner id, e.g. forge-03 or codex")
    p.add_argument("--title", help="PR title; '[FORGE-0N] ...' or '[CODEX] ...' gives the owner (default: $PR_TITLE)")
    p.add_argument("--branch", help="PR branch; forge/0N-... or codex/... gives the owner (default: $PR_BRANCH, $GITHUB_HEAD_REF)")
    p.add_argument("--rules", help=f"rules file (default: {RULES_REL} at the merge base, else in the working tree)")
    p.add_argument("--explain", action="store_true", help="show the deciding pattern or exception for every file")
    p.add_argument("--whois", nargs="+", metavar="PATH", help="print the owner and winning pattern of each path")
    args = p.parse_args(argv)
    try:
        if args.whois:
            return cmd_whois(args)
        if not args.base:
            p.error("--base is required (or use --whois PATH)")
        return cmd_check(args)
    except OwnershipError as e:
        print(f"check_ownership: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
