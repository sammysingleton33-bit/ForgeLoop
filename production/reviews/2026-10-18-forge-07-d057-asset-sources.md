# FORGE-07: D-057 asset sources, first checks (2026-10-18)

Companion to section 8 (A1 to A7) of `2026-10-18-forge-07-full-match-surface.md`. FORGE-00 asked me to review D-057 (9) to (12) and `docs/research/2026-10-18-art-sourcing-brief.md` against evidence. No asset PR is open yet, so this is the source check and the gaps I will hold the asset PRs to. Evidence labels: `first-hand` = I fetched it myself on 2026-10-18; `secondary` = a search snippet or a mirror; nothing here is Studio evidence.

## 1. What I verified, and how
| Claim | Result |
|---|---|
| The official KayKit repos are CC0 | **first-hand.** `LICENSE.txt` on `main` of `github.com/KayKit-Game-Assets/` for `KayKit-Character-Pack-Adventures-1.0` (commit 672074b7), `KayKit-Medieval-Hexagon-Pack-1.0` (84fa4e91), `KayKit-Character-Pack-Skeletons-1.0` (15b62b9b) and `KayKit-Dungeon-Remastered-1.0` (b0ca9bd9) each read "License: (Creative Commons Zero, CC0)", "free to use in personal, educational and commercial projects", crediting Kay Lousberg optional. CC0 applies to what the pack ships; the committed asset still needs its own manifest row with the commit id it came from |
| The "brand resource" in the Adventurers licence | it is an optional logo; the "no logos" rule in the brief is consistent with it |
| Kenney is CC0 | **secondary only.** Search snippets show CC0 on Kenney's own itch.io pack pages and in GitHub mirrors; kenney.nl is blocked here. Rule: commit Kenney files only with the licence file from the downloaded zip recorded in the manifest |
| Quaternius is QAL v1.0 and bans redistribution | **not confirmed by me.** My search found no QAL text; the brief marks it "likely". The rule in D-057 (9), no Quaternius files committed, is the safe reading and I agree with it |
| Synty and Creator Store content are not used | agreed; nothing of either may appear in the tree (A2, A3) |

## 2. Gaps to close before the asset PRs
1. **The manifest does not enforce provenance.** On #90's head (`blender/lib/manifest.py`) `check()` fails on duplicate ids, unsorted assets, a lod0 triangle count over budget and a failed validation. It does not require a source URL, date, sha256 or licence per asset, which D-057 (9) and the brief require. Needed before FL-0135 and FL-0136 land: a required-fields rule (a missing field fails; any licence other than CC0 fails for a committed asset) with a spec. FORGE-02 told; FORGE-00 told.
2. **Pack size.** `KayKit-Character-Pack-Adventures-1.0` is 126 files and about 124 MB (32 fbx, 28 png, 27 gltf with 27 bin, 5 glb); `KayKit-Medieval-Hexagon-Pack-1.0` is 1,478 files (442 fbx, 263 obj with 263 mtl, 221 gltf with 221 bin, 54 png, 5 jpg). Both carry stray Windows `.url` shortcuts. AGENTS.md says exported binaries are reproducible and large files are not committed unless the team decides. Expectation: a pinned commit id and a fetch script in the repo, and only the files actually used committed, never a whole pack; no `.url` shortcuts, no previews or logos from the pack.
3. **Budgets** (≤ 1,000 triangles per citizen, body ≤ 900, tool ≤ 150; segmented MeshParts on the Motor6D tree): I will measure triangles per segment from the files in the PR (A5), not take the figure from the PR text. Every number stays provisional until a Studio or phone measurement.

## 3. Still open (each needs the PR)
A3 (no scripts in anything imported: none expected from CC0 mesh formats, to be checked by extension and content), A6 (no personal paths or account ids in metadata or logs), A7 (`build.py --verify`, which needs bpy; the evidence is FORGE-02's or FORGE-05's run, labelled theirs), and the owner steps in D-057 (12) (experience owner and Asset Privacy before any upload), which are the owner's, not mine.
