---
id: FL-0017
title: CI job that builds asset exports as a downloadable artifact
track: asset
owner: forge-02
status: SPECIFIED
priority: P2
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0013]
estimate_h: 2
evidence: []
---

# CI job that builds asset exports as a downloadable artifact

## Outcome
Exports are reproducible on GitHub Actions (pip bpy) and downloadable as an artifact, so nothing large is committed.

## Requirements
- Coordinate the workflow file change with FORGE-05 (owner of forgeloop.yml)

## Validation
CI run produces the artifact

## Completion criteria
- [ ] Artifact downloadable and matches manifest

## Log
- 2026-10-12 forge-00: created (SPECIFIED).
