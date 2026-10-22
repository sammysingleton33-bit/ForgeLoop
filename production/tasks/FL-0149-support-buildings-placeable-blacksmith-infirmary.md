---
id: FL-0149
title: "Support buildings placeable (blacksmith, infirmary, granary, shrine): key-citizen gate on, RulerAI builds them"
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Support buildings placeable (blacksmith, infirmary, granary, shrine): key-citizen gate on, RulerAI builds them

## Outcome
A ruler can build a Blacksmith, Infirmary, Granary and Shrine (one of each per kingdom). Each one brings its key citizen, whose support can be offered in the Crown Arena. AI kingdoms build them too, so arena support perks appear in real matches as designed (D-029, D-060).

## Context
- **D-060** (main ada0c833): key citizens went live on loyalty alone as an interim; the building gate follows once these buildings exist.
- **Part budget (FORGE-02's measurement, 22 Oct 17:56):** these stand-ins are already in `KitCeiling.spec`'s per-kingdom list, so placing them at maxCount 1 changes the all-built total by 0: still 26,526 of 27,000. A second copy of all of them would not fit (+1,594).
- **Not in the sim yet:** today they exist only as Kit stand-in models, not as G2 BuildingTypes. Barracks already exists. It does NOT yet bring a Captain: no generated citizen can hold that occupation (D-061). The Merchant cannot appear either, so the Market waits for VS-3 (D-061 (2)).
- **Naming:** `config Support.roles[r].building` uses 'smithy'; the G13.5 id is 'blacksmith'. Reconcile them (D-060 (3)).

## Requirements
- **G2 contract change**, additive: new BuildingTypes, plus catalog entries with cost, footprint, maxCount 1, level 1 and the Kit stand-in model. FORGE-05 reviews and FORGE-00 approves; CONTRACTS G2, G6 and G13.5 rows follow at merge.
- **Gate:** turn on the key-citizen building gate (the single function from the FL-0069 slice). A role is offered only while a finished building of its type stands.
- **RulerAI:** builds blacksmith, infirmary and granary first, then the shrine, once Founding is done. Keep economy pacing within seed noise. When both are due, the palisade gate (#315) and keep L2 come before a support building (stone is the AI's bottleneck).
- **Coverage evidence:** FullMatch sims, 8 seeds. Report roles per kingdom at Endgame for the AIs (target ≥ 2 on average) and for an idle player kingdom.
- **Player path:** FORGE-03 shows the new buildings in the build menu, and the menu and How-to-play say which supporter each one brings. The Barracks names no Captain, and there is no Market (D-061). That is FORGE-03's follow-up; give them the handoff.

## Validation
- Automated: specs for the catalog, placement, gate, RulerAI build order and offers end-to-end; full `check.sh`; the fairness gate unchanged; KitCeiling ≤ 27,000.
- Studio (owner): build an Infirmary and see the Healer offered at the loadout. Unverified until then.

## Completion criteria
- [ ] The four buildings are placeable with the gate on, merged with FORGE-05's G2 review.
- [ ] RulerAI coverage shows ≥ 2 roles per AI kingdom by Endgame on average.
- [ ] FORGE-03's menu and How-to-play follow-up is filed.

## Log
- 2026-10-22 FORGE-00: filed under D-060 after FORGE-02's measurement showed it fits the budget. Starts after FORGE-01's FL-0069 key-citizens slice (loyalty-only interim).
- 2026-10-22 forge-00: SPECIFIED → READY. Filed under D-060; fits KitCeiling at 0 cost
- 2026-10-22 forge-00: scope cut to four buildings (D-061). The Captain and the Merchant cannot appear in a real match yet. Costs approved as FORGE-01 proposed (blacksmith 80 wood + 60 stone; infirmary 90 + 40; granary 70 + 20; shrine 50 + 60), maxCount 1, one level, no keep gate. Conditions: AI stone priority; a full FairnessGate run with the gate on, reporting whether AI kingdoms reach pledged loyalty about as often as a player; RulerAI places them in the village cluster (render required); ownership exception from FORGE-05; CONTRACTS row text goes in the PR body.
