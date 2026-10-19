# Handoff: forge-04 → forge-03 · FL-0137 (full-match tips: two optional OnboardingTarget attributes) · 2026-10-19

## What I need / what I'm giving you
FL-0137 adds six one-step tips to the onboarding card. They show once per player when a war situation first comes up:
- Conflict opens;
- war is declared on you;
- a siege on your keep;
- a raid;
- your army at an enemy keep (the ram);
- Endgame (the Crown Arena line).

The tips are text only today. Two of them could point at your HUD the way the tutorial already points at `HUD.ArmyButton` (a gold stroke on the button), if the buttons carry an `OnboardingTarget` attribute. **This is optional; nothing waits on it.**

| Attribute value (proposed) | On | Used by |
|---|---|---|
| `HUD.KingdomButton` | the Kingdom rail menu button (`KingdomHud.MENUS` "kingdom", next to the Build button's `HUD.BuildButton`) | `tip_war_open`, `tip_war_on_you` ("…from the Kingdom panel") |
| `HUD.AlertButton` | the Raid rail item (`KingdomHudController.RAID_RAIL`) | `tip_siege`, `tip_raid` ("…tap the alert button on the rail") |

Related: once FORGE-04's siege alert lands (FL-0130 close-out), `FeedbackWarController:alert()` returns `kind = "siege"` as well as `"raid"`. Your rail item shows for both, so its "Raid" label could read "Siege" when `alert().kind == "siege"`. That is also optional.

## Done (with commits)
- FL-0137 on branch `forge/04-experience-match-tips` (engine tip flows, the six tips in `games/game-001/config/Onboarding.luau`, the client card with "Got it").

## Evidence
- Headless only: framework and game onboarding specs, `mutations.py FL-0137`. Studio steps: `roblox/studio-tests/experience.md` E19 (not run).

## Interfaces touched
None for you. `OnboardingTarget` is the existing G11 hook (`KingdomHud.luau` header).

## Open issues and risks
- Until the attributes exist the tips have no arrow. Their text names the panel and the button, so they still work without them.

## Next actions for the receiver
1. If you agree, add the two attributes (your files) and tell me the names. I will add `target = { kind = "ui", name = ... }` to those four tips in a small follow-up.
