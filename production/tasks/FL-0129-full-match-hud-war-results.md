---
id: FL-0129
title: "Full-match UI: phase and timer bar, war and peace panel, spectate screen, Results with the leadership recap, wall placement UI"
track: build
owner: forge-03
status: BUILDING
priority: P0
game: game-001
created: 2026-10-18
updated: 2026-10-18
depends_on: [FL-0125]
evidence:
  - Lune economy/Diplomacy 9/0, KingdomUI 41/0; mutations FL-0129.py 20/20; renders hud-phase + kingdom-rivals(-confirm) desktop/phone-se looked at; not Studio-played
---

# Full-match UI: phase and timer bar, war and peace panel, spectate screen, Results with the leadership recap, wall placement UI

## Outcome
A ruler always knows the phase and time left, can declare war, propose and accept peace from a clear panel, sees what happens when their kingdom falls (spectate), and gets a Results screen with the leadership recap. Drawing walls and gates is as easy as placing a house.

## Context
- Owner directive 2026-10-18 section G; BRIEF §2 (Results with leadership recap); D-053. Server remotes come from FL-0125 (Match.Spectate, war/peace via existing Army/Diplomacy remotes; check `src/shared/Army/Remotes.luau` and `Sim/Diplomacy.luau`) and FL-0126 (Build.PlaceLine/PlaceGate).

## Requirements
- Phase/timer bar on the HUD (G3 phase + endsAt), with the next phase named; collapses on phone.
- War and peace panel: each rival kingdom with emblem, relation (peace/war/cooldown), score; buttons Declare war / Propose peace / Accept peace with the server's refusal codes mapped (FL-0105 style). Co-ruler permission rules follow the server.
- Spectate screen when eliminated: who eliminated you, a camera target list (FORGE-04 provides the camera), Leave/Stay.
- Results + `LeadershipRecap` controller: winner, standings, your reputation arc (six values, start vs end), key decisions and their effects, citizens lost/gained. Data from Match.Ended plus Reputation history.
- Wall tool in the build menu: click-drag a line with a live cost and validity tint, then a Gate button on a selected segment (consumes FL-0126).
- All of it on mouse, touch and gamepad; 667×375 phone fit.

## Validation
Automated UI specs (economy/ui folders). Studio: B20/B21 rows including phone emulator screenshots.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (owner's local Studio session).

## Log
- 2026-10-18 FORGE-00: created for Operation Crownfall (owner directive 2026-10-18, D-053).
- 2026-10-18 forge-03: READY → BUILDING. Started (Operation Crownfall, D-053): phase/timer bar first (Match.State on main), then the war & peace panel against a diplomacy contract proposed to FORGE-01 (no client remote or relation state on main yet)
- 2026-10-18 forge-03: BUILDING → BUILDING. FL-0129a in PR: phase bar (Match.State) + Rivals tab (war & peace) against a diplomacy contract proposed to FORGE-01 (handoff 2026-10-18-forge-03-to-forge-01-diplomacy-remote); Rivals dormant until the server serves Kingdom.Diplomacy. Next: FL-0129b after FL-0125, FL-0129c after FL-0126
