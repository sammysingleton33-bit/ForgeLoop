# Review: turning a building (B15 rotation; the user's first Studio feedback 2026-10-13)

Renders from `design/ui/render` (headless; not Studio). Each opened and judged by eye.

| Render | What it shows | Judgement |
|---|---|---|
| `placing-{phone,tablet,desktop}.png` | The placement bar: **Turn** with the rotate icon, the word (tablet/desktop) and the facing dial; the hint line names R / Shift+R | Turn is now the most legible control after Place; name, cost and verdict keep their room (bar 480 px on phones, 600 px on tablet/desktop). |
| `placing-bad-{phone,tablet,desktop}.png`, `placing-room-phone.png` | The same bar with a refusal | The red reason still fits on a phone. |
| `placing-ghost-{phone,tablet,desktop}.png` | The real ghost from the overview camera at its 120-stud start zoom (pitch 52°), a farm turned a quarter: the cream door strip and facing arrow; the bar's dial points the same way | The arrow reads at a glance on desktop and is clearly visible on a phone (about 30 px long). The renderer flat-shades parts and does not draw SelectionBox outlines (README deviations 23–24), so the slab's outline is missing here; the arrow is what this render checks. Uses the ViewportFrame renderer (FL-0099, on main since #126). |
| `plot-pick-turn-{phone,tablet,desktop}.png` | The plot picker with the v0.4-g9h turn served by the spec double: Storehouse "Faces right" | Desktop: a Facing row (dial, label, hint, Turn). Phone: the drawer is too short for a row, so the label is a chip beside the build time and Turn (icon + dial, 76 × 44) sits left of "Build Storehouse here"; nothing scrolls. |

Known limits: the dial is camera-relative and the plot label is street-relative, so after the player
rotates the camera they can differ in wording ("Faces right" with the dial pointing up); both are
true. The dial refreshes on the next render (any aim, turn or push), not on a camera move alone.

## Moving a building (FL-0120)

| Render | What it shows | Judgement |
|---|---|---|
| `building-move-{phone,desktop}.png` | My barracks' panel with **Move** (✥) beside "Upgrade to Lv 2" | Move reads as the secondary action; Upgrade keeps its width on desktop; on a phone both fit the bottom row and the price stays above it. |
| `placing-move-{phone,desktop}.png` | Moving a house: "Move House", no costs, "✓ Good spot", "Move here" | The bar says what is happening and that it is free; the wider confirm fits "Move here" (118 / 132 px). |
| `placing-move-plot-{phone,desktop}.png` | The house snapped onto a free medium plot from the aerial camera, turned a quarter: the plot outline stays put, the facing arrow and the bar's dial agree (down-left), "✓ Faces right" | The snap reads clearly: footprint inside the plot outline, arrow out of the front. |

The facing dial is now drawn with frames (shaft and two head strokes) instead of the "▲" glyph: the
renderer drew a rotated glyph 180° off at oblique angles (README deviation 25), which made the earlier
`plot-pick-turn-*` renders point the wrong way (re-shot here; they now agree with the ghost). Roblox
rotates glyphs correctly, but frames also avoid font and centring risks. After #139 merged, the
`placing-*`, `placing-bad-*`, `placing-room-phone` and `placing-ghost-*` renders were re-shot with the
frame arrow too (looked at: the arrow is crisp and points the same way as the ghost's).
