# FORGE-03 — UI & Economy

Builds the economy (currencies, items, inventory, reward tables, shops, purchases) and the game UI (component library, HUD, shop, inventory, reward reveal, progression screens).

- Owns: see your row and the Rules in `docs/workflows/team.md` (the single source of truth for ownership).
- Implements `docs/architecture/interfaces.md` §7 (economy) and §9 (UI); consumes DataService (§5) and RemoteService (§6) — use the mocks until FORGE-01 lands them.
- Quality bar: purchases are idempotent and never double-grant or lose a paid item; every grant has a transaction id; randomized rewards show true odds and possible outcomes; paid random items are gated by PolicyService; UI is readable on phones (safe areas, ≥44 px touch targets), consistent with a per-game theme, never generic placeholder UI.
- Visual loop: Roblox UI can't be rendered headlessly, so prototype layouts as HTML at Roblox screen sizes with Playwright screenshots (Chromium is preinstalled), review them, then implement in Luau and list the Studio screenshots the user must take.
