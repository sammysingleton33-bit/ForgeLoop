# Handoff: forge-04 → forge-03, forge-05 · conversation camera focus and return (G13.8) · FL-0100 (1/2) · 2026-10-13

## What I'm giving you
`RulerCameraController` (FL-0100 part 1, D-036, CONTRACTS G13.8):
- **`focusOn(position, { duration = 0.6 }) -> boolean`.**
  - It saves the overview view (focus, rotation, zoom) the first time.
  - It then glides, eased, to `conversation.zoom` = 30 studs (25–35) from the citizen.
  - The focus moves 6 studs toward the camera, so the citizen sits **above the screen centre**, clear of the portrait rising from the bottom.
  - It stays inside the map bounds.
  - It returns false in walk mode, or before the overview has a focus.
- **In front of the citizen's face** (CONTRACTS G13.8 v0.4-g9e: the held citizen turns to face the ruler's character, #108).
  - `focusOn(position, { facing })` sets the camera yaw so it looks at the citizen's front (`Def.conversationYaw`).
  - On `opened`, the facing comes from the citizen's rig, `EntityController:getModel(entityId):GetPivot().LookVector`.
  - While the panel is open, the rig's facing is re-read every 0.2 s. When the server's turn toward the ruler arrives (more than 10°), the camera glides round to the new front.
  - A pan, a "go to" or a turn by the player stops the following.
  - Without a rig the current rotation is kept.
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
1. Open a conversation from the aerial view. The camera glides in about 0.6 s to the citizen. The citizen stays visible above the portrait, and the kingdom stays visible around them. The camera looks at the citizen's face; if the citizen turns toward your ruler just after, the camera follows round to the front.
2. Close it. The camera glides back to the same view: position, rotation and zoom.
3. Settings → Reduced motion on: steps 1–2 cut instead of gliding.
4. Pan during the glide: the glide stops and the pan works.
5. A citizen near the map edge: the view stays inside the map.
6. Phone emulator: the citizen is not under the portrait.

## Evidence
- `games/game-001/tests/experience/RulerCamera.spec.luau`: 6 new specs, two of them for the face-on framing (v0.4-g9e): `conversationYaw`, and the rig's facing with the following.
  - The pure `conversationView`: framing, zoom range, clamp.
  - The glide in and `restore` equality (focus, yaw, zoom, camera position).
  - The reduced-motion cut.
  - `opened`/`closed`, a pan ending the glide, and walk mode ignoring it.
- `python3 roblox/tests/unit/experience/mutations.py FL-0100` → 12/12 caught.
- **Unverified:** how smooth it is and where it frames on real screens (Studio).

## Next (FL-0100 part 2)
Reaction poses by tone on the portrait and the world rig. The world rig needs FORGE-01's `EntityController:playPose` (proposed in the bubbles handoff). The portrait needs FORGE-02's `Kit.portrait` rig.

## Interfaces touched
Additive (G13.8): `RulerCameraController:focusOn(position, opts)` and `:restore()`. `focusOn(position)` without options is unchanged.
