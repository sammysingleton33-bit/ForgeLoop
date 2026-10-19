# Handoff: FORGE-01 → FORGE-05 (cc FORGE-00, FORGE-03, FORGE-07) · FL-0070 part 1: SupportModel and config Support · 2026-10-19

Stacked on #208 (Arena Types / Caps / DuelModel).

## What I'm giving you
The pure support half of the Crown Arena: the score, the tier, the key-citizen trigger offers and the duel modifier lists they become, with the PROVISIONAL weights in config `Support`. FORGE-05's harness can read its support numbers from here instead of `DesignSupport` (`options.support`).

## Done
- `config/Support.luau`: component weights (reputation 15, happiness 15, stability 15, morale 10, loyalty 20, conduct 15, valour 10), sampling (40 % whole match, 60 % last 15 min), tier bands and passive blessings (design §3), the six key roles and their perks with pledged / empowered numbers (§4), the Crowd Rally, offer loyalty thresholds (80 / 95), and the ruler decisions LeadershipService will record (`acts`: component, signed delta, pre-authored text).
- `src/shared/Arena/SupportModel.luau`: `score(samples, {now}) -> (score, tier, breakdown)`, `tierOf`, `trend`, `offers(keyCitizens, tier) -> (offers, slots)`, `modifiers(tier, picks) -> { Modifier }` (the shape `Caps.check` and `DuelModel` read).
- Specs `sim/SupportModel.spec` (15): score edges, time weighting (a last-minute deed moves the score under 5 points; an early mistake is repairable), offers at loyalty 79 / 80 / 95, dead and duplicate key citizens, Crowd Rally only at Adoring, and **every tier x every pick set up to its slots x both powers passes `Caps.check`** (that assertion is how the numbers stay inside G12.3). Mutation rows `mutations/FL-0070.py` (16).
- One real bug found by the spec and fixed: perk effect texts containing `%` broke `string.gsub` (now a function replacement).

## Interfaces (additive)
None new beyond G12.2's `SupportModel.score / offers` (signatures as in CONTRACTS, `ruler` = `{ now }`) and the added `tierOf`, `trend`, `modifiers`.

## Evidence
- GATE_PLACEHOLDER
- Headless only. Nothing here has been balanced: the weights and numbers are the design's provisional ones.

## Open issues and risks
- `score` takes samples with all seven components 0-100. LeadershipService (next PR, FL-0069) produces them: kingdom components from Reputation/Happiness/Stability/Morale/Loyalty and the ruler's conduct and valour from the act ledger.
- The Merchant / Elder perks exist in config (`fineWares`, `rallyingHymn`) though VS-2 ships Blacksmith, Healer, Captain and Provisioner first; they are offered only when such a key citizen exists.

## Next actions for the receiver
1. FORGE-05: let the harness read `config/Support` (`SupportModel.modifiers`) and re-run the fairness cells.
2. FORGE-03: the offer fields (`citizenName`, `loyalty`, `condition`, `effect`) are what the perk picker shows.

## Files to read
- `games/game-001/src/shared/Arena/SupportModel.luau` (header), `games/game-001/config/Support.luau`
