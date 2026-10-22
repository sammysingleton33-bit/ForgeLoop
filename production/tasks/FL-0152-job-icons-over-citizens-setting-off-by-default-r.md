---
id: FL-0152
title: "Job icons over citizens (setting, off by default): readable jobs from the start camera"
track: build
owner: forge-04
status: BUILDING
priority: P2
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Job icons over citizens (setting, off by default): readable jobs from the start camera

## Outcome
A player who finds citizens hard to read from the default camera can turn on "Job icons over citizens" and see each citizen's job at a glance. Whether it becomes the default is the owner's call ("closer start camera or job icons?", B22.3 notes).

## Context
- D-059: the owner's playtest said citizens are barely recognisable at the default aerial distance. #316 (1.5x rigs, spacing) and #317 (silhouettes) are the first fixes. This is the fallback if they are not enough.
- FORGE-04 has a prototype on `forge/04-experience-job-glyphs`: CitizenGlyphController, the `jobGlyphs` setting, at most 50 pooled icons, reads the rig's KitJob attribute. Placeholder art; FORGE-03 makes the icons.

## Requirements
- Off by default. The setting sits in Settings under Gameplay.
- Fully visible at the start zoom (70) and fading out as the camera comes close. Hidden in walk mode, the duel, scripted shots and conversations, and under a speech bubble.
- On phones, workers in a cluster must not overlap into a smear. For example, merge neighbours with the same job into one icon, or cap it per cluster.
- Client only: no server or contract change.

## Validation
- Specs plus mutation rows.
- A sheet over the 1.5x start-frame renders, on desktop and on an 844x390 phone, opened and judged.
- Studio (owner): unverified until seen.

## Completion criteria
- [ ] Merged after FORGE-07's review, with the setting off by default.
- [ ] The phone sheet shows no overlapping smear at the farm cluster.

## Log
- 2026-10-22 forge-00: filed for FORGE-04's prototype (B22.4). The default waits for the owner's answer.
- 2026-10-22 forge-00: SPECIFIED → READY. Filed for FORGE-04's prototype
- 2026-10-22 forge-00: READY → BUILDING. Prototype on forge/04-experience-job-glyphs
