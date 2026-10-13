---
id: FL-0020
title: "UI foundation: builder, theme tokens, component library, responsive rules"
track: build
owner: forge-03
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0003]
estimate_h: 8
evidence:
  - check.sh OVERALL PASS on forge/03-ui-economy-fl0020 (Lune 306/0, game-001 specs 8/0, both builds + place checks)
  - "Specs: Components 7, Kit 3, UIThemeParity 3; mutations fail Kit (Format sign) and Parity (gold500 drift)"
  - "Screens reviewed: design/ui/REVIEW.md; prototype/kit-{phone,tablet,desktop}.png; luau/kit-1280x1400.png (real Luau render found and fixed the pill delta layout bug)"
  - "#24 e3a5e74; integration-log.md"
---

# UI foundation: builder, theme tokens, component library, responsive rules

## Outcome
A reusable, themeable UI kit that looks designed, not default: Create builder, Theme, components (Button, IconButton, Panel, Modal, Tabs, Grid, ItemCard with rarity frame, CurrencyPill, ProgressBar, Toast), safe-area aware scaling.

## Requirements
- interfaces.md section 9 (DisplayOrder bands, layout zones, touch targets)
- HTML/Playwright prototypes at phone (e.g. 844x390), tablet and desktop sizes reviewed visually before Luau implementation
- Component props documented in headers

## Validation
Prototype screenshots inspected; Lune specs for pure layout/format helpers; Studio screenshot checklist for the user

## Completion criteria
- [ ] design/ui/ prototypes + screenshots committed
- [ ] Components consumable by FORGE-04

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-03: READY → BUILDING. Design and Luau kit built on forge/03-ui-economy.
- 2026-10-12 forge-03: BUILDING → REVIEW. UI foundation: Create builder, Theme (+ per-game UITheme: game-001 medieval, sandbox neutral), Style, Icon (glyph fallback until icons are uploaded), Format, Motion, ToastStack; 10 components (Button, IconButton, Panel, Modal, Tabs, Grid, ItemCard, CurrencyPill, ProgressBar, Toast) with props in headers; design tokens, 34-icon set, HTML prototypes + component sheet at 3 sizes, Luau snapshot renderer (design/ui/render). No external framework.
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending, plus a tracked follow-up (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main. Follow-up: FL-0105 (Toast achievement accent; dark emblem on light tinctures).
