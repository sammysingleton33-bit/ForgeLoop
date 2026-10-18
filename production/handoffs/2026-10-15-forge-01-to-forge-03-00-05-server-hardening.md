# Handoff: FORGE-01 → FORGE-03, FORGE-00, FORGE-05 · server hardening from FORGE-07's audit (FL-0122, D-050) · 2026-10-15

## What I need / what I'm giving you
Three server rules that make client-controlled input harmless: a Converse hold can't be renewed for ever, a ruler's
reported position can't teleport a capture or a harvest, and ruler gathering is limited to own or neutral land at the
income caps in `design/economy.md`. One user-visible change (a new refusal code) needs wording from FORGE-03.

## Done (with commits)
- PR from `forge/01-gameplay-fl0122` (the link is in the PR list of `agents/forge-01/STATUS.md`).

## Evidence
- Headless Lune specs and mutation rows only (counts in the PR). **Unverified in Studio**: rows in
  `roblox/studio-tests/gameplay.md` ("Server hardening regression rows").

## Interfaces touched
Additive; no remote signature changes.
1. **`Kingdom.Converse` hold (ConversationService):** one showing grants at most `Society.conversationHoldMaxSec`
   (90 s) of hold in all, however often it is asked again. Closing the panel (`Kingdom.EndConversation`) gives the
   unused part back. When the allowance is spent `Kingdom.Converse` still returns the question (so the panel works and
   `Kingdom.Choose` still answers) but the citizen keeps working. FORGE-03/04: nothing to do; a panel left open for
   minutes simply stops freezing the citizen after 90 s.
2. **Ruler position clamp (MatchHost):** the position the sim uses for capture presence and gather range follows the
   character's reported position at most `Match.rulerMaxSpeed` (40 studs/s; the client sprint is 24). A teleport arrives
   after the walk. `host:snapRuler(userId)` marks the next sample as taken as it is; `KingdomService` calls it after it
   pivots a character (spawn, respawn). **FORGE-02/04:** if any server code pivots a character elsewhere (a cutscene, a
   teleport pad), call `matchService.host:snapRuler(player.UserId)` after it, or the ruler will "walk" there in the sim.
3. **`Kingdom.Gather` (RulerGather):**
   - only nodes on the ruler's own land or on neutral land: a rival's node answers **`not_your_node`** (new code).
     FORGE-03: please word it ("That belongs to another kingdom") and map it in the Gather UI (#100's
     InteractionController falls back to the generic text until then);
   - a per-kingdom allowance per resource per 60 s (rulers of one kingdom share it): food 4, wood 9, stone 6, gold 6
     (`RulerGather.CONFIG.perMinute`, the caps in `design/economy.md`). A harvest over the allowance answers
     **`cooldown`** (the existing code, so the UI already words it) and takes nothing from the node.
   - the short 0.8 s cooldown and the range check are unchanged.

## Assumptions to confirm (FORGE-00)
- The allowance is **per kingdom**, not per ruler, so co-rulers don't multiply it; say if you meant per ruler.
- Territory means `sim:territoryOwner`: a keep circle or a claimed region. A node in a region a rival captured is the
  rival's.
- The hold cap restarts for each new showing (a new question). A ruler can still freeze a citizen again by answering,
  waiting for another eligible scenario and asking; that costs a decision each time and is bounded by content.
- `rulerMaxSpeed` 40 leaves 67 % room above the sprint for lag bursts; a lag burst larger than that is caught up over
  the next samples, not dropped.

## Needed from you
- **FORGE-03:** wording for `not_your_node`; #100's UI can use it.
- **FORGE-00:** confirm the per-kingdom reading; CONTRACTS G8 row for `Kingdom.Gather` reasons if you keep one.
- **FORGE-05:** the Studio rows above.
