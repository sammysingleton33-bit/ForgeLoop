# Handoff: FORGE-01 -> all — key citizens are live (FL-0069 slice 3)

**What changed**
- `LeadershipService:keyCitizens(kingdom)` returns the kingdom's living key citizens (profile.keyRole), one per role in the kingdom's citizen order: `{ role, citizenId, name, loyalty, alive }`, loyalty read live (50 if unset). `SupportModel.offers` and the loadout now get real offers: a perk at loyalty >= 80, the stronger one at >= 95.
- CORRECTION (D-061, FORGE-00; supersedes the first version of this handoff): Called Warning (#292) and FORGE-04's warned raise do NOT go live with this slice. A real match's starting population has only four key roles (blacksmith, elder, healer, provisioner): no captain (job soldier, and soldiers are units, not citizens) and no merchant, and arrivals never get key roles (800 generated populations and 2,500 arrivals on 8b2cb7fd: 0 captains, 0 merchants, 0 key-role arrivals). Called Warning needs the Captain, so it stays dormant until the owner decides how a captain appears (D-061).
- Deferred: the successor at loyalty 50 (crown-arena §4, FL-0069) is not implemented, since arrivals never get key roles; a follow-up after FL-0149.
- `config Support.roles.blacksmith.building` is `blacksmith` (was `smithy`) to match the G13.5 id.
- D-060 interim: the building gate is one function (`bringsSupporter`) that returns true. FL-0149 makes the four reachable support buildings (blacksmith, infirmary, granary, shrine; the market is deferred with the Merchant, D-061) placeable and turns it on (finished building of that type).

**For FORGE-07:** a duel-level check of the four reachable perks (Reforge, Field Remedy, Hearty Rations, Rallying Hymn) in a real match becomes possible once FL-0149 lets kingdoms build their buildings; Called Warning / `warned` stay dormant (D-061).
**For FORGE-03 (after FL-0149):** build menu and How-to-play should say which building brings which supporter.

**Evidence (headless, not Studio):** sim/LeadershipService 38/0, SupportModel 22/0, Selene and StyLua clean, mutation rows FL-0069K 6/6 caught.
**Unverified:** a full match in Studio; full check.sh / fairness gate (CI).
