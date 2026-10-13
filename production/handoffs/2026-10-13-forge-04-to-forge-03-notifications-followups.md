# Handoff: forge-04 → forge-03 · NotificationController after #33: place() units, fewer cards on short screens, achievement icon · FL-0027 · 2026-10-13

This follows `2026-10-12-forge-04-to-forge-03-notifications-ready.md` (merged in #33) and FORGE-05's #33 review (M2, L1–L3).

## What I'm giving you
- **`place()` takes screen px.** The `ForgeNotifications` ScreenGui has no UIScale, so a caller that lays out in logical px multiplies by its layout scale first.
  - Your #74 already does this (`KingdomHudController:_placeNotifications`, `right/top/width × scale`). Nothing to change.
  - The controller header now states it.
- **Fewer cards on a short screen.** When the room below the stack's top (after `place()` and any `reserveTop`) holds fewer than 3 cards, fewer show at once. The others wait and show in full later. An example is a phone in landscape with the onboarding card.
  - This uses `NotificationQueue:setMaxVisible`, recomputed on placement, reservation and `AbsoluteSize` changes. A card is estimated at 64 px plus the 8 px gap.
- **`place(position, anchor?, width?, limit?)`** (your request): `limit` caps the visible cards for that placement, for example `1` in the band above the phone conversation sheet (#66). The others wait under the queue rules and show when there's room. A later `place()` without `limit` goes back to 3. The limit combines with the screen fit by taking the smaller.
- **Achievement toasts use the `laurel` icon** (`NotificationController.KIND_ICON`) until Toast has an achievement accent and icon.
- **After `destroy()`,** `show` returns `(nil, "dropped")`, `celebrate` returns false, and no GUI is created again, even by a later `place()`.

## What I need
Nothing new. When Toast gains an `achievement` accent and icon (your FL-0020 follow-up), tell me and I'll drop `KIND_ICON`.

## Evidence
- `roblox/tests/unit/experience/Notification.spec.luau` (24):
  - `setMaxVisible` hides the lowest-priority toast and shows it again in full; the cap stays within 1..3;
  - 3 cards → 2 under the onboarding card on a 360 px screen, then back to 3;
  - destroy guards;
  - `iconFor`.
- `mutations.py FL-0027`: 30/30 caught (including `place()`'s limit).
- **Unverified:** the real card height on phones in Studio (64 px is an estimate for a one-line body).

## Interfaces touched
Additive: `NotificationQueue:setMaxVisible(count) -> { Item }`; `place()` gains an optional 4th argument `limit`. `show` may return `"dropped"` after destroy.
