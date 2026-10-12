# Decisions

Format: ID · date · decision · why · status (active / superseded by D-xxx). Newest last.

| ID | Date | Decision | Why | Status |
|---|---|---|---|---|
| D-001 | 2026-10-12 | FORGELOOP-01 lives in `forgeloop/` inside the `sammysingleton33-bit/DLS` repo. | It is the only repository this workspace's GitHub access covers. The folder is self-contained and can be split into its own repo later with `git subtree split --prefix forgeloop`. | active (user may choose a dedicated repo — FL-0014) |
| D-002 | 2026-10-12 | `forge/integration` is the integrated build branch, based on `main` plus FORGELOOP only (no DLS business code). Workers PR into it; FORGE-05 merges. `main` only at user-approved milestones. | Keeps game work isolated from the DLS business tooling and gives Studio one identifiable build. | active |
| D-003 | 2026-10-12 | Team: FORGE-00 Director, 01 Gameplay, 02 Blender, 03 UI & Economy, 04 Experience, 05 Integration & QA; Codex = intelligence. Ownership by path (`docs/workflows/team.md`). | User directive; path ownership prevents parallel workers overwriting each other. | active |
| D-004 | 2026-10-12 | Luau uses require-by-string with relative paths, top-level only, no aliases. | Live in Roblox and native in Lune, so the same code runs in headless tests and Studio. Studio smoke test S1 confirms. | active, Studio confirmation pending |
| D-005 | 2026-10-12 | Toolchain: Rojo 7.7.1, Selene 0.31.0, StyLua 2.6.0, Lune 0.11.0 (pinned in `rokit.toml`); Blender 5.2.2 (bpy wheel on Linux, desktop Blender on Windows). | Verified installable and working in the cloud sandbox on 2026-10-12. Rojo is the Git-friendly Studio sync. | active |
| D-006 | 2026-10-12 | Services/controllers get an injected `Env`; data is namespaced per owner; remotes declared per area; a server event bus decouples systems. | Lets five workers build in parallel and test headlessly with mocks (`docs/architecture/interfaces.md`). | active |
| D-007 | 2026-10-12 | Generators, manifests and small previews are committed; exported meshes are reproducible build outputs (CI artifact), not committed. No Git LFS for now. | Avoids repo bloat and LFS push uncertainty through the proxy. Revisit when hand-authored `.blend` files appear. | active |
| D-008 | 2026-10-12 | Claude does the heavy implementation and the first market/platform research; Codex reviews strategy, writes high-leverage specs and prompt improvements. All state stays in Git so any provider (Codex, AreaAI, other) can pick up a task via `tools/forge.py prompt <ID>`. | Claude capacity ≫ Codex capacity; provider neutrality. | active |
| D-009 | 2026-10-12 | Until Game #1 is approved, workers build genre-agnostic infrastructure and a `games/sandbox` integration place. | Game #1 needs user selection; infrastructure is useful for every candidate. | active |
