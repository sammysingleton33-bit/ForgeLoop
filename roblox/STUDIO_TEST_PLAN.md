# Studio test plan (gate G6)

Headless checks (`bash roblox/scripts/check.sh`) cannot run Roblox Studio. These steps are run by the
user on Windows against the **integrated build (`main`)**. Paste the Output text and the BuildInfo sha
into the chat; FORGE-05 records them in `production/quality-gates/studio-runs.md`. S1–S3 take under
10 minutes.

## Setup (pick one)

**A. Live sync with Rojo (recommended for repeat runs)**
1. Install Rokit once: https://github.com/rojo-rbx/rokit (Windows installer or `rokit.exe self-install`).
2. In Git Bash, in the repository folder:
   ```bash
   git checkout main && git pull
   rokit install                      # Rojo 7.7.1, Selene, StyLua, Lune from rokit.toml
   bash roblox/scripts/stamp_build.sh # writes BuildInfo.json with the current sha
   rojo plugin install                # installs the matching Rojo Studio plugin (once per Rojo version)
   rojo serve roblox/default.project.json
   ```
3. Roblox Studio → **New** → **Baseplate**. **Plugins** tab → **Rojo** → **Connect** (localhost:34872).
   The Explorer now shows `ReplicatedStorage > Forge`.

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

**Pass:** all four lines appear, the command prints `PlayerReady sandbox`, and Output shows no red
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

## Report template (paste into the chat)
```
Studio run — date, setup A/B, BuildInfo sha: <sha>
S1: PASS/FAIL  (Output lines pasted below)
S2: PASS/FAIL
S3: PASS/FAIL  (Command Bar output pasted below)
<Output window text>
```

## Area test steps (written and owned by each worker; the files appear as their PRs land)
- Gameplay — `roblox/studio-tests/gameplay.md` (FORGE-01)
- Assets — `roblox/studio-tests/assets.md` (FORGE-02)
- UI & economy — `roblox/studio-tests/ui-economy.md` (FORGE-03)
- Experience — `roblox/studio-tests/experience.md` (FORGE-04)
