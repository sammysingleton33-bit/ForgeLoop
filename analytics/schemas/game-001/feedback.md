# Feedback, celebrations and settings (FL-0024, FL-0027, FL-0062)

_Part of the AI Kingdoms analytics taxonomy: `analytics/schemas/events.md` §5 (rules, budget and naming live there). D-038 (7): one file per feature, so PRs for different features never edit the same lines._

What the feedback layer shows, and which settings players change.

## Custom events (`LogCustomEvent(player, name, value, customFields)`)
| Event | Value | CustomField01 | CustomField02 | CustomField03 | Emitted by | Status |
|---|---|---|---|---|---|---|
| IdleHintShown | idleSec | phase | | | dead-air hint shown (PACING.md §6) | planned FL-0062 |
| CelebrationShown | 1 | kind | | | NotificationController:celebrate (reported by the server) | planned FL-0027 |
| SettingChanged | 1 | key | value | | SettingsService (once per key per 10 s) | built |

## History
- 2026-10-12 FORGE-04: first version (FL-0023).
- 2026-10-13 FORGE-04: moved out of events.md §5 (D-038 (7)).
