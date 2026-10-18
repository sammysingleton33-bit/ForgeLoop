# Art sourcing brief for the Crownfall visual upgrade (D-057), 2026-10-18

_Source: a FORGE-00 research workflow of 5 researchers, each re-checked by an independent skeptic, plus a synthesis. Web search and GitHub mirrors only, because the agent proxy blocks kenney.nl, quaternius.com and itch.io. Every claim keeps the confidence its verifier gave it. FORGE-00 checked one point first-hand afterwards: the official KayKit GitHub repos (`github.com/KayKit-Game-Assets/*`) can be cloned from the cloud container, and their LICENSE.txt reads **CC0**._

## Director's addendum (FORGE-00, verified first-hand)
- `git ls-remote` works for `KayKit-Character-Pack-Adventures-1.0`, `KayKit-Character-Pack-Skeletons-1.0`, `KayKit-Medieval-Hexagon-Pack-1.0` and `KayKit-Dungeon-Remastered-1.0`. Their LICENSE.txt (raw.githubusercontent.com) says *Creative Commons Zero, CC0*, and crediting Kay Lousberg is optional.
- **Consequence:** a medieval CC0 source is reachable **without any owner download**. KayKit becomes the primary candidate for characters and medieval pieces, pending the one D-019 render comparison. Kenney (owner download) is an optional supplement.
- Quaternius: its site now shows QAL v1.0, which bans redistribution (*likely*). Don't commit Quaternius files.

---

