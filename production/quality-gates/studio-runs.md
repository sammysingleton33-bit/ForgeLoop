# Studio runs (gate G6)

Every Studio test the user runs, newest last. FORGE-05 records it from the report pasted in chat;
nothing is recorded that the user has not run. Plans: `roblox/STUDIO_TEST_PLAN.md` (S1–S3),
`games/game-001/STUDIO_PLAYTEST.md` (VS-1), `production/quality-gates/multiplayer-test-plan.md`.

| date | BuildInfo sha | place (artifact / local) | tests | result | evidence (Output lines, screenshots) | recorded on |
|---|---|---|---|---|---|---|
| — | — | — | (no Studio run yet) | — | — | — |

## Builds delivered to the user (FL-0093, D-030)
After every merge that changes what can be seen or played, FORGE-05 sends FORGE-00 the CI
`forgeloop-game001-<sha>.rbxl` and a truthful works / doesn't-yet list; FORGE-00 passes it to the user.
"Works" below means verified headlessly (Lune, Rojo, place check), never in Studio, until a run is
recorded in the table above.

| # | date | main sha | artifact | what you can see / do (headless-verified) | doesn't work yet | sent to FORGE-00 |
|---|---|---|---|---|---|---|
| B1 | 2026-10-12 | `b6f252f` | [`forgeloop-game001-b6f252f`](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38310484338/artifacts/11774113089) (run 38310484338) | The AI Kingdoms valley builds at server start: terrain (river, bridges, hills, roads, fields), forests and props, warm lighting with `Technology = Future`; Output `WorldService ready ms=…`; 38 resource nodes, 12 build zones, 1 objective, 4 kingdom plots tagged (only crimson is dressed). Debug panel (F8 / button) in Play with `forge.buildInfo`, `forge.services`. | No character or kingdom yet (FORGE-01 #31 open), so **Play shows no avatar** — use **Test → Run** to fly over the world. No HUD (FORGE-03 #25 open), no citizens, conversations, construction, army or onboarding steps (they start on `KingdomJoined`). World is 11,115 parts: frame rate and phone performance unknown. | 2026-10-12 |
| B2 | 2026-10-12 | `986c773` | [`forgeloop-game001-986c773`](https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38314053545/artifacts/11776021599) (run 38314053545) | Everything in B1, with the world lighter (8,327 parts, down from 11,465 once build slots landed) and 40 build-slot markers (10 per kingdom). **Play now spawns you as a ruler** at your kingdom (crown and cape, Teams/party), the camera starts in the aerial overview (WASD / drag to pan, wheel to zoom, Q/E to rotate) and tapping a slot or building selects it. Kingdom HUD (resources, Build rail and drawer). Debug panel presets (F8). Headless evidence only: check.sh 9/9 on the merge result, boot gate 75 s with no errors. | **F1: a flat green slab covers the terrain and river** around the kingdoms (MatchHost `createGround`; fix with FORGE-01; B3 follows). No throne seating, no citizens, conversations or reputation yet (FORGE-01 services not merged). The Build drawer opens but nothing can be placed: the server has no `Build.*` remotes yet, so Output shows `Build.*` warnings. Frame rate and phone performance unknown. | 2026-10-12 |

B1 note: FORGE-00 delivered B1 to the user as a direct file, rebuilt from `b6f252f` with the same BuildInfo stamp (place check PASS, 228 KB), with the steps above (FORGE-00 message 21:27 UTC). The user's Output lines and screenshots come back through FORGE-00 and get recorded in the table at the top.
