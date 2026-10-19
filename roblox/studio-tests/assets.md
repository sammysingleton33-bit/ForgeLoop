# Studio tests — FORGE-02 assets (gate G6)

Run by the user on Windows (Studio does not run on Linux). Record results with the BuildInfo sha
and the manifest commit. **None of these have been run yet.**

| # | Step | Expected | Result |
|---|---|---|---|
| A0 | Desktop Blender 5.2.x: `blender -b -P blender\build.py -- --all --no-render` from the repo root | Ends with `BUILD PASS`; for 5 random ids the `exports\<id>.validation.json` tri counts and sizes equal `blender/manifest.json` | not run |
| A1 | Import `exports/house_cottage_02.fbx` with the settings in `blender/README.md` (Front/Top, Scale Unit Stud, Make Double Sided off) | One Model with one MeshPart; textured with the palette (no magenta, no white) | not run |
| A2 | Scale | MeshPart size ≈ manifest `dimensions_studs` (±1 %); a default R15 character fits through the door (7.6 tall) | not run |
| A3 | Orientation | The door side faces the Model's front (−Z / LookVector); roof up | not run |
| A4 | Pivot | Model pivot at the base centre; `:PivotTo(CFrame.new(0,0,0))` puts the asset on the ground at the origin | not run |
| A5 | Single-sided rendering | No see-through holes from any angle (geometry is closed) with DoubleSided off | not run |
| A6 | Shared texture | Import a second asset; both reference the same palette image; re-using one TextureID on both looks identical | not run |
| A7 | Collision | CollisionFidelity from the manifest; walk into walls/door step; tree canopies do not block (CanCollide off + trunk box) | not run |
| A8 | Performance | 30 houses + 40 trees in view on a phone (or Studio device emulator): no warning, stable frame rate; note MicroProfiler numbers | not run |
| A9 | Shading | Thatch/foliage smooth, architecture faceted as in `blender/previews/*.jpg`; note any normal artifacts | not run |
