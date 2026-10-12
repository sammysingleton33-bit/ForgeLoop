# Quality gates

A task reaches `ACCEPTED` only when the gates for its kind of work pass, with evidence recorded in the task file. "Unverified" is an allowed, honest state; claiming a gate you did not run is not.

| Gate | Applies to | Pass condition | Evidence to record |
|---|---|---|---|
| G1 Static | all Luau | `bash roblox/scripts/check.sh` green: Selene 0 errors, StyLua clean, Rojo build OK, place-structure check OK | check.sh summary line + sha |
| G2 Unit | all Luau logic | Lune specs for success **and** failure paths; new code has specs; specs proven able to fail | spec count, notable cases |
| G3 Contract | code touching `Contracts/` or another area's API | matches `docs/architecture/interfaces.md`; breaking change approved in `DECISIONS.md` | link |
| G4 Security | remotes, economy, purchases, data | server-authoritative; args validated; rate-limited; idempotent grants; no partial writes | specs named |
| G5 Visual | assets, UI, VFX | render/screenshot opened and reviewed against the brief; review note committed | image path + review file |
| G6 Studio | anything engine-dependent (physics, replication, UI layout, DataStore, purchases) | steps in `roblox/STUDIO_TEST_PLAN.md` run by the user on the integrated build | BuildInfo sha + result |
| G7 Performance | assets, effects, game builds | within budgets (`production/quality-gates/budgets.md` once FL-0032 lands) | numbers |
| G8 Integration | every PR | CI green; merged result green; ownership respected | PR + CI link |

Tasks whose only missing gate is G6 may be merged as `REVIEW` and accepted once the user's Studio run passes.
