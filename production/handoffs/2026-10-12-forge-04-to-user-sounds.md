# Handoff: forge-04 → user · sounds to choose or upload for AI Kingdoms · FL-0024 · 2026-10-12

## What I need / what I'm giving you
AI Kingdoms needs **53 sounds** (17 needed for the first five minutes). Picking Creator Store sounds or uploading audio requires **your** Roblox account, so FORGE-04 can't do it. The game already runs without them: missing sounds are skipped and counted, and every event also has a visual cue. No money is involved: Creator Store audio is free, and audio imports are free within the monthly quota.

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
Do the 17 **P0** sounds first; they cover the whole tutorial and the first minutes.

## The list (generated from `roblox/src/shared/Experience/Sounds.luau` and `games/game-001/config/Sounds.luau`)
| Priority | Sound id | Category | Default volume | Search the Creator Store for | What it should sound like |
|---|---|---|---|---|---|
| P0 | `ambience.village` | ambience (loops) | 0.45 | 'medieval village ambience' (birds, distant chatter, livestock) | Own kingdom by day: birds, distant chatter, livestock; calm and unobtrusive. |
| P0 | `kingdom.build.complete` | sfx | 0.65 | 'construction complete' / 'medieval success' | Building finished: bright wooden/brass flourish under 1.5 s. |
| P0 | `kingdom.build.place` | sfx | 0.55 | 'wood plank drop' / 'place building' | Building placed: solid wooden thunk; confirms the click landed. |
| P0 | `kingdom.citizen.assign` | voice | 0.5 | 'peasant yes my lord' / 'medieval acknowledgement' | Citizen accepts a task: short vocal acknowledgement (no words needed). |
| P0 | `kingdom.farm.harvest` | sfx | 0.5 | 'scythe' / 'wheat harvest' | Wheat cut and gathered; plays with the harvest VFX and the +Food number. |
| P0 | `kingdom.founded` | sfx | 0.7 | 'kingdom horn' / 'coronation fanfare' | Match start: your kingdom is founded; horn call that says 'this is yours'. |
| P0 | `kingdom.upgrade.fanfare` | sfx | 0.75 | 'royal fanfare short' / 'trumpets' | Kingdom tier up: full royal trumpets, 2-3 s; the biggest non-victory moment. |
| P0 | `music.build` | music (loops) | 0.5 | 'medieval town busy' / 'celtic folk upbeat' | Development: busier rhythm, light percussion; sounds like growth. |
| P0 | `music.calm` | music (loops) | 0.5 | 'medieval village peaceful' (lute, recorder, 2-4 min loop) | Opening/early development: warm, unhurried folk; no percussion. |
| P0 | `notify.info` | ui | 0.45 | 'soft bell single' | Small hand bell, one strike, 300 ms tail. |
| P0 | `notify.reward` | ui | 0.6 | 'coins pouch' / 'gold coins' | Coins dropping into a pouch, bright and short (under 600 ms). |
| P0 | `notify.warning` | ui | 0.6 | 'war drum hit' / 'low horn short' | Attention without panic: one low drum hit or short low horn. |
| P0 | `onboarding.complete` | ui | 0.65 | 'quest complete medieval' | Tutorial finished: a bigger version of onboarding.step with a short flourish. |
| P0 | `onboarding.step` | ui | 0.5 | 'soft success chime' | Tutorial step done: warm, quiet two-note chime (heard up to 9 times in 5 minutes). |
| P0 | `ui.click` | ui | 0.5 | 'ui click soft' / 'wood tap' | Soft, dry tap under 80 ms; must not tire after 500 presses. |
| P0 | `ui.close` | ui | 0.4 | 'parchment close' / 'book close' | Panel closes: softer, lower mirror of ui.open. |
| P0 | `ui.open` | ui | 0.45 | 'parchment unroll' / 'book open' | Panel opens: short paper/leather swish, 150-250 ms. |
| P1 | `ambience.battlefield` | ambience (loops) | 0.5 | 'battle ambience distant' | Distant clashes and shouts while a battle runs nearby. |
| P1 | `ambience.wind` | ambience (loops) | 0.35 | 'wind fields' / 'countryside wind' | Open land between kingdoms; under everything at low volume. |
| P1 | `kingdom.alarm.bell` | sfx | 0.7 | 'church bell alarm' / 'warning bell' | Your town is under attack: fast bell strikes; always paired with a warning toast. |
| P1 | `kingdom.army.recruit` | sfx | 0.6 | 'war horn short' / 'soldiers ready' | Units recruited: short horn plus armour rattle. |
| P1 | `kingdom.citizen.cheer` | voice | 0.55 | 'crowd cheer small' / 'villagers cheer' | A few citizens cheer (building done, festival, battle won). |
| P1 | `kingdom.citizen.grumble` | voice | 0.45 | 'crowd murmur unhappy' | Low morale: discontented murmur. |
| P1 | `kingdom.citizen.panic` | voice | 0.55 | 'villagers scream run' (mild) | Town attacked: citizens flee indoors; urgent but not gory. |
| P1 | `kingdom.combat.arrows` | sfx | 0.5 | 'arrow volley' | Arrow volley whoosh. |
| P1 | `kingdom.combat.clash` | sfx | 0.55 | 'sword clash' / 'melee battle' | Melee clash; several variants via pitch. |
| P1 | `kingdom.gold.collect` | sfx | 0.55 | 'coins clink' | Gold income / tax collected: a few coins. |
| P1 | `kingdom.siege.breach` | sfx | 0.8 | 'wall collapse' / 'gate break' | Walls breached: long collapse rumble; marks the turning point of a siege. |
| P1 | `kingdom.siege.impact` | sfx | 0.75 | 'stone impact wall' / 'boulder crash' | Projectile hits a wall: heavy stone crunch with debris tail. |
| P1 | `kingdom.siege.launch` | sfx | 0.6 | 'catapult launch' / 'trebuchet' | Siege engine fires: wooden creak and release. |
| P1 | `kingdom.stone.mine` | sfx | 0.5 | 'pickaxe stone' | Pickaxe on stone, single hit. |
| P1 | `kingdom.territory.gain` | sfx | 0.6 | 'flag raise' / 'banner flap + bell' | Region claimed: banner flap and one bright bell. |
| P1 | `kingdom.territory.lost` | sfx | 0.6 | 'low horn' / 'defeat sting short' | Region lost: short descending horn. |
| P1 | `kingdom.wood.chop` | sfx | 0.5 | 'axe chop wood' | Axe into wood, single hit. |
| P1 | `music.battle` | music (loops) | 0.55 | 'medieval battle epic' / 'war drums' | Conflict: battle or siege involving the player; driving drums and brass. |
| P1 | `music.defeat` | music (loops) | 0.5 | 'medieval sad' / 'lament' | Match lost: dignified lament, not punishing; short loop under the results screen. |
| P1 | `music.tension` | music (loops) | 0.5 | 'medieval tension' / 'war drums distant' | Competition: rivals near the border; low strings and distant drums. |
| P1 | `music.victory` | music (loops) | 0.6 | 'victory fanfare medieval' (with a calm loopable tail) | Match won: triumphant fanfare that settles into a celebratory loop. |
| P1 | `notify.achievement` | ui | 0.7 | 'fanfare short' / 'trumpet flourish' | Two-second brass flourish; the most rewarding UI sound, used sparingly. |
| P2 | `celebrate.levelup` | ui | 0.7 | 'level up medieval' / 'harp gliss' | Upward harp/brass gesture, 1-2 s. |
| P2 | `celebrate.streak` | ui | 0.65 | 'bell sequence' / 'chime cascade' | Daily streak: short ascending bell run; pitch can rise with streak length. |
| P2 | `kingdom.army.march` | sfx | 0.4 | 'army marching footsteps' | Marching column; burst when an order is given. |
| P2 | `kingdom.build.hammer` | sfx | 0.4 | 'hammer nails wood construction' | Construction in progress: hammering, played in short bursts while a site is active. |
| P2 | `kingdom.event.festival` | sfx | 0.6 | 'medieval festival' / 'tavern celebration' | Festival starts: drums, pipes and cheering. |
| P2 | `kingdom.event.threat` | sfx | 0.6 | 'ominous drone short' / 'plague bell' | Plague, drought or raid begins: ominous low sting. |
| P2 | `kingdom.morale.down` | sfx | 0.5 | 'negative sting soft' | Morale fell a band: soft falling tone. |
| P2 | `kingdom.morale.up` | sfx | 0.5 | 'positive chime warm' | Morale rose a band: warm chime with distant cheer. |
| P2 | `reward.common` | ui | 0.5 | 'pickup soft' | Short tick; the baseline every other tier rises above. |
| P2 | `reward.epic` | ui | 0.7 | 'epic reveal' / 'choir hit' | Distinct sting: choir or brass swell, about 1.5 s. |
| P2 | `reward.legendary` | ui | 0.8 | 'legendary reveal' / 'royal fanfare' | Unique, story-worthy reveal, 2-3 s; never reused for anything else. |
| P2 | `reward.rare` | ui | 0.6 | 'magic chime' / 'sparkle' | Three-note sparkle with a short shimmer tail. |
| P2 | `reward.uncommon` | ui | 0.55 | 'chime two notes' | Two rising notes. |
| P2 | `ui.error` | ui | 0.45 | 'wooden thud' / 'denied soft' | Not allowed / not enough resources: low muted knock, never a harsh buzzer. |

## Evidence
- Each sound has an id, category, default volume, licence note and source note. Spec `Audio.spec.luau` "accepts the factory list and both game lists" rejects any sound missing one of these.
- "every music state has a registered track" checks that all music states (calm, build, tension, battle, victory, defeat) have a sound.
- **Unverified:** no sound has been chosen, heard or level-checked yet.

## Next actions for you
1. Choose or upload the P0 sounds and send me the ids.
2. Then P1. P2 can wait until after the first playtest.
