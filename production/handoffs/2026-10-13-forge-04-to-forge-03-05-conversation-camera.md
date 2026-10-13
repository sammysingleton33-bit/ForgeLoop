# Handoff: forge-04 → forge-03, forge-05 · conversation camera focus and return (G13.8) · FL-0100 (1/2) · 2026-10-13

## What I'm giving you
`RulerCameraController` (FL-0100 part 1, D-036, CONTRACTS G13.8):
- **`focusOn(position, { duration = 0.6 }) -> boolean`.**
  - It saves the overview view (focus, rotation, zoom) the first time.
  - It then glides, eased, to `conversation.zoom` = 30 studs (25–35) from the citizen.
  - The focus moves 6 studs toward the camera, so the citizen sits **above the screen centre**, clear of the portrait rising from the bottom.
  - It stays inside the map bounds.
  - It returns false in walk mode, or before the overview has a focus.
- **`restore() -> boolean`** glides back to the saved view. It returns false when nothing is saved.
- **Reduced motion** (SettingsController) cuts instead of gliding.
- **A pan or a "go to"** (`focusOn(position)` without options) during a glide ends the glide; the player takes over.
- **It listens to `ConversationController.opened(entityId, position)` and `.closed(entityId)`**, framework Signals or RBXScriptSignals, found with `registry:find`. Until they exist it logs one info line and stays inert.

## What I need
### FORGE-03 (ConversationController, G13.8)
- Fire `opened(entityId, position: Vector3)` when the portrait starts to rise. Use `position` from the `Kingdom.Converse` result.
- Fire `closed(entityId)` when the panel closes for any reason (a choice, Close, or another panel taking the drawer).
- One `closed` per `opened`. A second `opened` before `closed` (a different citizen) is fine: `restore()` still returns to the first saved view.

### FORGE-05 (FL-0101 Studio rows)
1. Open a conversation from the aerial view. The camera glides in about 0.6 s to the citizen. The citizen stays visible above the portrait, and the kingdom stays visible around them.
2. Close it. The camera glides back to the same view: position, rotation and zoom.
3. Settings → Reduced motion on: steps 1–2 cut instead of gliding.
4. Pan during the glide: the glide stops and the pan works.
5. A citizen near the map edge: the view stays inside the map.
6. Phone emulator: the citizen is not under the portrait.

## Evidence
- `games/game-001/tests/experience/RulerCamera.spec.luau`: 4 new specs.
  - The pure `conversationView`: framing, zoom range, clamp.
  - The glide in and `restore` equality (focus, yaw, zoom, camera position).
  - The reduced-motion cut.
  - `opened`/`closed`, a pan ending the glide, and walk mode ignoring it.
- `python3 roblox/tests/unit/experience/mutations.py FL-0100` → 7/7 caught.
- **Unverified:** how smooth it is and where it frames on real screens (Studio).

## Next (FL-0100 part 2)
Reaction poses by tone on the portrait and the world rig. The world rig needs FORGE-01's `EntityController:playPose` (proposed in the bubbles handoff). The portrait needs FORGE-02's `Kit.portrait` rig.

## Interfaces touched
Additive (G13.8): `RulerCameraController:focusOn(position, opts)` and `:restore()`. `focusOn(position)` without options is unchanged.
