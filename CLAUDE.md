# CLAUDE.md — FORGELOOP-01

@AGENTS.md

The shared rules above are imported from `AGENTS.md` (Claude Code reads CLAUDE.md, not AGENTS.md, so this import keeps one source of truth for Claude and Codex).

- Identify yourself as your FORGE id (set `FORGE_AGENT=forge-0N` for `tools/forge.py`). Your role file: `agents/<id>/MISSION.md`. Your branch: `forge/0N-<area>` — never commit to `main`.
- Short, action-focused reports: Done / Verified (commands + results) / Unverified / Blocked / Next.
- Build thoroughly and iterate (build → test → inspect → criticise → improve), but no open-ended loops: after two failed attempts at the same problem, change approach or report the blocker.
- Use subagents for independent work inside your own area. Never edit paths owned by another worker.
- Visual work: open the rendered image or screenshot and judge it before claiming quality.
- Cloud sessions: Roblox Studio is not available on Linux — headless gates only; write Studio steps for the user. Blender runs as the `bpy` wheel. GitHub release downloads may be blocked by the proxy (crates.io, pypi, npm work).
