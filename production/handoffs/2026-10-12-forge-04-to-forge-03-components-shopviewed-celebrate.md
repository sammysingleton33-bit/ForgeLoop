# Handoff: forge-04 → forge-03 · UI components, ShopViewed, celebrate, HUD hooks, txType · FL-0023..0027 · 2026-10-12

## What I need / what I'm giving you
These are FORGE-04's day-one needs from your UI kit and economy services. In return you get:
- the analytics `txType` mapping for EconomyService;
- the `celebrate` API contract;
- the onboarding hooks your HUD can call.
Game #1 is AI Kingdoms (user directive, 2026-10-12).

## 1. Components I will consume (interfaces §9)
My controllers draw minimal Instance-based views today and switch to your components once they merge, changing only each controller's `_render`/`_build`.

| Component | Used by | Props I need |
|---|---|---|
| Panel | onboarding card, daily-reward claim panel, quest list, settings | title, body slot, close/skip action, compact size for phones |
| Button / IconButton | Skip, Claim, settings toggles | label, icon, `onActivated`, disabled state, ≥ 44 px touch target |
| Toast | NotificationController (FL-0027) | title, body, kind (`info` / `reward` / `warning` / `achievement`), count badge ("×3"), icon |
| ProgressBar | quests, streak track, onboarding progress | value 0..1, label, colour from Theme |
| Modal | settings screen | — |
| Theme tokens | everything | the onboarding (60–69) and notifications (70–79) DisplayOrder bands; kind colours; reward tier colours (common…legendary) |

## 2. `ShopViewed` (interfaces §4)
Fire `GameEvents.ShopViewed(player, shopId, itemId?)` **once per shop open** (and once per item detail view, with `itemId`). My adapter starts a new funnel session (GUID) on every `ShopViewed` and continues it with `PurchaseCompleted` within 900 s. A purchase without an open session is never counted as a conversion. Spec: `AnalyticsService.spec.luau` "gives each shop open its own session id".

## 3. `NotificationController:celebrate(kind, payload)` (interfaces §8; built in FL-0027)
- Call it at the **end** of your reward reveal: `celebrate("reward", { rarity, itemId, qty })`.
- I never react to `RewardRolled` on my own, so there is no double celebration.
- Other kinds I raise myself: `kingdomTier`, `onboardingComplete`, `achievement`, `dailyStreak`, `victory`.
- All transient toasts go through `NotificationController:show({ title, body?, kind, durationSec? })`. Please don't create toasts directly.

## 4. HUD hooks for onboarding (AI Kingdoms)
- Set the attribute `OnboardingTarget = "HUD.Resources"` on the resource bar and `OnboardingTarget = "HUD.BuildButton"` on the Build button, and `"HUD.Shop"` on the sandbox shop button. My controller outlines that GuiObject while its step is active.
- Call `OnboardingController:report("ResourceInspected")` when the player taps a resource counter. Call `report("GoalAcknowledged")` when they dismiss the "next goal" card, if you build it as a component (otherwise my card auto-advances).
- Get the controller from your client registry: `registry:find("OnboardingController")`.

## 5. Economy (FL-0045)
- **Currency for tutorial rewards:** `Crowns` (assumed name, please confirm or rename). Onboarding grants 25 at the first harvest and 50 at completion via `EconomyService:grant(player, "Crowns", amount, "onboarding:<flow>:<step>:<userId>", "Onboarding")`. It must be idempotent per txId (§7).
- **Analytics:** EconomyService is the only caller of `AnalyticsService:economy` (§7/§8). The `txType` mapping is in `analytics/schemas/events.md` §6:
  - `IAP` (Robux to currency, source);
  - `Shop` (buy = sink, sell = source);
  - `Gameplay` (match/quest/achievement rewards = source; gameplay spend = sink);
  - `TimedReward` (daily, source);
  - `Onboarding` (tutorial, source);
  - `ContextualPurchase` (speed-ups and revives, sink).
  Budget: ≤ 5 currencies (creator-docs AS "Limited to 5 unique currency types"), ≤ 20 transaction types, ≤ 100 SKUs. In-match resources (Food, Wood, Stone, Gold) are **not** economy events.
- `CurrencyChanged` drives my FirstReward funnel (step 2, delta > 0). Fire it exactly once per successful grant (§4 rule).

## 6. Settings screen
Settings keys and validation: `roblox/src/shared/Experience/Schema.luau` (`SETTINGS`):
- volumes: master, music, sfx, ambience, ui;
- `reducedMotion`, `cameraShake`, `showHints`, `citizenBarks`;
- `notifications`: all | important.
The panel reads `SettingsController:get(key)` and calls `SettingsController:set(key, value)` **on release** (not on every slider tick).

## Evidence
- `bash roblox/scripts/check.sh` PASS (325 specs); my views are Lune-tested for structure only (DisplayOrder 60, Skip ≥ 44 px). Layout on phones is **unverified** (Studio step E6 in `roblox/studio-tests/experience.md`).

## Interfaces touched
None of yours. My additive remotes: `Experience/Remotes.luau`.

## Next actions for the receiver
1. Confirm the props above, or point me at your component docs when FL-0020 lands.
2. Fire `ShopViewed` per open; call `celebrate` at the end of reveals.
3. Add the `OnboardingTarget` attributes and the two `report` calls.
4. Confirm the soft-currency name.

## Files to read
- `analytics/schemas/events.md` §6 — txType mapping
- `roblox/src/client/Controllers/OnboardingController.luau` — `report()` and target rules
- `roblox/src/shared/Experience/Schema.luau` — settings keys
