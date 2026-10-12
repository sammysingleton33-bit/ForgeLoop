# Handoff: forge-04 → user · sounds to choose or upload for AI Kingdoms · FL-0024/FL-0062 · 2026-10-12

_Revised 2026-10-12: the list is regenerated for the VS-1 slice (CONTRACTS v0.4-g2). Siege, festival, morale and alarm sounds moved to VS-2 and are not asked for now._

## What I need / what I'm giving you
AI Kingdoms has **41 sounds** on its list: 20 **P0** for the tutorial and the first minutes, 13 P1 for the rest of the VS-1 slice, and 8 P2 for later. Picking Creator Store sounds or uploading audio requires **your** Roblox account, so FORGE-04 can't do it. The game already runs without them: missing sounds are skipped and counted, and every event also has a visual cue. No money is involved: Creator Store audio is free, and audio imports are free within the monthly quota.

## Platform facts (Roblox creator-docs, read 2026-10-12 at commit af5f853)
- Creator Store audio is "free-to-use audio assets made by Roblox and the Roblox community for creators to use within their games, including more than 100,000 professionally-produced sound effects and music tracks" (audio/assets.md).
- Your own uploads: "If you're ID verified, you can import 2,000 free audio assets per 30 days; if you're unverified, you can import 100 free audio assets per 30 days." Formats: mp3, ogg, wav or flac, "less than 20 MB in size and 7 minutes in duration" (audio/assets.md).
- Uploaded audio is **private** by default. You can grant it to specific experiences ("the asset privacy system lets you grant usage permissions to specific friends and experiences"), and "Restricted assets must be explicitly granted permission before they are visible or audible at runtime" (projects/assets/privacy.md).

## How to do it (about 10 seconds per sound once you're in the flow)
1. Open Studio, then **Toolbox → Creator Store → Audio**. Use the search terms in the table below.
2. Preview a few candidates. Choose a sound that matches the "should sound like" column. Keep it short: under 1.5 s for effects, a clean loop for music and ambience.
3. Right-click the sound → **Copy Asset ID**.
4. Collect the ids in a message like `kingdom.build.complete = 1234567890 (title, creator)` and send them to FORGE-04, either in chat or as a file in `production/handoffs/`. I'll enter them in the registry with the title and creator as the licence and source note, and set each to `candidate` until you have heard it in game (Studio test E3).
5. If you'd rather use original audio (commissioned, or recorded by you): import it in **Creator Hub → Creations → Audio**, then grant the experience permission and send me the id the same way.
Do the 20 **P0** sounds first; they cover the whole tutorial and the first minutes.

## The list (generated from `roblox/src/shared/Experience/Sounds.luau` and `games/game-001/config/Sounds.luau`)
P0: the tutorial and the first minutes. P1: the rest of the VS-1 slice. P2: after the first playtest (reward tiers and streaks are not used in VS-1).

| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P0 | `ambience.birds` | ambience (loops) | 0.4 | 'forest birds daytime' / 'countryside birds' | The valley by day; under everything. |
| P0 | `kingdom.build.complete` | sfx | 0.65 | 'construction complete' / 'medieval success' | Building finished: bright wooden/brass flourish under 1.5 s. |
| P0 | `kingdom.build.place` | sfx | 0.55 | 'wood plank drop' / 'place building' | Building placed: solid wooden thunk; confirms the click landed. |
| P0 | `kingdom.capture` | sfx | 0.75 | 'capture flag sting' / 'victory sting short' | Objective captured by us: bright sting with bell; tower recolours at the same moment. |
| P0 | `kingdom.chop` | sfx | 0.45 | 'axe chop wood' | Axe into wood, single hit; plays on a woodcutter's swing near the camera and on ruler gathering. |
| P0 | `kingdom.founded` | sfx | 0.65 | 'kingdom horn' / 'coronation fanfare' | We joined our kingdom: horn call that says 'this is yours'. |
| P0 | `kingdom.hammer` | sfx | 0.4 | 'hammer nails wood construction' | Construction in progress: short hammering bursts while builders work. |
| P0 | `kingdom.harvest` | sfx | 0.45 | 'scythe' / 'wheat harvest' | Wheat cut and gathered (farmers). |
| P0 | `kingdom.mine` | sfx | 0.45 | 'pickaxe stone' | Pickaxe on stone, single hit. |
| P0 | `kingdom.recruit` | sfx | 0.6 | 'war horn short' / 'soldiers ready' | Soldiers recruited: short horn plus armour rattle. |
| P0 | `music.build` | music (loops) | 0.5 | 'medieval town busy' / 'celtic folk upbeat' | Expansion: busier rhythm, light percussion; sounds like growth. |
| P0 | `music.calm` | music (loops) | 0.5 | 'medieval village peaceful' (lute, recorder, 2-4 min loop) | Founding: warm, unhurried folk; no percussion. |
| P0 | `notify.info` | ui | 0.45 | 'soft bell single' | Small hand bell, one strike, 300 ms tail. |
| P0 | `notify.reward` | ui | 0.6 | 'coins pouch' / 'gold coins' | Coins dropping into a pouch, bright and short (under 600 ms). |
| P0 | `notify.warning` | ui | 0.6 | 'war drum hit' / 'low horn short' | Attention without panic: one low drum hit or short low horn. |
| P0 | `onboarding.complete` | ui | 0.65 | 'quest complete medieval' | Tutorial finished: a bigger version of onboarding.step with a short flourish. |
| P0 | `onboarding.step` | ui | 0.5 | 'soft success chime' | Tutorial step done: warm, quiet two-note chime (heard once per tutorial step, several times in the first minutes). |
| P0 | `ui.click` | ui | 0.5 | 'ui click soft' / 'wood tap' | Soft, dry tap under 80 ms; must not tire after 500 presses. |
| P0 | `ui.close` | ui | 0.4 | 'parchment close' / 'book close' | Panel closes: softer, lower mirror of ui.open. |
| P0 | `ui.open` | ui | 0.45 | 'parchment unroll' / 'book open' | Panel opens: short paper/leather swish, 150-250 ms. |
| P1 | `ambience.river` | ambience (loops) | 0.35 | 'river stream gentle' | Played near the river (positional bed placed by FeedbackController). |
| P1 | `ambience.wind` | ambience (loops) | 0.3 | 'wind fields' / 'countryside wind' | Open ground and the overview camera. |
| P1 | `kingdom.capture.lost` | sfx | 0.6 | 'low horn' / 'defeat sting short' | A rival captured an objective: short descending horn. |
| P1 | `kingdom.cheer` | voice | 0.5 | 'crowd cheer small' / 'villagers cheer' | A few citizens cheer (keep level 2, a capture). |
| P1 | `kingdom.deposit` | sfx | 0.4 | 'coins clink' / 'crate drop' | A citizen dropped goods at the storehouse: small clink; coalesced so many deposits do not chatter. |
| P1 | `kingdom.horn.war` | sfx | 0.7 | 'war horn long' / 'battle horn' | Conflict begins, or our lands are raided: long horn; always paired with a warning toast. |
| P1 | `kingdom.keep.upgrade` | sfx | 0.75 | 'royal fanfare short' / 'trumpets' | Keep reached a new level: full royal trumpets, 2-3 s; the biggest moment before a capture. |
| P1 | `kingdom.pickup` | sfx | 0.55 | 'wood pickup' / 'item pickup soft' | The ruler gathered a resource: quick satisfying pickup; pairs with the +N float. |
| P1 | `music.battle` | music (loops) | 0.55 | 'medieval battle epic' / 'war drums' | While our soldiers fight or our lands are attacked: driving drums and brass. |
| P1 | `music.tension` | music (loops) | 0.5 | 'medieval tension' / 'war drums distant' | Conflict and Endgame when not fighting: low strings, distant drums. |
| P1 | `music.victory` | music (loops) | 0.6 | 'victory fanfare medieval' (with a calm loopable tail) | Our kingdom won (or captured the slice objective): fanfare settling into a loop. |
| P1 | `notify.achievement` | ui | 0.7 | 'fanfare short' / 'trumpet flourish' | Two-second brass flourish; the most rewarding UI sound, used sparingly. |
| P1 | `ui.error` | ui | 0.45 | 'wooden thud' / 'denied soft' | Not allowed / not enough resources: low muted knock, never a harsh buzzer. |
| P2 | `celebrate.levelup` | ui | 0.7 | 'level up medieval' / 'harp gliss' | Upward harp/brass gesture, 1-2 s. |
| P2 | `celebrate.streak` | ui | 0.65 | 'bell sequence' / 'chime cascade' | Daily streak: short ascending bell run; pitch can rise with streak length. |
| P2 | `music.defeat` | music (loops) | 0.5 | 'medieval sad' / 'lament' | Match lost: dignified lament, not punishing. |
| P2 | `reward.common` | ui | 0.5 | 'pickup soft' | Short tick; the baseline every other tier rises above. |
| P2 | `reward.epic` | ui | 0.7 | 'epic reveal' / 'choir hit' | Distinct sting: choir or brass swell, about 1.5 s. |
| P2 | `reward.legendary` | ui | 0.8 | 'legendary reveal' / 'royal fanfare' | Unique, story-worthy reveal, 2-3 s; never reused for anything else. |
| P2 | `reward.rare` | ui | 0.6 | 'magic chime' / 'sparkle' | Three-note sparkle with a short shimmer tail. |
| P2 | `reward.uncommon` | ui | 0.55 | 'chime two notes' | Two rising notes. |

## Evidence
- Each sound has an id, category, default volume, licence note and source note. `SoundRegistry.validate` rejects any sound missing one of these:
  - framework list: `roblox/tests/unit/experience/Audio.spec.luau` "accepts the factory list and the sandbox list";
  - game list: `games/game-001/tests/experience/Sounds.spec.luau` "is a valid registry list".
- The same game spec checks that every music state (calm, build, tension, battle, victory, defeat) has a looping track, and that the VS-1 sounds above exist.
- **Unverified:** no sound has been chosen, heard or level-checked yet.

## Next actions for you
1. Choose or upload the P0 sounds and send me the ids.
2. Then P1. P2 can wait until after the first playtest.
