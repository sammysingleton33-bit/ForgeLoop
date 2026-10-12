# Lessons learned

One file per area (`gameplay.md`, `blender.md`, `ui-economy.md`, `experience.md`, `integration.md`, `process.md`). Add only verified, reusable lessons. Each entry: date · lesson · evidence · confidence tag:
- `observed-once` — seen once; useful hint
- `repeated` — confirmed on two or more tasks/games
- `standard` — promoted into `docs/standards/` or a template by FORGE-00

Retire entries that turn out wrong (strike through + reason) instead of deleting them.

## Carried over from the previous survival-arena project (user report, not re-verified)
- 27 passing checks did not mean playable quality → G6 Studio gate exists. `observed-once`
- Flood hazard never raised the arena water to the intended ~10 ft → FL-0011 requires measured water height in Studio. `observed-once`
- Primitive trees (cylinder trunk + one sphere) were rejected → FORGE-02 visual review loop. `observed-once`
- The place was hard to find later (not in Studio recents, unclear save location, cross-PC issues) → source in Git, BuildInfo stamp, inventory script FL-0034. `observed-once`
- Studio server/client test windows closed; animation-loading warnings → capture Output logs in Studio test reports. `observed-once`
