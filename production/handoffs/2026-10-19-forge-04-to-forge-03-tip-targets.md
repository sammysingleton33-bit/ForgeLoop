# Handoff: forge-04 → forge-03 · FL-0137 (full-match tips: two optional OnboardingTarget attributes) · 2026-10-19

## What I need / what I'm giving you
FL-0137 adds six one-step tips to the onboarding card. They show once per player when a war situation first comes up:
- Conflict opens;
- war is declared on you;
- a siege on your keep;
- a raid;
- your army at an enemy keep (the ram);
- Endgame (the Crown Arena line).

Four of the tips point at your HUD the way the tutorial already points at `HUD.ArmyButton` (a gold stroke on the button), through these `OnboardingTarget` attributes. **FORGE-03 has added both in #232 (FL-0138), with these names; the tips use them.** Until #232 is on main the tips show without a mark.

| Attribute value | On | Used by |
|---|---|---|
| `HUD.KingdomButton` | the Kingdom rail menu button (`KingdomHud.MENUS` "kingdom") | `tip_war_open`, `tip_war_on_you` ("…from the Kingdom panel") |
| `HUD.RaidButton` | the Raid / alert rail item (`KingdomHudController.RAID_RAIL`), shown for any alert | `tip_siege`, `tip_raid` ("…tap the marked button") |

Related: once FORGE-04's siege alert lands (#235), `FeedbackWarController:alert()` returns `kind = "siege"` as well as `"raid"`. Your rail item shows for both; FORGE-03 plans to label it "Siege" when `alert().kind == "siege"` (a follow-up after #232). The siege tip says "the marked button", so it reads right either way.

## Done (with commits)
- FL-0137 on branch `forge/04-experience-match-tips` (engine tip flows, the six tips in `games/game-001/config/Onboarding.luau`, the client card with "Got it").

## Evidence
- Headless only: framework and game onboarding specs, `mutations.py FL-0137`. Studio steps: `roblox/studio-tests/experience.md` E19 (not run).

## Interfaces touched
None for you. `OnboardingTarget` is the existing G11 hook (`KingdomHud.luau` header).

## Open issues and risks
- Until #232 is on main the tips have no mark. Their text names the panel and the button, so they still work without it.

## Next actions for the receiver
1. Done in #232 (FORGE-03, 2026-10-19). Nothing else; keep the two names stable, since the tips depend on them.
