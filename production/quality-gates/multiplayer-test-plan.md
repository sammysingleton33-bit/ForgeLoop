# Multiplayer test plan — AI Kingdoms (FORGE-05)

Real multiplayer behaviour (replication, server authority against a real client, two players
competing for one resource) cannot be proven headlessly. Each test below is run by the user in
Roblox Studio with **Test → Clients and Servers → Local Server** (2–4 players) against the integrated
build (`main`), and recorded in `production/quality-gates/studio-runs.md` with the BuildInfo sha.
Headless specs prove the server logic; these tests prove it survives replication.

Status: **M1 is runnable now** (`roblox/STUDIO_TEST_PLAN.md`). M2–M8 are the acceptance tests for the
vertical slice; each becomes runnable when the systems in its "Needs" column are merged, and its exact
clicks are then written into `STUDIO_TEST_PLAN.md` from the owning worker's `roblox/studio-tests/<area>.md`.

| Test | Players | What must be true | Needs (owner) | Status |
|---|---|---|---|---|
| M1 Join & see each other | 2 | Both clients log the same sha; both spawn at the lobby plaza; each sees the other move | map (FORGE-05) | ready |
| M2 Kingdom assignment | 4 | Match start gives each player a different kingdom (or 1 human + AI kingdoms); each ruler spawns on its own `ForgeRulerSpawn`; every client's HUD shows its own kingdom; a 5th joiner waits in the lobby or spectates | match/kingdom service (FORGE-01), HUD (FORGE-03) | waiting |
| M3 Villagers replicate | 2 | Villagers spawn at `ForgeVillagerSpawn`, walk to a resource node and back to the `ForgeStockpile`; both clients see the same villager in the same place (≤ 1 s lag); villagers are server-owned (client cannot move them) | villager AI (FORGE-01) | waiting |
| M4 Resource authority | 2 | Resource totals change only on the server (villager delivery); HUD values match the server for both players; a client firing the gather/deliver remote with forged amounts changes nothing and is rate-limited (server log) | economy (FORGE-03), remotes (FORGE-01) | waiting |
| M5 Build / upgrade | 2 | Player A builds on an own `ForgeBuildPlot`: cost deducted once (server), building appears for both clients; Player B cannot build on A's plot; double-click / two remotes in one frame builds once | construction (FORGE-01/03 per brief), UI (FORGE-03) | waiting |
| M6 Leave & rejoin | 2 | A player leaving mid-match: their kingdom becomes AI-controlled or frozen (per brief), no errors; rejoining the same server restores their data (DataStore in Studio needs API access enabled) | DataService (FORGE-01) | waiting |
| M7 Troops & combat | 2 | Recruited troops gather at `ForgeRallyPoint`; damage is applied by the server only; both clients agree on health/kills | combat (FORGE-01) | later |
| M8 Siege & match end | 2–4 | Destroying/capturing a `ForgeKeep` eliminates that kingdom; last kingdom standing wins; results screen for every client; return to lobby | match resolution (FORGE-01), results UI (FORGE-03) | later |

## Rules for every multiplayer test
- Use the Local Server mode (separate server and client processes), not Play Solo: Play Solo runs
  server and client in one process and hides replication bugs.
- Record per test: BuildInfo sha, player count, PASS/FAIL, Output lines from the **Server** window
  and from one client, and any red errors verbatim.
- An exploit check (M4, M5) is done from a client's Command Bar (client context) with the exact
  snippet the owning worker provides in its `studio-tests/<area>.md`.
- Performance: note the Server window's **View → Stats** heartbeat / memory once per run while all
  villagers are active (budgets: FL-0032).
