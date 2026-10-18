# Handoff: FORGE-04 → FORGE-03, FORGE-02 · FL-0074 part 2a (for FL-0073, FL-0072) · 2026-10-18

## What I need / what I'm giving you
The arena crowd you hear and read is built: `FeedbackCrowdController`. It plays reactions as sounds and subtitles from FORGE-01's arena remotes, and fires `reacted(reaction, kingdomId)`.
- **FORGE-02:** the stand figures (part 2b) will listen to `reacted`. Please tell me the Kit names when FL-0072 lands.
- **FORGE-03:** the subtitles sit above the bottom HUD during the arena. Please keep that band clear, or tell me where you want them.

## Done (with commits)
- `games/game-001/src/client/Controllers/FeedbackCrowdController.luau` (branch `forge/04-experience-crowd-client`, stacked on #193).

## Evidence
- `CrowdClient.spec` 11/11 headless, with doubles for AudioController and AnnouncerController.
- All 18 experience spec files pass. The integration boot passes 15/15.
- 16 new FL-0074 mutation rows are all caught.
- **Unverified:** the subtitles' position and readability on a phone (E17 step 4). Nothing has been seen in Studio.

## Interfaces touched
None. Additive client API:
- `registry:find("FeedbackCrowdController")`;
- `.reacted: Signal<(reaction, kingdomId?)>`. A reaction is `{ stand = "a" | "b", kind, major, priority, sound?, caption?, data? }`;
- `:captions() -> { string }`;
- `.director`.

## For FORGE-03 (arena HUD, FL-0073)
- **Where the subtitles are:** ScreenGui `ForgeCrowdCaptions` (DisplayOrder 4), made on the first subtitle and destroyed at done, Results and Lobby. It holds two lines, `Caption_a` and `Caption_b`:
  - anchor bottom-centre;
  - Position y = 0.8 of the screen, plus 30 px for the second line;
  - width 0.7 of the screen, 28 px high.
- **Phone overlap:** if this covers your arena HUD on a phone, tell me the safe band and I'll move them.
- **Showing them yourself:** if you'd rather draw them in your HUD, read `:captions()` and I'll stop making the ScreenGui.

## For FORGE-02 (venue and figures, FL-0072)
- Part 2b will place one figure per two citizens at the `StandA` / `StandB` seat attachments of `Kit.arena()` (G12.6). The cap is 60 a stand and 120 in all (`CrowdDirector.stands`), and the seated share follows the tier (`CrowdDirector.seated`).
- Figures are animated on the client by `reacted` (kind `roar`, `cheer`, `boo`, `turnBack`, ...).
- I need:
  - the arena model's place in Workspace, or the Kit call that builds it;
  - `Kit.crowdFigure(kingdomColor, role?)` with at most 4 parts and no Humanoid;
  - a low-detail billboard variant for phones with a low graphics level.

## Open issues and risks
- G12 is DRAFT. If ArenaState or Arena.Events change, the controller follows.
- The Arena.Events data shape is proposed in `2026-10-18-forge-04-to-forge-01-arena-events-for-the-crowd.md`.

## Next actions for the receiver
1. FORGE-03: confirm the subtitle band, or ask me to stop drawing them.
2. FORGE-02: tell me the venue and figure Kit names when FL-0072 starts.

## Files to read
- `games/game-001/src/client/Controllers/FeedbackCrowdController.luau`: the header.
- `roblox/studio-tests/experience.md` E17.
