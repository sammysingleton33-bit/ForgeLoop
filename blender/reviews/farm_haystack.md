# farm_haystack — author review log (FORGE-02 farm worker)

Asset ids `farm_haystack_01..06`, budget `prop` (1800). 01 domed rick (pole, two weighted ropes,
pitchfork, ladder), 02 round-bale pyramid + bale on end + rolled bale, 03 square-bale pyramid (10 bales,
fallen bale, burst heap, fork), 04 loaded hay wain (racks, 8-spoke wheels, shafts, roped load, fork),
05 two pole stogs on branch platforms + rake, 06 mixed pile (heap, bales, wheelbarrow, fork, rake, basket).

## Round 1 — first pass (quick build)
Images: `previews/farm_haystack.jpg` (r1, overwritten).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 5 | 4 | 4 | 3 | 2 | 3 | 4 |

Problems seen
- Every hay mass (rick, stogs, cart load, heap) was a smooth noise-displaced **bun / clay blob**: no straw
  texture, one flat colour. Stogs read as onions/teardrops.
- Straw tufts too few and too small; only 736-1136 of 1800 tris used.
- Pitchforks "stuck" in hay had the tines in the air.

Changes
- New `layered_profile()` (in `_farm_common.py`): ricks/stogs wrapped in overlapping thatch-like layers
  with dark lip undersides and alternating `hay`/`thatch` band colours (per-face colours by lathe band).
- Heaps and the cart load: lumpier noise (0.4 @ 0.85), banded colours (dark base -> `straw` top),
  30-40 larger straw tufts. `stuck_fork()` buries the tines and tilts the handle out.

## Round 2
Images: `previews/farm_haystack.jpg`, `scratchpad/farm/m.png` (01/04/05/06 heroes).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 5 | 4 | 4 | 4 | 4 | 4 | 4 |

Problems seen: rick reads a little like a bee skep (very regular layers); stogs like stacked pagodas;
straw tufts stick straight out like thorns.

Changes (round 3): layer heights made irregular; stogs 3 softer layers (lip 0.2); tufts now hang outwards
and downwards (1.55-2.1 rad from vertical) like loose straw.

## Round 3 — final (full build)
Images: `previews/farm_haystack.jpg` (final), `renders/farm_haystack/farm_haystack_0N_hero.png`, `farm_haystack_gameplay.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 5 | 4 | 4 | 4 | 4 | 4 | 4 |

Final 886-1254 tris / 1800 (headroom left on purpose: these get scattered in numbers), variation min 0.331,
BUILD PASS. Hanging tufts read as loose straw now. Remaining weakness: the rick's regular stacked layers still
hint at a bee skep; colour range is narrow (all straw tones) by nature — the tools carry the contrast.
