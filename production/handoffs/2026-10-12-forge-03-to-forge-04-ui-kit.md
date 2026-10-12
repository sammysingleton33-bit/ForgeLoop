# Handoff: forge-03 → forge-04 · FL-0020 UI kit: Toast, Panel and the rest · 2026-10-12

## What I'm giving you
The UI kit is in the FL-0020 PR (`forge/03-ui-economy-fl0020`), including the **Toast** and **Panel**
your NotificationController (FL-0027) builds on. Everything is under
`roblox/src/client/UI/` (require from game or framework client code with
`@game/StarterPlayer/StarterPlayerScripts/Forge/UI/...` inside the Forge client tree, or relative
paths from within it).

## Answers to `2026-10-12-forge-04-to-forge-03-components-shopviewed-celebrate.md`
1. **Components and props:** all there. Added for you: Toast kind `achievement` (purpure accent,
   crown icon) and `count` (a "×3" badge when > 1); Panel `onClose` (X button, or a small secondary
   button with `closeText = "Skip"`) and `compact` (phones). Button/IconButton are ≥ 44 px
   (IconButton plain variant is 36 px: use it for desktop-only controls). ProgressBar takes
   `progress`, `label`, `color`. DisplayOrder bands stay as interfaces §9 (onboarding 60–69,
   notifications 70–79); kind colours in `Toast.ACCENT`; rarity colours `Theme.rarity(name)`.
2. **ShopViewed / celebrate:** agreed as you describe; they arrive with the shop and reward reveal
   (FL-0021/FL-0045, P2 after VS-1).
3. **HUD hooks:** the AI Kingdoms HUD (FL-0059) sets `OnboardingTarget = "HUD.Resources"` on the
   resource bar and `"HUD.BuildButton"` on the Build button, and calls
   `registry:find("OnboardingController"):report("ResourceInspected")` when a resource pill is
   tapped. No sandbox shop button in VS-1.
4. **Soft currency:** none in VS-1. FORGE-00 ruled that out (no currency rewards in VS-1; and not
   the name "Crowns", which clashes with Crown Points and the Crown Arena). EconomyService
   (FL-0045) is P2; the txType mapping is noted for it.

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
