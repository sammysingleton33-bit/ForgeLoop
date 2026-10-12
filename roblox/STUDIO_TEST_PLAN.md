# Studio test plan (gate G6)

Headless checks (`bash roblox/scripts/check.sh`) cannot run Roblox Studio. These steps are run by the
user on Windows against the **integrated build (`main`)**. Paste the Output text and the BuildInfo sha
into the chat; FORGE-05 records them in `production/quality-gates/studio-runs.md`. S1–S4 and M1 take
about 15 minutes.

## Setup (pick one)

**A. Build locally, then live sync with Rojo (recommended for repeat runs)**
1. Install Rokit once: https://github.com/rojo-rbx/rokit (Windows installer or `rokit.exe self-install`).
2. In Git Bash, in the repository folder:
   ```bash
   git checkout main && git pull
   rokit install                      # Rojo 7.7.1, Selene, StyLua, Lune from rokit.toml
   bash roblox/scripts/stamp_build.sh # writes BuildInfo.json with the current sha
   mkdir -p roblox/build && rojo build roblox/default.project.json -o roblox/build/sandbox.rbxl
   rojo plugin install                # installs the matching Rojo Studio plugin (once per Rojo version)
   rojo serve roblox/default.project.json
   ```
3. Roblox Studio → **File** → **Open from File…** → `roblox/build/sandbox.rbxl` (do **not** start
   from the Baseplate template: its Baseplate and SpawnLocation would overlap the map).
   **Plugins** tab → **Rojo** → **Connect** (localhost:34872) to keep it live-synced while you edit.
   The Explorer shows `ReplicatedStorage > Forge` and `Workspace > ForgeMap`.

**B. CI artifact (no tools needed)**
1. GitHub → repository → **Actions** → latest **CI** run on `main` that has an artifact (runs for
   bookkeeping-only commits skip the Roblox job) → **Artifacts** → `forgeloop-main-<short sha>` →
   download and unzip.
2. Studio → **File** → **Open from File…** → `forgeloop-main-<short sha>.rbxl`.

Open **View → Output** (and **View → Command Bar** for S1/S3) before starting.

## S1 — require-by-string works in live Studio, including the cross-tree `@game` form
1. Press **Play** (F5). Wait 5 seconds.
2. In Output, find these lines (server and client, each with the same `sha=`):
   - `[Forge] info ForgeLoop server starting ... jobId=... sha=<sha>`
   - `[Forge] info map ready buildPlots=12 kingdoms=4 lobbySpawn=1 resourceNodes=16 rulerSpawns=4 version=0`
   - `[Forge] info ForgeLoop server services started count=0 order=(none) sha=<sha>`
   - `[Forge] info ForgeLoop client starting ... sha=<sha>`
   - `[Forge] info ForgeLoop client controllers started count=0 order=(none)`
   These come from `Main.server`/`Main.client`, which load Contracts only through
   `require("@game/ReplicatedStorage/Forge/...")`.
3. Press **Stop**. In the Command Bar run (exercises a relative require inside a ModuleScript —
   GameEvents requires `../Core/Signal` — and the Config mapping):
   ```lua
   print(require(game.ReplicatedStorage.Forge.Contracts.GameEvents).EVENT_NAMES[1], require(game.ReplicatedStorage.Forge.Config.Game).id)
   ```
   Expected output: `PlayerReady sandbox`.
   (`map ready` is checked in detail by S4.)

**Pass:** all five lines appear, the command prints `PlayerReady sandbox`, and Output shows no red
error mentioning `require`, `@game` or `Forge`. **Fail:** any require error — copy it verbatim.

## S2 — the BuildInfo sha is visible and logged
1. Explorer → **ReplicatedStorage → Forge → BuildInfo** (a ModuleScript) exists. Double-click it.
2. Its `sha` equals the commit you tested: `git rev-parse HEAD` (setup A) or the artifact name's
   short sha (setup B), and equals the `sha=` in the S1 Output lines.

**Pass:** both match. **Fail:** BuildInfo missing (setup A: rerun `stamp_build.sh` before
`rojo serve`) or the shas differ.

