# Visual reviews (D-019)

Every generator gets `reviews/<generator>.md` (human log) and, once a fresh-context reviewer has scored it,
`reviews/<generator>.json` (machine verdict pinned to each asset's geometry hash; `build.py --merge-only`
copies it into the manifest; any geometry change drops the asset back to `UNREVIEWED`).

## Rubric (score 1–5)
| Criterion | Pass |
|---|---|
| Silhouette | ≥ 4 |
| Variation between variants | ≥ 4 |
| Readability at gameplay distance | ≥ 4 |
| Proportions / shape language | ≥ 3 |
| Palette | ≥ 3 |
| Detail density | ≥ 3 |
| Cohesion with the kit | ≥ 3 |
| Triangle cost | ≥ 3 |

Verdicts: `PASS` (every criterion at or above its threshold) / `NEEDS-WORK`.

## Process
1. Author rounds (≥ 2): render → open the image → score → list what looks wrong → change → re-render.
   Log each round: scores, problems, changes, before/after image paths.
2. Final scoring by a **fresh-context reviewer subagent** that sees only the contact sheet(s) and this rubric.
   Its verdict goes into `<generator>.json` and the `.md` log.
3. Calibration: the first contact sheets are judged by FORGE-00 or the user (D-019).

## `<generator>.json` format
```json
{"generator": "house_cottage", "generator_version": 2, "round": 3, "reviewer": "fresh-context subagent",
 "verdict": "PASS", "scores": {"silhouette": 4, "...": 4}, "notes": "...",
 "assets": {"house_cottage_01": {"verdict": "PASS", "geometry_hash": "0123456789abcdef"}}}
```
