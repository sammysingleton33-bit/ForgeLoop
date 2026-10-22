# Handoff: FORGE-01 → FORGE-00, FORGE-02, FORGE-04 · unit kind as the job on the wire (FL-0128 wire finding, part 1) · 2026-10-19

A unit's kind now reaches the client as its job, so an archer, a knight and a ram stop arriving as the spear soldier.

## What changed
- `Types.JOB_IDS` (G2 JobId) gains `"archer"`, `"knight"`, `"ram"` at the end (the wire code is the index, so existing codes do not move; `EventCodec.JOBS` follows). They are unit kinds, not citizen jobs: `Catalog` still refuses them as entries of config Jobs.
- `Replication.jobOf`: a citizen keeps its job; a unit (no job) sends its unit kind (`soldier`, `archer`, `knight`, `ram`). Used by `entityState` (G4) and the spawn identity. The entity kind stays `"soldier"`.
- Specs: `sim/Replication` (units and the spawn event round trip), `sim/Types` (the list). Rows: `FL-0128U.py`, 3 of 3 caught.

## What is not here yet
- The `EntityController` ram branch (`Kit.siege` has no rig on main until FORGE-02's war kit, #260, lands; the branch must not reset the ram's `Log` joint and should drive it with `Kit.siegeTransform`). I do it as the next PR once #260 is on main.
- The CONTRACTS G2/G4 rows: FORGE-00 lands them.

## Evidence (headless only)
Specs `sim/Replication` 9, `sim/Types` 3, `sim/EventCodec` 9, `sim/Catalog`, `sim/Population` pass; StyLua clean; Selene 0 warnings. Not seen in Studio: whether the client draws the knight and archer (Kit.character already maps job to unit kind in FORGE-02's war kit).
