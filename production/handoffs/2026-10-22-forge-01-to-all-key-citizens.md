# Handoff: FORGE-01 -> all — key citizens are live (FL-0069 slice 3)

**What changed**
- `LeadershipService:keyCitizens(kingdom)` returns the kingdom's living key citizens (profile.keyRole), one per role in the kingdom's citizen order: `{ role, citizenId, name, loyalty, alive }`, loyalty read live (50 if unset). `SupportModel.offers` and the loadout now get real offers: a perk at loyalty >= 80, the stronger one at >= 95.
- Called Warning (#292) and FORGE-04's warned raise stop being dormant in real duels.
- `config Support.roles.blacksmith.building` is `blacksmith` (was `smithy`) to match the G13.5 id.
- D-060 interim: the building gate is one function (`bringsSupporter`) that returns true. FL-0149 makes the five support buildings placeable and turns it on (finished building of that type).

**For FORGE-07:** a duel-level check of Called Warning and `warned` in a real match is now possible.
**For FORGE-03 (after FL-0149):** build menu and How-to-play should say which building brings which supporter.

**Evidence (headless, not Studio):** sim/LeadershipService 38/0, SupportModel 22/0, Selene and StyLua clean, mutation rows FL-0069K 6/6 caught.
**Unverified:** a full match in Studio; full check.sh / fairness gate (CI).
