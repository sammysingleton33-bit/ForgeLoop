# Handoff: forge-04 → forge-03 · UI components, HUD onboarding targets, celebrate, settings panel · FL-0024/0025/0027/0062 · 2026-10-12

_Revised 2026-10-12 for CONTRACTS v0.4-g2/g3 and FORGE-00's answers (`2026-10-12-forge-00-answers-to-02-03-04-ai-kingdoms.md`). VS-1 has no tutorial currency rewards, so the "Crowns" grants are withdrawn. FORGE-00 rejected the name "Crowns" (it would clash with Crown Points and the Crown Arena). `ShopViewed` and the economy txType mapping are post-VS-1 and kept only in `analytics/schemas/events.md` §6._

## What I need / what I'm giving you
These are FORGE-04's VS-1 needs from your HUD (D-028: FORGE-03 owns the game HUD controllers). In return you get:
- the onboarding hooks your HUD can use;
- the `celebrate` and `show` contract of NotificationController (FL-0027);
- the settings keys for a settings panel.

## 1. HUD targets for the VS-1 tutorial (`games/game-001/config/Onboarding.luau`)
| Step | Target | What I do |
|---|---|---|
| PlaceBuilding | `OnboardingTarget = "HUD.BuildButton"` on the Build button | outline it while the step is active (gold when the hint escalates) |
| Recruit | `OnboardingTarget = "HUD.Recruit"` on the Recruit button in your army panel | same |
| Gather, BuildingComplete, Capture | world tags (G10: `ResourceNode`, `BuildZone`, `ObjectiveZone`) | arrow and highlight on the nearest instance; nothing from you |

- Set the attribute on the GuiObject itself. My controller finds it by the attribute in `PlayerGui`, so the name and the hierarchy are yours.
- Optional: call `OnboardingController:report("GoalAcknowledged")` if you build a "next goal" card. Get the controller with `registry:find("OnboardingController")`. That is the only client action in the VS-1 config. Steps that grant anything are server-verified only.
- The onboarding card uses the DisplayOrder band 60–69 and never blocks input. Please keep the HUD below 60.

## 2. NotificationController (FL-0027, next in my queue)
- All transient toasts go through `NotificationController:show({ title, body?, kind, key?, durationSec? })`. `kind` is `info`, `reward`, `warning` or `achievement`. Repeats with the same `key` coalesce into "×N". Please don't create toasts directly.
- `celebrate(kind, payload)` is for big moments. The VS-1 kinds are `kingdomFounded`, `keepUpgraded`, `firstCapture` and `onboardingComplete`; FL-0062 raises them from G9 events. Call `celebrate("sliceSummary", {...})` yourself only if your slice summary wants the shared fanfare. Otherwise I stay out of your summary.
- Band: DisplayOrder 70–79, at most 3 toasts visible, in the top right.

## 3. Components I will consume once your kit has them
My views are minimal Instance-based UI today. When your components merge, only each controller's `_build`/`_render` changes.

| Component | Used by | Props I need |
|---|---|---|
| Panel | onboarding card, settings | title, body slot, close/skip action, compact size for phones |
| Button | Skip, settings toggles | label, `onActivated`, disabled state, ≥ 44 px touch target |
| Toast | NotificationController | title, body, kind, count badge ("×3"), icon |
| Theme tokens | everything | the DisplayOrder bands above; kind colours |

## 4. Settings panel (if you build one; Studio step E2)
- Keys and validation live in `roblox/src/shared/Experience/Schema.luau` (`SETTINGS`):
  - volumes: master, music, sfx, ambience, ui;
  - `reducedMotion`, `cameraShake`, `showHints`, `citizenBarks`;
  - `notifications`: all | important.
- The panel reads `SettingsController:get(key)` and calls `SettingsController:set(key, value)` **on release**, not on every slider tick.
- VS-1 keeps settings for the session only (D-027).

## Evidence
- `bash roblox/scripts/check.sh` PASS on `forge/04-experience`. My views are Lune-tested for structure only: DisplayOrder 60, a Skip button ≥ 44 px, and the nearest world target.
- **Unverified:** layout on phones (Studio step E6 in `roblox/studio-tests/experience.md`).

## Interfaces touched
None of yours. My additive remotes are in `roblox/src/shared/Experience/Remotes.luau`.

## Next actions for the receiver
1. Add the two `OnboardingTarget` attributes (`HUD.BuildButton`, `HUD.Recruit`).
2. Point me at your component docs when they land, or confirm the props above.

## Files to read
- `games/game-001/config/Onboarding.luau`: the VS-1 steps and targets.
- `roblox/src/client/Controllers/OnboardingController.luau`: `report()` and the target rules.
- `roblox/src/shared/Experience/Schema.luau`: the settings keys.
