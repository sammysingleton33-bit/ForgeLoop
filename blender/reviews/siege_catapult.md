# siege_catapult — author review log (D-019)

Images: `previews/siege_catapult.jpg`, `renders/siege_catapult/siege_catapult_red_01_hero.png`,
`renders/siege_catapult/siege_catapult_blue_01_hero.png`, `renders/siege_catapult/siege_catapult_yellow_01_hero.png`,
`renders/siege_catapult/siege_catapult_gameplay.png` (overwritten each round).
Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Builds: red + green = torsion mangonel (rope skein, A-frame with padded stop beam), blue + yellow = hinged
counterweight between two A-frame towers. Extras: red fire brazier, green front timber mantlet (Thornwood
hoardings), yellow gilded domes on the towers (Sunspire), blue compact crisp frame.

## Round 1 (first quick build)
Scores: 4 / 4 / 3 / 4 / 3 / 4 / 4 / 4
Problems seen:
- Torsion arm lay almost flat at rail height: bucket and stone hidden behind the A-frame, so from the front 3/4
  view the red/green engines read as a cart with a goal post.
- Counterweight bucket sat low at the rear, hidden by the winch.
- Kingdom colour only on small pennants/shields: at 40 studs all four engines are the same brown.
- Shields on the counterweight rails were placed over the rear wheel hubs (intersection); stones were
  20-tri icosahedra (too faceted).
Changes: torsion arm cocked at 22-26 deg onto a rear rest trestle, bigger bucket + stone; counterweight tail
raised onto a trestle; winch drums lowered onto bearing blocks; stones subdivided.

## Round 2
Scores: 4 / 4 / 4 / 4 / 3 / 4 / 4 / 4
Problems seen:
- Buckets and stones now visible above the frame, but kingdom identity still weak at gameplay distance.
- Yellow pennant stuck out low at the front next to the wheel (read as debris).
Changes: kingdom cloth drapes along both rails (three pointed tails, trim bands top/bottom) with the heater
shields in front; yellow pennant moved to the top of a tower; wheel tyre profile simplified (6-point ring)
and drape grid trimmed to stay under 4000.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3
Seen: classic catapult silhouettes in two families, kingdom colour now reads from drapes + pennant + shields +
pad/counterweight stripe; spoked iron-tyred wheels, iron straps, rope skein/winch rope all visible.
Remaining weaknesses: tris 3574-3860 / 4000 leave little headroom (wheels are 1000 of it); the torsion arm is
partly hidden by the stop beam in the front 3/4 view; no animation rig (static pose: cocked and loaded).

## Round 4 (bug found while building the ballista/ram)
Problem seen: the heater shields on the rails were rotated the wrong way, so the hero showed their plain
trim-coloured backs (no emblem) facing outwards. Change: shield rotation sign fixed; star/flame/oak/sun
shields now face out over the drapes (checked on `siege_catapult_blue_01_hero.png`). Scores unchanged
(4 / 4 / 4 / 4 / 4 / 4 / 4 / 3), palette read improved.

## Fresh-review round 2 (FORGE-02 lead: NEEDS-WORK, variation 3 / readability 3 / cohesion 3)
Problems reported: red shield showed the retired flame; yellow shield sun read as a purple ring/crescent and
sat behind the A-frame; red/green shared one low chassis and blue/yellow one A-frame; green_01 3956 tris.
Changes:
- Four chassis now: red = low 4-wheel frame (brazier); green = two big rear wheels (R 2.7) + front sled runners
  with upturned noses and iron shoes (Thornwood), drapes dropped, mantlet kept (3416 tris);
  blue = A-frame towers; yellow = tall vertical trestle towers with X-braces, raking struts, bronze cap straps
  and gold ball finials (domes removed).
- Crown on red, new sun (no purple), fields via `field()` / `border()`; side shields moved between the towers and
  the rear wheels, plus a front shield on the nose beam of the counterweight engines.
- Yellow trimmed (lower X-braces, guy ropes) to stay under budget; winch rope coil tagged as rope.
Seen (`siege_catapult_yellow_01_hero.png`, sheet): four different silhouettes (min diff 0.42), every engine
shows its emblem on a visible shield. Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3. Tris 3416-3982 / 4000.
