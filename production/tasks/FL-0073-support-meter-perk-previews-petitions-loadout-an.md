---
id: FL-0073
title: Support meter, perk previews, petitions, loadout and perk picker, arena intro and HUD, leadership recap
track: build
owner: forge-03
status: READY
priority: P2
game: game-001
created: 2026-10-12
updated: 2026-10-18
depends_on: [FL-0070]
context: [games/game-001/design/crown-arena.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 18
evidence: []
---

# Support meter, perk previews, petitions, loadout and perk picker, arena intro and HUD, leadership recap

## Outcome
Players always know where they stand: a support meter with a readable breakdown, citizen cards that preview loyalty perks and petitions, a loadout and perk picker before the duel, a two-sided arena intro card, a duel HUD, and a leadership recap at Results (design §4, §7, §8).

## Context
D-029; design §4, §7, §8; CONTRACTS G12.1 (`SupportView`, `TriggerOffer`, `ArenaState`), G12.4 remotes, G12.6 `DuelController`. **VS-1 UI tasks come first.** Prototype in HTML in slack time against the G12 shapes; wire after FL-0070/FL-0071.

## Requirements
- Controllers (team.md): `SupportMeter*`, `PerkPicker*`, `Loadout*`, `ArenaIntro*`, `ArenaHud*`, `LeadershipRecap*`, `Petition*`.
- Support meter: tier name and colour, score, trend arrow; tap → breakdown per component with the latest moments. Tier always shown as text plus colour.
- Citizen card additions: loyalty bar, role, perk preview ("At 80 loyalty, Bram will reinforce your armour in the arena"), open petition with a Fulfil button (`Kingdom.FulfilPetition`).
- Loadout and perk picker (20 s): weapons, armour, offers with citizen name, loyalty, effect and trigger condition; slots limited by tier; Crowd Rally shown for Adoring.
- Arena intro card: both champions, tiers, top three reasons, chosen triggers with portraits. Arena HUD: HP, stamina, trigger icons (armed, fired), opponent's triggers visible.
- Leadership recap at Results: five biggest moments, triggers fired, crowd outcome.
- Phone layout first; touch targets ≥ 44 px.

## Validation
HTML prototypes reviewed at 844x390 and 1920x1080 (screenshots in `games/game-001/design/ui/`). Lune specs for formatting and slot logic. Studio: run the arena with debug presets and capture each screen.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots or video) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for the Crown Arena (D-029, VS-2) (READY).
- 2026-10-13 forge-00: READY → SPECIFIED. FORGE-00 reconciliation 2026-10-13 (stale-status sweep): its dependencies are not built yet (FL-0018 economy core, or the Crown Arena FL-0070/FL-0071), so it is SPECIFIED, not READY.
- 2026-10-18 forge-00: SPECIFIED → READY. Operation Crownfall (D-053): arena work starts now; FORGE-01 order FL-0125 → FL-0069 → FL-0070 → FL-0071; defaults from crown-arena.md §11 apply
