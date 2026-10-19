# FORGE-02 status

_Maintained by the worker. Keep it short and current._

| Field | Value |
|---|---|
| Session branch | `forge/02-blender-fl0135-idle` (this PR); other work branches below |
| Open PRs | this one (FL-0135 (b): idle accessory, hair tufts, three portrait lows), #240 (FL-0072 `Kit.arenaDress` placement and decoration physics, budget scan), #228 (FL-0136 phase 1: environment source comparison, docs and tooling) |
| Merged this cycle | #90 pipeline core, #184 outposts, #197 miner pick, #200 four kingdom styles, #207 mesh-citizen Kit runtime, #217 Crown Arena venue + crowd + armour + weapons, #220 citizen mesh kit (style B), #226 170-stud silhouette pass |
| Current task | FL-0135 (b) PR; then FL-0128 war kit (worker, branch `forge/02-blender-fl0128-war`), FL-0136 nature and wheat meshes (worker P, `forge/02-blender-fl0136-nature`) and the FL-0136 env-mesh runtime (`forge/02-blender-fl0136-envrt`, PR held until #228 merges) |
| Last verified check | `bash roblox/scripts/check.sh` OVERALL PASS on this branch merged with main 790c56d2 (game-001 specs 2326 / 0, 146 files) and on #240 (2300 / 0); `bash blender/scripts/check.sh` PASS on the worker's tree. Headless only; **no Studio evidence for any of this art** |
| Blockers | None for me. All mesh art waits on the owner's Studio import (`games/game-001/art/IMPORT_CHARACTERS.md`) before anything is judged in the real viewport |
| Needs from others | Owner: re-import the citizen kit (this PR regenerates `citizen_kit.fbx`), then Studio screenshots at close range and the 170-stud aerial; FORGE-00 holds (a) 1.15x citizen scale and (c) per-job torso / `tints.cloth_panels` until those exist. FORGE-01: `ArenaService` calls `Kit.arenaDress` once #240 is on main (handoff `2026-10-19-forge-02-to-forge-01-arena-dress-follow-up.md`) |

## Open work branches (pushed, not merged)
- `forge/02-blender-fl0128-war` (worker): wall / gate / tower levels, siege ram, soldier variants, building damage states; D-019 render review and part-count report owed before its PR.
- `forge/02-blender-fl0136-nature` (worker P): style-B nature and wheat meshes (trees 300 to 900 tris, three wheat growth stages) with one D-019 round each.
- `forge/02-blender-fl0136-envrt` (head 83695c53): env-mesh runtime (`Kit/EnvMesh.luau`, `env_to_luau.py`, fallbacks to the stand-ins); PR after #228.
- Parked, not for merge: `forge/02-blender-fl0086-buildings`, `forge/02-blender-b12-visuals`, `forge/02-blender-fl0085-record`, `forge/02-blender-env-wheat` (superseded by the FL-0136 mesh path).

## Last report
FL-0135 (b), interim art (D-051), Blender renders and headless evidence only: idle citizens get a headband or bandana and a rose bindle or rucksack; hat jobs get a hair tuft; healer front cross and merchant scale beam fixed for the portrait. Fresh D-019 delta reviewer: BETTER (idle variation 3 to 4, hat jobs 2 to 3, readability unchanged). Hat-job variation stays at 3 (invisible at 170 studs) and idle items read "partly" at 170 studs; Studio behaviour is unverified.
Still placeholder quality: all mesh art until the Studio import is judged; wheat and boulders until FL-0136 lands; per-individual variation at 170 studs.
