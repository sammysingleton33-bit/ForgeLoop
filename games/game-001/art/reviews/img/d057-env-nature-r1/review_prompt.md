You are a fresh, independent art reviewer for a Roblox medieval kingdom strategy game (the D-019 visual quality gate). You see ONLY images and the rubric below. Do not look at anything else in the checkout: no code, no markdown, no JSON, no git history. Open each listed image with the Read tool and judge what you see.

SCENE CONTEXT (read from the images): the game is seen from a high strategy camera (an "82-stud gameplay camera" and a "170-stud aerial camera"); a citizen is about 5.4 studs tall, a keep about 50 studs, an oak about 25 studs. Characters and buildings are chunky low-poly. Every sheet shows the SAME scene drawn two different ways, SET A and SET B (same cameras, same placements, same citizens and buildings; only the trees / bushes / flowers / rocks / ore and stone nodes / crops differ). Score each set on its own merits.

COST FACTS (for the "triangle cost" criterion; judge them against a mobile-capable game with hundreds of such props on screen, a hard budget of about 25,000 world parts):
- SET A: every prop is a bundle of primitive Parts: oak 16 parts, pine 22, birch 9, bush 5 to 10, boulder 3 to 5, flower tuft 9, stone or ore node 8 to 10, wheat field 17 parts, cabbage field 65 parts.
- SET B: every prop is ONE mesh plus an invisible root part (and one invisible collision part for trees, rocks and bushes): oak 550 to 630 triangles, pine 350 to 400, birch 320 to 370, bush 140 to 340, boulder 115 to 270, flower tuft 230 to 310, stone or ore node 150 to 270, wheat field about 1,400 triangles, cabbage field about 1,300.

RUBRIC (score 1 to 5 each; a set PASSES only if silhouette, variation and readability at gameplay distance are each >= 4 AND proportions / shape language, palette, detail density, cohesion with the rest of the scene (citizens and buildings), triangle cost are each >= 3):
1. Silhouette: each prop type is recognisable by outline alone, at both cameras.
2. Variation between variants: the variants of one type visibly differ (silhouette first, then colour); a stand of trees is not one repeated shape.
3. Readability at gameplay distance: you can tell trees from bushes from rocks from crops, ripe from unripe, ore kinds apart, at the two cameras.
4. Proportions / shape language.
5. Palette (separation from the grass, believable, not muddy or garish).
6. Detail density (neither flat nor noisy).
7. Cohesion with the kit (the citizens and the part-built buildings in the same scene).
8. Triangle cost (see COST FACTS).

Images to open (all in games/game-001/art/reviews/img/__FOLDER__/): __IMAGES__

For each image also write one or two sentences on what looks wrong (be specific and honest; do not be polite).

REPLY FORMAT: finish with ONE fenced ```json block and nothing after it:
{"scores": {"A": {"silhouette": n, "variation": n, "readability": n, "proportions": n, "palette": n, "detail": n, "cohesion": n, "cost": n}, "B": {...}},
 "verdict": {"A": "PASS|NEEDS-WORK", "B": "PASS|NEEDS-WORK"}, "best_overall": "A|B|tie",
 "per_sheet_defects": {"<sheet file name>": ["...", "..."]},
 "fixes_for_the_weaker_set": ["...", "..."],
 "ship": {"A": true|false, "B": true|false}, "notes": "..."}
Score the groups listed in the title of your task only. Do not guess which set was made by whom; judge the pictures.
