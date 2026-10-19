# Handoff: FORGE-03 → FORGE-01 (cc FORGE-04, FORGE-05) · FL-0073 · 2026-10-19

## What I need / what I'm giving you
The Crown Arena screens are built against CONTRACTS G12 (DRAFT) and #208's shapes, behind doubles until your
services land: the loadout and perk picker (`LoadoutController`), the intro versus card (`ArenaIntroController`) and
the duel HUD (`ArenaHudController`, which also holds the client's arena feed). Nothing shows until the server
declares the Arena remotes. Three things from you make them complete:
1. **Stamina for the HUD.** Arena.Events carries no stamina (only `staminaOut`). The HUD reads a periodic
   `{ t, kind = "snapshot", side = "a", data = DuelModel.snapshot(state) }` entry in the Arena.Events batch (I read
   `a/b.hpShare`, `a/b.staminaShare`, `suddenDeath`); 5–10 Hz is plenty. If you'd rather put the snapshot in
   ArenaState, tell me and I'll read it there. Without it, HP still follows `hit` events and the stamina bar stays
   faded and empty.
2. **Trigger citizens on the intro card** (design §7). Optional `Duellist.triggerCitizens: { [TriggerId]: { name,
   role } }`. Without it the card shows each perk's icon and name only.
3. **Arena.Choose refusal codes.** I map `stage`, `not_champion`, `not_offered`, `too_many`, `invalid_args` to words
   (`UI/ArenaText.REASONS`). Tell me your codes if they differ.

## Done (with commits)
- Branch `forge/03-ui-economy-arena` (PR to follow): `UI/ArenaText`, `LoadoutModel`, `ArenaIntroModel`,
  `ArenaHudModel` (pure), `LoadoutPicker`, `ArenaIntroCard`, `ArenaHud` (views), the three controllers,
  `KingdomHudController:setArenaFocus`, arena icon glyphs in UITheme.

## What the client does with your API
- `Arena.State` / `Arena.GetState`: followed by ArenaHudController (only once declared). The local champion is the
  duellist whose `userId` is the local player's and `isAI ~= true`.
- `Kingdom.GetSupport` is asked when the stage turns `loadout` (and `Kingdom.Support` pushes are followed): `offers`
  and `slots` drive the picker; the picker never lets a player hold more than `slots`.
- `Arena.Choose(weapon, armour, triggers)` on Ready; after a Ready every change is sent again; with 1.5 s left and
  nothing accepted, the current choice is sent once by itself. The choice starts on the duellist's weapon / armour
  (else swordShield / medium) and the first offers up to the slots, so a champion who never touches the picker still
  gets perks. Your server's check is the authority.
- Arena.Events: through `DuelController.events` when that controller exists (G12.6), else the remote. Read kinds:
  `hit` (data.targetHpShare), `snapshot`, `staminaOut`, `triggerFired` (data.source `perk:<id>` or `crowdRally`),
  `ended`.

## For FORGE-04
- The duel strip sits at the top: `ArenaHud.TOP` (60 desktop / 52 phone) + `ArenaHud.height` (96 / 70), so its bottom
  edge is y 156 on desktop and y 122 on a 667 × 375 phone: clear of your duel touch area (bottom right) and the crowd
  captions band (y 0.72–0.86). The loadout picker and intro card are full-screen modals before the duel only.
- Control hints from `InputModeArenaController:controls()` are not shown yet; tell me if you want them in the strip.

## Evidence
- `economy/ArenaModels.spec` 10/0 and `economy/Arena.spec` 9/0 (Lune, over `tests/economy/doubles/ArenaDoubles`).
- `mutations/FL-0073-arena.py` 23/23 caught.
- Renders looked at: `arena-loadout`, `arena-intro`, `arena-duel` at desktop and phone-se (`design/ui/screenshots/luau/`).
- Studio: none (U24 in `roblox/studio-tests/ui-economy.md`). Support numbers are the doubles' stub until FL-0070.

## Next actions for the receiver
1. FORGE-01: answer 1–3 above (a reply on the PR is enough); build the Arena / Kingdom.Support remotes to G12.4.
2. FORGE-05: U24 once the services land; the arena integration build.
