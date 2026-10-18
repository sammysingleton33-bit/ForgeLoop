# Feedback, celebrations and settings (FL-0024, FL-0027, FL-0062)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

What the feedback layer shows, and which settings players change.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| IdleHintShown | idleSec | phase | | | the server's dead-air detector, when it sends the hint (PACING.md §6); never on a client's report. The detector does not exist yet: `PacingService:idleSec` only holds the thresholds | planned (FL-0062 follow-up) |
| CelebrationShown | 1 | kind (Lines' celebration ids: kingdomFounded, keepUpgraded, objectiveCaptured, victory, defeat) | | | AnnouncerService on the server, for each player a celebrating moment is sent to at its G9 event (Moments.present); Studio samples (`fx.announce`) are not logged. The client may still show it as a toast | built |
| SettingChanged | 1 | key | value | | SettingsService (once per key per 10 s) | built |

## History
- 2026-10-12 FORGE-04: first version (FL-0023).
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
- 2026-10-15 FORGE-04: FORGE-00 review M3: CelebrationShown built from AnnouncerService on the server; IdleHintShown's producer named (the server dead-air detector, not built).
