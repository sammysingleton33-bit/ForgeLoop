---
id: FL-0138
title: "How to play panel and launch UI pass: the full match in short cards, desktop sizes, onboarding targets"
track: build
owner: forge-03
status: READY
priority: P1
game: game-001
created: 2026-10-19
updated: 2026-10-19
depends_on: [FL-0129]
evidence: []
---

# How to play panel and launch UI pass: the full match in short cards, desktop sizes, onboarding targets

## Outcome
A new player can open **How to play** from the Kingdom menu at any time, and read the whole D-053 match in six short cards with one picture each. On desktop (1280×720, 1920×1080, 2560×1440) and on a 667×375 phone, every core panel fits and works, including the new arena and support screens. FORGE-04's tips can point at the Kingdom menu and Raid buttons.

## Context
- The owner's launch-ready definition (Crownfall handoff §7): "A new player can understand how to play" and "Critical UI works on supported desktop and mobile devices".
- D-053 (full match), D-054 (war and peace), D-056, G12 (Crown Arena), FL-0137 (FORGE-04's in-match tips, which complement this panel; there is no duplicate text between them), and `tools/phone-audit.py` (FORGE-03, #215).

## Requirements
- **How to play** (Kingdom menu, and one link from the Lobby or waiting screen). Six cards:
  1. The match: phases and the timer, read from config `Pacing` so the lengths stay true.
  2. Crown Points: how you earn them, and that they decide the arena pair.
  3. Build and citizens: jobs, food, happiness, reputation.
  4. War, peace and sieges: senior ruler, newcomer lock, rams, defending your keep.
  5. The Crown Arena: the top 2 qualify, co-rulers vote, champion loadout and perks, and support from your citizens with its fairness caps in plain words (no pay-to-win).
  6. Falling and spectating.
  Each card is plain words, under 60 words, with no ally or betrayal wording (VS-3). It is phone-fit, and Back and Next both work by touch and by keyboard.
- **Desktop pass:** extend `phone-audit.py` (or add a sibling) to 1280×720, 1920×1080 and 2560×1440. Fix any clipping or overlap in the HUD, drawer, Rivals, spectate, Results, the arena loadout, intro, HUD, support meter, citizen card and petitions.
- **Onboarding targets:** an `OnboardingTarget` attribute on the Kingdom menu button and the Raid rail button, for FL-0137 (FORGE-04 asks by handoff).
- Keep to your own paths. No monetization surfaces (D-053: none until an RC is approved).

## Validation
- Automated: specs for the card model (text length, config-driven phase lengths, navigation), the desktop and phone audits at 0 problems, and mutations.
- Interactive (owner, Studio): open How to play on desktop and in the 667×375 emulator and screenshot each card. These rows are added to ui-economy.md and stay unverified until they are run.

## Completion criteria
- [ ] How to play panel with six cards, config-driven, phone-fit
- [ ] Desktop audit at three sizes, 0 problems, across the core panels
- [ ] OnboardingTarget attributes for FL-0137
- [ ] FORGE-07 review READY; Studio rows written

## Log
- 2026-10-19 FORGE-00: created (Crownfall P3/P4, launch-ready §7 "understand how to play" and "critical UI on desktop and mobile"). FORGE-03 picks it up after FL-0073 (#225, #227, #229); FL-0129c (wall tool) follows FL-0126 part 2.
- 2026-10-19 forge-00: SPECIFIED → READY. FORGE-00: ready for FORGE-03 after FL-0073
