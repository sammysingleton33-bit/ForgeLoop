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
`node design/ui/shoot.js` → `design/ui/screenshots/prototype/<scene>-<device>.png`, devices phone
844×390 (notch insets 47/47/21 + 58 px Roblox top bar), tablet 1024×768, desktop 1920×1080.
`*-guides-*` variants draw the emulated notch and top-bar bands.

| Scene | What it shows |
|---|---|
| `hud` | resting HUD: crest + name plate, 4 resource pills + citizens, top-bar timer, rail, construction chip |
| `build` | Construction drawer, Economy tab (phone: list pane) |
| `build-detail` | Quarry selected, affordable: costs with have ✓, Build CTA |
| `build-short` | Quarry with 30 Wood: red row "have 30", CTA "Need 20 more Wood" |
| `build-locked` | Gold Mine: "Requires Town Hall Lv 2", lock icon |
| `built` | after Build: deltas under pills, green "Construction started", "Paid …", progress, toast, queue chip |
| `kingdom` | Kingdom → Overview: citizens by job, production and storage per resource |
| `kingdom-buildings` | building list: progress, worker steppers, Upgrade |
| `upgrade` | Town Hall upgrade detail (the upgrade menu reuses the detail pane) |
| `kit` | all 10 components × states (default, pressed, disabled, loading, empty, error, owned) |

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
7. After a successful build, the cost rows turned red (the money was just spent) → the success state
   shows what was paid and the progress instead.
8. Touch targets: rail 48 px (phone) / 58 px, CTAs and tabs ≥ 44 px tall where tapped with a thumb;
   steppers are 32 px (sized for desktop/tablet first — see open issues).

## Open issues
- Steppers (+/−) are 32 px: below the 44 px phone target. Proposal: 40 px hit area on phones.
- All cosmetic banners share one icon; distinct art comes with the shop/inventory work (FL-0021).
- Emoji fallbacks are used in Luau until the icons are uploaded (user handoff).
- The prototype's stylised kingdom backdrop is a stand-in for the game camera view.
- Luau snapshot screenshots of the real Luau UI: see the next section.

## Luau UI snapshots
Pending: rendered from the actual Luau instance trees (`design/ui/render/`), listed here once
generated and reviewed.
