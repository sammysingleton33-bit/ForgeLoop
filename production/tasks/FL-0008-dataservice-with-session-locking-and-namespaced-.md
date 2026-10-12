---
id: FL-0008
title: DataService with session locking and namespaced profiles + PlayerService
track: build
owner: forge-01
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 8
evidence: []
---

# DataService with session locking and namespaced profiles + PlayerService

## Outcome
Player data never lost or duplicated: session-locked profiles, per-owner namespaces with versioned migrations, autosave, BindToClose flush, saveNow for purchases; PlayerService fires PlayerReady.

## Requirements
- Implements interfaces.md section 5 exactly
- Lock = jobId + timestamp; steal stale locks after timeout; retries with backoff; request-budget aware
- Friendly kick when load fails after retries
- Releasing signal before final save

## Validation
Lune specs with MockDataStoreService: two servers contending for one key, stale-lock steal, transient failures, migration per namespace, saveNow failure path, BindToClose; Studio test steps in roblox/studio-tests/gameplay.md

## Completion criteria
- [ ] Specs cover success and failure paths
- [ ] No data loss/duplication scenario left untested

## Log
- 2026-10-12 forge-00: created (READY).
