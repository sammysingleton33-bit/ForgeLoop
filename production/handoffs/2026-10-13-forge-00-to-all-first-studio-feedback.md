# Handoff: FORGE-00 → FORGE-01, 02, 03, 04, 05, 07 · the user's first live Studio playtest feedback · 2026-10-13

## What this is
- **The run:** the user's first live Roblox Studio playtest of AI Kingdoms, on their own PC (2026-10-13 evening). The user didn't name the build; the latest delivered build was B13 `d65fb2e`.
- **What they think:** they like the overall look and direction. This is **not** a change of direction and **not** a scope cut: the next cycle is a usability and visual polish pass that keeps the full AI Kingdoms design.
- **Their setup:** they now also run a local Claude Code session connected to Studio through Studio's built-in MCP server (Windows).
- **Where this sits:** this file is the record of what they said. D-049 (DECISIONS.md) sets the cycle's priorities and rules, and the tasks carry the work.

## The user's feedback (their words, from their two messages to FORGE-00)
**Environment / visuals**
- "Trees look too blocky and low-detail." / "Trees look extremely blocky. Improve their shapes, leaves, branches, variety, and overall appearance."
- "Rocks and environmental props also feel too simple." / "Rocks and environmental assets feel too primitive."
- "The world needs more visual polish and more believable natural shapes."

**AI citizens**
- "Citizen / worker designs are too simple. Their tools and silhouettes need more personality and readability. They should be more visually distinct from one another, especially from the aerial view."
- "AI citizens, clothing, and occupational tools need substantially better visual detail and distinct personalities."

**Kingdom spawn / farms**
- "The starting kingdom contains trees and rocks placed on top of or inside farm areas. The player's initial kingdom footprint needs cleanup and smarter placement logic. Farms and build zones should start in a clean, intentional state."
- "Starting farms contain trees and rocks. Fix environment generation and obstruction logic."

**Citizen interaction readability**
- "Chat bubbles are difficult to notice and interact with from the aerial view. Citizen interaction signals need to be much easier to see and understand."
- "Citizen chat bubbles are difficult to see and interact with from the aerial camera."

**Building usability**
- "Buildings and walls currently cannot be rotated. The player should be able to rotate buildings during placement."
- "Add building rotation and wall orientation controls."
- "The player should also be able to reposition or rearrange placed buildings / plots more freely, similar to Clash of Clans style base editing. Evaluate a move/edit mode for buildings and walls without breaking the current VS-1 loop."
- "Add a Clash of Clans-inspired base editing system so players can select, move, and rearrange placed buildings and plots. For movable plots, establish clear rules so relocation preserves gameplay logic, resource ownership, pathing, construction state, and building restrictions. No duplication exploits."

## The user's priority order
- **First message:**
  1. farm/build plot cleanup and initial kingdom layout;
  2. citizen interaction readability;
  3. building rotation;
  4. trees and environment shapes;
  5. citizen appearance and tools;
  6. wall placement;
  7. building move/reposition;
  8. decoration logic and obstruction prevention.
- **To FORGE-05 directly:**
  1. kingdom cleanup;
  2. building rotation;
  3. chat bubble readability;
  4. initial art upgrades where ready.

  Ship the next Studio build as soon as items 1–3 are integrated. Don't wait for every polish task.
- **Latest message:** finish **B14** (the cinematic conversation set) first, without disruption. Then the next build.

## Ownership (the user's guidance, mapped onto docs/workflows/team.md so every file keeps one owner)
- **FORGE-01:** world-generation *rules*, placement rules, building relocation logic. Kingdom Layout, Build remotes, BuildingService.
- **FORGE-02:** trees, rocks, citizens, tools and visual assets. Kit, WorldService/WorldPlan dressing, world Layout.
- **FORGE-03:** rotate and move interfaces (placement UI, edit mode), conversation readability in its UI.
- **FORGE-04:** camera interactions and presentation polish, including `CitizenBubbleController` (FORGE-04's file).
- **FORGE-05:** integration, Studio testing, builds.
- **FORGE-07:** independent review (once the user's go-ahead is given in its session).

## Next actions
- Every worker: read D-049 and your tasks; B14 work comes first.
- FORGE-05: record the run in `production/quality-gates/studio-runs.md` (build not named) and gate each fix against these items.