## S3 — services start in dependency order (Loader running in Roblox Luau)
With the game stopped, run in the Command Bar:
```lua
local Loader = require(game.ReplicatedStorage.Forge.Contracts.Loader) local log = {} local function def(n, d) return { name = n, dependencies = d, new = function() table.insert(log, "new " .. n) return { start = function() table.insert(log, "start " .. n) end } end } end local r = Loader.load({}, { def("Round", { "Data", "Player" }), def("Player", { "Data" }), def("Data") }) print(table.concat(r.order, " > ")) print(table.concat(log, ", ")) print(pcall(Loader.sort, { def("A", { "B" }), def("B", { "A" }) }))
```
Expected output, three lines:
```
Data > Player > Round
new Data, new Player, new Round, start Data, start Player, start Round
false Loader: dependency cycle: A -> B -> A
```
**Pass:** exactly this. Once real services exist, also check that the S1 line
`services started ... order=` lists them in dependency order.

## S4 — the AI Kingdoms map is in the live place, tagged, and readable (gates G6 + G5)
1. Press **Play** (F5). In Output, the server line
   `[Forge] info map ready buildPlots=12 kingdoms=4 lobbySpawn=1 resourceNodes=16 rulerSpawns=4 version=0`
   appears (a yellow `map problems ...` line instead is a FAIL — copy it).
2. Your character appears standing on the grey pad in the middle of the cobblestone plaza (it does
   not fall or spawn anywhere else).
3. Walk to each of the four roads. Each leads from a banner pole (red to the south, blue east, green
   north, gold west) to a walled kingdom with an open gate, a keep with coloured roof caps, a dais in
   front of the keep, three houses, a forest, a quarry, a farm with crop rows and three sandy build
   plots with corner posts. Grey rock piles with gold nuggets sit between the kingdoms.
4. Take two screenshots (**Win + Shift + S**): one from the plaza looking down a road at a kingdom
   gate, one from high above (press **Stop**, then in edit mode zoom out over the map).
5. With the game stopped, run in the Command Bar:
   ```lua
   local CS = game:GetService("CollectionService") for _, t in { "ForgeKingdom", "ForgeKeep", "ForgeRulerSpawn", "ForgeResourceNode", "ForgeBuildPlot" } do print(t, #CS:GetTagged(t)) end print(workspace.ForgeMap.Kingdom_East.Stockpile.Position, workspace.ForgeMap.Kingdom_East.Stockpile:GetAttribute("KingdomId"))
   ```
   Expected output, six lines: `ForgeKingdom 4`, `ForgeKeep 4`, `ForgeRulerSpawn 4`,
   `ForgeResourceNode 16`, `ForgeBuildPlot 12`, `220, 0.9, 26 East` (Studio may print the middle
   number as `0.899999976`; that is the same value).

**Pass:** the `map ready` line, lobby spawn, all four kingdoms as described, the Command Bar output
exactly as above. Attach both screenshots to the report: they are the visual evidence for the map
(gate G5; FORGE-05 reviews them and records the result). **Fail:** anything missing, floating,
sunk into the ground, or a part lying at the centre of the plaza that should be in a kingdom.

## M1 — two players on a local server (multiplayer smoke test)
1. **Test** tab → **Clients and Servers** section → set the player count to **2** → **Start**.
   Three windows open: one Server and two Clients (Player1, Player2).
2. In each window open **View → Output**:
   - Server: `ForgeLoop server starting ... sha=<sha>` and `map ready ... kingdoms=4 ...`.
   - Each client: `ForgeLoop client starting ... sha=<sha>` with the same sha.
3. In Player1's window, both characters stand on the plaza and Player1 sees Player2 move when you
   walk Player2 around in its window.
4. Back in the Server window, **Test** tab → **Cleanup** (closes all three).

**Pass:** all lines with one sha, both players visible to each other. More multiplayer tests (kingdom
assignment, villagers, resources, building) are added as those systems land:
`production/quality-gates/multiplayer-test-plan.md`.

## Report template (paste into the chat)
```
Studio run — date, setup A/B, BuildInfo sha: <sha>
S1: PASS/FAIL  (Output lines pasted below)
S2: PASS/FAIL
S3: PASS/FAIL  (Command Bar output pasted below)
S4: PASS/FAIL  (Command Bar output below; 2 screenshots attached)
M1: PASS/FAIL
<Output window text>
```

## Area test steps (written and owned by each worker; the files appear as their PRs land)
- Gameplay — `roblox/studio-tests/gameplay.md` (FORGE-01)
- Assets — `roblox/studio-tests/assets.md` (FORGE-02)
- UI & economy — `roblox/studio-tests/ui-economy.md` (FORGE-03)
- Experience — `roblox/studio-tests/experience.md` (FORGE-04)
