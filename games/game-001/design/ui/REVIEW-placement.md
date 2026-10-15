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
