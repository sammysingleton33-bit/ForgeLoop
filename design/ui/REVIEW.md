# AI Kingdoms UI — design review note (FORGE-03, FL-0020, gate G5)

Reviewed by FORGE-03 on 2026-10-12 by opening every screenshot listed here. This is a self-review;
a fresh-eyes review by the user or FORGE-00 is still wanted (the visual gate is not self-certified).

## Direction
"Heraldic ledger": dark ink panels with gold trim, a faint inner rule and a hard drop shadow; the
heraldic tinctures as the palette (Or, Azure, Gules, Vert, Purpure); a blackletter display face
(Grenze Gotisch) only for titles, Merriweather for names, Montserrat for numbers and body text —
all three are Roblox font families. Every effect is one Roblox can draw: linear UIGradient,
UICorner, UIStroke, offset shadow frames, rotation (the gold diamond ornament). Icons are an
original 34-icon set (`design/ui/icons.js`, `icons/`, `icons/png/`, sheet:
`screenshots/icons-sheet.png`).

Tokens: `design/ui/tokens.json` → `prototype/tokens.css` (generated) and
`games/sandbox/config/UITheme.luau` (Luau; same values).

## Screens and sizes (HTML prototypes, Playwright)
`node design/ui/shoot.js` → `screenshots/prototype/kit-{phone,tablet,desktop}.png`: all 10
components × states (default, pressed, disabled, loading, empty, error, owned) on phone 844×390
(notch insets 47/47/21 + 58 px Roblox top bar), tablet 1024×768 and desktop 1920×1080.

Game screens live with their game: the AI Kingdoms HUD, build menu and Kingdom panel are
prototyped against CONTRACTS G8 in `games/game-001/design/ui/` (FL-0059). An earlier kingdom-screen
prototype here (pre-contract: Town Hall, worker steppers, storage caps) was reviewed and then
removed when the contracts replaced its data model; the layout lessons it taught carried over:

## What I checked, and what changed because of it
1. Phone two-pane drawer clipped the Build button → phone uses one pane (list → detail → back) with
   the CTA pinned below a scrolling body.
2. Desktop drawer was stretched with empty space → drawer height capped (tablet 470, desktop 480).
3. Kingdom subtitle unreadable over the sky → name plate behind name and subtitle.
4. Cap bar under each pill collided with the rate text → removed; "amount / cap" text and an amber
   border at cap instead.
5. Floating deltas overlapped the Roblox top-bar buttons on phones → deltas float under the pills.
6. Toast and queue chips overlapped the open drawer on phones → both now centre in the area the
   drawer leaves free; phone toasts sit below the pills.
7. Touch targets: rail 48 px (phone) / 58 px, CTAs and tabs ≥ 44 px tall where tapped with a thumb.

Screenshots are committed palette-compressed (`python3 design/ui/compress-shots.py <png…>`, 256
colours, no dithering) to keep the repository light (D-007).

## Open issues
- All cosmetic banners share one icon; distinct art comes with the shop/inventory work (FL-0021).
- Emoji fallbacks are used in Luau until the icons are uploaded (user handoff).
- The prototype's stylised kingdom backdrop is a stand-in for the game camera view.
- Luau snapshot screenshots of the real Luau UI: see the next section.

## Luau UI snapshots (the real kit, not the prototype)
`design/ui/render/` runs the actual Luau modules under Lune and draws the instance tree they build
with a Roblox-layout emulation (approximation; deviations listed in `design/ui/render/README.md`).
- `screenshots/luau/kit-1280x1400.png` — every component and state from `roblox/src/shared/UI`,
  game-001 theme (`PROJECT=games/game-001/default.project.json DEVICES=1280x1400 bash
  design/ui/render/shoot-luau.sh kit`). Matches the prototype sheet (`kit-*.png`): colours, fonts,
  trims, badges, rarity frames, toasts, panel ornament, modal.
- `screenshots/luau/selftest-{phone,tablet,desktop}.png` — the renderer's own self-test.
- **Found by this render and fixed:** the spend delta of a CurrencyPill was laid out inside the pill
  by its UIListLayout instead of floating under it (the pill now keeps its content in a `Row`).
- Glyph fallbacks (emoji) show where uploaded icons will go.
