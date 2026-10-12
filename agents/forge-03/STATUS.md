# FORGE-03 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/03-ui-economy` (cloud session, 2026-10-12) |
| Open PR | draft PRs listed in "Last report" once opened (D-016: drafts until FL-0003 merges) |
| Current task | AI Kingdoms first playable UI (user directive; task to be created by FORGE-00) on FL-0018 + FL-0020 |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS at `f8d621b`: 349 Lune specs, Selene 0/0, StyLua 120 files, Rojo build, place check |
| Blockers | none on my side; Studio checks (G6) need the user; live gameplay needs FORGE-01's kingdom API |
| Needs from others | FORGE-01: confirm the kingdom API (`production/handoffs/2026-10-12-forge-03-to-forge-01-kingdom-api.md`) and land RemoteService / Core/RemoteClient / Validate. FORGE-00: record Game #1 = AI Kingdoms, create tasks and `games/game-001` (`…-to-forge-00-ai-kingdoms.md`). User: upload icons (`…-to-user-ui-icons.md`). FORGE-04: NotificationController (toasts fall back to UI/ToastStack). |

## Last report
- **Done:** AI Kingdoms economy config; FL-0018 economy core (Bundle, Wallet, Currencies,
  Construction, ItemRegistry, Inventory, RewardTables with honest odds and pity);
  EconomyTreasuryService (in-match kingdom ledgers, Economy remotes); FL-0020 design (tokens, icons,
  HTML prototypes at 3 sizes, component sheet) and Luau kit (Create, Theme, Layout, Format, Motion,
  10 components); kingdom HUD, construction drawer, kingdom panel and UIController wired end to end
  through FORGE-01 doubles.
- **Verified:** check.sh green; an 11-case end-to-end UI spec drives real taps; five mutations of key
  rules (wallet idempotency, exactly-once events, builder limit, menu verdict, controller guard)
  each fail a spec; prototype screenshots reviewed (`design/ui/REVIEW.md`).
- **Unverified:** anything in Roblox Studio (G6, `roblox/studio-tests/ui-economy.md`); real FORGE-01
  services (doubles only); icons (glyph fallbacks until uploaded).
- **Next:** stacked draft PRs; FL-0045 rest (EconomyService profile wallets, InventoryService,
  RewardService, ShopService), FL-0019 PurchaseService, army/territory/standings screens after
  FORGE-01's APIs.

## Doubles in use (swap when the real modules merge)
- `roblox/tests/unit/economy/doubles/RemoteDoubles.luau`: RemoteService, Core/RemoteClient, Validate
- `roblox/tests/unit/economy/doubles/KingdomDoubles.luau`: KingdomService, KingdomController, Gameplay kingdom remotes
- UIController reaches RemoteClient via `env.sharedModules("RemoteClient").Core` until a static require is possible.
