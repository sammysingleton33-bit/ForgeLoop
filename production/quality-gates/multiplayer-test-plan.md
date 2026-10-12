# Multiplayer test plan — AI Kingdoms (FORGE-05)

Replication, server authority against a real client, and two players competing for one resource
cannot be proven headlessly. Each test runs in Roblox Studio with **Test → Clients and Servers →
Local Server** (2–4 players) on an integrated build of `main` (`forgeloop-game001-<sha>.rbxl`) and is
recorded in `production/quality-gates/studio-runs.md` with the BuildInfo sha. Headless specs prove
the server logic; these tests prove it survives replication.

M1 and M2 are part of the VS-1 playtest (`games/game-001/STUDIO_PLAYTEST.md`). M3–M8 become runnable
as their systems merge; FORGE-05 then writes their exact clicks into the playtest script from the
owner's `roblox/studio-tests/<area>.md`.

| Test | Players | What must be true | Needs (task, owner) | Status |
|---|---|---|---|---|
| M1 Join and see each other | 2 | Both clients log the same sha and `trees=Forge,Game`; each sees the other ruler move | FL-0046 (FORGE-05) | ready |
| M2 Shared kingdom | 2 | Both can be in one kingdom (party); HUD member list shows both; one player's gathering shows in the other's HUD | FL-0048 (FORGE-01), FL-0059 (FORGE-03) | waiting |
| M3 Citizens replicate | 2 | Same citizen, same place on both clients (≤ ~100 ms interpolation lag); clients cannot move citizens | FL-0049, FL-0050 (FORGE-01) | waiting |
| M4 Treasury authority | 2 | Totals change only on the server; both HUDs match it; a client firing `Kingdom.Gather` / `Treasury.*` with forged arguments changes nothing and is rate-limited (server log) | FL-0051 (FORGE-01), FL-0058 (FORGE-03) | waiting |
| M5 Build / upgrade | 2 | A's House on A's plot: cost charged once, visible to both; B cannot build on A's territory; double-click / two calls in one frame builds once | FL-0051, FL-0059 | waiting |
| M6 Leave and rejoin | 2 | A player leaving mid-match: no server errors, their kingdom continues (AI or frozen, per brief); rejoining the same server restores their kingdom membership | FL-0048 | waiting |
| M7 Troops and capture | 2 | Recruited soldiers at the barracks; server-only damage; both clients agree on capture progress; contested capture (two kingdoms in radius) does not progress | FL-0052 | waiting |
| M8 Siege and match end (VS-2) | 2–4 | Destroying a rival keep eliminates it; last kingdom standing / Crown Points at timer; results screen on every client; back to lobby | later tasks | later |

## Rules for every multiplayer test
- Use **Local Server** (separate server and client processes), never Play Solo: Play Solo runs server
  and client in one process and hides replication bugs.
- Record per test: BuildInfo sha, player count, PASS/FAIL, Output lines from the **Server** window and
  one client, red errors verbatim.
- Exploit checks (M4, M5) are run from a client window's Command Bar with the exact snippet the owning
  worker provides.
- Performance: during M3, note the Server window's **View → Script Performance** activity of
  `ServerScriptService.Forge.Main` and **View → Stats** frame rate (budgets: BRIEF §14, FL-0032).
