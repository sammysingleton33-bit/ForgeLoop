# Integration log

One line per merge into `main` (newest last). Maintained by FORGE-05 (D-014). Checks are run on the
**merge result** (PR head + current `main`), not only on the PR head. `artifact` is the CI upload of the
stamped place for that `main` commit; its BuildInfo sha is read from the CI log line
`place check: PASS ... BuildInfo stamped <sha>` (`--require-stamp`).

| date | main sha | PR | tasks | checks (merge result) | CI on main | artifact |
|---|---|---|---|---|---|---|
| 2026-10-12 | `f9e9b0a` | [#1](https://github.com/sammysingleton33-bit/ForgeLoop/pull/1) FORGE-00 skeleton | FL-0003 (REVIEW, G6 pending) | PR CI [run 38209213389](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38209213389) green on head `26fbf66`; local merge result `d026a93` (head + main `798b94d`): check.sh OVERALL PASS — Lune 179/0/0 broken, 16 files; Selene 0 errors; StyLua 69 files; Rojo build; place check 17 instances/9 scripts/8 requires; pytest 32 passed; forge validate 45 tasks 0 errors. Negative gates: failing spec → lune FAIL exit 1; broken `@game` require in Main.server → place check FAIL exit 1; unformatted file → stylua FAIL exit 1; restored → PASS. Ownership gate: exempt (bootstrap, D-016); gate not yet built (FL-0029). | [run 38295342210](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38295342210) green (roblox + tools) | `forgeloop-main-f9e9b0a` (id 11768980793, 13802 B zip, sha256 78916f8e…); BuildInfo stamped `f9e9b0ad71a4` per CI log. Download from the cloud sandbox blocked by the proxy (blob storage), so the file itself was not opened here. |
