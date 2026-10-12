# Handoff: FORGE-03 → FORGE-01 (cc FORGE-00) · FL-0089 (needs FL-0080, FL-0083) · 2026-10-12

## What I need / what I'm giving you
The reputation strip and screen (FL-0089) are built against CONTRACTS G13.4 and a double of your
ReputationService. Please confirm (or correct) the payload assumptions below when you build FL-0080;
FORGE-00: the screen reads category texts from `Content/Reputation.categories` once FL-0083 lands.

## Done (with commits)
- `7992009` HUD reputation strip, `ReputationPanelController`, reputation screen (tabs Reputation /
  History / Kingdom), pure model, Layout zone, icons, specs, prototype and renders (branch
  `forge/03-ui-economy-fl0089`, built on PR #25's branch; no PR opened yet).

## Evidence
- `bash roblox/scripts/check.sh` → OVERALL PASS (framework 339 specs; game-001 138 specs, 0 failed;
  selene 0 errors; stylua 194 files; both Rojo builds and place checks PASS). Headless only.
- `ReputationModel.spec.luau` 16 passed; `ReputationUI.spec.luau` 15 passed (end to end through the
  real RemoteService with `tests/economy/doubles/ReputationDoubles.luau`).
- 7 mutations (oldest-first history, no clamping, number removed from the strip, push ignored,
  drawer over the strip, invented prose, sub-44 px tap target) each fail at least one spec.
- Visual: `games/game-001/design/ui/REVIEW-reputation.md`. **Unverified in Studio.**

## Interfaces touched
Additive only. Client side: `ReputationPanelController` (new), Layout `hud.reputation` zone (game
UI, FORGE-03). No shared contract changed. The remote declarations live only in my test double.

## Assumptions FORGE-01 should confirm (FL-0080)
1. **Declarations** (area `Kingdom`, your `src/shared/Kingdom/Remotes.luau`):
   `{ name = "Kingdom.Reputation", kind = "serverEvent" }` and
   `{ name = "Kingdom.GetReputation", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } }`.
2. **Push payload = GetReputation payload.** `Kingdom.Reputation` carries the full
   `{ values, history (latest 30), kingdom = { happiness, stability, morale } }` for the ruler, fired
   after every `apply` and after a kingdom condition changes. The client replaces its copy and
   floats `new − old` per category. (If you prefer deltas-only pushes, tell me: the client then needs
   `GetReputation` after each push.)
3. **`t` = `workspace:GetServerTimeNow()` seconds** (the G3 `endsAt` clock). The client shows
   "just now" (< 10 s), "45 s ago", "2 min ago", "1 h ago" from `serverTimeNow() − t`.
4. **History order:** any order is fine; the client sorts newest first. Equal `t` (one decision
   touching two categories): the later list position is shown first, so append in the order applied.
5. **Values** are numbers 0..100 (fractions allowed; shown rounded). History `delta` may be fractional
   (shown with one decimal). `text` is plain words for the player; `source` is not shown.
6. **Category ids** exactly G13.2: `compassion honor competence courage authority fear`. Unknown
   categories in history are dropped by the client.
7. **No kingdom → `GetReputation` returns nil** (the strip stays hidden until a reply with data).
   A late joiner gets a fresh `GetReputation` when `Kingdom.State` says their kingdom changed.
8. `kingdom.morale` is shown as "Army morale" (living-kingdom §3 "army morale").

## Note to FORGE-00 (FL-0083)
- The screen expects `Content/Reputation.categories[id] = { name, description, affects }` (strings;
  `name` optional — it overrides the UI name). `description` is shown under "About", `affects` under
  "What affects it". Missing fields are simply not shown.
- The switch is one line in `games/game-001/src/client/UI/ReputationText.luau`:
  `local CONTENT: any = nil` → `local CONTENT: any = require("@game/ReplicatedStorage/Game/Content/Reputation")`.
  Then the spec line `expect(ReputationText.provider).toBeNil()` in `ReputationModel.spec.luau` and
  the "invents no category prose" case in `ReputationUI.spec.luau` must be updated (they assert the
  pre-content state). FORGE-03 will do it when FL-0083 is on main; tell me if you prefer to.

## Open issues and risks
- Before FL-0080 lands, the live game has no `Kingdom.GetReputation`: the controller logs a warning
  and the strip stays hidden (by design).
- Tablet drawers are 72 px shorter (398 px) because they now start under the strip; the Kingdom
  overview scrolls to its 4th standing on tablet. Phones under ~640 logical px wide: the drawer
  covers part of the strip (it already covers the pills there).
- New icons need uploading with the others (`design/ui/icons/png/rep_*.png`, `happiness.png`,
  `stability.png`; asset request in `2026-10-12-forge-03-to-user-ui-icons.md`); emoji until then.

## Next actions for the receiver
1. FORGE-01: declare the two remotes as above (or tell FORGE-03 what differs) and fire the push
   with the full payload.
2. FORGE-01: answer `GetReputation` with nil for players without a kingdom.
3. FORGE-00: generate `Content/Reputation` with `categories[id] = { name, description, affects }`.
4. User (Studio, after FL-0080): take a decision in a conversation; the strip bar moves, a "+N"
   floats, and History shows the line on top with "just now".

## Files to read
- `games/game-001/src/client/Controllers/ReputationPanelController.luau` — data flow (header)
- `games/game-001/src/client/UI/ReputationModel.luau` — how the payload is read
- `games/game-001/tests/economy/doubles/ReputationDoubles.luau` — the double = my assumptions in code
- `games/game-001/design/ui/REVIEW-reputation.md` — screenshots and design decisions
