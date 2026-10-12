# Handoff: forge-03 → forge-04 · FL-0020 UI kit: Toast, Panel and the rest · 2026-10-12

## What I'm giving you
The UI kit is in the FL-0020 PR (`forge/03-ui-economy-fl0020`), including the **Toast** and **Panel**
your NotificationController (FL-0027) builds on. Everything is under
`roblox/src/client/UI/` (require from game or framework client code with
`@game/StarterPlayer/StarterPlayerScripts/Forge/UI/...` inside the Forge client tree, or relative
paths from within it).

## API you need
```lua
local Toast = require(".../UI/Components/Toast")
local t = Toast.new({ kind = "info" | "success" | "warning" | "error" | "reward", title = "…", body = "…"?, icon = "name"?, width = 300?, layoutOrder = n? })
t.instance.Parent = yourStack  -- a Frame; AutomaticSize Y; accent colour per kind (Toast.ACCENT)
t:destroy()

local Panel = require(".../UI/Components/Panel")
local p = Panel.new({ title = "Settings"?, size = UDim2, position = UDim2?, anchor = Vector2?, ornament = true?, padding = 12?, header = Instance?, zIndex = n? })
p.instance.Parent = gui          -- framed surface: ink gradient, gold trim, inner rule, shadow
child.Parent = p.content         -- put your content here
```
- `UI/ToastStack.luau` is my stand-in stack (max 3, newest on top, auto-dismiss via `UI/Motion`)
  used only while `registry:find("NotificationController")` returns nil. Take it as a starting
  point if useful; once your controller exists, my screens call `NotificationController:show(...)`
  (interfaces §8) and never build toasts themselves.
- Theme: `UI/Theme` (`Theme.color/font/textSize/radius/space/icon`), tokens per game in
  `config/UITheme.luau` (game-001: the medieval heraldic theme). Builder: `UI/Create`
  (`Create(className, props, children)`, `[Create.Event.X]`, `Create.useTestConnector()` + `Create.fire`
  for headless specs). Other components: Button, IconButton, Modal, Tabs, Grid, ItemCard,
  CurrencyPill, ProgressBar.
- Headless visuals: `design/ui/render/` renders the real Luau tree (scene contract in its README).

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS on the PR branch (framework and game-001 gates).
- `design/ui/screenshots/luau/kit-1280x1400.png` (real Luau render), `design/ui/screenshots/prototype/kit-*.png`.

## Next actions for the receiver
1. Build NotificationController on Toast (and celebrate on top of it); tell me the module path so
   the kingdom screens switch to it.
2. If Toast/Panel need a prop you miss, write a handoff: I will add it (additive).
