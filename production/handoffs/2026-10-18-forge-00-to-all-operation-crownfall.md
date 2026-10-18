# Handoff: FORGE-00 → FORGE-01…07 · Operation Crownfall missions · 2026-10-18

## What this is
- **The directive:** the owner's 2026-10-18 directive is to build the full AI Kingdoms game toward launch, not another slice. The rulings are in **D-053**.
- **Where we are:** B19 (`2923bd1`) is the latest build. Nothing has merged since, and nothing from B14 to B19 has been seen in Studio.
- **Audit (2026-10-18):**
  - **Built in the sim but switched off:** the full match is coded (timed phases, AI governors with war and peace, combat, Ram siege ×4, walls that block armies, diplomacy, consequences). The build ships `Match.mode = "slice"` with PvP off and AI kingdoms idle, so a player never sees any of it.
  - **Not built at all:** the Crown Arena (FL-0069 to FL-0076), placing walls and gates, outposts, spectating, Results with the leadership recap, the other three kingdoms' dressing, the war kit, combat feedback, persistence and sound assets (the owner's pick list).
  - **Interim (D-051):** citizen art (FL-0118 NEEDS-WORK), wheat and boulders (they need the owner's mesh pilot).
  - **Open PRs:** #177, #176, #118, #100 (held), #90.

## Critical path and integration plan
| Build | Contents (merge order) | Proves |
|---|---|---|
| **B20** | #176, #177, #118 → **FL-0125** full match → FL-0129 phase bar and war panel → FL-0130 war feedback → FL-0127 part 1 (outposts in Layout) | A real four-kingdom match starts, has AI wars and ends. |
| **B21** | FL-0126 walls, gates and outposts → FL-0127 four kingdoms → FL-0128 war kit → FL-0069/FL-0070 support inputs and the support meter (FL-0073 part 1) | Fortify, expand, and see the kingdoms' identities. |
| **B22** | FL-0071 arena core → FL-0072 venue → FL-0073 arena UI → FL-0074 crowd → FL-0075 duel input → FL-0076 fairness harness | The match ends in the Crown Arena. |
| **B23** | Polish, FL-0008 persistence (D-053 (6)), mobile pass, release checklist | Release candidate for the owner's playtest. |

**Batches:** FORGE-05 merges in these batches, FORGE-07 reviews every PR, and FORGE-00 lands contract rows at merge, the same way as D-052 (5). Additive contract text goes in your PR's handoff; nobody edits CONTRACTS.md directly. No worker waits on unrelated work: when blocked, take the next item in your list.

## Missions (one persistent session each; start with the first unblocked item)
### FORGE-01 (gameplay; the critical path)
1. **FL-0125 (P0): full match by default.** Turn on match mode, PvP, active governors, elimination and spectate, the arena hooks in MatchService, and the full-match headless spec with tick timing. Unblocks B20, FL-0129 and FL-0130.
2. **FL-0069 → FL-0070 → FL-0071 (P1): the Crown Arena core.**
   - Ledger and key citizens; SupportModel and SupportService with the fairness caps.
   - ArenaService, the pure `DuelModel`, DuelService and the AI champion.
   - Land DuelModel first, so FORGE-05's FL-0076 harness can start.
   - Write the G12 contract rows in your handoff; G12 becomes effective at merge.
3. **FL-0126 (P1):** `Build.PlaceLine`/`PlaceGate`, towers that shoot, outposts that grant territory, and governors that fortify.
4. **Housekeeping:** #118 when re-reviewed. Settle #100 with FORGE-05: rebase or close.
- **Owns:** see `docs/workflows/team.md` (Sim, Kingdom, Build, Army, Match, Arena; Match/Military/Objective/Governor/Support/Arena/Duel services; matching config).

### FORGE-02 (art)
1. **FL-0127 part 1 first:** three neutral outposts in `world/Layout.luau`, which FL-0126 consumes. Then the four distinct kingdoms: style table, all plots dressed, fair node counts, NodeKeepOut green, part ceiling held.
2. **FL-0072 (P2→P1 now):** arena venue, crowd figures and armour/weapon sets, needed by B22.
3. **FL-0128:** wall, gate and tower levels, the siege ram, soldier variants and the building `Damage` states.
4. **FL-0118 fixes:** the pick reads as a hammer; the miner, hauler and idle looks. Wheat and boulders (FL-0117) stay parked until the owner rules on the mesh pilot.
5. **#90 Blender pipeline:** follow FORGE-07's re-review.
- **Gate:** D-019 renders at the aerial camera distance before claiming quality. D-051 applies.

### FORGE-03 (UI and economy)
1. **FL-0129 (P0), in this order:**
   - Phase/timer bar and the war and peace panel. These can start now against the existing Diplomacy/Army commands.
   - Spectate and Results with the leadership recap, against FL-0125's remote rows.
   - The wall tool, against FL-0126.
2. **FL-0073:** the during-match support meter (crown-arena.md §8). Stub it until FL-0070 lands, then add the arena intro, HUD, loadout and perk picker.
3. **Phone 667×375 pass** on every new panel.
4. **#176 and the economy.md low.**

### FORGE-04 (experience)
1. **FL-0130 (P1):** hits, deaths (kneel and fade, no gore), building damage and collapse, raid alarm, war/siege/elimination announcer moments, phase transitions, spectate camera.
2. **FL-0074 and FL-0075:** crowd director, chants and boos, arena camera and music, duel input on PC, touch and gamepad. Start them against crown-arena.md §5 and §7 and FORGE-01's DuelModel once it is on main.
3. **#177.** Add every new sound to the owner's pick list instead of guessing assets.

### FORGE-05 (integration)
1. **FL-0131 (P0):** clear the PR queue, integrate FL-0125 and cut **B20** with studio-runs rows; measure tick, part and entity counts; start the release checklist (FL-0032).
2. **FL-0076:** the fairness harness and caps spec as soon as DuelModel lands.
3. **check.sh:** keep it inside its limits; optimise rather than skip.
- **Builds:** send each cut sha to FORGE-00; FORGE-00 builds it locally, delivers it to the owner and writes the checklist rows.

### FORGE-06 (dialogue)
1. **FL-0133:** DRAFT VS-2 lines (war, raid, siege, famine, outpost, arena eve, key-citizen pledges with loyalty variants), in your isolated workspace.
- **Still pending:** the owner's instruction holds (commit nothing until approved), and the owner's three answers are still pending (FORGE-00 has re-asked).

### FORGE-07 (review)
1. **FL-0132:** finish the owed re-reviews (#118, #90, #176, #177), then review FL-0125, FL-0126 and the arena PRs adversarially. Check:
   - authority;
   - validation and rate limits;
   - co-ruler permissions;
   - elimination edge cases;
   - a match that never ends;
   - the tick budget.

## Rules that still apply
- **Ownership and branches:** edit only your own paths (team.md); work on your own branch; open a PR into main. FORGE-05 alone merges.
- **Evidence:** headless checks are not Studio evidence. Say "unverified" for anything not seen.
- **Visual work:** acceptance needs D-019 renders.
- **Owner approval:** no publishing, asset uploads, spending or monetization without the owner.

## Next actions
- **Every worker:** read D-053 and your tasks, set your first task to BUILDING with a note, and report your PR to FORGE-05 and FORGE-00 when it opens.

## Owner's launch-ready definition (directive 2026-10-18 §7, verbatim)
AI Kingdoms is launch-ready only when:

* A new player can understand how to play.
* A complete intended match can start, progress and end.
* Multiplayer and competing kingdoms function.
* Major citizen, construction, military and reputation systems work.
* Crown Arena functions as the final payoff.
* The game looks coherent and finished from primary camera views.
* Critical UI works on supported desktop and mobile devices.
* Performance is acceptable on representative devices.
* No known critical gameplay, persistence, economy or security exploits remain.
* Core systems have been verified in real Roblox Studio / appropriate live tests.
* Content, assets and monetization meet Roblox requirements.
* Published experience metadata, permissions and release materials are ready.
* The owner has played and approved the release candidate.

No publishing without explicit owner approval.
The first release can receive patches, new content, balance changes and ongoing feature updates after launch.
This does not justify shipping a broken or misleadingly incomplete game.

## Update 2026-10-18: visual quality upgrade (D-057)
The owner found the citizens and the general art unacceptable for launch. This is a priority correction, not a reset. Everyone except FORGE-02 keeps their current order.
- **FORGE-02 now:**
  1. **FL-0135 citizens and rulers (P0 art)** with licensed prebuilt assets: audit, pick one source and style, character kit with variation, import-ready batch, before/after.
  2. FL-0127 outposts (#184) to merge.
  3. **FL-0136 environment and architecture** with assets (absorbs FL-0117 and FL-0127 part 2's look).
  4. FL-0072 arena venue.
  5. FL-0128 war kit, in the new style.
  - FL-0118 is superseded; its merged primitive rigs stay as the fallback.
- **FORGE-04:** be ready to adapt the pose driver if FL-0135 picks skinned bones. The joint names stay the same.
- **FORGE-05:** integrate the asset path. Builds without the owner's import must still pass the place check (Kit fallback). After the import, cut a build with the asset ids and the new studio-runs rows. Release checklist L6 cites D-057.
- **FORGE-07:** asset safety review. Licences must come from primary sources. Nothing non-redistributable may be committed (the repo is public). No scripts may hide in imported or Creator Store models.
- **B20 is not held for art.**
