# plant_grass — author review log (D-019)

Images: `previews/plant_grass.jpg`, `renders/plant_grass/plant_grass_02_hero.png`,
`renders/plant_grass/plant_grass_03_hero.png` (overwritten each round; scores taken from that round's images).

Rubric order: silhouette / variation / readability @40 / proportions / palette / detail / kit cohesion / tris.

## Round 1
Scores: 3 / 4 / 3 / 3 / 4 / 3 / 3 / 4
Seen: six kinds (short, tall, meadow, dry straw, seed-head, reeds with cattails), blades are solid 16-tri tapered
blades with dark base -> light tip.
Problems: a tall octagonal root disc plus upright inner blades made every tuft look like a potted plant / vase.
Changes: root crown lowered to a 0.16-stud jittered disc; blades lean more the further out they start.

## Round 2
Scores: 3 / 4 / 3 / 4 / 4 / 3 / 3 / 4
Problems: still a dark vertical bundle at the base: the blade spine stayed nearly vertical for the lower 40 % and the
dark colour band covered the bottom 30 %.
Changes: blade spine fans from the base (lean 0.32 at 42 % height, 0.68 at 78 %), dark band only the bottom 20 %;
tall tuft spread widened.

## Round 3
Scores: 4 / 4 / 3 / 4 / 4 / 4 / 4 / 4
Seen: tufts fan out like stylized game grass, seed heads and cattails add a third detail level; 506-674 / 800 tris.
Remaining weaknesses: tiny at 40 studs (readability 3 is expected for ground cover; meant to be scattered in
groups); blades have a flat front + ridge, so very close up they look slightly faceted.

## Round 4 (triangle trim requested by FORGE-02; v2)
Change: grass tufts use the 10-tri blade (one bend: ring at 58 % height + tip) instead of 16 tris (two bends).
Tufts 506-674 -> 326-530 tris (-21 % on the seed-head tuft with its stalks, -33 to -36 % on the rest).
Seen (`previews/plant_grass.jpg`): fan shape, colour ramp and silhouettes are effectively unchanged at hero and
gameplay distance. Scores unchanged.

## Round 5: revert to v1 (FORGE-02 lead)
The v2 10-tri blade (round 4) cost the round-1 PASS: fresh review round 2 = NEEDS-WORK (silhouette 3).
`generators/plant_grass.py` restored byte-identical from a024e40 (VERSION 1; the shared blade helper's default
3-ring path is the v1 geometry); all 6 geometry hashes equal the PASS hashes pinned in f76edef
`reviews/plant_grass.json`, which is restored.
Polish backlog (fresh review round 2, not acted on):
- tufts 01-04 share one needle-blade spiky fan outline (04 = same tuft in tan); blades splay near-horizontal on 02/03.
- base of 06 (reeds) reads as a solid faceted tube.
- thin spiky blades clash with the chunky rounded kit language: try fewer, broader, rounder-tipped blades.
