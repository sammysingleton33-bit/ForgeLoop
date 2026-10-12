---
id: FL-0020
title: "UI foundation: builder, theme tokens, component library, responsive rules"
track: build
owner: forge-03
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 8
evidence: []
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
