# Handoff: forge-03 → forge-01, forge-05 (cc forge-00) · building rotation B1 + B2 (CONTRACTS v0.4-g9h) · 2026-10-15

## What I'm giving you
From the user's first Studio playtest (`production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`): "Buildings and walls currently cannot be rotated."

- **B1, free placement (Build rail), works on main's server today:**
  - the bar's Turn button: the rotate icon, "Turn" on tablet and desktop, and a dial showing where the door will face from the current camera;
  - R turns, **Shift+R** turns back; on a gamepad **R1** turns and **L1** turns back (Y is the camera's View toggle, FORGE-07 M1 on #135);
  - the ghost has a cream door strip on its front edge and a cream facing arrow pointing out of it, sized to read from the aerial camera.
- **B2, plot Turn, built against CONTRACTS v0.4-g9h, live since FORGE-01's #132 (main f36b1f0):**
  - the plot detail gets a Facing row (dial, "Faces the street / right / away / left", Turn); phones get a chip and a Turn button beside the CTA;
  - a ghost previews the selected building on the plot, inside the plot's outline (`world/Layout` slot centre + yaw);
  - Turn offers only the turns where `Fit.fits(type, size, turn)` is true;
  - `Build.PlaceSlot(slotId, type, turn)` sends the turn.

## FORGE-01: how my client switches B2 on
- **The switch:** `UI/Turns.supported()` reads the shared `src/shared/Build/Remotes.luau`. It is true when the `Build.PlaceSlot` entry declares **three or more args**, so declare the turn as `Validate.optional(Validate.integer(0, 3))`.
  - No other flag is needed, and until then PlaceSlot keeps its exact two arguments.
  - Ship `Fit.fits(type, size, turn?)` in the same PR. My client calls `Fit.fits(type, size, t)` for t = 0..3 once the switch is on. An old Fit that ignores the turn would offer turns your server refuses.
- **Turn semantics I implement:**
  - yaw = slot yaw + turn × 90°, in CFrame.Angles(0, yaw, 0). +1 is a quarter counter-clockwise seen from above, the `rot` sense.
  - The labels assume the street is in front of the slot (its −Z).
  - An odd turn swaps the footprint's axes.
- **The fit rule my spec double uses (`SlotDoubles.fitsTurned`):** largest-level footprint, swapped for odd turns, inside `slotSizes[size]`. Under that rule a house on S and a barracks on M get only 0 and 2.

## Evidence
- **Specs:** `games/game-001/tests/economy/Rotation.spec.luau`, 13 specs:
  - the rotation and screen-angle maths;
  - ghost door and arrow geometry for rot 0–3;
  - Turn and dial end to end (desktop and phone), Shift+R past 0;
  - plot Turn unsupported (2 args, no row);
  - plot Turn supported: all four turns, the ghost CFrame and outline, PlaceSlot args[3] = 1;
  - barracks 0/2 only; a misfit refused (`does_not_fit`); the phone layout; in-flight; ghost removal.
- **Existing specs:** KingdomUI and PlotUI pass unchanged.
- **Mutations:** 18/18 killed.
- **Renders:** reviewed in `games/game-001/design/ui/REVIEW-placement.md`.
- **Studio:** unverified; steps in `roblox/studio-tests/ui-economy.md` U17.

## Next actions
1. **FORGE-01:** land the server turn and `Fit.fits(…, turn)` as above; my specs' double shows the expected behaviour. Tell me if you name or shape anything differently.
2. **FORGE-05:** gate B1 and B2 together (FORGE-01's #132 is merged); Studio U17 steps 1–8.
