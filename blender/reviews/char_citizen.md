# char_citizen — author review log (D-019)

Generator: `generators/char_citizen.py` (+ shared kit `generators/_char_common.py`), budget `character` (2500).
6 variants: peasant man (red), peasant woman (blue), farmer (green), merchant (yellow), blacksmith (red), elder (blue).
Hero view az 30 / el 10, lineup gap 2.5, gameplay 40 studs.
Scores 1-5: silhouette / variation / readability / proportions / palette / detail / cohesion / tri cost.
Round sheets were copied to the worker scratchpad (`r1/char_citizen_r*.jpg`); the committed
`previews/char_citizen.jpg` is the final full build.

## Round 1 (quick build)
Images: `previews/char_citizen.jpg` (round 1 state), `renders/char_citizen/char_citizen_02_hero.png`, `_04_hero.png`, `_gameplay.png`.
Validation: 6/6 PASS (1634-2148 tris), variation PASS (min 0.159, woman vs elder).
Scores: 4 / 5 / 4 / 4 / 3 / 4 / 3 / 5.
Seen:
- Strong role silhouettes: bucket + hood, dress + basket, straw hat + pitchfork, fur-trimmed coat + hand on hip, leather apron + hammer + beard, hunched robe + stick. Kingdom accents (sash, bodice, neckerchief, hat, bandana, stole) visible at 40 studs.
- Peasant woman: white headscarf + white sleeves read as a bald old person; `tunic_blue` dress + blue bodice doubled the kingdom colour.
- Merchant: the chaperon's liripipe hung out to the side like a jug handle; red coat on a yellow-kingdom merchant could be misread as red kingdom.
- Peasant man: brown hood on a brown tunic -> one brown blob (monk look).
- Farmer: kingdom neckerchief too small to read.
- Elder: forward lean too subtle at 0.2 rad.
Changes:
- Woman: dress `cloth_brown`/`tunic_brown`, scarf `canvas`, red hair fringe under the scarf + braid over the shoulder.
- Merchant: liripipe drapes down the back; coat colour follows the kingdom family (`tunic_red/blue/green`, `tunic_brown` for yellow).
- Peasant man: hood `tunic_green` (brown for the green kingdom), tunic brown or cream.
- Farmer neckerchief enlarged; elder lean 0.3 rad.

## Round 2 (quick build)
Images: `previews/char_citizen.jpg` (round 2 state), `renders/char_citizen/char_citizen_01_hero.png`, `_02_hero.png`.
Validation: 6/6 PASS (1634-2148 tris), variation PASS (min 0.181).
Scores: 4 / 5 / 4 / 4 / 4 / 4 / 3 / 5.
Seen:
- Woman now reads instantly (hair fringe + braid + scarf + apron + basket). Elder's hunch reads. Merchant hat reads as a hat.
- Peasant man: the hair cap pokes through the side of the hood (brown patches on the green hood) — interpenetration artefact.
Changes:
- Removed the hair cap under the peasant man's hood.

## Round 3 = final (full build)
Images: `previews/char_citizen.jpg`, `renders/char_citizen/*_hero.png`, `renders/char_citizen/char_citizen_gameplay.png`.
Validation: 6/6 PASS, 1634-2148 tris (budget 2500), variation PASS (min 0.181, woman vs elder).
Scores: 4 / 5 / 4 / 4 / 4 / 4 / 3 / 5.
Seen:
- Hood artefact fixed (no more hair patches); all six roles read at 40 studs and each carries one clear kingdom accent
  (red sash, blue bodice, green neckerchief, yellow chaperon, red bandana, blue stole).
- Peasant man's hood opening is a flat cut, so one cheek edge of the head shows slightly at the side of the hood.
- Woman and elder wear floor-length skirts: only shoes are modelled below (no hidden legs) — the rig must skin the skirt.
Final self-scores: silhouette 4, variation 5, readability 4, proportions 4, palette 4, detail 4, cohesion 3, tri cost 5.
Remaining weaknesses: hood face-opening cut; elder hair uses `stone_pale` (no grey hair swatch in palette v1);
mitten hands; kingdom accents are small on citizens by design (villagers, not soldiers).