{
  "summary": "Verify licenses, reachability and Roblox technical paths for upgrading AI Kingdoms art with prebuilt assets",
  "agentCount": 11,
  "logs": [],
  "result": {
    "synthesis": "# AI Kingdoms asset brief for FORGE-00 (2026-10-18)\n\n## A. Sources and style\n**Style: Kenney low-poly, flat-shaded, a 512² palette atlas or flat colours.** Lock it only after an aerial and portrait bpy render; none exists yet.\n\n| Source | Use | Licence | Public repo |\n|---|---|---|---|\n| Kenney Mini Characters, Castle, Fantasy Town 2.0, Nature, Survival kits | citizens, buildings, crops, trees, rocks, tools | CC0, confirmed in mirrored [License.txt](https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-castle-kit/3D/fantasy/License.txt) copies; Kenney publishes CC0 models on [GitHub](https://raw.githubusercontent.com/KenneyNL/Starter-Kit-City-Builder/main/README.md) himself | **Yes**: edited meshes, palettes, License.txt, provenance (URL, date, sha256). No Kenney logo |\n| Quaternius flat-colour packs (Fantasy RTS, Crops) | gap-fill only, after a style check | CC0 per [showcase](https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/LICENSES.md) (likely). The site shows QAL v1.0, which bans redistribution (likely); its scope is unresolved ([loki #322](https://github.com/ImDarkly/loki/issues/322)) | Raw zips: **no** (gitignored cache). Derived meshes: owner decides. Bestiary (QAL): never |\n| Synty | no | [One-Time EULA](https://syntystore.com/pages/one-time-purchase-licence) likely bans \"Game Creation Software\" content; SyntyPass is revocable | Never |\n| Creator Store, templates, NPC Kit | avoid | Roblox only; you may distribute only what you created ([docs](https://create.roblox.com/docs/production/creator-store), [Limited Use](https://create.roblox.com/docs/resources/limited-use-license)) | Never |\n\nKenney characters aren't medieval (likely); crowns, capes and armour get made in Blender. Fallback if the render test fails: KayKit ([CC0, confirmed](https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/LICENSE.txt)).\n\n## B. Citizens\n**Recommended: rigid MeshPart segments on the existing Motor6D tree, animated procedurally through Motor6D.Transform on clients** ([perf](https://create.roblox.com/docs/performance-optimization/improve), [Motor6D](https://create.roblox.com/docs/reference/engine/classes/Motor6D)).\n- Mini Characters (measured): 723–876 tris on a 7-joint rig that mirrors our tree. Skinning is rigid (2 of 12 checked), so a 6-part split is lossless.\n- Parts sharing MeshContent and TextureContent are instanced into one draw call.\n- Skinned bones: portrait or hero characters only. LOD reportedly skips skinned meshes (likely), and skinned instancing is undocumented.\n- EditableMesh: no. It needs an owner toggle, the client memory budget is unpublished, it doesn't replicate, and it is capped at 20k tris / 60k verts ([ref](https://create.roblox.com/docs/reference/engine/classes/EditableMesh)).\n- Limits ([specs](https://create.roblox.com/docs/art/modeling/specifications)): 20k tris per mesh, ≤4 influences per vertex, frozen bones, one material per mesh.\n\n**Budget (working figure, unmeasured):** ≤1,000 tris per citizen (body ≤900, tool ≤150). That is about 150k tris on screen (150) and 300k in total (300); today a citizen is about 132. No per-citizen textures, PBR or normal maps. Each kingdom gets one 512² palette (TextureID swap), or all share one atlas tinted with MeshPart.Color.\n\n**Pipeline:** Blender export with embedded textures → Studio Importer → .rbxm → Rojo `$path`. Kenney's external texture files have been [reported colourless](https://itch.io/t/5208814/kenney-assests-not-uploading-in-color-on-roblox), hence the embedding.\n\n## C. Owner actions (3 sittings, $0)\n1. **Browser (15 min):** download the free zips from `kenney.nl/assets/{mini-characters,castle-kit,fantasy-town-kit,nature-kit,survival-kit}`, save https://quaternius.com/license.html as a PDF, and upload them all to the session. Our proxy blocks these hosts.\n2. **Roblox settings (5 min):** confirm whether a user or a group owns the experience. Before any upload, enable [Asset Privacy](https://create.roblox.com/docs/projects/assets/privacy); it is not retroactive, and Open Use is irreversible. Keep \"Allow Loading Third Party Assets\" off.\n3. **Studio (1 h):** import FORGE's files and export .rbxm per the handoff. Run the 300-citizen stress test on a real phone (Render Stats, FPS) and take aerial and portrait screenshots.\n\nNo purchases or API keys needed.\n\n## D. Creator Store safety\n- Default: don't use it. Our own exports contain no scripts.\n- Approved exceptions, in a scratch place only:\n  - check the script count;\n  - set SandboxedInstanceMode = Experimental and Sandboxed = true;\n  - delete all scripts;\n  - search for `require(`, `loadstring`, `getfenv`, `LoadAsset`, `HttpService` and obfuscated or whitespace-padded code ([guide](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities)).\n- Popularity and verification aren't safety signals. No runtime loading, no scanner plugins.\n- Never commit store content or meshes extracted from it.\n\n## E. Risks and unverified items\n1. 300-citizen performance is unmeasured, so every budget above is provisional.\n2. Visuals are unrendered: clothing, portrait readability, and character scale (about 0.7 units vs 1-unit kits).\n3. QAL scope over downloads after 2026-08-28.\n4. Importer behaviour: .glb, external textures, meshes over 20k tris, multi-material splits.\n5. Kenney licences were read only in mirrors, the zip hashes come from third parties, and the 2026-03-29 Mini Characters re-upload is unchecked.\n6. That MeshPart.Color keeps instancing is a community report only; bilinear TextureID filtering may make palette colours bleed.\n7. Roblox's terms for free store assets; Rojo-built MeshPart sizing.",
    "findings": [
      {
        "topic": "Skeptic re-check: Quaternius licences (CC0 vs QAL v1.0), redistribution, prices, measured mesh/rig data, download sources and public-repo commits for AI Kingdoms (Roblox)",
        "claims": [
          {
            "claim": "ACCESS NOTE, CONFIRMED by my own run on 2026-10-18. WebFetch failed with ENOTFOUND for quaternius.com/license.html, quaternius.itch.io, patreon.com, x.com, opengameart.org, app.cinevva.com, creativecommons.org and create.roblox.com. curl through the proxy got 'CONNECT tunnel failed, response 403' for quaternius.com and quaternius.itch.io; the proxy log called these 'connect_rejected'. These worked: raw.githubusercontent.com, media.githubusercontent.com (LFS objects), anonymous git clone of public github.com repos, and WebFetch of github.com issue pages. The GitHub MCP and API were limited to the owner's two repos. Everything below about Quaternius-owned pages therefore comes from search snippets or GitHub mirrors. I downloaded nothing from Quaternius directly.",
            "source_urls": [
              "https://quaternius.com/license.html",
              "https://quaternius.itch.io/",
              "https://poly.pizza/u/Quaternius"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "QAL v1.0 EXISTS, LIKELY; I re-checked it from a search snippet of the page itself. A search hit for quaternius.com/license.html shows the title 'Quaternius • Quaternius Asset License (QAL)', the heading 'Quaternius Asset License (QAL) v1.0' and 'Last updated: 8/28/2026'. The snippet says use is free of charge in personal, educational and commercial games and other projects, with no credit required, but the assets themselves may not be resold or redistributed. It also says changes do not apply retroactively to Assets already obtained under an earlier version. CONFIRMED as a third-party quote only: homie RIGHTS.md (page read 2026-10-03) quotes 'No attribution is required' and the ban on 'extract, repackage, sublicense, sell, or otherwise redistribute the Assets (in original or modified form) as a standalone asset, asset pack, stock file, template, or similar product'. The exact phrase 'the version in effect at the time you obtained the Assets governs' appears only in TMHSDigital PR #58 (page read 2026-10-04). I could not read it first-hand, so that wording is UNVERIFIED. Per search summaries the page also says that shipping a finished product which incorporates the assets is not restricted. NOT VERIFIED: which packs or downloads the QAL claims to cover.",
            "source_urls": [
              "https://quaternius.com/license.html",
              "https://raw.githubusercontent.com/homie-rocks/homie/main/plugins/homie/skills/animate/references/RIGHTS.md",
              "https://github.com/TMHSDigital/Free-Game-Dev-Assets/pull/58",
              "https://raw.githubusercontent.com/TMHSDigital/Free-Game-Dev-Assets/main/catalog/animation/quaternius-animated-men-pack.md"
            ],
            "confidence": "likely"
          },
          {
            "claim": "NOT EVERY PACK IS CC0. Two parts were checked separately. (1) OpenAgents keeps Bestiary sources out of its public repo: CONFIRMED first-hand. Its README says the Bestiary – Dungeon Monsters Kit 'uses Quaternius Asset License v1.0 … restricts standalone asset redistribution. Its source files are not retained in this public repository', while the same directory keeps its CC0 packs. (2) The itch page label: LIKELY, from search snippets only. They say the Bestiary itch page is marked '(QAL License)' and that it is the only QAL-labelled itch page the search surfaced. Other snippet details: 7 rigged enemies in 3 colour variations, compatible with the Universal Animation Library, no animations, released around August 2026, name-your-own-price, Standard download 45 MB, full package $20+.",
            "source_urls": [
              "https://quaternius.itch.io/bestiary-dungeon-monsters-kit",
              "https://quaternius.com/packs/bestiarydungeonmonsterskit.html",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/README.md"
            ],
            "confidence": "likely"
          },
          {
            "claim": "CC0 LABELS PERSIST, LIKELY. CONFIRMED first-hand: trebeljahr/quaternius-showcase LICENSES.md ('Last checked against quaternius.com: 2026-10-10') lists 32 packs as CC0-1.0. It says 'The \"License\" link in the quaternius.com header now opens the QAL page' and 'each of their source pages still names CC0'. It also says those packs were copied from quaternius.com in December 2022 and that some packs have been updated since. CONFIRMED as a third-party quote: TMHSDigital catalog entries quote the live FAQ (2026-10-04) as 'All models are under the CC0 License.' CANNOT VERIFY the extra FAQ wording 'credit is appreciated, never required'. LIKELY, from search snippets: these itch pages list CC0 — Medieval Village MegaKit ('Creative Commons Zero v1.0 Universal'), Fantasy Props MegaKit, Stylized Nature MegaKit, Universal Base Characters, Modular Character Outfits – Fantasy, Universal Animation Library (latest update Jun 16 2026) and UAL2. The Quaternius X post 'I make free asset packs with a CC0 license…' (status 1559299393177747456) appears in a search snippet. CONFIRMED in mirrors: License.txt files read CC0 for the Ultimate Animated Character Pack (two independent repos), Universal Base Characters, Outfits – Fantasy and UAL2 Standard.",
            "source_urls": [
              "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/LICENSES.md",
              "https://raw.githubusercontent.com/TMHSDigital/Free-Game-Dev-Assets/main/catalog/animation/quaternius-animated-men-pack.md",
              "https://quaternius.itch.io/medieval-village-megakit",
              "https://quaternius.itch.io/universal-animation-library",
              "https://x.com/quaternius/status/1559299393177747456",
              "https://quaternius.com/faq.html"
            ],
            "confidence": "likely"
          },
          {
            "claim": "VERBATIM License.txt: CONFIRMED, WITH A CORRECTION. The three OpenAgents files each read 'License: CC0 1.0 Universal (CC0 1.0) Public Domain Dedication https://creativecommons.org/publicdomain/zero/1.0/ … Models by @Quaternius'. Correction: the OpenAgents README says the animation licence file comes from the Standard edition of Universal Animation Library 2, not UAL1. Only base-license.txt and outfits-license.txt say the Standard edition holds 'a portion of the models'. base-license.txt describes the SOURCE version as having 'all the models with rigged .blends, and Unity(URP), Unreal Engine and Godot projects with custom shaders already set up'. The UACP mirror License.txt (both repos) reads 'LowPoly Models by @Quaternius … License: CC0 1.0 Universal (CC0 1.0) Public Domain Dedication'.",
            "source_urls": [
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/base-license.txt",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/outfits-license.txt",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/animations-license.txt",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/README.md",
              "https://github.com/BMOxOMB/Proyecto_ProgramacionConPatrones"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "OTHER PROJECTS' POLICIES: CONFIRMED by WebFetch of each issue. ImDarkly/loki #322 (opened Oct 14, 2026): 'Quaternius Asset License v1.0 (Aug 28, 2026) prohibits redistributing raw asset files' and 'Our packs were downloaded after that date and a public repo is public distribution'. It keeps in-game use and local copies. asvirts/aenon #41 (Oct 11, 2026): the QAL was posted on 2026-08-28 'while its pack pages and the License.txt inside the downloads still say CC0'. It rules: use an archive only if its own License.txt grants CC0, commit that file beside the assets, and record the download date and the conflicting site notice; otherwise fall back to KayKit. Kiikurage/game-test #10 (Oct 9, 2026): CC0 only, no Mixamo or QAL; re-check the bundled *-license.txt. michaelcrosato/riftlight #49 (Oct 12, 2026): 'QAL packs are not allowed. Only its CC0 packs are.' These are project opinions, not legal rulings.",
            "source_urls": [
              "https://github.com/ImDarkly/loki/issues/322",
              "https://github.com/asvirts/aenon/issues/41",
              "https://github.com/Kiikurage/game-test/issues/10",
              "https://github.com/michaelcrosato/riftlight/issues/49"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "ULTIMATE ANIMATED CHARACTER PACK CONTENTS: LIKELY. CONFIRMED in the mirror BMOxOMB/Proyecto_ProgramacionConPatrones: folder 'Ultimate Animated Character Pack - Nov 2019' with Blends/, FBX/ (50 .fbx) and glTF/ (52 .gltf) and a CC0 License.txt. The 52 glTFs are 46 humanoids plus Cow, Pug and 4 hat/hair props (Chef_Hat, Cowboy_Hair, Ninja_Male_Hair, VikingHelmet). The FBX folder lacks Goblin_Male and Knight_Male. Humanoids: BaseCharacter, BlueSoldier F/M, Casual/Casual2/Casual3 F/M, Casual_Bald, Chef F/M, Cowboy F/M, Doctor (4), Elf, Goblin F/M, Kimono F/M, Knight_Male, Knight_Golden F/M, Ninja (4), OldClassy F/M, Pirate F/M, Soldier F/M, Suit F/M, Viking F/M, Witch, Wizard, Worker F/M, Zombie F/M. A third-party catalog (TMHSDigital, 2026-10-04) quotes the pack page: 52 models, FBX/OBJ/Blend, CC0. CANNOT VERIFY: the quaternius.com pack page, the Patreon post, or the Google Drive folder ID (an exact-ID search found nothing; Patreon is unreachable).",
            "source_urls": [
              "https://quaternius.com/packs/ultimatedanimatedcharacter.html",
              "https://github.com/BMOxOMB/Proyecto_ProgramacionConPatrones",
              "https://raw.githubusercontent.com/TMHSDigital/Free-Game-Dev-Assets/main/catalog/animation/quaternius-ultimate-animated-character-pack.md",
              "https://www.patreon.com/posts/ultimate-pack-31403272"
            ],
            "confidence": "likely"
          },
          {
            "claim": "UACP MEASUREMENTS: CONFIRMED; I downloaded the LFS objects from media.githubusercontent.com and parsed them myself. Knight_Golden_Male.gltf sha256 96b5ac2f7b46fd279bc28bb9eda54a9e1d8d6aa2ffded19fbeb33d3e7c09265f, the same LFS oid in dancerphil/games and BMOxOMB. Each character is 1 skinned mesh with 23 joints: Bone, Body, Hips, Abdomen, Torso, Neck, Head, Shoulder/UpperArm/LowerArm/Fist .L/.R, UpperLeg/LowerLeg/Foot .L/.R, PoleTarget.L/.R. There are 0 textures. Materials: Worker Skin/Shirt/Vest/Pants/Hat/Face; Golden Knight Skin/Armor/Armor_Dark/Detail/Red; Viking Skin/Light/Main/Pants/Hair/Face. Each embeds the same 17 clips (Death, Defeat, Idle, Jump, PickUp, Punch, RecieveHit, Roll, Run, Run_Carry, Shoot_OneHanded, SitDown, StandUp, SwordSlash, Victory, Walk, Walk_Carry). Triangles: Worker_Male 2,524, Knight_Golden_Male 2,964, Viking_Male 6,264. Skin uses JOINTS_0 only, so at most 4 influences per vertex. The glTF generator string is 'Khronos glTF Blender I/O v1.6.16' (a 2021-era exporter), so the glTF folder was probably added after the Nov 2019 release; the FBX files were not measured.",
            "source_urls": [
              "https://github.com/dancerphil/games/tree/main/shared/models/characters",
              "https://github.com/BMOxOMB/Proyecto_ProgramacionConPatrones"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "MODULAR MEN/WOMEN MEASUREMENTS: CONFIRMED; I re-measured the trebeljahr GLBs and every number matched. Men use 49 joints and Women 51; materials are flat colours with 0 textures. Each character is 4 skinned meshes (Men Adventurer has 5, including a Backpack). Triangles: Farmer 5,476, Worker 5,240, Adventurer 10,198, King 11,100; Women Medieval 6,404, Witch 6,900, Soldier 7,900, Adventurer 6,796. The GLBs have 0 animations and the generator string is 'FBX2glTF v0.9.7'. Caveat on the stated cause: 'the converter dropped the clips' is an inference. The Knight GLB, made with the same converter, kept its 12 clips. Pack page text: CONFIRMED only for Women, from the BlenderNation Bazaar snippet (10 characters, 24 animations, '4 models that can be swapped', humanoid-rig version, FBX/OBJ/glTF/Blend). The Men pack page was not seen; a 3DPixel listing calls both CC0. The mirror copies date from December 2022.",
            "source_urls": [
              "https://github.com/trebeljahr/quaternius-showcase/tree/main/public/glb/modular_men",
              "https://bazaar.blendernation.com/listing/ultimate-modular-women-pack/",
              "https://quaternius.com/packs/ultimatemodularcharacters.html",
              "https://quaternius.com/packs/ultimatemodularwomen.html"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "ANIMATED KNIGHT: CONFIRMED by re-measurement. KnightCharacter.glb is 1 skinned mesh of 956 tris with 31 joints and 12 clips (Death, Idle, Idle_swordLeft/Right, Jump, Roll, Roll_sword, Run, Run_swordAttack, Run_swordRight, swordAttackJump, Walking). Materials: Armor, Boots, Skin. Separate props: Helmet1–3, ShoulderPads, Sword, ShortSword, Katana, Club. itch lists it as 'LowPoly Animated Knight' under CC0 (snippet).",
            "source_urls": [
              "https://github.com/trebeljahr/quaternius-showcase/tree/main/public/glb/single_knight_pack",
              "https://quaternius.itch.io/lowpoly-animated-knight",
              "https://quaternius.com/packs/knightcharacter.html"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "UNIVERSAL BASE + OUTFITS – FANTASY MEASUREMENTS: CONFIRMED; I re-measured the OpenAgents glTFs. The skeleton has 65 joints in UE-mannequin style (root, pelvis, spine_01–03, neck_01, Head, clavicle/upperarm/lowerarm/hand with full finger chains, thigh/calf/foot/ball). Materials are PBR with base-colour, metallic-roughness and normal maps. Triangles: Superhero_Male 14,318, Superhero_Female 15,060, Male_Peasant 12,894, Female_Peasant 13,568, Male_Ranger 26,982, Female_Ranger 26,966; hair and eyebrows 830–3,284. Correction: Ranger outfits are 9 skinned meshes, adding Arms_Bracer and two Belt meshes beyond Arms/Body/Legs/Feet/Hood/Pauldron. The largest single Ranger part is Male_Ranger_Feet_Boots at 9,172 tris. The skin is limited to 4 influences per vertex. These are OpenAgents re-exports (generator 'Khronos glTF Blender I/O v4.3.47', textures normalised), not the original zip files. The outfit README text is confirmed.",
            "source_urls": [
              "https://github.com/OpenAgentsInc/openagents/tree/main/assets/verse/characters/quaternius",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/outfits-readme.txt"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "UNIVERSAL BASE / OUTFITS TIERS AND PRICES: LIKELY, from itch search snippets only. Universal Base Characters: 'Average 13k tris'; Standard zip 122 MB; Source about 600 MB at $19.99+. Correction: Modular Character Outfits – Fantasy Source is $20+ (688–725 MB in different cached pages), not $19.99. Outfits has 12 outfits from 62 modular parts, with changelog v2.0 dated 29/1/2026. Release sales of 25% have been seen, so prices vary.",
            "source_urls": [
              "https://quaternius.itch.io/universal-base-characters",
              "https://quaternius.itch.io/universal-base-characters/purchase",
              "https://quaternius.itch.io/modular-character-outfits-fantasy/purchase",
              "https://itch.io/s/159068/universal-base-characters-release-sale"
            ],
            "confidence": "likely"
          },
          {
            "claim": "UNIVERSAL ANIMATION LIBRARY 1 & 2: LIKELY, PARTLY CORRECTED. CONFIRMED from snippets and mirrors: 120+ (UAL1) and 130+ (UAL2) clips, CC0, a 'universal humanoid rig', 'compatible with other common rigs (Mixamo for example)', GLB for Unreal/Godot, FBX for Unity, .blend in Source. The _RM root-motion file and the non-RM file are confirmed by the bundled readme and by tilakverse (UAL1.glb and UAL1_RM.glb). UAL1 Standard holds 45 clips (OpenGameArt/Godot store snippet). UAL1 tiers: Pro $9.99, Source $14.99, changelog v2.0 23/1/2026 and v2.1 4/2/2026. UAL2: Standard 9.7 MB, Source $14.99 (30 MB); 80.lv says Standard is about 70% of the pack. CONTRADICTED IN PART: OpenAgents' remark that 'the Standard library has no dedicated run, bow, death, or magic-casting clips' describes its retained UAL2 Standard subset of 43 clips. The OpenGameArt and Godot store descriptions say UAL1 Standard includes death animations, jog and sprint. The clips Sword_Regular_A/B/C, Sword_Block and Hit_Knockback are confirmed in OpenAgents animations.json, and Walk_Loop and Jog_Fwd_Loop in its README. CANNOT VERIFY 'Death01', 'Sprint' or 'Roll' as exact clip names.",
            "source_urls": [
              "https://quaternius.itch.io/universal-animation-library",
              "https://quaternius.itch.io/universal-animation-library-2",
              "https://opengameart.org/content/universal-animation-library",
              "https://store.godotengine.org/asset/quaternius/universal-animation-library/",
              "https://raw.githubusercontent.com/OpenAgentsInc/openagents/main/assets/verse/characters/quaternius/animations-readme.txt",
              "https://raw.githubusercontent.com/tilakpatell/tilakverse-assets/main/README.md",
              "https://80.lv/articles/get-this-animation-asset-library-with-over-130-diverse-items"
            ],
            "confidence": "likely"
          },
          {
            "claim": "MEDIEVAL VILLAGE MEGAKIT: LIKELY, from snippets. The quaternius.com page lists 'Models 304'; its licence field was blank in the snippet. itch lists CC0 1.0 with tiers Standard 153 MB (pay what you want), Pro $9.99+ (291 MB) and Source $14.99+ (675 MB; Unity URP, Unreal and Godot). The OpenGameArt Standard has 176 models, but its zip is about 100 MB, which suggests an older build. The Godot store lists FBX/OBJ/glTF and says Standard has no Godot project. Patreon Silver gives one Source key per month (site snippet). NOT VERIFIED: the 'interior and exterior faces' and 'grid-sized' details, and the wear-colour shaders.",
            "source_urls": [
              "https://quaternius.com/packs/medievalvillagemegakit.html",
              "https://quaternius.itch.io/medieval-village-megakit/purchase",
              "https://opengameart.org/node/174568",
              "https://store.godotengine.org/asset/quaternius/medieval-village-megakit/"
            ],
            "confidence": "likely"
          },
          {
            "claim": "FANTASY PROPS MEGAKIT: LIKELY, CORRECTED. 200+ props, CC0. The OpenGameArt Standard has 94 models (zip about 73.7 MB). itch lists Standard 143 MB, Pro $9.99+ (249 MB; the earlier finding left this tier out) and Source $14.99+ (545 MB; engine projects, collisions and worn texture variants). An itch sale has listed MegaKits at 50% off.",
            "source_urls": [
              "https://quaternius.itch.io/fantasy-props-megakit",
              "https://opengameart.org/content/fantasy-props-megakit",
              "https://itch.io/s/157561/fantasy-megakit-sale"
            ],
            "confidence": "likely"
          },
          {
            "claim": "STYLIZED NATURE MEGAKIT: LIKELY, from snippets. 40 trees, 35 plants and flowers, 27 rocks, plus grass and bushes; 110+ models (the site says 116); all textured. A quaternius.com snippet confirms 'tree leaves can be swapped between 7 different varieties'. CC0. Standard 99 MB (OpenGameArt: 68 models, about 104 MB), Pro $9.99 (172 MB), Source $14.99 (684 MB).",
            "source_urls": [
              "https://quaternius.itch.io/stylized-nature-megakit",
              "https://quaternius.com/packs/stylizednaturemegakit.html",
              "https://opengameart.org/content/stylized-nature-megakit"
            ],
            "confidence": "likely"
          },
          {
            "claim": "OLDER FLAT-COLOUR PACKS: LIKELY; contents CONFIRMED in the Dec-2022 showcase mirror, pack pages not read. Ultimate Fantasy RTS: 128 GLBs covering Archery, Barracks, Farm (+_Wheat), Houses (3 types), Market, Mine, Port, Dock, Storage, Temple, TowerHouse, TownCenter, Wall, WallTowers (+Door/DoorClosed), WatchTower, Windmill, Wonder/WonderWalls in First/Second Age and Level 1–3 variants, plus Resource trees, rocks and gold, mountains, crates and logs. The mirror holds no unit characters. Crops: 102 GLBs; each crop has 4 numbered stages plus a '_Crop' item, and many also have '_Harvested'. A Patreon snippet says 5 stages and 100+ models, CC0. Ultimate Nature: 150 GLBs (Birch, Common and Pine trees with Autumn, Dead and Snow variants). Medieval Village Pack: 44 GLBs, all named items present. Modular Medieval Buildings: 30 GLBs (towers, walls, WallEntrance, Door, Banner, Bridge, Watchtower). RPG: 106 GLBs (Crown, Crown2, Armor_* variants, chests, coins). Medieval Weapons: 24 GLBs (swords, axes, Scythe, Spear, 5 shields, 4 bows). Licence for all: CC0-1.0 per showcase LICENSES.md (2026-10-10).",
            "source_urls": [
              "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/LICENSES.md",
              "https://github.com/trebeljahr/quaternius-showcase/tree/main/public/glb",
              "https://www.patreon.com/posts/33407069",
              "https://quaternius.com/packs/ultimatefantasyrts.html"
            ],
            "confidence": "likely"
          },
          {
            "claim": "OLDER-PACK TRIANGLE COUNTS: CONFIRMED; all 17 values reproduced exactly by my own parse: Houses_FirstAge_1_Level1 404, Wall_FirstAge 404, Resource_Tree1 552, Farm_FirstAge_Level1_Wheat 5,174, TownCenter_SecondAge_Level3 11,830, Wheat_4 102, Corn_4 958, PineTree_1 1,911, CommonTree_1 2,888, Rock_1 28, MarketStand_1 1,548, House_1 5,758, Blacksmith 7,659, Banner 56, Wall 108, LargeTower 576, Crown 592, Sword 872. Each is 1 mesh with 0 textures and named flat-colour materials (e.g. Blacksmith has 8 slots). These are FBX2glTF v0.9.7 conversions made in December 2022, so current downloads may differ.",
            "source_urls": [
              "https://github.com/trebeljahr/quaternius-showcase/tree/main/public/glb"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "POLY PIZZA: LIKELY, from search snippets only. The artist page lists '1411' free models by Quaternius, downloadable as FBX and OBJ+GLTF with no login. The sampled listings (Animated Human, Dragon, Fox) show 'Public Domain (CC0)'. Poly Pizza as a whole hosts mixed licences (some CC-BY), so check each listing.",
            "source_urls": [
              "https://poly.pizza/u/Quaternius",
              "https://poly.pizza/m/c3Ibh9I3udk",
              "https://poly.pizza/m/ZSYgIuHfYb",
              "https://flat.social/credits"
            ],
            "confidence": "likely"
          },
          {
            "claim": "DOWNLOAD SOURCES: LIKELY. The itch pay-what-you-want model with a free Standard tier and paid Pro/Source tiers ($9.99–$20) is confirmed by snippets. The Patreon Silver tier gives one Source key per month (snippet). OpenGameArt and the Godot Asset Store carry Standard editions (snippets). CANNOT VERIFY that older pack pages link to Google Drive.",
            "source_urls": [
              "https://quaternius.itch.io/",
              "https://quaternius.com/packs/medievalvillagemegakit.html",
              "https://store.godotengine.org/asset/quaternius/universal-animation-library/",
              "https://opengameart.org/node/174568"
            ],
            "confidence": "likely"
          },
          {
            "claim": "COMMITTING TO A PUBLIC REPO: LIKELY. The CC0 1.0 legal code (SPDX copy) waives all rights 'for any purpose' and says the waiver is not subject to revocation, rescission, cancellation or termination, with an irrevocable fallback licence. So a pack whose bundled License.txt grants CC0 may be redistributed. CONFIRMED first-hand: tilakpatell/tilakverse-assets (README 'about 2.2 GB'; every quaternius/ pack 'is CC0 1.0') publicly hosts even Source editions of UAL1, UAL2 and Stylized Nature MegaKit; trebeljahr/quaternius-showcase and OpenAgents also host CC0 Quaternius files. QAL-labelled packs may not be committed, raw or modified (QAL clause as quoted above). UNRESOLVED: whether the QAL claims to cover new downloads of packs whose page and License.txt still say CC0. loki #322 assumes it does; aenon #41 and the showcase assume it does not.",
            "source_urls": [
              "https://spdx.org/licenses/CC0-1.0.html",
              "https://creativecommons.org/publicdomain/zero/1.0/",
              "https://raw.githubusercontent.com/tilakpatell/tilakverse-assets/main/README.md",
              "https://raw.githubusercontent.com/trebeljahr/quaternius-showcase/main/LICENSES.md",
              "https://github.com/ImDarkly/loki/issues/322"
            ],
            "confidence": "likely"
          },
          {
            "claim": "ADDED: ROBLOX IMPORT LIMITS, LIKELY, from create.roblox.com search snippets (WebFetch blocked). 'Individual meshes can not exceed 20,000 triangles', and 'A vertex can not be influenced by more than 4 bones or joints'. Bones must be frozen (scale 1, rotation 0) with the root at 0,0,0. Layered and rigid accessories are capped at 4k tris. Some tutorials (Custom characters, Layered clothing) use 10k per part. Every Quaternius mesh measured above is under 20k tris per mesh and uses JOINTS_0 only (≤4 influences). The full 27k-tri Ranger outfit is split into 9 meshes, the largest 9,172.",
            "source_urls": [
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://create.roblox.com/docs/avatar/character-bodies/specifications",
              "https://create.roblox.com/docs/resources/beyond-the-dark/custom-characters"
            ],
            "confidence": "likely"
          }
        ],
        "implications_for_project": [
          "Licence gate for FORGE-07 is unchanged and supported by four independent project rulings. Accept a Quaternius pack only if the License.txt inside the downloaded zip says CC0 1.0. Record the pack name, pack-page URL, download date, zip sha256, a copy of License.txt and a note that quaternius.com/license.html shows QAL v1.0 (8/28/2026). Reject QAL-labelled packs (Bestiary is the only one found) from the public sammysingleton33-bit/ForgeLoop repo.",
          "Default commit policy: commit generators, manifests, licence copies and small previews. Keep raw zips in a gitignored, sha256-checked cache. The reason is not that CC0 forbids commits (it does not, and the waiver is irrevocable). It is that the QAL's scope over post-2026-08-28 downloads is unresolved. It also matches AGENTS.md ('exported binaries are reproducible'). Committing Roblox-ready derived meshes from CC0 packs is legally fine but needs an owner decision.",
          "Prototype citizen candidate, now verified first-hand: Ultimate Animated Character Pack (CC0 License.txt in two mirrors). It has 46 humanoids, each one skinned mesh of 2.5k–6.3k tris on an identically named 23-joint rig. Materials are flat colour with no textures, skin influences are ≤4, and the 17 clips are built in. It fits Roblox's 20k tris/mesh and 4-influence rules without decimation. Performance for about 300 skinned citizens is still unverified and needs a Studio test.",
          "Modular Men/Women (5.2k–11.1k tris across 4–5 parts, 49/51 joints) are already under the 20k per-mesh cap. Decimation to about 1.5–3k is a performance choice, not an import requirement. Their 24 clips were not measured: the mirror GLBs have none, and the cause is unknown. Download the original zip before relying on them.",
          "Universal Base + Fantasy Outfits: each sub-mesh is under 20k tris, so the import limit is not the blocker. The blocker is cost: 13–27k tris per character, 65 joints and PBR textures. Keep it for portrait or hero characters only. The Outfits Source tier is $20+ (owner approval).",
          "Environment set (CC0 per the showcase, mirror-measured): Ultimate Fantasy RTS has 128 models with First/Second Age and Level 1–3 versions (~400 tris houses up to an 11.8k town centre) and no unit characters. Add Crops (4 stages + crop item, ~100–1k tris), Ultimate Nature (1.9–2.9k-tri trees), Medieval Village Pack, Modular Medieval Buildings and RPG crown/armour. All are flat-colour single meshes that tint well per kingdom.",
          "Keep to the flat-colour 2019–2022 family for visual unity. The textured MegaKits (Medieval Village, Fantasy Props, Stylized Nature) have CC0 itch labels, but their Pro/Source tiers cost $9.99–$14.99 (owner approval) and they need texture uploads.",
          "Roblox upload of any QAL asset should stay private or not distributed on the Creator Store, since that listing could be standalone redistribution. Distributed CC0 assets carry no such constraint. Uploads under the owner's account still need owner approval."
        ],
        "open_questions": [
          "What is the full QAL v1.0 text, and does it claim to govern downloads made after 2026-08-28 of packs whose page and License.txt still say CC0? Only search snippets and third-party quotes were available. A human should read and save https://quaternius.com/license.html as a PDF.",
          "Is 'the version in effect at the time you obtained the Assets governs' the QAL's exact wording? It is seen only in TMHSDigital PR #58.",
          "Does the Quaternius FAQ actually say 'credit is appreciated, never required'? This could not be verified.",
          "Which packs besides Bestiary are QAL-labelled on the day of download? The search surfaced no others, but itch and the site were not read directly.",
          "Is the UACP Google Drive folder (ID 1sNi1AfenfPRrvRt5yfaj5QMMd6KKcUJ5) or the Patreon post still live, and what does the current quaternius.com UACP download contain? Do its FBX files match the measured glTF rig and materials? The FBX folder in the mirror lacks Goblin_Male and Knight_Male.",
          "Modular Men/Women: what are the 24 clip names and the humanoid-rig bone names in the original zips? Why do the mirror GLBs have no clips?",
          "Do current downloads of the 2019–2022 packs still match the December-2022 mirror copies? The showcase notes that some packs were updated.",
          "Roblox runtime performance and limits for about 300 skinned MeshPart citizens (bones per skinned mesh, draw calls, animation cost) need a Studio test. The 20k tris/mesh and 4-influence figures come from create.roblox.com search snippets only."
        ]
      },
      {
        "topic": "Kenney (kenney.nl): skeptic re-check of license, redistribution, price, pack contents, formats, triangle counts, rigs, download sources and Roblox fit for AI Kingdoms (aerial strategy view, public ForgeLoop repo)",
        "claims": [
          {
            "claim": "[CONFIRMED, with one addition] Access note. kenney.nl, kenney.itch.io, itch.io and opengameart.org are blocked from this agent too: WebFetch gives ENOTFOUND, and curl gets 'CONNECT tunnel failed, response 403' on the kenney.nl Castle Kit zip and on opengameart.org. These hosts did work: raw.githubusercontent.com, media.githubusercontent.com (Git LFS binaries) and GitHub code search. I re-downloaded every cited GLB and PNG and measured them with my own independent glTF parser. I got Roblox facts from Roblox's official public creator-docs repo on GitHub (create.roblox.com itself was not fetched). Kenney-site facts below come from search snippets, often from searches limited to the kenney.nl domain.",
            "source_urls": [
              "https://kenney.nl/support",
              "https://kenney.nl/media/pages/assets/castle-kit/a395102d20-1711543616/kenney_castle-kit.zip",
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/art/modeling/specifications.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED] License text. Mirrored copies of the License.txt files read: 'License: (Creative Commons Zero, CC0) http://creativecommons.org/publicdomain/zero/1.0/ — You can use this content for personal, educational, and commercial purposes. Support by crediting 'Kenney' or 'www.kenney.nl' (this is not a requirement)'. I re-read this exact text for Castle Kit (2.0), created 27-03-2024, in two independent mirrors; Fantasy Town Kit (2.0), 03-08-2025; Blocky Characters (2.0), 10-06-2025; and Mini Characters 1 (1.0), 17-07-2024. I also found it for Survival Kit (2.0), 03-04-2024, and in many GitHub mirrors for Nature Kit (2.1), creation date 29-04-2020. Caveat: every copy is a mirror. I did not read any License.txt straight from a kenney.nl zip.",
            "source_urls": [
              "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-castle-kit/3D/fantasy/License.txt",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/licenses/castle-kit.txt",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/licenses/fantasy-town-kit.txt",
              "https://raw.githubusercontent.com/eagleskyai/woodland-demo/main/assets/licenses/blocky-characters.txt",
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/License.txt",
              "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-survival-kit/3D/nature/License.txt",
              "https://github.com/laanlabs/openPlan3D/blob/4e66c60c00fba494181d647cc10324becd9a50b5/static/models/nature-kit-License.txt"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED via a kenney.nl-only search snippet; page not fetched] The support page says: all game assets on the asset pages are public domain (CC0) and free to use, even commercially; attribution is optional; the Kenney logo 'is reserved for official projects by our studio'; and Kenney cannot support importing assets into specific engines. CC0 waives copyright, so redistributing and modifying the assets is allowed. I did not fetch the CC0 legal code in this check.",
            "source_urls": [
              "https://kenney.nl/support",
              "https://creativecommons.org/publicdomain/zero/1.0/"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED] Kenney's own Starter Kit City Builder repo on GitHub releases its code under MIT ('Copyright (c) 2026 Kenney'). Its README says: 'Assets included in this package (2D sprites, 3D models and sound effects) are CC0 licensed'. So Kenney himself redistributes his CC0 models in a public GitHub repo.",
            "source_urls": [
              "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-City-Builder/main/README.md",
              "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-City-Builder/main/LICENSE.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CORRECTED] Mini Characters page and name. The current kenney.nl page is https://kenney.nl/assets/mini-characters, titled 'Mini Characters', not 'mini-characters-1'. A kenney.nl search snippet lists it at 25 files, version 1.0, 2024. Mirrored License.txt files exist under both titles, 'Mini Characters 1 (1.0)' and 'Mini Characters (1.0)', with the same creation date of 17-07-2024. A third-party doc gives a newer zip URL, https://kenney.nl/media/pages/assets/mini-characters/bfc7e272b4-1774770718/kenney_mini-characters.zip; its timestamp decodes to 2026-03-29, so the zip was re-uploaded after the 2024 mirrors were made. Contents of that re-upload are unverified. One mirror holds 26 GLBs: 12 characters (male-a..f, female-a..f), 10 aids (glasses, sunglasses, mask, hearing, cane, cane-blind, cane-low-vision, crutch, red and green defibrillators) and 4 wheelchairs. OpenGameArt: 12 characters, 32 animations each, about 2.4 MB zip.",
            "source_urls": [
              "https://kenney.nl/assets/mini-characters",
              "https://opengameart.org/content/mini-character-1",
              "https://raw.githubusercontent.com/nikolashaag/turbo-dismount/main/docs/research/research_kenney-assets.md",
              "https://github.com/series-ai/jam-ready-assets/tree/main/kenney-mini-characters/3D/characters/Models/GLB%20format"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by my own measurement] Mini Characters GLBs:\n- Size: character-male-a is 723 tris / 1,259 verts (body-mesh 450 tris, head-mesh 273). character-male-c is 793 tris / 1,455 verts. character-female-a is 876 tris / 1,576 verts. aid-glasses is 52 tris.\n- Rig: two skinned meshes on a 7-joint skin (root, leg-left, leg-right, torso, arm-left, arm-right, head). The hierarchy is root > {leg-left, leg-right, torso} and torso > {arm-left, arm-right, head}.\n- Material: one material, 'colormap'. The image is external (uri Textures/colormap.png, 512x512, 8,706 B). The sampler is magFilter NEAREST, minFilter NEAREST_MIPMAP_NEAREST.\n- Animation: 32 clips, exactly as listed. idle is 1.33 s and walk 0.67 s.\n- Generator: UnityGLTF; only extension used: KHR_texture_transform.\n- Mirror check: the series-ai mirror's LFS oid (sha256 77572792…) equals the SHA-256 of the EdJGM copy, so the two independent mirrors are byte-identical.\n- Added: characters are about 0.67 (male-a) to 0.78 (female-a) units tall.",
            "source_urls": [
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/character-male-a.glb",
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/character-male-c.glb",
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/character-female-a.glb",
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/Textures/colormap.png",
              "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-mini-characters/3D/characters/Models/GLB%20format/character-male-a.glb"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED by my own measurement] Mini Characters skinning is rigid. Every vertex has exactly one non-zero weight. In male-a, the body mesh's 804 vertices go to leg-left 212, leg-right 212, arm-left 146, arm-right 146 and torso 88, and the head mesh's 455 vertices all go to head. female-a is also rigid: body 1,052 verts (legs 180 each, arms 302 each, torso 88) and head 524. So a bone-wise split into 6 rigid parts loses no deformation, at least for male-a and female-a, the two I checked.",
            "source_urls": [
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/character-male-a.glb",
              "https://raw.githubusercontent.com/EdJGM/Juego-Godot/main/kenney_mini-characters/Models/GLB%20format/character-female-a.glb"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED] Blocky Characters 2.0 (https://kenney.nl/assets/blocky-characters). OpenGameArt says 18 skins and 27 animations, in FBX, OBJ and glTF, CC0, version 2.0. A kenney.nl snippet calls 2.0 'completely remade'. A third-party doc says this download URL worked: https://kenney.nl/media/pages/assets/blocky-characters/8369c0cf30-1749547469/kenney_blocky-characters_20.zip (timestamp = 2025-06-10). I could not test that URL myself.",
            "source_urls": [
              "https://opengameart.org/content/blocky-characters",
              "https://kenney.nl/assets/blocky-characters",
              "https://raw.githubusercontent.com/nikolashaag/turbo-dismount/main/docs/research/research_kenney-assets.md"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED, with a precision fix] Blocky Characters, measured.\n- character-a: 72 tris / 143 verts in 6 unskinned meshes. Hierarchy: root > {leg-left, leg-right, torso}, torso > {arm-left, arm-right, head}. The 27 clips animate node rotations; there is no skin.\n- Texture: external Textures/texture-a.png, 1024x1024. The sampler sets only minFilter LINEAR.\n- Added: the material requires the KHR_materials_unlit extension.\n- Fix: the files are NOT byte-identical across skins. character-a, -b and -r have different SHA-256s and different BIN chunks, and their animation data differs slightly. Their POSITION, TEXCOORD_0, NORMAL and index data are identical (compared to 5 decimals), and only the referenced atlas (texture-a/b/r) changes. I checked 3 of the 18 skins.",
            "source_urls": [
              "https://raw.githubusercontent.com/zees-games/mg-buses-from-hell/main/assets/kenney/characters/character-a.glb",
              "https://raw.githubusercontent.com/zees-games/mg-buses-from-hell/main/assets/kenney/characters/Textures/texture-a.png",
              "https://media.githubusercontent.com/media/pedroulissespu/trabalho-2-cg/main/assets/kenney/npcs/Models/GLB%20format/character-b.glb",
              "https://media.githubusercontent.com/media/pedroulissespu/trabalho-2-cg/main/assets/kenney/npcs/Models/GLB%20format/character-r.glb"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[PARTLY CORRECTED] None of Kenney's character packs that I found are medieval. kenney.nl lists Animated Characters Protagonists (8 files, 2020), Animated Characters Survivors (8 files, 2019, tagged zombie/survivor) and Animated Characters Retro. On OpenGameArt, the older Animated Characters 1/2/3 are each 'rigged model including 4 skins and 3 animations' (idle, jump, running). Only Survivors / Animated Characters 3 is zombie- and survivor-themed, not the whole series. Separately, the paid 'Kenney Character Assets', since renamed 'Animated Characters Bundle', has 4 models, 75 skins, 40 accessories and 17 animations, with Blender source files. It is included in All-in-1 from v1.8. I could not verify whether any of its skins or accessories are medieval. Mini Characters' clothing and faces were not visually inspected.",
            "source_urls": [
              "https://kenney.nl/assets/animated-characters-protagonists",
              "https://kenney.nl/assets/animated-characters-survivors",
              "https://opengameart.org/content/animated-characters-2",
              "https://kenney.itch.io/kenney-character-assets",
              "https://kenney.itch.io/kenney-game-assets/devlog/604490/update-version-18"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED, count varies by source] Castle Kit 2.0. kenney.nl lists 75 files, with 2.0 dated 27/03/2024 as a 'complete remake'. itch.io says 70+ models in OBJ, FBX and glTF, a 2.1 MB zip, and 'Name your own price' (free). OpenGameArt says 75+. A third-party manifest records the zip at https://kenney.nl/media/pages/assets/castle-kit/a395102d20-1711543616/kenney_castle-kit.zip: 2,232,589 bytes, SHA-256 921f3f73927bb23106cae34bc21d5ab4b033a9fc120475e96f714a406e3169df, fetched 2026-07-26. I could not download the zip, so the size and hash are third-party data only.",
            "source_urls": [
              "https://www.kenney.nl/assets/castle-kit",
              "https://kenney-assets.itch.io/castle-kit",
              "https://kenney-assets.itch.io/castle-kit/purchase",
              "https://opengameart.org/content/castle-kit",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/manifest.json"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by my own measurement and the manifest] Castle Kit GLBs:\n- My measurements: wall 178 tris (1.0 x 1.31 units), tower-square-mid-windows 364, siege-trebuchet 1,518 in 10 meshes (arm, catapult, weight, wheels). The manifest values match my measurements for every model I could check.\n- Manifest-only values: tower-square-base 28, tower-hexagon-mid 404, wall-doorway 500, gate 146, flag 144, flag-wide 256, flag-banner-long 68, siege-tower 1,598, siege-ram 1,112, siege-catapult 928, siege-ballista 676.\n- Material: one material, 'colormap', with an external Textures/colormap.png (512x512, 7,529 B). The sampler is magFilter NEAREST, minFilter NEAREST_MIPMAP_NEAREST.\n- Caveat: the manifest covers only 23 of the roughly 75 Castle models.",
            "source_urls": [
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/castle-kit/wall.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/castle-kit/siege-trebuchet.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/castle-kit/tower-square-mid-windows.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/castle-kit/Textures/colormap.png",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/manifest.json"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED, count varies by source] Fantasy Town Kit 2.0. kenney.nl lists 160 files and calls 2.0 a complete remake (1.0 was 2022); an older itch listing says 150. The All-in-1 v3.1 changelog lists 'Updated Fantasy Town Kit (complete remake)'. OpenGameArt (4 Aug 2025) says 160+ objects in separate FBX/OBJ/GLTF files. The License.txt says 2.0, created 03-08-2025. The zip URL, size 3,854,691 B and SHA-256 1a7530c0… come only from a third-party manifest; I did not download the zip. Note: these are 160 modular pieces (walls, roofs, props), not 160 complete houses.",
            "source_urls": [
              "https://kenney.nl/assets/fantasy-town-kit",
              "https://kenney.itch.io/kenney-game-assets/devlog/1005549/update-version-31",
              "https://opengameart.org/content/fantasy-town-kit",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/licenses/fantasy-town-kit.txt"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED, citation corrected] Fantasy Town Kit GLBs, my measurements: cart 608 tris (3 meshes), fountain-round 1,002 (materials 'colormap' and 'Water', the latter baseColorFactor 0.19/0.72/1.0 at alpha 0.6), roof-gable 72. The manifest values match (banner-red 98, banner-green 102, cart-high 1,028, fence 84, fence-gate 560, hedge 54, lantern 158, pillar-stone 124, pillar-wood 44, chimney 32, roofs 44–72, stairs-stone 136). The texture is an external Textures/colormap.png (512x512, 11,143 B), with sampler minFilter LINEAR_MIPMAP_LINEAR. I hashed it myself: SHA-256 4aac939d… for the Town colormap vs 66fd49be… for Castle (and 0d4947d3… for Mini Characters), so all three are different files with the same name. Correction: the zees-games README cited for this actually describes the Survival Kit vs Car Kit colormaps, not Castle vs Town. My hash comparison is the real evidence.",
            "source_urls": [
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/fantasy-town-kit/cart.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/fantasy-town-kit/fountain-round.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/fantasy-town-kit/roof-gable.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/fantasy-town-kit/Textures/colormap.png",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/castle-kit/Textures/colormap.png",
              "https://raw.githubusercontent.com/zees-games/mg-buses-from-hell/main/assets/kenney/README.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED in part] Nature Kit (https://kenney.nl/assets/nature-kit). kenney.nl and OpenGameArt say 330 / 330+ objects: trees, rocks, terrain, waterfalls, camping gear and plants. An older itch listing says 320. Many mirrored License.txt files say 'Nature Kit (2.1)', created 29-04-2020. The zip (https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip, timestamp = 2023-03-01, 10,537,521 B, SHA-256 fa7974a0…) comes only from a third-party manifest. kenney.nl's All-in-1 listing shows both 'Nature Kit' and 'Nature Kit (Classic)'. Crops are not mentioned in any listing, but crop models exist (see the next claim).",
            "source_urls": [
              "https://kenney.nl/assets/nature-kit",
              "https://opengameart.org/content/nature-kit",
              "https://kenney.nl/data/itch/preview/",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/manifest.json",
              "https://github.com/laanlabs/openPlan3D/blob/4e66c60c00fba494181d647cc10324becd9a50b5/static/models/nature-kit-License.txt"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by my own measurement] Nature Kit GLBs.\n- My measurements: tree_oak 196 tris (1.23 units tall), tree_detailed 402, crops_wheatStageB 360, rock_largeA 80.\n- Colour: there are no images or samplers. Colour comes from per-material baseColorFactor (e.g. leafsGreen, woodBark, dirt, grass, woodInner), and some models also carry a white '_defaultMat'. Each model is one mesh with 2–3 primitives.\n- Generator: UniGLTF-1.27.\n- The manifest values match: trees 50–402 tris (21 trees), rocks 16–80, crops_cornStageC 148, crops_dirtRow 44, fence_simple 64, log_stack 184, tent_detailedOpen 232, plant_bushSmall 16. The manifest covers 70 of the roughly 330 models.",
            "source_urls": [
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/nature-kit/tree_oak.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/nature-kit/tree_detailed.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/nature-kit/crops_wheatStageB.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/nature-kit/rock_largeA.glb",
              "https://raw.githubusercontent.com/lospolosadwords-dev/birodalmak/main/assets/models/manifest.json"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[MIXED] Other CC0 Kenney 3D packs.\n- Retro Medieval Kit: kenney.nl shows 100 assets, 2.0 dated 19/02/2025 ('Additional objects'), CC0; OpenGameArt says retro early-3D style with low-resolution textures. Confirmed by snippets.\n- Survival Kit 2.0 (created 03-04-2024): itch says 70+ models, OpenGameArt says 80. New finding, which closes the original's open question: a mirror contains tool-axe, tool-pickaxe, tool-hammer, tool-shovel and tool-hoe GLBs.\n- Tower Defense Kit: official itch says 160+ models in OBJ/FBX/DAE/STL/glTF. The UFO claim is not re-verified.\n- Hexagon Kit (60+) and Graveyard Kit (80): counts come only from aggregators. Unverified.",
            "source_urls": [
              "https://kenney.nl/assets/retro-medieval-kit",
              "https://opengameart.org/content/retro-medieval-kit",
              "https://kenney.nl/assets/survival-kit",
              "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-survival-kit/3D/nature/Models/GLB%20format/tool-pickaxe.glb",
              "https://raw.githubusercontent.com/series-ai/jam-ready-assets/main/kenney-survival-kit/3D/nature/Models/GLB%20format/tool-axe.glb",
              "https://opengameart.org/content/survival-kit",
              "https://kenney-assets.itch.io/tower-defense-kit",
              "https://kenney-assets.itch.io/hexagon-kit",
              "https://www.kenney.nl/assets/graveyard-kit"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED] Style and formats.\n- Look: OpenGameArt listings say 'Optimized, low poly models'.\n- Texturing: Castle, Town and Mini Characters each use their own pack-wide 512x512 'colormap', and Nature uses flat material colours. I measured both directly.\n- Format advice: Kenney's knowledge base (search snippet) says to avoid OBJ unless it's the only option, that 'FBX and GLB (glTF) files are equal in features but GLB is smaller in size', and to fix missing colours by importing the included textures, noting 'Each asset pack requires its own texture(s)'.\n- Added (measured): kits are built on a roughly 1-unit grid (wall 1.0 wide, roof-gable 1.1, tree_oak 1.23 tall), while Mini Characters are only 0.67–0.78 tall. Every kit needs a deliberate scale factor before Roblox import, and the relative scale between kits needs checking.",
            "source_urls": [
              "https://opengameart.org/content/fantasy-town-kit",
              "https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines",
              "https://www.kenney.nl/knowledge-base/game-assets-3d/model-packages"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[PARTLY CONTRADICTED] Download sources.\n- (1) kenney.nl asset pages. The free zip URLs follow https://kenney.nl/media/pages/assets/<slug>/<hash>-<unix-timestamp>/kenney_<slug>[_ver].zip and change when a pack is updated. A third-party doc says to treat the /assets/<slug> page as the stable entry point.\n- (2) kenney-assets.itch.io mirrors: free, 'Name your own price'.\n- (3) OpenGameArt mirrors.\n- (4) Paid All-in-1 on itch.io: 'Buy Now $19.95 USD or more'. CONTRADICTED: v3.3.0 is not the latest. Devlogs exist for v3.5 (Cube Pets, Light Masks, Factory Kit remake) and v3.7 (Domino Pack, City Kit Roads update, Mini Dungeon update). The 456 MB figure is unverified; one snippet showed 2.7.0 at 454 MB.\n- Clarification: the Blender source files added in v1.8 belong to the 'Animated Characters Bundle' (formerly Kenney Character Assets), not to Mini Characters or Blocky Characters.",
            "source_urls": [
              "https://raw.githubusercontent.com/nikolashaag/turbo-dismount/main/docs/research/research_kenney-assets.md",
              "https://kenney-assets.itch.io/castle-kit/purchase",
              "https://kenney.itch.io/kenney-game-assets",
              "https://kenney.itch.io/kenney-game-assets/devlog/1140258/update-version-33",
              "https://itch.io/devlog/1526460/update-version-35.amp",
              "https://itch.io/devlog/1635977/update-version-37.amp",
              "https://kenney.itch.io/kenney-game-assets/devlog/604490/update-version-18"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippet] Roblox colour pitfall. An itch.io thread reports a Kenney 3D kit uploading to Roblox 'just without color'. It was never resolved and was auto-archived. My measurements fit this: every textured Kenney GLB references its atlas by an external relative URI (Textures/<name>.png) instead of embedding it. An official Roblox doc page (search snippet) gives the manual fix: upload the image and paste its asset ID into MeshPart.TextureID. Whether Studio's importer resolves external URIs inside a .glb is unverified.",
            "source_urls": [
              "https://itch.io/t/5208814/kenney-assests-not-uploading-in-color-on-roblox",
              "https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines",
              "https://create.roblox.com/docs/en-us/art/accessories/creating-rigid/importing"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CORRECTED using official Roblox docs] Roblox limits.\n- Triangle limit (resolves the original's 20k-vs-10k conflict): Roblox creator-docs say 'Individual meshes can not exceed 20,000 triangles'. The 10,000 / 21,000 figures come from vendor blogs (Nilo) and are unverified. The largest Kenney piece measured is 1,598 tris.\n- Formats: the Importer doc lists '.fbx, .obj, or .gltf'. A Roblox DevForum recap (Mar–Apr 2024) says Open Cloud import gained glTF/glb support, matching 'the same formats as the Studio 3D Importer'. So .glb is likely accepted, but the doc page doesn't name it.\n- Texture filtering (CONTRADICTED): it is not true that no nearest-neighbour option exists. SurfaceAppearance.ResampleMode takes Enum.ResamplerMode.Pixelated, which the docs define as 'Nearest neighbor filtering'. MeshPart has no ResampleMode property, so MeshPart.TextureID stays bilinear.\n- Scripting limits: SurfaceAppearance.ColorMap is PluginSecurity, so game scripts cannot change it at runtime. SurfaceAppearance.Color (a tint) and MeshPart.TextureID can be changed at runtime ('the texture can' change during runtime; MeshId cannot).",
            "source_urls": [
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/art/modeling/specifications.md",
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/studio/importer.md",
              "https://devforum.roblox.com/t/3d-import-recap-mar-apr-2024/2979668",
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/SurfaceAppearance.yaml",
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/enums/ResamplerMode.yaml",
              "https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/MeshPart.yaml",
              "https://nilo.io/articles/vibe-code-roblox-triangle-limit"
            ],
            "confidence": "confirmed"
          }
        ],
        "implications_for_project": [
          "Redistribution holds up. Kenney's License.txt is CC0, Kenney himself puts CC0 models in public GitHub repos, and only the logo is reserved. So Blender-edited Kenney meshes and palette PNGs can be committed to the public ForgeLoop repo.\n- Keep each pack's License.txt beside its files.\n- Record provenance: page URL, zip URL, SHA-256 and fetch date. Re-hash the zips ourselves, because the existing hashes come from a third-party manifest and kenney.nl was unreachable.\n- Don't use the Kenney logo. Credit 'Kenney' (optional).\n- The free packs need no owner approval. The All-in-1 ($19.95+) and the Animated Characters Bundle are purchases and need owner approval.",
          "Pin current URLs, not 2024 mirrors. Mini Characters now lives at kenney.nl/assets/mini-characters, and its zip was re-uploaded on 2026-03-29. Fetch and diff it against the 2024 mirror files before pinning a hash. The fetch script should start from the /assets/<slug> page, because the media hash path changes on every update.",
          "Mini Characters is still the best Kenney citizen base.\n- Size: 723–876 tris on a 7-joint rig, root > {legs, torso} and torso > {arms, head}. That maps directly onto the existing Motor6D tree.\n- Skinning is rigid (verified for male-a and female-a), so a 6-part split in Blender is lossless.\n- Scale: the characters are only about 0.67–0.78 units tall, so Blender export needs a fixed scale factor that matches the building kits; set it once, in the pipeline script.",
          "Budget arithmetic stands but is unmeasured in Roblox. 300 × 723–876 tris is about 217k–263k tris, vs about 132 tris per citizen today (11 boxes × 12 tris). Every split part is far under Roblox's official 20,000-tris-per-mesh limit. A microprofiler test is still needed.",
          "Correction on Blocky Characters blur. Roblox now offers nearest-neighbour filtering through SurfaceAppearance.ResampleMode = Pixelated, so the 1024² atlases need not blur. MeshPart.TextureID has no such option. Blocky is still not recommended as the main citizen: it has the classic blocky look, and its material needs KHR_materials_unlit, which Roblox likely ignores (unverified). At most use it as a far-distance proxy.",
          "Kingdom palettes. The cheapest route is to give each kingdom its own copy of the pack's 512² palette PNG and swap MeshPart.TextureID per kingdom. Roblox docs confirm TextureID can be changed at runtime, but it filters bilinearly, so swatch edges may bleed. Pixel-exact palettes need SurfaceAppearance (Pixelated), but its ColorMap cannot be changed by game scripts at runtime. If we go that way, pre-author one SurfaceAppearance per kingdom variant in Studio, or use SurfaceAppearance.Color as a script-writable tint. Nature Kit has no texture, so recolour it through MeshPart.Color after splitting by material, if the importer splits per material (unverified).",
          "Occupation gear is partly covered. Survival Kit 2.0 includes tool-axe, tool-pickaxe, tool-hammer, tool-shovel and tool-hoe GLBs, which suit farmers, miners, woodcutters and builders. Crowns, capes, armour and ruler identity still have to be authored in Blender in Kenney's flat style. Alternatively, evaluate the paid Animated Characters Bundle (75 skins, 40 accessories, Blender source) after owner approval; whether it has any medieval items is unverified.",
          "The environment fit for the aerial camera stands.\n- Castle Kit (~75 models): walls, towers, gates, flags, siege engines.\n- Fantasy Town Kit 2.0 (160 modular pieces, not 160 complete houses): walls, roofs, chimneys, carts, fences, hedges, lanterns, fountain.\n- Nature Kit 2.1 (~330 models): trees, rocks, wheat and corn crop stages, dirt rows, fences, logs, tents.\n- Retro Medieval Kit (100): an alternative style.\nEvery measured piece is 16–1,598 tris. Only about 132 models were measured in total; spot-check the rest after download.",
          "Import pipeline: the Blender export must embed textures, either as a GLB with a packed image or as FBX with embedded media. Kenney GLBs reference Textures/*.png externally, and a user report says they arrive in Roblox without colour. Keep each pack's colormap in its own folder: the Castle, Town and Mini colormaps have different SHA-256s despite the same filename.",
          "Safety: Kenney packs are pure mesh, texture and animation data. glTF can't carry Roblox scripts, and the only extensions seen are KHR_texture_transform and KHR_materials_unlit. Importing our own Blender exports avoids the 'free model with scripts' risk entirely.",
          "Animation: Mini Characters' 32 clips (idle 1.33 s, walk 0.67 s, sprint, sit, die, pick-up, emote-yes/no, interact, melee, kick, holding) animate rotations on torso, arms, head and legs. They can be baked to per-part keyframes, or the existing procedural Motor6D system can be kept. Uploading them as Roblox Animation assets needs the owner's account."
        ],
        "open_questions": [
          "Visual quality is still unverified. Nobody has rendered Mini Characters (faces, clothing, readability at aerial and portrait distance) or the building kits. This needs a Blender (bpy) render or a Studio screenshot.",
          "Does the Studio 3D Importer accept .glb directly (the docs name only .fbx/.gltf/.obj), and does it resolve a GLB's external texture URI? Does it keep KHR_texture_transform, ignore KHR_materials_unlit, and split multi-material Nature Kit meshes into separate MeshParts? Each needs a Studio test.",
          "Does bilinear MeshPart.TextureID filtering make neighbouring swatches bleed on the 512² colormaps at aerial distance? If it does, should we use pre-authored Pixelated SurfaceAppearances per kingdom, given that ColorMap can't be changed by scripts at runtime, or bake UVs to flat per-material colours?",
          "Did the 2026-03-29 re-upload of Mini Characters change geometry, clip names or file count? kenney.nl says 25 files, while a mirror holds 26 GLBs. Download it, diff against the 2024 mirrors, and pin the SHA-256.",
          "The Castle, Fantasy Town and Nature zip sizes and SHA-256s come only from a third-party manifest. Re-download and re-hash them from kenney.nl, from a network that can reach it.",
          "What is the current All-in-1 version and size? Devlogs reach at least v3.7. Does the Animated Characters Bundle contain anything medieval? Only relevant if the owner approves the purchase.",
          "What uniform scale factor maps the Kenney kits (1-unit grid) and Mini Characters (about 0.7 units tall) to Roblox studs, so citizens, doors and walls read correctly from both the aerial and portrait cameras?",
          "Performance of about 300 citizens built from 6 MeshParts each (about 800 tris), vs the current 11 primitive Parts, on server replication and mobile clients, is unmeasured.",
          "Does mixing Kenney environments with Quaternius or KayKit characters or accessories stay visually cohesive, or should all ruler and occupation gear be authored in Kenney's style?"
        ]
      },
      {
        "topic": "Roblox Creator Store (renamed from 'Creator Marketplace' around Jan 2024; reached in Studio through the Toolbox window, so not 'formerly Toolbox'): licence/terms for using store models, judging creators, free-model risks and safe vetting, redistribution/re-upload/public-repo limits, official Roblox medieval/character assets, mesh moderation and IP policy. This is a skeptic re-check of the earlier findings.",
        "claims": [
          {
            "claim": "ACCESS NOTE (re-checked): WebFetch to en.help.roblox.com, conductatlas.com and tostracker.app failed with ENOTFOUND. curl to www.roblox.com, devforum.roblox.com, en.help.roblox.com and web.archive.org failed too (no response). Proxy logs show 403s for quaternius.com and kenney.nl. GitHub works. I re-used a clone of github.com/Roblox/creator-docs and its HEAD matches what the earlier research reported: 70a0110fee0c0900103e545fcaee69a8bd2a942f, committed 2026-10-17. Every 'confirmed' doc claim below was re-checked by grepping that clone. Everything about Terms of Use, Creator Store Terms, Community Standards or DevForum rests only on WebSearch snippets.",
            "source_urls": [
              "https://github.com/Roblox/creator-docs"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CORRECTION to the topic label: the Creator Store replaced and renamed the 'Creator Marketplace'. The change was announced at RDC in September 2023, launched in January 2024, and USD pricing went live in late March 2024. The Toolbox is the Studio window, and its 'Creator Store' tab is how you reach the store. The Toolbox was not renamed.",
            "source_urls": [
              "https://tubefilter.com/2024/01/29/roblox-creator-store-fees/",
              "https://www.pocketgamer.biz/roblox-launches-new-creator-store-for-faster-game-building",
              "https://create.roblox.com/docs/projects/assets/toolbox",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/assets/toolbox.md"
            ],
            "confidence": "likely"
          },
          {
            "claim": "CONFIRMED: The Creator Store is 'a marketplace that features millions of assets made by Roblox and independent creators for others to use within their game development'. You can reach it on the Creator Hub and in Studio's Toolbox, and you can save assets to your inventory to reuse in any project.",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/creator-store.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "Creator Store Terms licence (snippet only; my own search returned the same text again, but the page was not fetched): 'By purchasing assets on the Creator Store, User is granted a license to use the asset in Roblox Studio and in Experiences on the Services', consistent with the User and Creator Terms. The store is only for Creator assets intended for Studio. The snippet also says purchases are 'final ... non-refundable and non-transferable' unless Roblox permits otherwise or the law requires it, while the official docs describe refunds and chargebacks that remove the asset from the buyer's inventory. SKEPTIC NOTE: the quoted grant covers PURCHASED assets. The snippets do not show what licence covers FREE store assets, which presumably fall under the general Terms of Use content licence (unverified).",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms",
              "https://create.roblox.com/docs/production/creator-store"
            ],
            "confidence": "likely"
          },
          {
            "claim": "DOWNGRADED: Roblox Terms of Use exact wording. I searched for the quoted phrases 'All Content is licensed and distributed to you by Roblox as principal' and '... prior written permission from Roblox', and for the 'non-sublicensable, non-transferable, non-assignable, revocable license to access and use Content' grant. No result showed any of these verbatim. What search does support (via third-party ConductAtlas summaries and help-centre snippets): creators grant Roblox a worldwide, non-exclusive, royalty-free, sublicensable licence over UGC, which Roblox sublicenses to other users, and the users' licence to Content is limited to use with the Services. A May 2026 ToU revision and a separate EEA/UK/Switzerland ToU exist, so the wording may differ by region and date.",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use",
              "https://en.help.roblox.com/hc/en-us/articles/52986395990932-Roblox-Terms-of-Use-for-the-European-Economic-Area-the-United-Kingdom-and-Switzerland",
              "https://conductatlas.com/platform/roblox/roblox-terms-of-use/user-content-license-grant/"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "DOWNGRADED: the quote 'Roblox-Owned Content may not be used outside of the Services unless ... expressly authorized by Roblox; and consistent with Roblox's Name and Logo Guidelines' was not found by an exact-phrase search. Snippets confirm only that the terms define 'Roblox-Owned Content' (graphics, code, avatar models, Roblox-published games and so on) as distinct from UGC that creators license to Roblox. The Limited Use License text in the docs (below) restricts Roblox kit code to deployment on Roblox.",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use",
              "https://en.help.roblox.com/hc/article_attachments/20957353013908"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED verbatim in the docs: you may distribute any Model, Plugin, MeshPart, Decal or audio asset 'that you have created and uploaded to your inventory'. 'You may also distribute composite assets which contain Open Use dependencies that were created by others, but you cannot distribute assets with Restricted dependencies that were not uploaded by you.' FAQ: 'you cannot sell or distribute composite models that contain Restricted assets that you didn't create, with the exception of Audio and Video ... You can share these models directly with your collaborators, but Roblox will not allow you to list assets you did not create on the Creator Store.' You can only sell assets you own, from an individual account; group-owned assets are ineligible. The FAQ also says asset privacy 'is not a form of DRM'.",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/creator-store.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "Public repo or re-upload of store models: I also found no Roblox document that addresses committing Creator Store models or their extracted meshes and textures to an external repository. The conclusion that it is not permitted is an INFERENCE from (a) the snippet licence scope 'Roblox Studio and in Experiences on the Services', and (b) the docs rule that you may distribute only assets you created, or composites with Open Use dependencies. The exact ToU anti-reproduction wording behind this inference is unverified (see above). The docs do say that, for an un-copylocked game containing a purchased model, 'none of the model's Restricted child image and mesh assets will load unless that person has also purchased the model', which shows Roblox treats purchased assets as non-shareable.",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms",
              "https://create.roblox.com/docs/production/creator-store",
              "https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use"
            ],
            "confidence": "likely"
          },
          {
            "claim": "Community view (not official; snippets consistent): the DevForum thread 'To what extend can i use Toolbox items?' asks whether toolbox accessories, some possibly stolen, can be used for about 350 NPCs. A reply in the separate thread 3907198 says Roblox usually removes the item and punishes the uploader, but 'users of stolen items can still be held accountable'. Thread 1215687 was not re-checked.",
            "source_urls": [
              "https://devforum.roblox.com/t/to-what-extend-can-i-use-toolbox-items/4768190",
              "https://devforum.roblox.com/t/can-i-use-other-peoples-modelsassets-without-explicit-permission/3907198",
              "https://devforum.roblox.com/t/last-double-check-on-copyright/1215687"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED, with additions. Restricted vs Open Use: an asset without permission 'cannot load in Studio', and Restricted assets must be granted 'before they are visible or audible at runtime'. Asset Privacy controls ONLY the default state of newly created Images, Decals and Meshes. It does not affect Models, MeshParts, Audio, Video, Animations or Packages. It is not retroactive, and it is enabled under Creator Dashboard > username > Settings > Advanced. 'Open Use is irreversible.' 'Game grants are permanent.' 'Your assets are always accessible to you in your own games regardless of their privacy setting.' Avatar Marketplace items require Open Use dependencies.",
            "source_urls": [
              "https://create.roblox.com/docs/projects/assets/privacy",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/projects/assets/privacy.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED: the Advanced Filter can 'Sort by relevance or rating', 'Filter creators by verification status and username', set price parameters and restrict results to specific asset types. Asset details pages show 'Technical details, such as the asset's triangle, vertice, and script count', and some offer a 'Try in Roblox' demo. (The details-page list was confirmed in creator-store.md; toolbox.md only links to it.)",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://create.roblox.com/docs/projects/assets/toolbox"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED: to distribute, an account must be at least 2 days old, not recently banned, and verified by age check or government ID; phone verification does not count. Per-30-day limits for verified vs unverified accounts: meshes 200/10, images 200/10, models 200/10, audio 100/10, plugins 10/2. Verification lets creators 'maximize their discoverability within the Creator Store'. Selling also requires a government-ID-verified seller account through Stripe, 2-Step Verification, and age 18+ (or 13–17 with parental consent). 'Verified' means identity- or age-checked, not that the content has been vetted.",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://create.roblox.com/docs/production/publishing/account-verification"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "The Verified Badge is a separate system. The official help article and the official DevForum announcement (snippets) say it is a visual indicator for notable, authentic creators to address impersonation, and that it does not affect search or recommendations for unverified creators. The sub-claim that 'community posts warn verified badges are no security guarantee' was not re-checked (unverified).",
            "source_urls": [
              "https://en.help.roblox.com/hc/articles/7997207259156",
              "https://devforum.roblox.com/t/introducing-the-verified-badge/1980978"
            ],
            "confidence": "likely"
          },
          {
            "claim": "CONFIRMED verbatim: 'Third-party assets from the Creator Store (Toolbox) are a common source of security risks, as they can contain malicious scripts called backdoors' that give 'unauthorized server-side access'. Backdoors 'often appear in otherwise legitimate-looking models', and the Toolbox UI indicates when a model contains scripts. Roblox moderation 'is not guaranteed to remove all such scripts'. Attackers may use whitespace to push code off-screen, and 'popularity doesn't guarantee safety'.",
            "source_urls": [
              "https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/security/third-party-vulnerabilities.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED, with a correction. Mitigations: (1) Workspace.SandboxedInstanceMode = Experimental. The vulnerabilities page misspells the property as 'SandboxedInstance', but the API reference and Capabilities page use SandboxedInstanceMode. (2) Set the model's Sandboxed = true. (3) Grant only the capabilities it needs, and be careful with Network, DataStore, AssetRequire, CapabilityControl and LoadString. 'Script capabilities are experimental and available as a client beta' (still true at docs HEAD 2026-10-17). 'In the future, we plan to automatically sandbox all assets from the Creator Store' is still stated as a future plan in the docs, and I found no announcement that it has shipped. 'Disable Scripts' is available in the Explorer context menu.",
            "source_urls": [
              "https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities",
              "https://create.roblox.com/docs/scripting/capabilities",
              "https://create.roblox.com/docs/reference/engine/classes/Workspace",
              "https://create.roblox.com/docs/production/creator-store"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED verbatim: Creator Store assets may not use (1) obscured engine features (LuaVMs, getfenv(), setfenv()); (2) remote requires: require(assetId), loadstring(), InsertService:LoadAsset(), AssetService:LoadAssetAsync(), ModuleScript.LinkedSource; (3) obfuscated code; (4) 'Extremely large scripts' with repeated lines or large unused strings. Violations can be reported with 'Report Item'.",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/creator-store.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CORRECTED (community reports only): DevForum threads from November 2025 report that automated moderation blocked models whose scripts merely contained the word 'require', including print(\"require\"). The [SOLVED] thread reportedly says this was fixed as of November 7. A later thread reports ModuleScript-containing models flagged for 'Misusing Roblox Systems', and a staff reply said the version should now be allowed. So the broad false-positive was reportedly temporary. Current behaviour is unknown.",
            "source_urls": [
              "https://devforum.roblox.com/t/solved-the-word-require-made-any-model-not-distributed-on-creator-store/4051504",
              "https://devforum.roblox.com/t/automated-moderation-false-flags-the-script-printrequire-as-violating-community-standards/4051529",
              "https://devforum.roblox.com/t/moderation-issue-with-my-public-assets/4065299"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "Community vetting tips (unofficial): hidden decals under Unions, odd-named objects and the ShieldScan plugin. Snippets say ShieldScan is a heuristic scanner created in December 2025 that flags require(assetId), HttpGet and loaders, with its README warning of false positives and the need for manual review. I could not reach github.com/tuidevelops/shield-scan anonymously (git ls-remote asked for credentials, so the repo may be renamed, private or deleted), so the repo and its licence are unconfirmed. Similar scanners such as Locksmith were reportedly taken down by Roblox, so a scanner plugin is itself a third-party trust risk.",
            "source_urls": [
              "https://devforum.roblox.com/t/shieldscan-anti-backdoor-scanner-for-roblox-studio/4736119",
              "https://awesome.ecosyste.ms/projects/github.com%2Ftuidevelops%2Fshield-scan",
              "https://devforum.roblox.com/t/what-is-the-best-way-to-find-hidden-decals-under-some-malicious-free-models/3706962",
              "https://devforum.roblox.com/t/locksmith-301/1642598"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED verbatim. InsertService:LoadAsset loads only assets 'created or owned by the game creator', shared by the owner, or owned by Roblox, and 'benign asset types such as t-shirts, shirts, pants and avatar accessories are loadable from any game as they are OpenUse'. AssetService:LoadAssetAsync is 'the modern replacement'. It returns a Model with Sandboxed = true and no script Capabilities. It can load 'any public free asset on the Creator Store' only when AssetService.AllowInsertFreeAssets ('Allow Loading Third Party Assets' in Experience Settings, default false) is on. ADDITION from the Creator Store FAQ: dynamically loading a PAID model does not work in group games unless the model was inserted before publish time, nor in collaborative games where the game owner does not own the model.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/InsertService#LoadAsset",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService#LoadAssetAsync",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/AssetService.yaml",
              "https://create.roblox.com/docs/production/creator-store"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. Official templates are 'uncopylocked games'. The Village template is 'house, garden, and orchard objects ... to create rural villages' (placeId 520390648, universeId 202770430). The Castle template is 'castle and foliage objects ... to create destructible kingdoms' (placeId 203810088, universeId 93411794). The NPC Kit (Drooling Zombie Rthro, Soldier Rthro, RO-01 and NP-C 9000 robots) is under Roblox's Limited Use License.",
            "source_urls": [
              "https://create.roblox.com/docs/resources/templates",
              "https://create.roblox.com/docs/resources/npc-kit",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/resources/templates.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "Negative result, search only: neither my search nor a grep of the full creator-docs for 'medieval' found any official Roblox medieval or fantasy character or building pack. 'medieval' appears in only 3 unrelated doc pages. Every medieval pack found is third-party, for example on BuiltByBit (USD 2.99–15, licence terms not checked) or the DevForum. A live Creator Store browse was not possible.",
            "source_urls": [
              "https://builtbybit.com/resources/stylized-medieval-environment-asset-pack.70270/updates",
              "https://builtbybit.com/resources/stylized-medieval-fantasy-asset-pack.58142/",
              "https://devforum.roblox.com/t/fantasy-village-buildings-kit/3351486",
              "https://kwstudio.org/collection/medieval-roblox"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED verbatim. The Limited Use License grants a 'limited, nonexclusive, non-transferable, non-sublicensable, revocable permission ... solely (a) for the purpose of internally incorporating the Licensed Software into your larger applications for deployment through the Roblox platform'. It includes the right to modify the Licensed Source. You may collaborate with 'other developers that have agreed to be bound by and comply with this License, including by distributing copies' to them. Attribution may not be removed. Roblox 'may terminate the License ... at any time for any reason or no reason', and on termination copies must be returned or destroyed. A public GitHub repo would distribute the code to people who have not agreed to the licence, so it is not compatible.",
            "source_urls": [
              "https://create.roblox.com/docs/resources/limited-use-license",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/resources/limited-use-license.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED: you can modify Humanoids, both player and 'non-player character models', through HumanoidDescription: scales, body-part asset IDs, accessories and clothing. Combined with the InsertService note that avatar accessories and clothing are OpenUse, this is a supported way to dress NPCs by asset ID. Note that the scale properties do not affect R6.",
            "source_urls": [
              "https://create.roblox.com/docs/characters/appearance",
              "https://create.roblox.com/docs/reference/engine/classes/InsertService"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED verbatim. Moderation is human and automated, proactive and reactive, and checks against the Community Rules, Terms of Use and IP guidelines. It 'generally happens within a few hours after you import'. Assets still in the queue at publish time cannot be seen or interacted with until approved. 'Roblox may take down games and/or terminate accounts that maliciously import or publish non-compliant assets.' Asset Manager imports 'enter the moderation queue and, upon approval, are added to the inventory of the user/group that owns the game'.",
            "source_urls": [
              "https://create.roblox.com/docs/projects/assets#asset-moderation",
              "https://create.roblox.com/docs/projects/assets/manager"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED verbatim. 'Individual meshes can not exceed 20,000 triangles' (avatar items have their own budgets). A vertex can be influenced by at most 4 bones. Bones must be frozen with scale 1,1,1 and rotation 0,0,0. With RenderFidelity Automatic, detail tiers are under 250 studs, 250–500 studs, and 500 studs or more.",
            "source_urls": [
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://create.roblox.com/docs/parts/meshes#level-of-detail"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED, with a wording correction. 'Roblox prohibits the unauthorized use of intellectual property, and removes from the Roblox platform content that violates this policy', and it suspends or terminates repeat or egregious infringers. The doc says you 'can still infringe a copyright even if you' didn't monetise, credited the creator, downloaded it from the internet, bought a physical copy, saw others use it, or believed it was fair use. That is a 'can still infringe', not an automatic infringement. Notices go to copyright_agent@roblox.com or, for people over 18, through the IP Platform (Rights Manager). Roblox generally cannot act on off-platform content.",
            "source_urls": [
              "https://create.roblox.com/docs/production/publishing/ip-guidelines",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/publishing/ip-guidelines.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "The Rules of Conduct / Community Standards page (snippet) lists as IP violations 'using another developer's code to create your experience without their permission', using another artist's media, and using a brand's logo without permission. CORRECTION: the earlier claim that licensed third-party IP goes 'only' through Roblox's licensing programme is not supported. The docs present the License Manager and Licenses catalog as an official route for partnering with rights holders, not as the only lawful one.",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Rules-of-Conduct",
              "https://create.roblox.com/docs/ip-licensing",
              "https://create.roblox.com/docs/ip-licensing/license-manager"
            ],
            "confidence": "likely"
          },
          {
            "claim": "CONFIRMED. Price ranges: models USD 2.99–49.99, plugins USD 4.99–249.99, USD only with no Robux. 'Only individual user accounts may purchase assets for USD on the Creator Store. Groups are ineligible to purchase models or plugins at this time.' Monthly per-seller transaction caps apply, and a refund removes the asset from the buyer's inventory. ADDITION: the FAQ says a purchased model CAN be put into a group or collaborative game, but collaborators who don't own it may not be able to copy and paste it, and the game needs permission to the model's Restricted child meshes and images.",
            "source_urls": [
              "https://create.roblox.com/docs/production/creator-store",
              "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/creator-store.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "The 'Business Users only / Consumers may not use the Creator Store' clause is still unconfirmed. One search summary placed it with the EEA/UK/Switzerland terms, but no result showed the clause text.",
            "source_urls": [
              "https://en.help.roblox.com/hc/en-us/articles/21308223046932-Creator-Store-Terms",
              "https://en.help.roblox.com/hc/en-us/articles/52986395990932-Roblox-Terms-of-Use-for-the-European-Economic-Area-the-United-Kingdom-and-Switzerland"
            ],
            "confidence": "unverified"
          }
        ],
        "implications_for_project": [
          "Keeping all Creator Store, Toolbox, template and NPC Kit content out of the public repo is still correct. The strongest, confirmed basis is the docs rule that you may distribute only assets you created, plus the Limited Use License limit on sharing copies to developers who have agreed to the licence. The Terms of Use quotes about reproduction and distribution are unverified, so cite the docs rules in DECISIONS.md, not the ToU quotes.",
          "The manifest licence basis should not read 'Creator Store Terms'. That snippet's licence covers PURCHASED assets, and the licence wording for free assets is unverified. Use 'Roblox platform use only: Creator Store free asset' or 'Creator Store purchased asset (Creator Store Terms)' as applicable, plus the date checked.",
          "Runtime loading through AssetService:LoadAssetAsync works for FREE third-party models only if 'Allow Loading Third Party Assets' is on. PAID models cannot be dynamically loaded in group-owned games unless inserted before publish. If AI Kingdoms is or will be group-owned, any paid model must be inserted in Studio before publishing.",
          "Vetting step (2): set Workspace.SandboxedInstanceMode = Experimental. The vulnerabilities doc misspells it 'SandboxedInstance'. Capabilities are still a client beta as of 2026-10-17 docs, and automatic sandboxing of Creator Store assets is still only a stated plan. Do not rely on Roblox to sandbox inserted models. Scripts must still be deleted or disabled manually.",
          "Do not install third-party scanner plugins such as ShieldScan without review. The repo could not be confirmed, and similar plugins have been taken down by Roblox. A Command Bar or our own repo-reviewed search script is safer for FORGE-07.",
          "Asset Privacy applies only to newly created Images, Decals and Meshes, not to Models or MeshParts, and only from the moment it is enabled. Turning it on before uploading custom citizen meshes is still advisable, and it is still an owner decision.",
          "Mesh limits (20k triangles, 4 influences, frozen bones), LOD distances (250/500 studs), moderation timing ('generally within a few hours') and invisibility until approved are all confirmed. The earlier pipeline and performance implications stand.",
          "There is no confirmed official Roblox medieval character or building pack. The Village and Castle templates are the only confirmed Roblox-made medieval-ish sources, and they are Roblox-owned content for use on Roblox. A live Studio or Creator Store browse by the owner is still needed to find candidates.",
          "IP: keep everything generic. The docs say crediting or not monetising does not stop an infringement. Treat the Roblox License Manager as the official route for licensed IP, without claiming it is the only one; no licensed IP is planned anyway.",
          "The CC0 status of Quaternius and Kenney assets is NOT verified in this session, because the proxy returned 403 for quaternius.com and kenney.nl. Do not commit their assets until a primary-source licence check is recorded."
        ],
        "open_questions": [
          "What is the exact current text of the Creator Store Terms (en.help.roblox.com article 21308223046932)? Specifically: the licence for FREE (non-purchased) assets, the 'non-transferable' wording, and whether a 'Business Users only' clause applies, possibly only in the EEA/UK/Switzerland. Someone with a normal browser needs to read the page.",
          "What is the exact current Roblox Terms of Use wording, effective May 2026 per search, on users' licence to Content and on reproducing or distributing Content outside the Services? The earlier verbatim quotes could not be confirmed.",
          "Is AI Kingdoms owned by the owner's individual account or by a group? This decides who can buy paid models and whether paid models can be runtime-loaded (not in group games unless inserted before publish).",
          "Does Roblox's automated moderation still block models containing require-like calls, and is the late-2025 false-positive fixed? This only matters if we ever distribute our own models on the Creator Store.",
          "Has automatic sandboxing of Creator Store assets shipped? The docs at 2026-10-17 still describe it as future, and Capabilities as a client beta.",
          "Do private mesh or 3D Importer uploads on the owner's account have rate limits or verification requirements? The confirmed 200/10-per-30-days limits apply to DISTRIBUTING on the Creator Store."
        ]
      },
      {
        "topic": "Skeptic re-check of 'synty' findings (Synty POLYGON/Sidekick licences, Roblox position, redistribution, prices, Roblox technical limits, alternatives). Access note: WebFetch and curl to syntystore.com, syntystudios.com, fab.com, create.roblox.com, devforum.roblox.com, kaylousberg.itch.io and web.archive.org all failed (ENOTFOUND, or proxy CONNECT 403). github.com, raw.githubusercontent.com and gist.github.com were readable, and four claims marked 'confirmed' come from full reads of those pages. Every other claim rests on WebSearch snippets, not full-page reads. Re-check verdicts are prefixed [CONFIRMED], [CONTRADICTED], [CORRECTED], [NEW] or [CANNOT VERIFY].",
        "claims": [
          {
            "claim": "[CONFIRMED via snippets] Synty sells under two licence types. (1) The One-Time Purchase Licence gives perpetual rights to the specific packs bought. (2) The Standard Subscription Licence (SyntyPass / All Access Pass) covers development with any library asset only 'while your subscription plan is active'.",
            "source_urls": [
              "https://syntystore.com/pages/licences-overview",
              "https://syntystore.com/pages/one-time-purchase-licence",
              "https://syntystore.com/pages/standard-subscription-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets] One-Time Purchase EULA, dated 9 July 2026 per a search summary:\n- Each licence includes 5 seats for 'your Team' unless the purchase documentation says otherwise.\n- Licences must cover the Team's highest headcount, at purchase or at any time afterwards, and more must be bought straight away if the Team grows.\n- Extra licences cost the original list price, ignoring promotions.\n- The licence is non-exclusive and royalty-free, 'worldwide, and is not limited by game engine, OS, platform or device'.\n- It is perpetual and cannot be terminated except as the EULA states.",
            "source_urls": [
              "https://syntystore.com/pages/one-time-purchase-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets] 'Team' means employees, contractors and other collaborators in a technical or creative role on any product that incorporates the assets. It excludes people working solely as producers or project managers, or solely on music or audio. Contractors may access source files, but must delete all copies when their engagement ends.",
            "source_urls": [
              "https://syntystore.com/pages/one-time-purchase-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets, with one CORRECTION] Redistribution rules:\n- One-Time EULA: 'You must not share the source files of any Assets outside your team.' You must not distribute the assets as stock art (2D or 3D) or otherwise share them for re-use by third parties. Modifying an asset does not make it yours.\n- FAQ: you may edit assets in Blender or Maya, but 'it is prohibited to resell any edited assets'.\n- Correction on transfer: the FAQ says licences are non-transferable, but the One-Time EULA allows a transfer to an entity that acquires all or substantially all rights in the products using the assets. This needs written notice to Synty and a signed undertaking from the transferee. The Subscription EULA is fully non-transferable.\n- Conclusion: Synty FBX, Blend or texture files, original or modified, in a public GitHub repo would breach the EULA.",
            "source_urls": [
              "https://syntystore.com/pages/one-time-purchase-licence",
              "https://syntystore.com/community/faq",
              "https://syntystore.com/pages/standard-subscription-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by full GitHub read] Flynsarmy/synty-in-blender is MIT licensed, and its README says 'No Synty assets are distributed in this repo. They can be purchased from the Synty store.' The SyntyStudios GitHub org has four public repos and no asset packs: synty-store-importer-unity (BSD-3-Clause), SidekicksToolRelease, SidekicksToolReleaseDev, and a forked gdrive-upload-action (MIT).",
            "source_urls": [
              "https://github.com/Flynsarmy/synty-in-blender",
              "https://github.com/SyntyStudios"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONTRADICTED] The original finding said the One-Time EULA lists 'creation of content for Metaverse-related and/or Game Creation Software and products' as a licence entitlement. Two search snippets quote the EULA verbatim and put that phrase in the PROHIBITED list: 'END USER will be prohibited from using the asset licence for the following products: Creation of Non-Fungible-Tokens (NFT) and/or use in Blockchain based projects or products. Creation of content for Metaverse-related and/or Game Creation Software and products. Inclusion in datasets utilised by Generative AI Programs...'. One other search summary paraphrased it as an 'entitlement', so the snippets conflict. The verbatim quotes are more reliable. Roblox is arguably 'Game Creation Software', so read literally, the current One-Time EULA may bar making content for Roblox.",
            "source_urls": [
              "https://syntystore.com/pages/one-time-purchase-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets, but stale] The FAQ (about 1,468 days old, so roughly 4 years) says 'Creation of content for Metaverse-related projects and products is prohibited'. It then carves out two cases:\n- A 'Metaverse Owner' (platforms such as Roblox, Second Life, VRChat) needs a custom licence to distribute assets to platform users.\n- A 'Metaverse User of an existing Game Creation Software' may use licensed assets in a project for others 'as long as they remain under your direct control and are not sublicensed in any way'.\nThis old FAQ carve-out is the only Synty text found that supports Roblox use under a One-Time licence. Whether it still overrides the July 2026 EULA's prohibited-use list is UNVERIFIED.",
            "source_urls": [
              "https://syntystore.com/community/faq",
              "https://syntystore.com/pages/one-time-purchase-licence"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "[CONFIRMED in substance; clause numbers CORRECTED] Standard Subscription Licence:\n- It defines a 'Content Creation System' as 'any software, website, game engine or middleware which enables end users to create commercialised content with our Assets'.\n- It bars using the assets to create or develop Content Creation Systems.\n- It allows UGC inside such a system if you are not its developer or owner (clause 1.7 per snippet).\n- The Authorised Purpose includes UGC within a game, platform, engine or middleware. Snippets place it in clause 1.3, not 1.4(b).\n- Clause 1.4 lists prohibited uses: (a) generative-AI datasets, stock art, asset-marketplace distribution; (b) generating 3D models with Generative AI. Clause 1.5 bars NFT/blockchain use. Clause 5.4 routes Content Creation System add-ons to the licensing email.\n- Synty may change the Authorised Purpose scope on 30 days' written notice.\n- The grant is 'non-exclusive, revocable, royalty-free, worldwide, non-sublicensable and non-transferable'.\n- The SyntyPass page says it covers 'individual UGC in Content Creation Systems e.g. Roblox games'. This is the only explicit Roblox permission in current Synty licence text.\nSnippets flagged that the clause numbering in the extracts is inconsistent.",
            "source_urls": [
              "https://syntystore.com/pages/standard-subscription-licence",
              "https://syntystore.com/products/syntypass"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippet; inference unchanged] Synty's contact page says that 'so long as the assets can only be used within your project you are allowed to monetise them', for example as in-app purchases. The FAQ says Sidekick characters may be sold in-game, for example as skins, under the applicable licence. INFERENCE (not stated by Synty): selling Synty-derived Roblox Marketplace or UGC avatar items is outside 'within your project'. Roblox also requires the meshes and textures behind avatar items to be Open Use, which would expose them to anyone.",
            "source_urls": [
              "https://www.syntystudios.com/contact",
              "https://syntystore.com/community/faq",
              "https://create.roblox.com/docs/projects/assets/privacy"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED + EXPANDED] Both Synty licences bar:\n- NFT/blockchain use;\n- inclusion in generative-AI datasets or development of generative-AI programs;\n- 'Generation of 3D models utilising Generative AI Programs' (missing from the original finding).\nThe FAQ calls this a 'blanket no NFT or Blockchain policy'. Custom licences (Metaverse, NFT, AI, reselling, agency) are arranged through Synty. The email spelling differs by source: the subscription EULA gives licencing@syntystudios.com, and the contact page lists licensing@syntystudios.com.",
            "source_urls": [
              "https://syntystore.com/pages/one-time-purchase-licence",
              "https://syntystore.com/pages/standard-subscription-licence",
              "https://www.syntystudios.com/licencing-plans",
              "https://www.syntystudios.com/contact"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED + CAVEATS] In June 2021 Roblox partnered with Synty to release free Synty packs in the Toolbox/Creator Store: Nature, City, and the Dungeon packs (Weapons & Props, Cave & Castle Interiors, Skeletons & Bones, and others). The listings say they are licensed for use in any Roblox game, and the DevForum announcement says they are 'completely free to use in anything you want to create on Roblox'. Two caveats are new:\n- A July 2024 DevForum bug report says the City Pack texture atlas was moderated, leaving most of its textures grey.\n- DevForum users reported items missing from the Dungeon pack.\nNo medieval village, farm or Fantasy Kingdom pack is in the set.",
            "source_urls": [
              "https://create.roblox.com/store/asset/6933438443/Synty-Nature-Pack",
              "https://create.roblox.com/store/asset/6933556508/Synty-City-Pack",
              "https://create.roblox.com/store/asset/6933790012",
              "https://create.roblox.com/store/asset/6934021345/Synty-Dungeon-Pack-Cave-Castle-Interiors",
              "https://devforum.roblox.com/t/free-synty-asset-packs-released-in-the-marketplace/1283755",
              "https://devforum.roblox.com/t/synth-city-pack-texture-was-moderated/3063788"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED + NEW] No Synty–Roblox licensing announcement for 2025–2026 was found. Roblox's License Manager launched on 15 July 2025 with Netflix, Lionsgate, Sega and Kodansha, and Synty is not named. NEW: a Synty reply on a store product page says 'At this stage, we don't natively support Roblox'. A July 2026 customer review asks for Roblox support and says the meshes use multiple textures per mesh.",
            "source_urls": [
              "https://www.businesswire.com/news/home/20250715671039/en/Roblox-Announces-New-Licensing-Platform-For-Experiences",
              "https://about.roblox.com/newsroom/2025/07/roblox-launches-new-licensing-platform-for-experiences",
              "https://syntystore.com/products/polygon-samurai-empire",
              "https://shop.app/products/8006594527484/polygon-elven-realm"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets] SyntyPass pricing:\n- USD 40/month with a 3-month pre-paid minimum, or USD 30/month billed annually (12 months pre-paid, 25% saving).\n- 5 seats per licence, and USD 10 store credit per licence per month, usable only on one-time purchase licences.\n- Payments are non-refundable.\n- The FAQ: 'Your SyntyPass licensing will end after your 3 month pre-paid minimum term concludes' (on cancellation).",
            "source_urls": [
              "https://syntystore.com/products/syntypass",
              "https://syntystore.com/community/faq"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CANNOT VERIFY] No source says whether a Roblox game already shipped with SyntyPass assets may stay live, or be updated, after cancellation. The available text points against it: the licence is 'revocable', development is licensed only 'while your subscription plan is active', and licensing 'will end' after the term. The marketing line 'cancel once your project is complete' is the only text suggesting otherwise.",
            "source_urls": [
              "https://syntystore.com/products/syntypass",
              "https://syntystore.com/pages/licences-overview",
              "https://syntystore.com/pages/standard-subscription-licence"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "[CONFIRMED price; details CORRECTED] POLYGON Knights Pack: USD 29.99 regular on the Synty Store and the Unity Asset Store (package 83694). The Unity listing shows latest version dated 17 Aug 2026 and €27.59 in the EU. An older Unity snapshot showed USD 24.89 (17% off). The USD 14.99 at 50% off and the Synty Store 'Sold out' status were not re-verified for this pack.",
            "source_urls": [
              "https://syntystore.com/products/polygon-knights-pack",
              "https://assetstore.unity.com/packages/3d/environments/fantasy/polygon-knights-pack-art-by-synty-83694"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED] POLYGON Fantasy Characters Pack: USD 29.99 on the Synty Store and the Unity Asset Store (package 97186).",
            "source_urls": [
              "https://assetstore.unity.com/packages/3d/characters/humanoids/fantasy/polygon-fantasy-characters-pack-art-by-synty-97186",
              "https://syntystore.com/products/polygon-fantasy-characters-pack"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[PARTLY CONFIRMED] POLYGON Modular Fantasy Hero Characters: USD 149.99 regular, 720 modular pieces, custom colour-change shader, male and female variants. A collection listing showed it sold out. Not re-verified: the USD 74.99 sale, the claim that the 120 premade characters are Unity-only, and the claim that the page repeats Metaverse bans.",
            "source_urls": [
              "https://syntystore.com/products/polygon-modular-fantasy-hero-characters"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED price; version CORRECTED] POLYGON Fantasy Kingdom Pack:\n- USD 349.99 on the Synty Store and the Unity Asset Store (package 164532), with 2,100+ prefabs and modular castle and house systems with interiors, siege and army props.\n- Correction: the Unity listing's latest version is 1.12.5, dated 16 Aug 2026 (265.6 MB, Unity 2022.3.56), not 1.12.4 from 27 May 2026.\n- It is also on Fab, listed 'From $349.99'.\n- The Synty Store showed it sold out with 50% banners.",
            "source_urls": [
              "https://assetstore.unity.com/packages/3d/environments/fantasy/polygon-fantasy-kingdom-pack-art-by-synty-164532",
              "https://syntystore.com/products/polygon-fantasy-kingdom",
              "https://www.fab.com/listings/3d968be5-531f-4f6c-abf9-1a799dca2641"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED + EXPANDED] POLYGON Farm Pack:\n- USD 49.99 regular, seen at USD 24.99 (50% off) on Unity.\n- 173 plants: sunflowers, pumpkins, chillis, hemp, strawberries, tomatoes, corn, wheat, peaches and more.\n- Six rigged characters (Farmer Male, Farmer Male Old, Farmer Female, Farm Boy, Farm Girl, Scarecrow), with no animations included.\n- The Unity listing uses the Standard Unity Asset Store EULA but offers 'Restricted Single Entity' and 'Restricted Multi Entity' tiers.\n- Version 1.6.3 was not re-verified.\n- Hemp is cannabis-adjacent and needs a Roblox policy check.",
            "source_urls": [
              "https://syntystore.com/products/polygon-farm-pack",
              "https://assetstore.unity.com/packages/3d/environments/industrial/polygon-farm-pack-art-by-synty-146192"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[NEW, missed by the original] POLYGON Fantasy Village:\n- USD 299.99 on the Synty Store, also listed on Fab.\n- 1,000+ prefabs, 15+ preset modular buildings, and a 350+ item generic assets folder.\n- A town centre, farmland and cottages; Fab tags include Farm, Harvest, Field, Windmill and Cottage.\n- Rigged animal characters, plus foliage, river and chimney-smoke FX.\nIt is the closest Synty match to a medieval village with farms.",
            "source_urls": [
              "https://syntystore.com/products/polygon-fantasy-village",
              "https://www.fab.com/listings/fff5101d-d58f-412f-8a9e-f768f1e7eeb3?lang=en"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CORRECTED] Sidekick packs:\n- Fantasy Villagers: USD 199.99 on the Synty Store and Unity (Unity v1.0.1, 30 Jan 2026). It has 83 villager parts plus 91 human base parts and Character Creator access.\n- Fantasy Sorcerers: USD 199.99, with 131 parts. The 'USD 139.99 sale' was not re-verified.\n- Both showed as sold out on the Synty Store.\n- Synty officially supports only Unity and Unreal; the Unreal plugin is in beta.\n- The Unity tool v1.2.1 (30 June 2026) added 'Generate FBX when merging parts', so FBX export goes through Unity.\n- Sidekick uses its own skeleton, which needs animation retargeting.\n- A customer review asks for a Blender export route.",
            "source_urls": [
              "https://syntystore.com/products/fantasy-villagers-sidekick-modular-characters",
              "https://assetstore.unity.com/packages/3d/characters/fantasy-villagers-sidekick-modular-characters-by-synty-343744",
              "https://syntystore.com/products/fantasy-sorcerers-sidekick-modular-characters",
              "https://syntystore.com/pages/sidekicks-changelog",
              "https://syntystore.com/community/faq"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CANNOT VERIFY cause] Many Synty Store packs show 'Sold out' alongside SyntyPass promotion. Re-observed for Fantasy Kingdom, Town, Modular Fantasy Hero, Fantasy Villagers and Fantasy Sorcerers. No source explains it or says one-time sales have ended.",
            "source_urls": [
              "https://syntystore.com/collections/all",
              "https://syntystore.com/products/polygon-fantasy-kingdom",
              "https://syntystore.com/products/fantasy-villagers-sidekick-modular-characters"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "[CONFIRMED via snippets] Humble Bundle purchases get 1 seat instead of 5. Synty 'cannot supply files to you when you have purchased from another store for legal reasons', treating Unity and Unreal/Fab as separate stores. Synty licences cannot be moved to the Unity Asset Store. The One-Time EULA's definition of 'Store' excludes the Unity Asset Store.",
            "source_urls": [
              "https://syntystore.com/community/faq",
              "https://syntystore.com/pages/one-time-purchase-licence"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED + CAVEAT] Unity Asset Store:\n- Unity's support article says Asset Store assets 'are not restricted to Unity projects' and may be used with other engines under the Asset Store EULA.\n- 'Restricted Assets' carry separate terms in their accompanying materials. An older Unity support article says Restricted Assets are 'only valid for personal and non-commercial use'.\n- Synty listings (for example Farm) show 'Restricted Single Entity / Restricted Multi Entity' tier labels. A forum user says this is the old 'Site' licence renamed, not the Restricted Asset designation. The real meaning is UNVERIFIED.",
            "source_urls": [
              "https://support.unity.com/hc/en-us/articles/34387186019988-Can-I-use-assets-from-the-Asset-Store-with-other-engines",
              "https://unity.com/legal/as-terms",
              "https://assetstore.unity.com/browse/eula-faq",
              "https://support.unity.com/hc/en-us/articles/205623589-Can-I-use-assets-from-the-Asset-Store-in-my-commercial-game?page=2"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED via snippets; consensus part not re-checked] Unity Asset Store seats:\n- Single Entity: one company; non-extension assets may be shared with its employees.\n- Multi Entity: extends to subsidiaries, affiliates and supervised independent contractors.\n- Editor extensions: per seat, with two computers per seat.\n- Community posts disagree on whether an unregistered group counts as one entity.\n- The 'no public repo' community consensus was not re-verified.",
            "source_urls": [
              "https://assetstore.unity.com/browse/eula-faq",
              "https://forum.unity.com/threads/new-asset-store-license-single-multi-entity.821226/",
              "https://discussions.unity.com/t/what-kind-of-license-can-be-used-to-protect-assets-purchased-from-the-asset-store-in-a-public-repo/860104"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CORRECTED] Fab:\n- Tiers: Personal (≤ USD 100k gross revenue in the last 12 months) and Professional (above that), with the same scope of rights in both.\n- The Standard License permits commercial distribution of projects that incorporate the assets and bars standalone resale or redistribution.\n- The 'prevent end-user extraction' and 'no third-party level-editor incorporation' terms come only from a secondary wiki (Licenseware); the official text was not confirmed.\n- Correction: fab.com/listings/02cc30c5-… is 'POLYGON - Shopping Plaza Map', not Prototype or Adventure. Prototype is 08c843dc-…\n- Fantasy Kingdom and Fantasy Village are on Fab.\n- A snippet says the Fab Fantasy Kingdom listing is tagged as allowing usage with AI. That conflicts with Synty's own AI bans and is unexplained.\n- 'Vikings not migrated' was not re-verified.",
            "source_urls": [
              "https://dev.epicgames.com/documentation/fab/licenses-and-pricing-in-fab",
              "https://www.fab.com/eula",
              "https://wiki.licenseware.io/wiki/fab-and-epic-content-licensing/",
              "https://www.fab.com/listings/02cc30c5-0bce-4ff5-9104-8c2251aec259",
              "https://www.fab.com/listings/08c843dc-696d-450e-971a-c4c9a2ce781f",
              "https://www.fab.com/listings/3d968be5-531f-4f6c-abf9-1a799dca2641"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by full GitHub read; itch.io details via snippets] KayKit is CC0 1.0 Universal: 'Free for personal and commercial use, no attribution required.'\n- Adventurers 1.0 on GitHub: 4 characters (+2 in EXTRA) and 75 animations. The current itch.io page says 5 characters in the free version.\n- Its LICENSE.txt names CC0 and links the legal text, with a non-mandatory credit request.\n- Medieval Hexagon: 200+ tiles, buildings and props (blacksmith, church, tavern, market, windmill, barracks and more) in 4 colour variants, as FBX and glTF. It uses a single 1024×1024 gradient atlas and lists Roblox as compatible.\n- itch.io: EXTRA tier USD 9.99, Source (.blend) USD 14.99. No separate licence is stated for the paid tiers. The author asks that unmodified copies are not resold.",
            "source_urls": [
              "https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0",
              "https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/LICENSE.txt",
              "https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0",
              "https://kaylousberg.itch.io/kaykit-adventurers",
              "https://kaylousberg.itch.io/kaykit-medieval-hexagon"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CORRECTED] Roblox technical fit:\n- Importer formats: .fbx, .obj and .gltf; .glb is not documented.\n- The official spec says individual meshes cannot exceed 20,000 triangles. The old 10k limit is outdated.\n- Skinned meshes: at most 4 bone influences per vertex, with no influence on the Root bone.\n- One UV set per component, UVs in 0–1, and one material per mesh object.\n- Correction: 4K (4096×4096) textures are now supported through Texture Streaming (Studio beta 30 Jan 2026, later in published experiences). Some Roblox docs and upload pages still say 1024.\n- Synty meshes can carry multiple materials or textures per mesh. Buyers report splitting them by material in Blender before import.\n- No official Synty triangle counts were found.",
            "source_urls": [
              "https://create.roblox.com/docs/studio/importer",
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://create.roblox.com/docs/art/modeling/texture-specifications",
              "https://devforum.roblox.com/t/4k-texture-rendering/4316229",
              "https://create.roblox.com/docs/avatar/character-bodies/specifications",
              "https://create.roblox.com/docs/art/modeling/skin-a-humanoid-model",
              "https://syntystore.com/products/polygon-samurai-empire"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CONFIRMED by full gist read] The nightcycle gist samples each face's UV colour on the Synty texture, splits an OBJ into one OBJ per colour group, and includes a Luau script that groups the imported MeshParts and sets Color from the hex in each part name.",
            "source_urls": [
              "https://gist.github.com/nightcycle/dba37e7241aac9873d92edc8105f3019"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "[CONFIRMED + UPDATED] Roblox Asset Privacy:\n- It governs only the default for new Images, Decals and Meshes, and is not retroactive.\n- Open Use is irreversible; an asset cannot go back to Restricted.\n- Roblox says it 'is not a form of DRM'.\n- UPDATE: the feature is now fully released, and per Creator Updates is enabled by default for newly created individual and group accounts. Older accounts still default to Open Use unless it is switched on.\n- Avatar Marketplace items need their dependent meshes and textures to be Open Use.",
            "source_urls": [
              "https://create.roblox.com/docs/projects/assets/privacy",
              "https://devforum.roblox.com/t/full-release-privacy-for-newly-created-image-mesh-and-decal-assets/4620416",
              "https://create.roblox.com/updates"
            ],
            "confidence": "likely"
          },
          {
            "claim": "[CANNOT VERIFY, not re-checked] Piracy sites offering paid Synty packs appear in search results. These URLs were not visited or re-searched. In any case, they are not legitimate sources.",
            "source_urls": [
              "https://unityassetcollection.com/polygon-adventure-pack-free-download/",
              "https://desirefx.me/3d_models/polygon-fantasy-kingdom-pack-art-by-synty-unity/"
            ],
            "confidence": "unverified"
          }
        ],
        "implications_for_project": [
          "Unchanged: no Synty, Unity Asset Store or Fab source mesh, texture, .blend or derived mesh may go into the public repo. Commit only generators, manifests and scripts that point at a local, gitignored path, plus Roblox asset IDs. KayKit (CC0) is the only premium-looking option whose source files may be committed.",
          "REVERSED: the earlier recommendation that one-time packs are safer than SyntyPass for Roblox no longer holds. Current SyntyPass text explicitly covers 'individual UGC in Content Creation Systems e.g. Roblox games', but the licence is revocable and post-cancellation rights are unknown. The July 2026 One-Time EULA appears to list 'Creation of content for Metaverse-related and/or Game Creation Software and products' as PROHIBITED, so Roblox use there rests on a roughly 4-year-old FAQ carve-out. Neither path is clean. Do not buy until Synty confirms in writing (to licensing@ / licencing@syntystudios.com) that a self-published Roblox experience is covered, and, for SyntyPass, whether a shipped game may stay live and be updated after cancellation. Sending that email is an external message and needs owner approval.",
          "The Unity Asset Store route (Standard Unity EULA, 'not restricted to Unity projects') may avoid Synty's Metaverse/Game Creation Software wording. This is unverified: Synty listings use 'Restricted Single Entity' tiers whose meaning is unclear, and Synty's own EULA may also apply. Ask the same question in the Synty email.",
          "Asset Privacy: before any upload, check that the owner's account or group has Asset Privacy turned on. It is the default only for newly created accounts, and Open Use cannot be undone. Never upload licensed meshes as Open Use. Remember privacy is not DRM, and that Synty-derived avatar or UGC items would have to be Open Use, which rules them out.",
          "Pack choice: POLYGON Fantasy Village (USD 299.99; village, farmland, cottages, windmill, 1,000+ prefabs), missed earlier, fits AI Kingdoms better than Fantasy Kingdom (USD 349.99). Revised list-price totals:\n- core (Fantasy Characters 29.99 + Knights 29.99 + Farm 49.99): about USD 110;\n- core + Fantasy Village: about USD 410;\n- core + Village + Kingdom: about USD 760.\nSyntyPass costs USD 120 minimum (3 months) or USD 360 a year and covers all of these while active. Every option needs owner approval.",
          "Sidekick (USD 199.99 per pack) is a poor fit for this pipeline. Official support is Unity and Unreal only, FBX export comes from the Unity tool, and characters use a custom skeleton. A Linux cloud session cannot run that tool, so it would need a Unity step on the owner's machine.",
          "Rig and import fit: Roblox allows up to 20k triangles per mesh, 4 bone influences per vertex and one material per MeshPart. Synty characters and props can be multi-material, so Blender scripts must split them by material or colour (nightcycle method) and then cut characters into rigid per-bone segments for the existing at-most-11-Part Motor6D citizen rig. Skinned MeshParts for about 300 citizens remain an unmeasured performance risk.",
          "Textures: the 1024px cap no longer binds because 4K is supported through Texture Streaming. Synty and KayKit gradient atlases are small anyway, so this matters little. Per-kingdom recolouring is still best done with vertex/part Color after a colour split.",
          "AI clauses: both Synty licences bar generative-AI datasets and 'Generation of 3D models utilising Generative AI Programs'. Do not feed Synty meshes to AI 3D-generation, retopology or text-to-3D tools. Deterministic Blender Python edits written by an agent are probably not 'Generative AI Program' use, but that is unconfirmed; include it in the Synty email and get FORGE-07 sign-off.",
          "The free Roblox-published Synty packs (Nature, Dungeon) remain a legally clear starting point for trees, rocks and props. Avoid the City Pack, whose atlas was moderated. FORGE-07 must inspect the packs for scripts before insertion."
        ],
        "open_questions": [
          "Does the full 9 July 2026 One-Time EULA really list 'Creation of content for Metaverse-related and/or Game Creation Software and products' under prohibited uses? Snippets conflict, and syntystore.com was unreachable, so the owner should read the page in a normal browser.",
          "Does Synty's old FAQ 'Metaverse User' carve-out still apply under the July 2026 One-Time EULA? Written confirmation from Synty is needed.",
          "Under SyntyPass (licence described as 'revocable'), can a published Roblox experience stay live and receive updates after cancellation?",
          "What do the 'Restricted Single Entity / Restricted Multi Entity' tiers on Synty's Unity listings mean? Does a Unity-bought Synty pack carry only the Unity EULA, or Synty's EULA too, for Roblox use?",
          "Why are many Synty Store packs marked 'Sold out'? Has Synty ended direct one-time sales?",
          "Why is Synty's Fab Fantasy Kingdom listing tagged as allowing AI usage when Synty's EULAs ban generative-AI use? Which terms govern a Fab purchase?",
          "What does the official Fab EULA text say about end-user extraction and third-party level-editor use? So far it is confirmed only through a secondary wiki.",
          "What are the triangle counts for POLYGON characters and props? They are needed for the 300-citizen budget and the 20k per-mesh cap.",
          "Do KayKit's paid EXTRA and Source tiers carry the same CC0 licence as the free tier? The itch.io page could not be read.",
          "Is Asset Privacy currently enabled on the owner's existing Roblox account or group?",
          "Do the 2021 Roblox-published Synty packs contain scripts? FORGE-07 needs to inspect them."
        ]
      },
      {
        "topic": "roblox_tech, skeptic re-check (2026-10-18). Roblox technical paths for imported character and environment meshes: importer limits, asset upload and ownership, Rojo, skinned Bones vs Motor6D rigs, EditableMesh, Open Cloud Assets API, texture and triangle budgets for crowds. Access note: in this re-check WebFetch to create.roblox.com, devforum.roblox.com, rojo.space and creation.dev all failed with DNS errors (getaddrinfo ENOTFOUND). Official text was checked in a clean clone of github.com/Roblox/creator-docs. `git fetch` confirmed HEAD 70a0110fee0c0900103e545fcaee69a8bd2a942f (2026-10-17) equals origin/main, with no local changes. Rojo docs were checked at github.com/rojo-rbx/rojo.space HEAD 8dbffe0. Rojo 7.7.1 was run locally for one headless test. DevForum content comes from WebSearch snippets only. Each claim starts with its verdict: CONFIRMED, CORRECTED, PARTLY CONFIRMED, CANNOT VERIFY or NEW.",
        "claims": [
          {
            "claim": "CONFIRMED. Individual meshes cannot exceed 20,000 triangles. Geometry must be watertight, in quads where possible (no N-gons), and have volume (not 0 thickness). Creator Store models have the same rule: each mesh dependency at most 20,000 triangles. The docs phrase the limit per individual mesh. A DevForum staff reply (snippet only) also says there is no total polygon limit for a model, so splitting geometry across MeshParts is supported.",
            "source_urls": [
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/art/modeling/specifications.md",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/parts/models.md",
              "https://devforum.roblox.com/t/3d-importer-full-release/2057539?page=3"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED WITH CORRECTION. Rig rules: at most 4 bone influences per vertex. No influences on Root (for humanoids, also none on HumanoidRootNode; such influences are dropped on import). Root at 0,0,0. Bones frozen (scale 1, rotation 0). Only one animation track per exported mesh or model. Correction on bone count: the docs say an R15 rig has 'at least 16 bones, 1 for each body part and a root bone'. However, the standard R15 hierarchy lists Root, HumanoidRootNode and 15 body-part bones, which is 17 nodes. Advanced R15 allows up to 37 extra optional bones. A grep of the current docs found no per-mesh bone-count limit.",
            "source_urls": [
              "https://create.roblox.com/docs/art/modeling/specifications",
              "https://create.roblox.com/docs/avatar/character-bodies",
              "https://create.roblox.com/docs/avatar/character-bodies/specifications",
              "https://create.roblox.com/docs/art/modeling/skin-a-humanoid-model",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/avatar/character-bodies/index.md",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/avatar/character-bodies/specifications.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY. The claim that the community sees 'no practical hard bone limit, only hardware cost' did not appear in search snippets. The docs state no bone cap (checked). Search snippets show one DevForum report of a severe frame-rate drop on one teammate's machine with skinned MeshParts of 20+ bones, and a reply that even unmoving bones cost something because the mesh is still skinned.",
            "source_urls": [
              "https://devforum.roblox.com/t/skinned-meshparts-are-live/831011",
              "https://devforum.roblox.com/t/will-skinned-mesh-cubes-with-8-bones-on-corners-in-big-amount-like-163-lag-a-lot-if-bones-wont-move/2321478",
              "https://devforum.roblox.com/t/performance-impact-of-constant-290-bone-updates/2528802"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED. The Importer takes .fbx, .gltf and .obj meshes. FBX and glTF support multiple meshes and hierarchies, basic and PBR textures, cages, rigs, avatar components, animation data and vertex colours. Rig Type is R15, Custom or No Rig, auto-detected by default. 'Keep Zero Influence Bones' is off by default. 'Merge Meshes' (off by default) merges all MeshParts into one MeshPart instead of a Model. The Asset Manager bulk import does not support meshes with rigging, skinning or animation, accessories, or characters with facial animation. Minor: the Importer's image list also includes .gif.",
            "source_urls": [
              "https://create.roblox.com/docs/studio/importer",
              "https://create.roblox.com/docs/parts/meshes",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/studio/importer.md",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/parts/meshes.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. Textures can be up to 4096x4096. Separately uploaded textures must be .png, .jpg, .tga or .bmp. Open Cloud image uploads must be under 8000x8000. Marketplace avatar textures are capped at 2048x2048. PBR budget: 256 px per 2x2x2-stud volume, and 1024x1024 is marked the maximum, for full-body clothing and humanoid characters. 256 is the recommended size for hair and shoes; separately, 256 is the maximum for non-albedo maps on rigid accessories. One material per mesh. Normal maps must be OpenGL tangent-space. Roblox may downsample when many textures render at once.",
            "source_urls": [
              "https://create.roblox.com/docs/art/modeling/texture-specifications",
              "https://create.roblox.com/docs/cloud/guides/usage-assets",
              "https://create.roblox.com/docs/avatar/character-bodies/specifications",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/art/modeling/texture-specifications.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY (still disputed). Search snippets confirm that a staff reply in the 3D Importer full-release thread says the importer auto-simplifies meshes over 20k and that models have no total polygon limit. Nilo (a vendor) says such imports fail with an error, and its own articles disagree with each other (10k / 20k / 21k). The skinned-mesh threads mention 10k-to-50k rig and 5k-to-10k mesh increases, then a later 21k mesh limit. The current Importer docs do not describe what happens above 20k. Only the solid-modeling (CSG) doc says results over 20k are simplified to 20k, and that is a different feature.",
            "source_urls": [
              "https://devforum.roblox.com/t/3d-importer-full-release/2057539?page=3",
              "https://nilo.io/articles/vibe-code-roblox-triangle-limit",
              "https://devforum.roblox.com/t/skinned-meshpart-studio-beta/705528",
              "https://devforum.roblox.com/t/skinned-meshparts-are-live/831011",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/parts/solid-modeling.md"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED WITH CORRECTION. MeshPart.MeshId and MeshContent are asset URIs. Scripts cannot write them (NotAccessibleSecurity), but they serialise (can_load and can_save true). AssetService:CreateMeshPartAsync(Content, options) creates new MeshParts from scripts. Correction: MeshPart:ApplyMesh(sourceMeshPart) does not take Content. It copies MeshContent, TextureContent, RenderFidelity, CollisionFidelity, FluidFidelity, MeshSize and collision geometry from another MeshPart onto an existing one. MeshSize is read-only and not serialised. Importer: 'Creator' sets the owning user or group. 'Upload to Roblox' (on by default) adds the asset to inventory. 'Add to Workspace' run from a saved or published game also grants that game permission to use the restricted asset.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/MeshPart",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService",
              "https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart",
              "https://create.roblox.com/docs/studio/importer",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/MeshPart.yaml"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED, WITH ADDITIONS. Images, Decals and Meshes are created Open Use unless the user (Creator Dashboard > Settings > Advanced) or the group owner (Group Profile) opts in to restricting assets on creation. The setting is not retroactive. Open Use is irreversible. Game grants are permanent. Your own assets always work in your own published games. Unpermitted restricted assets do not load and log a clickable Output error. Addition: Asset Privacy does NOT change defaults for Models, MeshParts, Packages, Animations, Audio or Video. Others can still see a restricted asset's metadata.",
            "source_urls": [
              "https://create.roblox.com/docs/projects/assets/privacy",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/projects/assets/privacy.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED (from the source repo; rojo.space itself was unreachable). Rojo supports binary .rbxm and XML .rbxmx models 'generated by Roblox Studio or another tool'. Its Limitations section lists MeshPart.MeshId (with binary data such as Terrain and CSG, and HttpService.HttpEnabled) as a property the Studio plugin cannot live-sync, and recommends generating a place file instead. So the workflow (Studio import, export .rbxm, reference with $path, rojo build) is consistent with the docs. Caveat for Open Cloud: the Assets guide warns that .rbxm/.rbxmx files edited outside Studio might not upload or work.",
            "source_urls": [
              "https://rojo.space/docs/v7/sync-details/",
              "https://github.com/rojo-rbx/rojo.space/blob/8dbffe025b928e2ff62969b386813a88b5eb593f/docs/sync-details.md",
              "https://create.roblox.com/docs/cloud/guides/usage-assets"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "PARTLY CHECKED. Headless test: Rojo 7.7.1 built a .model.json MeshPart with only MeshId and Size. The output .rbxmx held only MeshContent, Size and Name, with no initial-size, collision or physics data. Creator Docs list MeshSize as not serialised. How Studio or a client sizes and collides such a MeshPart was not tested (no Studio on Linux). The DevForum reports of wrong scale for scripted or JSON-rebuilt MeshParts are confirmed only as snippets. Exporting a .rbxm from Studio is still the safer path, but the failure mode is unverified.",
            "source_urls": [
              "https://devforum.roblox.com/t/meshpart-created-by-script-has-the-wrong-size/1942754",
              "https://devforum.roblox.com/t/meshpartgetoriginalsize/58179",
              "https://create.roblox.com/docs/reference/engine/classes/TriangleMeshPart",
              "https://github.com/rojo-rbx/rojo.space/blob/8dbffe025b928e2ff62969b386813a88b5eb593f/docs/sync-details.md"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED WITH CORRECTION. InsertService:LoadAsset only loads assets created or owned by the game creator, shared by the asset owner, or owned by Roblox (plus OpenUse benign types such as clothing and accessories). Free Creator Store models need AssetService:LoadAssetAsync with AllowInsertFreeAssets. Correction: scripts cannot set AllowInsertFreeAssets (read security is RobloxScriptSecurity). It is controlled only by the Studio Experience Settings toggle 'Allow Loading Third Party Assets', which is off by default. Addition: LoadAssetAsync returns a model with Sandboxed=true and no script Capabilities by default, so loaded scripts do not run unless capabilities are granted.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/InsertService",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/AssetService.yaml"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. Bone.Transform is the animated offset of a bone relative to its CFrame. Scripts can write it (security None) 'in a manner similar to Motor6D.Transform'. It is NotReplicated and not saved (can_save false). Motor6D.Transform is Hidden and NotReplicated, and is applied as a batch in a parallel job after RunService.PreSimulation; the docs call this 'much more efficient than many immediate updates'. If an Animator exists, it overwrites Motor6D.Transform every frame between PreAnimation and PreSimulation. The performance guide says procedural animation should write Motor6D.Transform, not C0/C1. So procedural animation must run on each client to be visible.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/Bone",
              "https://create.roblox.com/docs/reference/engine/classes/Motor6D",
              "https://create.roblox.com/docs/performance-optimization/improve",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/Motor6D.yaml"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY. The earlier finding said bones do not change collision or physics. This is not in the current Bone reference or anywhere else in the docs (grep). The only related text: constraints attached to Bones use the bones' animated position and orientation.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/Bone",
              "https://create.roblox.com/docs/physics/mechanical-constraints"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED. Official guidance for many NPCs: play NPC animations on the client by creating the Animator there. Prefer AnimationController or a custom movement controller over Humanoid. Disable unused HumanoidStates. Pool NPCs and spawn or cull them by player proximity. Avoid frequent instantiation or modification of Humanoid or skinned models; updateInvalidatedFastClusters over 4 ms is a warning sign. Skinned MeshParts in a Model without a Humanoid use spatial FastClusters that rebuild as they move. Adding a Humanoid forces a single cluster but adds memory overhead. Size and scale changes also rebuild FastClusters.",
            "source_urls": [
              "https://create.roblox.com/docs/performance-optimization/improve",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/performance-optimization/improve.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY, with partial checks. Snippets confirm a reply in the 290-bone thread suggesting under about 3k bone updates per frame on PC. The '2,000 moving bones at 60 FPS' figure was not found. The 10,000+ NPC thread exists: iPhone 8 Plus, 55-60 FPS, self-reported, network-bound at 100-120 KB/s. However, snippets do not confirm that it packs 100 NPCs into one skinned MeshPart, and say a later edit moved to a humanoid-based NPC system. The Pixel 7 Pro thread exists, but the '30 NPCs of about 1k triangles' detail was not confirmed; replies blamed memory and scripts.",
            "source_urls": [
              "https://devforum.roblox.com/t/performance-impact-of-constant-290-bone-updates/2528802",
              "https://devforum.roblox.com/t/10000-physical-npcs-running-with-60-fps-on-low-end-device/3660293",
              "https://devforum.roblox.com/t/game-with-skinned-meshes-has-poor-performance-on-mobile-renderfidelity-doing-nothing/2649641"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "PARTLY CONFIRMED. The Automatic RenderFidelity distances (Highest under 250 studs, Medium at 250-500, Lowest at 500+) are confirmed in the enum and MeshPart docs. Snippets confirm a staff reply in 'Skinned MeshParts are live' saying LOD 'has never worked with skinned meshes' and is a known limitation under investigation. The reply is undated, and a 2022 'Skinned mesh rig cannot generate LOD' thread exists. No 2026 official statement was found either way.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/enums/RenderFidelity",
              "https://devforum.roblox.com/t/skinned-meshparts-are-live/831011?page=38",
              "https://devforum.roblox.com/t/renderfidelity-not-functioning/1833657",
              "https://devforum.roblox.com/t/game-with-skinned-meshes-has-poor-performance-on-mobile-renderfidelity-doing-nothing/2649641"
            ],
            "confidence": "likely"
          },
          {
            "claim": "CONFIRMED. MeshParts with the same MeshContent are instanced into one draw call when their SurfaceAppearances are identical. Without a SurfaceAppearance, TextureContents must match; with neither, Materials must match. The Importer does no de-duplication of meshes, so upload once and reuse. The docs say nothing about skinned-mesh instancing. Community (snippets only, unverified): a DevForum reply says MeshPart.Color does not affect instancing, and a 2017 Roblox rendering post says per-part colour comes from a separate instance buffer.",
            "source_urls": [
              "https://create.roblox.com/docs/performance-optimization/improve",
              "https://devforum.roblox.com/t/does-roblox-use-mesh-instancing/399564",
              "https://devforum.roblox.com/t/rendering-updates-september-2017"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. CreateEditableMesh() makes an empty mesh, with no upload. It is displayed with AssetService:CreateMeshPartAsync(Content.fromObject(em)); more MeshParts can reference the same Content, or the result can be copied onto an existing part with ApplyMesh(newMeshPart). Limits: 60,000 vertices and 20,000 triangles (a quad counts as 2); going over errors. Batch methods and skinning or FACS APIs exist; 4 bones per vertex is the general rig rule. Caveat: search shows thread 4779401 titled '[Studio Beta] EditableMesh Batching APIs & Parallel Queries'. The docs list batch methods without a beta tag, but their published-game status was not confirmed.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/EditableMesh",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/EditableMesh.yaml",
              "https://devforum.roblox.com/t/studio-beta-editablemesh-batching-apis-parallel-queries/4779401"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. EditableMesh fails by default in published games. The owner enables 'Enable Mesh / Image APIs' (Creator Dashboard > game > Configure > Settings) or 'Allow Mesh / Image APIs' (Studio Experience Settings > Security) after reviewing the Terms of Use. Clients have strict, device-specific memory budgets with no published number: CreateEditableMesh and CreateEditableMeshAsync return nil when the budget is used up. Server, Studio and plugins are unlimited. CreateEditableMeshAsync loads only assets owned by or shared with the game owner, the Studio user, or the client player, or owned by a group where one of them has edit rights; otherwise it throws.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/EditableMesh",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED (docs change only). Commit 784c5e2 (2026-10-13) removed 'you must be 13+ age verified and ID verified' from both the EditableMesh and EditableImage reference pages. No other page at HEAD mentions an ID requirement for these APIs. Search-engine copies of create.roblox.com, including localised pages, still show the old text.",
            "source_urls": [
              "https://github.com/Roblox/creator-docs/commit/784c5e217446c65958d5d84f5c5f1d127951a8d7",
              "https://create.roblox.com/docs/zh-tw/reference/engine/classes/EditableMesh"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY. It is unknown whether the platform still requires ID verification to enable Mesh / Image APIs in published games. No DevForum or official announcement of the removal was found. The earlier finding's 'reconciling the extra ID Verification requirement' quote from thread 4779401 could not be seen in snippets.",
            "source_urls": [
              "https://devforum.roblox.com/t/studio-beta-editablemesh-batching-apis-parallel-queries/4779401",
              "https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED (docs part). Content.Object values (EditableMesh, EditableImage) do not replicate yet. A server-side one on a replicated Instance arrives as an unusable placeholder that throws on access and renders as a cyan/magenta checkerboard, and the docs say not to do this. CreateDataModelContentAsync turns an EditableMesh or EditableImage into ephemeral, DataModel-scoped Opaque Content under a server storage budget. CreateContentResult values: Success, PermissionDenied, UploadFailed, StorageLimitExceeded, Unknown. The options parameter currently has no controls.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/datatypes/Content",
              "https://create.roblox.com/docs/reference/engine/classes/AssetService",
              "https://create.roblox.com/docs/reference/engine/enums/CreateContentResult",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/datatypes/Content.yaml"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY. It is unknown whether Opaque content from CreateDataModelContentAsync replicates to clients and so works around the missing replication. The docs say nothing. The cited DevForum post (4541898) did not come up in search; one third-party summary site was unreachable and its snippet called the API Studio Beta.",
            "source_urls": [
              "https://devforum.roblox.com/t/full-release-introducing-createdatamodelcontent-convert-editable-mesh-and-image-data-into-static-content/4541898",
              "https://www.creation.dev/learn/roblox-createdatamodelcontent-editable-mesh-optimization"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "CONFIRMED, WITH ADDITIONS. POST https://apis.roblox.com/assets/v1/assets: every Assets v1 endpoint, Create Asset included, is marked x-roblox-stability BETA and needs scopes asset:read and asset:write. API keys go in the x-api-key header; the key needs the 'assets' API with Read/Write in Access Permissions. A key's access equals its owner's permissions. Limits per call: one asset, up to 20 MB. Model accepts .fbx/.gltf/.glb/.rbxm/.rbxmx, imports as a Model of MeshParts, and is uploaded as a package. The Mesh type accepts only Asset Delivery API content. Content updates work only for .fbx. Poll results with GET /assets/v1/operations/{id}; the response includes moderationResult.moderationState. New from the OpenAPI spec: Create, Get and Update Asset are limited to 120 requests/min per API-key owner (or per OAuth authorization); versions, archive and rollback to 100/min; Get Operation to 300/min. Keys unused for 60 days expire. For group automation the docs recommend a dedicated alt account.",
            "source_urls": [
              "https://create.roblox.com/docs/cloud/guides/usage-assets",
              "https://create.roblox.com/docs/cloud/auth/api-keys",
              "https://create.roblox.com/docs/reference/cloud/assets/v1",
              "https://create.roblox.com/docs/cloud/reference/rate-limits",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/cloud/openapi.json"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. GPU texture memory scales with pixel count (1024x1024 uses 4x the memory of 512x512). Images are transcoded to a fixed format, so pre-compression or dropping alpha saves no memory. Most images need at most 512x512, and minor ones should be under 256x256. Tint one texture with SurfaceAppearance.Color instead of uploading colour variants. Use trim sheets. GraphicsTexture and GraphicsMeshParts are Developer Console memory tags. The Studio device emulator is not accurate for memory (design.md, test-on-hardware.md). Vertex painting reduces texture memory and draw calls (art/blender.md). The free-model warning (scripts generating thousands of instances) is in identify.md.",
            "source_urls": [
              "https://create.roblox.com/docs/performance-optimization/improve",
              "https://create.roblox.com/docs/performance-optimization/identify",
              "https://create.roblox.com/docs/performance-optimization/design",
              "https://create.roblox.com/docs/performance-optimization/test-on-hardware",
              "https://create.roblox.com/docs/art/blender"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED. ColorMap, NormalMap, MetalnessMap and RoughnessMap are PluginSecurity for both read and write. Their *Content variants (and EmissiveMaskContent) are script-readable but PluginSecurity to write. Color, AlphaMode, EmissiveStrength, EmissiveTint and ResampleMode are script-writable, and AlphaMode.TintMask exists. MeshPart.TextureID and TextureContent are script-writable. So runtime variety comes from cloning prepared SurfaceAppearances, tinting, or swapping TextureID.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance",
              "https://create.roblox.com/docs/reference/engine/classes/MeshPart",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/SurfaceAppearance.yaml"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CONFIRMED WITH CORRECTION. The docs give no general per-NPC triangle budget. Avatar body maximum is 10,742 triangles (DynamicHead 4,000, Torso 1,750, each limb 1,248; also stated in auto-setup requirements). Rigid accessories are capped at 4k. Correction on SLIM: the page shows about 2.6M vs 170k triangles (far audience) and about 670k vs 100k (near) with SLIM off and on. It links a '200 animated avatars' demo place but never says these figures come from 200 avatars. It also warns that render stats can report wrong triangle counts when SLIM avatars are on. SLIM avatars exclude NPCs (even standard or advanced R15), R6 and custom-proportion rigs. Model SLIM excludes Models with a Humanoid and animated or runtime-modified models, and needs StreamingEnabled, a place saved to Roblox, and Team Create.",
            "source_urls": [
              "https://create.roblox.com/docs/avatar/character-bodies/specifications",
              "https://create.roblox.com/docs/avatar-setup/auto-setup-requirements",
              "https://create.roblox.com/docs/avatar/rigid-accessories/specifications",
              "https://create.roblox.com/docs/workspace/streaming/slim",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/workspace/streaming/slim.md"
            ],
            "confidence": "confirmed"
          },
          {
            "claim": "CANNOT VERIFY as guidance. Snippets confirm only that Nilo, a vendor selling Roblox asset tools, publishes these numbers: 1,000-3,000 triangles for supporting NPCs on mid-range mobile, under 5,000 as an LOD target, under 100 draw calls per frame. Nilo's articles also state conflicting Roblox per-mesh limits (10k, 20k, 21k). These are not Roblox guidance.",
            "source_urls": [
              "https://nilo.io/articles/vibe-code-roblox-triangle-limit",
              "https://nilo.io/articles/vibe-coding-low-poly-optimization",
              "https://nilo.io/articles/vibe-coding-roblox-performance"
            ],
            "confidence": "unverified"
          },
          {
            "claim": "NEW, CONFIRMED. Since the Avatar Joint Upgrade, R15 player characters spawn with AnimationConstraints instead of Motor6Ds when StarterPlayer.AvatarJointUpgrade is on, which is the default for new games. Code that looks for Motor6D on player characters will not find joints. The Motor6D page says Motor6D 'remains appropriate for non-avatar mechanical rigs' where physics simulation is not needed. This affects player characters, not custom NPC Motor6D rigs; a dated beta-thread staff reply (snippet) says there are no plans to drop Motor6D rigs.",
            "source_urls": [
              "https://create.roblox.com/docs/reference/engine/classes/Motor6D",
              "https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint",
              "https://github.com/Roblox/creator-docs/blob/70a0110fee0c0900103e545fcaee69a8bd2a942f/content/en-us/reference/engine/classes/Motor6D.yaml",
              "https://devforum.roblox.com/t/studio-beta-avatar-joint-upgrade-enabling-physically-simulated-characters/3266099?page=10"
            ],
            "confidence": "confirmed"
          }
        ],
        "implications_for_project": [
          "The recommended path stands: keep the segmented Motor6D citizen rig with procedural animation, and swap primitives for shared, low-poly, rigid (unskinned) MeshParts. Official docs support instancing (same MeshContent plus identical SurfaceAppearance or TextureContent), writing Motor6D.Transform, and client-side NPC animation. Motor6D is still documented as right for non-avatar rigs; the Avatar Joint Upgrade only changes R15 player characters. That skinned meshes lose RenderFidelity LOD comes from an undated staff reply, not current docs ('likely'). At about 300-1,000 triangles per segment, automatic LOD may matter little anyway.",
          "Any FORGE code that finds joints with FindFirstChildOfClass('Motor6D') must not run on player characters in new experiences, which now use AnimationConstraint. It is fine on citizen NPC rigs the game builds itself.",
          "Variety: per the docs, the safest way to keep instancing is shared mesh, no SurfaceAppearance (or one identical SurfaceAppearance), and colour from vertex colours plus MeshPart.Color. That Color doesn't break instancing is community-reported only. Whether a different SurfaceAppearance.Color tint breaks instancing is undocumented; measure draw calls (Shift+F2 Render Stats) before relying on it.",
          "Crowd budget: treat 1,000-2,000 triangles per citizen as an unmeasured working figure. Don't anchor on SLIM's '170k for 200 avatars': the page doesn't tie those numbers to 200 avatars, render stats can misreport with SLIM avatars on, and SLIM excludes NPCs. Real-phone measurement (GraphicsMeshParts, GraphicsTexture, draw calls, FPS) is still required, and performance stays unverified until then.",
          "Build pipeline: import in Studio (owner session), export the MeshPart models as .rbxm, reference them with $path, then rojo build. Don't hand-write MeshParts in .model.json. Rojo 7.7.1 wrote only MeshContent and Size for such a part (headless test), and what Studio then does with its size and collision is unverified. If Rojo-built .rbxm files are ever sent to Open Cloud, note the docs' warning that files edited outside Studio may not upload.",
          "Open Cloud automation is possible but gated. It needs an owner-made key with the assets API Read/Write (never committed; keys idle 60 days expire). Create Asset is BETA, limited to 120 requests/min per key owner and 300/min for operation polling. Model uploads land as packages. Each operation reports a moderation state, so plan for moderation delay (length undocumented).",
          "Licensing in the public repo: Asset Privacy only restricts Images, Decals and Meshes created after it is enabled. It is not retroactive and does not cover Models, MeshParts or packages. Open Use mesh IDs written in a public .rbxm can be loaded by anyone. For paid or licence-restricted packs, enable Asset Privacy before the first import. Whether a Studio-exported .rbxm carries derived collision geometry (and so counts as redistribution) is unverified; check a sample .rbxm before committing licensed-asset exports.",
          "EditableMesh stays a fallback only: owner toggle required, unpublished client memory budget, no replication of Content.Object, 20k triangles and 60k vertices per mesh. The docs no longer mention ID verification (2026-10-13), but whether the platform still requires it is unverified, and the batching APIs may still be Studio Beta.",
          "FORGE-07 asset safety: never load Creator Store models at runtime. AllowInsertFreeAssets is off by default, can't be set by scripts, and lives in Studio Experience Settings ('Allow Loading Third Party Assets'). LoadAssetAsync sandboxes loaded scripts by default, but don't depend on that. Bring free models in through Studio, review and strip their scripts, then export to .rbxm."
        ],
        "open_questions": [
          "Does the platform (not just the docs) still require 13+ age and ID verification to enable Mesh / Image APIs in published games? Check the owner's Creator Dashboard toggle.",
          "Does Opaque Content from CreateDataModelContentAsync replicate from server to clients, how big is the server storage budget, and is the API full release or Studio Beta? DevForum post 4541898 could not be reached or found.",
          "Does the 2026 Importer auto-simplify or reject meshes over 20k triangles, and is there any per-file or per-rig total cap? Only an older staff snippet (auto-simplify, no model total) and vendor claims (error) exist.",
          "Are skinned MeshParts instanced across characters, and does RenderFidelity LOD now apply to skinned meshes? No 2026 source either way.",
          "Do different SurfaceAppearance.Color tints on the same MeshContent and SurfaceAppearance break instancing? MeshPart.Color reportedly does not (community only).",
          "Does a Studio-exported MeshPart .rbxm contain derived collision or physics geometry (PhysicalConfigData), and does that matter for redistribution of licensed packs? Inspect one exported file.",
          "How does Studio size and collide a Rojo-built MeshPart that has only MeshId and Size? Needs a Studio test by the owner.",
          "Is the existing citizen animation system on the client or the server, and does it write Motor6D.Transform or C0/C1? Check roblox/src.",
          "How long does moderation take for Open Cloud Model uploads before the asset is usable? The docs show a moderationState field but no timing.",
          "Will the experience and assets be owned by the owner's user account or a group? This decides the Importer Creator setting, who can enable Asset Privacy (groups: owner only), and whether game permission grants are needed."
        ]
      }
    ]
  },
  "workflowProgress": [
    {
      "type": "workflow_phase",
      "index": 1,
      "title": "Research"
    },
    {
      "type": "workflow_phase",
      "index": 2,
      "title": "Verify"
    },
    {
      "type": "workflow_phase",
      "index": 3,
      "title": "Synthesize"
    },
    {
      "type": "workflow_agent",
      "index": 1,
      "label": "research:quaternius",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "ae83c8a77ccec4884",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580431,
      "lastProgressAt": 1792363580431,
      "cached": true,
      "resultPreview": "{\"topic\":\"Quaternius (quaternius.com, quaternius.itch.io, poly.pizza): licences (CC0 vs the new QAL), packs that fit a medieval kingdom game, file formats, measured triangle and rig data, download sources, and whether files may be committed to a public repo\",\"claims\":[{\"claim\":\"Access note: WebFetch could not resolve quaternius.com, quaternius.itch.io, poly.pizza, opengameart.org, store.godotengin…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…"
    },
    {
      "type": "workflow_agent",
      "index": 2,
      "label": "research:kenney",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "a5dc523b35eff8f07",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580433,
      "lastProgressAt": 1792363580433,
      "cached": true,
      "resultPreview": "{\"topic\":\"Kenney (kenney.nl): license, medieval/castle/town/nature/character packs, formats, triangle counts, rigs, download sources, and fit for the AI Kingdoms Roblox aerial strategy view and a public repo\",\"claims\":[{\"claim\":\"Access note: kenney.nl, kenney.itch.io, kenney-assets.itch.io, opengameart.org, poly.pizza and create.roblox.com were all blocked (WebFetch ENOTFOUND; curl CONNECT 403 fro…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…"
    },
    {
      "type": "workflow_agent",
      "index": 3,
      "label": "research:creator_store",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "ac108b0d46303d33b",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580433,
      "lastProgressAt": 1792363580433,
      "cached": true,
      "resultPreview": "{\"topic\":\"Roblox Creator Store (formerly Toolbox): licence/terms for using store models, judging creators, free-model risks and safe vetting, redistribution/re-upload/public-repo limits, official Roblox medieval/character assets, mesh moderation and IP policy\",\"claims\":[{\"claim\":\"ACCESS NOTE: The proxy blocked WebFetch/curl to create.roblox.com, en.help.roblox.com and devforum.roblox.com (403 / EN…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…"
    },
    {
      "type": "workflow_agent",
      "index": 4,
      "label": "research:synty",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "a8ff450d58296bdba",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580434,
      "lastProgressAt": 1792363580434,
      "cached": true,
      "resultPreview": "{\"topic\":\"Synty Studios POLYGON / Sidekick packs and similar premium low-poly packs (Unity Asset Store, Fab, Synty Store): price, Roblox EULA position, public-repo redistribution, seats, style fit. Access note: WebFetch and curl to syntystore.com, devforum.roblox.com and create.roblox.com were blocked (proxy CONNECT 403 / ENOTFOUND). Every claim below comes from WebSearch snippets of the cited pag…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…"
    },
    {
      "type": "workflow_agent",
      "index": 5,
      "label": "research:roblox_tech",
      "phaseIndex": 1,
      "phaseTitle": "Research",
      "agentId": "ade0e890ef1daadd7",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580435,
      "lastProgressAt": 1792363580435,
      "cached": true,
      "resultPreview": "{\"topic\":\"Roblox technical paths for imported character and environment meshes (2025-2026): importer limits, asset upload/ownership, Rojo, skinned Bones vs Motor6D rigs, EditableMesh, Open Cloud Assets API, texture/triangle budgets for crowds. Access note: create.roblox.com and devforum.roblox.com were blocked by the proxy (CONNECT 403 / DNS failure). Official Creator Hub text was read from its so…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…"
    },
    {
      "type": "workflow_agent",
      "index": 6,
      "label": "verify:quaternius",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "ad5dfa26fd14bfbf6",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580490,
      "queuedAt": 1792363580436,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "Skeptic re-check: Quaternius licences (CC0 vs QAL v1.0), re…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792364309619,
      "tokens": 186163,
      "toolCalls": 89,
      "durationMs": 729127,
      "resultPreview": "{\"topic\":\"Skeptic re-check: Quaternius licences (CC0 vs QAL v1.0), redistribution, prices, measured mesh/rig data, download sources and public-repo commits for AI Kingdoms (Roblox)\",\"claims\":[{\"claim\":\"ACCESS NOTE, CONFIRMED by my own run on 2026-10-18. WebFetch failed with ENOTFOUND for quaternius.com/license.html, quaternius.itch.io, patreon.com, x.com, opengameart.org, app.cinevva.com, creative…"
    },
    {
      "type": "workflow_agent",
      "index": 7,
      "label": "verify:kenney",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "a1c541d5e2d4d0b6f",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792363580491,
      "queuedAt": 1792363580437,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "Kenney (kenney.nl): skeptic re-check of license, redistribu…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792364094621,
      "tokens": 168537,
      "toolCalls": 75,
      "durationMs": 512152,
      "resultPreview": "{\"topic\":\"Kenney (kenney.nl): skeptic re-check of license, redistribution, price, pack contents, formats, triangle counts, rigs, download sources and Roblox fit for AI Kingdoms (aerial strategy view, public ForgeLoop repo)\",\"claims\":[{\"claim\":\"[CONFIRMED, with one addition] Access note. kenney.nl, kenney.itch.io, itch.io and opengameart.org are blocked from this agent too: WebFetch gives ENOTFOUND…"
    },
    {
      "type": "workflow_agent",
      "index": 8,
      "label": "verify:creator_store",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "ac443b3b69fd13bf2",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792364096652,
      "queuedAt": 1792363580438,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "Roblox Creator Store (renamed from 'Creator Marketplace' ar…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792364395861,
      "tokens": 131731,
      "toolCalls": 45,
      "durationMs": 299208,
      "resultPreview": "{\"topic\":\"Roblox Creator Store (renamed from 'Creator Marketplace' around Jan 2024; reached in Studio through the Toolbox window, so not 'formerly Toolbox'): licence/terms for using store models, judging creators, free-model risks and safe vetting, redistribution/re-upload/public-repo limits, official Roblox medieval/character assets, mesh moderation and IP policy. This is a skeptic re-check of th…"
    },
    {
      "type": "workflow_agent",
      "index": 9,
      "label": "verify:synty",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "a7f8e38888d85b7ed",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792364311435,
      "queuedAt": 1792363580439,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "Skeptic re-check of 'synty' findings (Synty POLYGON/Sidekic…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792364712115,
      "tokens": 154249,
      "toolCalls": 78,
      "durationMs": 400680,
      "resultPreview": "{\"topic\":\"Skeptic re-check of 'synty' findings (Synty POLYGON/Sidekick licences, Roblox position, redistribution, prices, Roblox technical limits, alternatives). Access note: WebFetch and curl to syntystore.com, syntystudios.com, fab.com, create.roblox.com, devforum.roblox.com, kaylousberg.itch.io and web.archive.org all failed (ENOTFOUND, or proxy CONNECT 403). github.com, raw.githubusercontent.c…"
    },
    {
      "type": "workflow_agent",
      "index": 10,
      "label": "verify:roblox_tech",
      "phaseIndex": 2,
      "phaseTitle": "Verify",
      "agentId": "a259f9c92586fdafc",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792364397558,
      "queuedAt": 1792363580439,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "roblox_tech, skeptic re-check (2026-10-18). Roblox technica…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792364973074,
      "tokens": 183518,
      "toolCalls": 83,
      "durationMs": 575515,
      "resultPreview": "{\"topic\":\"roblox_tech, skeptic re-check (2026-10-18). Roblox technical paths for imported character and environment meshes: importer limits, asset upload and ownership, Rojo, skinned Bones vs Motor6D rigs, EditableMesh, Open Cloud Assets API, texture and triangle budgets for crowds. Access note: in this re-check WebFetch to create.roblox.com, devforum.roblox.com, rojo.space and creation.dev all fa…"
    },
    {
      "type": "workflow_agent",
      "index": 11,
      "label": "synthesis",
      "phaseIndex": 3,
      "phaseTitle": "Synthesize",
      "agentId": "a7a2bb7648fff344e",
      "model": "claude-opus-5-5",
      "state": "done",
      "startedAt": 1792364974918,
      "queuedAt": 1792364974912,
      "attempt": 1,
      "lastToolName": "Bash",
      "lastToolSummary": "cd /tmp/claude-0/-home-user/fc880084-fd50-5f9a-a040-0b74fd9…",
      "promptPreview": "Context: AI Kingdoms is a Roblox game (Luau, built with Rojo from a PUBLIC GitHub repo sammysingleton33-bit/ForgeLoop). Citizens are currently procedurally animated rigs of at most 11 primitive Parts joined by Motor6Ds (head, torso, arms, legs, tool), up to ~300 on a server, viewed mostly from an aerial strategy camera and in close-up conversation portraits. The owner wants professional prebuilt a…",
      "promptFramed": true,
      "lastProgressAt": 1792365144597,
      "tokens": 140038,
      "toolCalls": 6,
      "durationMs": 169678,
      "resultPreview": "# AI Kingdoms asset brief for FORGE-00 (2026-10-18)\n\n## A. Sources and style\n**Style: Kenney low-poly, flat-shaded, a 512² palette atlas or flat colours.** Lock it only after an aerial and portrait bpy render; none exists yet.\n\n| Source | Use | Licence | Public repo |\n|---|---|---|---|\n| Kenney Mini Characters, Castle, Fantasy Town 2.0, Nature, Survival kits | citizens, buildings, crops, trees, ro…"
    }
  ],
  "totalTokens": 964236,
  "totalToolCalls": 376
}
